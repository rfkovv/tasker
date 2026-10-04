import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import '../domain/sync_event.dart';
import '../domain/sync_transport.dart';

/// HTTP implementation of [SyncTransport] against the dumb 8c server
/// (`POST /events`, `GET /events?since=&limit=`).
///
/// Uses `dart:io` [HttpClient] (not `package:http`) because
/// [allowSelfSigned] requires `badCertificateCallback`, which the
/// higher-level package does not expose.
///
/// Config comes from the constructor — no global state, no app_settings
/// reads (wiring lands in 8c-4).
class HttpSyncTransport implements SyncTransport {
  HttpSyncTransport({
    required this.baseUrl,
    required this.apiKey,
    this.allowSelfSigned = false,
    this.connectTimeout = const Duration(seconds: 5),
    this.requestTimeout = const Duration(seconds: 30),
    HttpClient? client,
  }) : _client = client ?? _createClient(allowSelfSigned);

  /// Server base URL, e.g. `http://127.0.0.1:8080`.
  final String baseUrl;

  /// Static Bearer API key (`SYNC_API_KEY` on the server).
  final String apiKey;

  /// DEV ONLY — disables TLS certificate verification for this client.
  ///
  /// Must be passed explicitly (`false` by default). Never enable in
  /// production builds; 8c-4 wires real config and keeps this false.
  final bool allowSelfSigned;

  final Duration connectTimeout;
  final Duration requestTimeout;

  /// Server batch cap — we slice larger push payloads into ≤200 chunks.
  static const maxBatch = 200;

  /// Pull page size (server default/max is 500/1000).
  static const pullLimit = 500;

  final HttpClient _client;

  static HttpClient _createClient(bool allowSelfSigned) {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 5);
    if (allowSelfSigned) {
      client.badCertificateCallback = (cert, host, port) => true;
    }
    return client;
  }

  /// Closes the underlying HTTP client (tests / dispose).
  void close({bool force = false}) {
    _client.close(force: force);
  }

  @override
  Future<void> pushBatch(List<SyncEvent> events) async {
    // Idempotency stance: a retry after a partial failure may duplicate
    // events in the server log. That is accepted — client LWW merge
    // dedupes by (tableName, rowId), so duplicates are harmless.
    if (events.isEmpty) return;

    for (var i = 0; i < events.length; i += maxBatch) {
      final end = min(i + maxBatch, events.length);
      final chunk = events.sublist(i, end);
      await _postChunk(chunk);
    }
  }

  Future<void> _postChunk(List<SyncEvent> chunk) async {
    final body = jsonEncode({
      'events': [
        for (final e in chunk)
          <String, dynamic>{
            'tableName': e.tableName,
            'rowId': e.rowId,
            'payload': e.payload,
          },
      ],
    });

    final response = await _send(
      method: 'POST',
      uri: Uri.parse('$baseUrl/events'),
      body: body,
    );
    await _expectOk(
      response,
      context: 'push batch (${chunk.length} events)',
      requireJsonObject: true,
    );
  }

  @override
  Future<SyncPullResponse> pullSince(String? cursor) async {
    // Pagination loop lives HERE so the engine's pull contract stays
    // "give me everything since cursor" (one call, full result).
    final events = <SyncEvent>[];
    var since = cursor;
    String? nextCursor = cursor;

    while (true) {
      final page = await _getPage(since: since);
      events.addAll(page.events);
      nextCursor = page.nextCursor;
      if (!page.hasMore) break;
      since = page.nextCursor;
      if (since == null) break;
    }

    return SyncPullResponse(events: events, nextCursor: nextCursor);
  }

  Future<({List<SyncEvent> events, String? nextCursor, bool hasMore})>
      _getPage({required String? since}) async {
    final uri = Uri.parse('$baseUrl/events').replace(
      queryParameters: <String, String>{
        'since': since ?? '0',
        'limit': '$pullLimit',
      },
    );

    final response = await _send(method: 'GET', uri: uri);
    final status = response.statusCode;
    final raw = await utf8.decoder.bind(response).join();

    if (status < 200 || status >= 300) {
      throw SyncTransportException(
        'pull failed: HTTP $status${_serverError(raw)}',
      );
    }

    Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException catch (e) {
      throw SyncTransportException('pull failed: malformed JSON ($e)');
    }
    if (decoded is! Map<String, dynamic>) {
      throw SyncTransportException(
        'pull failed: response is not a JSON object',
      );
    }

    final rawEvents = decoded['events'];
    if (rawEvents is! List) {
      throw SyncTransportException('pull failed: missing "events" list');
    }

    final events = <SyncEvent>[];
    for (var i = 0; i < rawEvents.length; i++) {
      final item = rawEvents[i];
      if (item is! Map<String, dynamic>) {
        throw SyncTransportException(
          'pull failed: events[$i] is not an object',
        );
      }
      final tableName = item['tableName'];
      final rowId = item['rowId'];
      final payload = item['payload'];
      if (tableName is! String ||
          tableName.isEmpty ||
          rowId is! String ||
          rowId.isEmpty ||
          payload is! Map<String, dynamic>) {
        throw SyncTransportException(
          'pull failed: events[$i] has bad envelope',
        );
      }
      events.add(
        SyncEvent(
          tableName: tableName,
          rowId: rowId,
          payload: Map<String, dynamic>.from(payload),
        ),
      );
    }

    final nextCursor = decoded['nextCursor'];
    final hasMore = decoded['hasMore'] == true;

    return (
      events: events,
      nextCursor: nextCursor is String ? nextCursor : since,
      hasMore: hasMore,
    );
  }

  Future<HttpClientResponse> _send({
    required String method,
    required Uri uri,
    String? body,
  }) async {
    try {
      final request = await _client.openUrl(method, uri).timeout(
            connectTimeout,
          );
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $apiKey');
      request.headers.contentType = ContentType.json;
      if (body != null) {
        request.write(body);
      }
      return await request.close().timeout(requestTimeout);
    } on TimeoutException catch (e) {
      throw SyncTransportException(
        'HTTP $method ${uri.path} timed out ($e)',
      );
    } on SocketException catch (e) {
      throw SyncTransportException(
        'HTTP $method ${uri.path} network error ($e)',
      );
    } on HandshakeException catch (e) {
      throw SyncTransportException(
        'HTTP $method ${uri.path} TLS error ($e)',
      );
    } on HttpException catch (e) {
      throw SyncTransportException(
        'HTTP $method ${uri.path} failed ($e)',
      );
    } catch (e) {
      throw SyncTransportException(
        'HTTP $method ${uri.path} failed ($e)',
      );
    }
  }

  Future<void> _expectOk(
    HttpClientResponse response, {
    required String context,
    bool requireJsonObject = false,
  }) async {
    final raw = await utf8.decoder.bind(response).join();
    final status = response.statusCode;
    if (status < 200 || status >= 300) {
      throw SyncTransportException(
        '$context failed: HTTP $status${_serverError(raw)}',
      );
    }
    if (!requireJsonObject) return;
    Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      throw SyncTransportException(
        '$context failed: malformed JSON response',
      );
    }
    if (decoded is! Map<String, dynamic>) {
      throw SyncTransportException(
        '$context failed: response is not a JSON object',
      );
    }
  }

  static String _serverError(String rawBody) {
    try {
      final decoded = jsonDecode(rawBody);
      if (decoded is Map<String, dynamic> && decoded['error'] is String) {
        return ' — ${decoded['error']}';
      }
    } on FormatException {
      // fall through
    }
    if (rawBody.isEmpty) return '';
    return ' — $rawBody';
  }
}
