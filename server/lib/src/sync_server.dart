import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'auth.dart';
import 'config.dart';
import 'event_log.dart';

/// Dumb sync-log HTTP server (dart:io only).
///
/// Endpoints:
/// - `POST /events` — body `{ "events": [ {tableName,rowId,payload} ] }`
///   → `{ "accepted": n, "firstSeq": x }`
///   - auth required; >200 events → 413; invalid envelope → 400
/// - `GET /events?since=<seq>&limit=<n>` — auth required
///   → `{ "events": [...], "nextCursor": "<seq>", "hasMore": bool }`
///   - **since is exclusive** (seq > since); missing/0 = full log
///   - default limit 500, max 1000
/// - `GET /health` — no auth → `{ "ok": true, "lastSeq": n }`
///
/// The server never inspects payload contents, table names, or merge
/// semantics. It validates auth + envelope shape, assigns seq, appends,
/// serves.
class SyncServer {
  SyncServer({
    required this.config,
    required this.log,
    HttpServer? server,
  }) : _server = server;

  static const maxBatch = 200;
  static const defaultLimit = 500;
  static const maxLimit = 1000;

  final ServerConfig config;
  final EventLog log;
  HttpServer? _server;

  /// In-flight request counter (graceful shutdown waits for 0).
  int _inFlight = 0;

  final _idle = Completer<void>();

  bool _shuttingDown = false;

  HttpServer get server {
    final s = _server;
    if (s == null) {
      throw StateError('SyncServer.start() has not been called');
    }
    return s;
  }

  int get port => server.port;

  /// Binds and serves. Returns when the socket is listening.
  Future<void> start() async {
    final bound = await HttpServer.bind(config.host, config.port);
    _server = bound;
    if (!config.useTls) {
      stderr.writeln(
        'WARNING: SYNC_CERT_PATH/SYNC_KEY_PATH not set — serving plain '
        'HTTP on ${config.host}:${config.port}. Do not expose publicly.',
      );
    }
    if (config.apiKey.isEmpty) {
      stderr.writeln(
        'WARNING: SYNC_API_KEY is empty — POST/GET /events will always '
        'return 401. /health remains open.',
      );
    }
    _serve(bound);
  }

  Future<void> _serve(HttpServer bound) async {
    try {
      await for (final request in bound) {
        if (_shuttingDown) {
          await _respond(request, HttpStatus.serviceUnavailable, {
            'error': 'shutting down',
          });
          continue;
        }
        unawaited(_handle(request));
      }
    } on HttpException {
      // Socket closed during shutdown — expected.
    }
  }

  Future<void> _handle(HttpRequest request) async {
    _inFlight++;
    final sw = Stopwatch()..start();
    var status = 500;
    try {
      status = await _route(request);
    } catch (error) {
      status = HttpStatus.internalServerError;
      await _respond(request, status, {'error': 'internal error'});
      stderr.writeln('ERROR ${request.uri.path}: $error');
    } finally {
      sw.stop();
      stdout.writeln(
        '${request.method} ${request.uri} → $status (${sw.elapsedMilliseconds}ms)',
      );
      _inFlight--;
      if (_shuttingDown && _inFlight == 0 && !_idle.isCompleted) {
        _idle.complete();
      }
    }
  }

  Future<int> _route(HttpRequest request) async {
    final path = request.uri.path;
    final method = request.method.toUpperCase();

    if (path == '/health' && method == 'GET') {
      await _respond(request, HttpStatus.ok, <String, dynamic>{
        'ok': true,
        'lastSeq': log.lastSeq,
      });
      return HttpStatus.ok;
    }

    if (path == '/events') {
      if (!_authorized(request)) {
        await _respond(request, HttpStatus.unauthorized, <String, dynamic>{
          'error': 'unauthorized',
        });
        return HttpStatus.unauthorized;
      }
      if (method == 'POST') return _handlePush(request);
      if (method == 'GET') return _handlePull(request);
      await _respond(request, HttpStatus.methodNotAllowed, <String, dynamic>{
        'error': 'method not allowed',
      });
      return HttpStatus.methodNotAllowed;
    }

    await _respond(request, HttpStatus.notFound, <String, dynamic>{
      'error': 'not found',
    });
    return HttpStatus.notFound;
  }

  bool _authorized(HttpRequest request) {
    final token = bearerToken(request.headers.value(HttpHeaders.authorizationHeader));
    if (token == null) return false;
    return isValidApiKey(provided: token, expected: config.apiKey);
  }

  Future<int> _handlePush(HttpRequest request) async {
    final body = await utf8.decoder.bind(request).join();
    Object? decoded;
    try {
      decoded = body.isEmpty ? null : jsonDecode(body);
    } on FormatException {
      await _respond(request, HttpStatus.badRequest, <String, dynamic>{
        'error': 'invalid JSON',
      });
      return HttpStatus.badRequest;
    }
    if (decoded is! Map<String, dynamic>) {
      await _respond(request, HttpStatus.badRequest, <String, dynamic>{
        'error': 'body must be a JSON object',
      });
      return HttpStatus.badRequest;
    }
    final events = decoded['events'];
    if (events is! List) {
      await _respond(request, HttpStatus.badRequest, <String, dynamic>{
        'error': 'missing or invalid "events" list',
      });
      return HttpStatus.badRequest;
    }
    if (events.isEmpty) {
      await _respond(request, HttpStatus.badRequest, <String, dynamic>{
        'error': '"events" must be non-empty',
      });
      return HttpStatus.badRequest;
    }
    if (events.length > maxBatch) {
      await _respond(request, HttpStatus.requestEntityTooLarge, <String, dynamic>{
        'error': 'batch exceeds $maxBatch events',
        'maxBatch': maxBatch,
        'received': events.length,
      });
      return HttpStatus.requestEntityTooLarge;
    }

    final envelopes = <({String tableName, String rowId, Map<String, dynamic> payload})>[];
    for (var i = 0; i < events.length; i++) {
      final raw = events[i];
      if (raw is! Map<String, dynamic>) {
        await _respond(request, HttpStatus.badRequest, <String, dynamic>{
          'error': 'events[$i] must be an object',
        });
        return HttpStatus.badRequest;
      }
      final tableName = raw['tableName'];
      final rowId = raw['rowId'];
      final payload = raw['payload'];
      if (tableName is! String || tableName.isEmpty) {
        await _respond(request, HttpStatus.badRequest, <String, dynamic>{
          'error': 'events[$i].tableName must be a non-empty string',
        });
        return HttpStatus.badRequest;
      }
      if (rowId is! String || rowId.isEmpty) {
        await _respond(request, HttpStatus.badRequest, <String, dynamic>{
          'error': 'events[$i].rowId must be a non-empty string',
        });
        return HttpStatus.badRequest;
      }
      if (payload is! Map<String, dynamic>) {
        await _respond(request, HttpStatus.badRequest, <String, dynamic>{
          'error': 'events[$i].payload must be an object',
        });
        return HttpStatus.badRequest;
      }
      envelopes.add((
        tableName: tableName,
        rowId: rowId,
        payload: Map<String, dynamic>.from(payload),
      ));
    }

    final written = await log.append(envelopes);
    await _respond(request, HttpStatus.ok, <String, dynamic>{
      'accepted': written.length,
      'firstSeq': written.first.seq,
      'lastSeq': written.last.seq,
    });
    return HttpStatus.ok;
  }

  Future<int> _handlePull(HttpRequest request) async {
    final params = request.uri.queryParameters;
    final sinceRaw = params['since'] ?? '0';
    final limitRaw = params['limit'];

    final since = int.tryParse(sinceRaw);
    if (since == null || since < 0) {
      await _respond(request, HttpStatus.badRequest, <String, dynamic>{
        'error': '"since" must be a non-negative integer',
      });
      return HttpStatus.badRequest;
    }

    var limit = defaultLimit;
    if (limitRaw != null) {
      final parsed = int.tryParse(limitRaw);
      if (parsed == null || parsed <= 0) {
        await _respond(request, HttpStatus.badRequest, <String, dynamic>{
          'error': '"limit" must be a positive integer',
        });
        return HttpStatus.badRequest;
      }
      limit = parsed > maxLimit ? maxLimit : parsed;
    }

    final result = await log.readSince(since: since, limit: limit);
    final events = [
      for (final record in result.records) record.toJson(),
    ];
    final nextCursor = result.records.isNotEmpty
        ? result.records.last.seq.toString()
        : since.toString();

    await _respond(request, HttpStatus.ok, <String, dynamic>{
      'events': events,
      'nextCursor': nextCursor,
      'hasMore': result.hasMore,
    });
    return HttpStatus.ok;
  }

  Future<void> _respond(
    HttpRequest request,
    int status,
    Map<String, dynamic> body,
  ) async {
    try {
      request.response.statusCode = status;
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode(body));
      await request.response.close();
    } on HttpException {
      // Client disconnected mid-response — ignore.
    }
  }

  /// Graceful shutdown: stop accepting, finish in-flight, flush, close.
  Future<void> stop() async {
    if (_shuttingDown) return;
    _shuttingDown = true;
    final s = _server;
    if (s != null) {
      await s.close(force: false);
    }
    if (_inFlight > 0) {
      await _idle.future.timeout(const Duration(seconds: 10));
    }
    await log.close();
  }
}
