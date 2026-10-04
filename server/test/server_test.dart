import 'dart:convert';
import 'dart:io';

import 'package:taskmaster_sync_server/server.dart';
import 'package:test/test.dart';

/// In-process test harness: real HttpServer on an ephemeral port.
class Harness {
  Harness._(this.server, this.client, this.baseUrl);

  final SyncServer server;
  final HttpClient client;
  final String baseUrl;

  static Future<Harness> start({
    required String logPath,
    String apiKey = 'test-key',
  }) async {
    final config = ServerConfig(
      port: 0, // ephemeral
      host: '127.0.0.1',
      apiKey: apiKey,
      logPath: logPath,
    );
    final log = await EventLog.open(logPath);
    final server = SyncServer(config: config, log: log);
    await server.start();
    final baseUrl = 'http://127.0.0.1:${server.port}';
    return Harness._(server, HttpClient(), baseUrl);
  }

  Future<void> stop() async {
    client.close(force: true);
    await server.stop();
  }

  Future<HttpClientResponse> postEvents(
    Object body, {
    String? token,
  }) async {
    final request = await client.postUrl(Uri.parse('$baseUrl/events'));
    if (token != null) {
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
    }
    request.headers.contentType = ContentType.json;
    request.write(jsonEncode(body));
    return request.close();
  }

  Future<HttpClientResponse> getEvents({
    String? since,
    int? limit,
    String? token,
  }) async {
    final params = <String, String>{};
    if (since != null) params['since'] = since;
    if (limit != null) params['limit'] = '$limit';
    final uri = Uri.parse('$baseUrl/events').replace(queryParameters: params.isEmpty ? null : params);
    final request = await client.getUrl(uri);
    if (token != null) {
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
    }
    return request.close();
  }

  Future<HttpClientResponse> getHealth() async {
    final request = await client.getUrl(Uri.parse('$baseUrl/health'));
    return request.close();
  }
}

Map<String, dynamic> event(
  String tableName,
  String rowId, {
  Map<String, dynamic>? payload,
}) {
  return <String, dynamic>{
    'tableName': tableName,
    'rowId': rowId,
    'payload': payload ?? <String, dynamic>{'id': rowId, 'title': 'x'},
  };
}

Future<Map<String, dynamic>> readJson(HttpClientResponse response) async {
  final body = await utf8.decoder.bind(response).join();
  return jsonDecode(body) as Map<String, dynamic>;
}

Future<Directory> tempDir() async {
  final dir = await Directory.systemTemp.createTemp('sync_server_test_');
  addTearDown(() async {
    if (await dir.exists()) await dir.delete(recursive: true);
  });
  return dir;
}

void main() {
  const apiKey = 'test-key';

  group('health', () {
    test('GET /health returns ok and lastSeq without auth', () async {
      final dir = await tempDir();
      final h = await Harness.start(
        logPath: '${dir.path}/log.ndjson',
        apiKey: apiKey,
      );
      addTearDown(h.stop);

      final res = await h.getHealth();
      expect(res.statusCode, HttpStatus.ok);
      final json = await readJson(res);
      expect(json['ok'], isTrue);
      expect(json['lastSeq'], 0);
    });
  });

  group('auth', () {
    test('POST /events without key → 401', () async {
      final dir = await tempDir();
      final h = await Harness.start(
        logPath: '${dir.path}/log.ndjson',
        apiKey: apiKey,
      );
      addTearDown(h.stop);

      final res = await h.postEvents({
        'events': [event('tasks', 't1')],
      });
      expect(res.statusCode, HttpStatus.unauthorized);
    });

    test('POST /events with wrong key → 401', () async {
      final dir = await tempDir();
      final h = await Harness.start(
        logPath: '${dir.path}/log.ndjson',
        apiKey: apiKey,
      );
      addTearDown(h.stop);

      final res = await h.postEvents(
        {'events': [event('tasks', 't1')]},
        token: 'wrong-key',
      );
      expect(res.statusCode, HttpStatus.unauthorized);
    });

    test('POST /events with correct key → 200', () async {
      final dir = await tempDir();
      final h = await Harness.start(
        logPath: '${dir.path}/log.ndjson',
        apiKey: apiKey,
      );
      addTearDown(h.stop);

      final res = await h.postEvents(
        {'events': [event('tasks', 't1')]},
        token: apiKey,
      );
      expect(res.statusCode, HttpStatus.ok);
      final json = await readJson(res);
      expect(json['accepted'], 1);
      expect(json['firstSeq'], 1);
    });

    test('GET /events without key → 401', () async {
      final dir = await tempDir();
      final h = await Harness.start(
        logPath: '${dir.path}/log.ndjson',
        apiKey: apiKey,
      );
      addTearDown(h.stop);

      final res = await h.getEvents(since: '0');
      expect(res.statusCode, HttpStatus.unauthorized);
    });
  });

  group('envelope validation', () {
    late Harness h;

    setUp(() async {
      final dir = await tempDir();
      h = await Harness.start(
        logPath: '${dir.path}/log.ndjson',
        apiKey: apiKey,
      );
    });

    tearDown(() => h.stop());

    Future<int> postRaw(String body) async {
      final request = await h.client.postUrl(Uri.parse('${h.baseUrl}/events'));
      request.headers
        ..set(HttpHeaders.authorizationHeader, 'Bearer $apiKey')
        ..contentType = ContentType.json;
      request.write(body);
      final res = await request.close();
      await res.drain<void>();
      return res.statusCode;
    }

    test('invalid JSON → 400', () async {
      expect(await postRaw('not-json'), HttpStatus.badRequest);
    });

    test('missing events list → 400', () async {
      expect(await postRaw('{}'), HttpStatus.badRequest);
    });

    test('empty events list → 400', () async {
      expect(
        await postRaw('{"events":[]}'),
        HttpStatus.badRequest,
      );
    });

    test('event missing tableName → 400', () async {
      final res = await h.postEvents(
        {
          'events': [
            {'rowId': 't1', 'payload': <String, dynamic>{}},
          ],
        },
        token: apiKey,
      );
      expect(res.statusCode, HttpStatus.badRequest);
    });

    test('event missing rowId → 400', () async {
      final res = await h.postEvents(
        {
          'events': [
            {'tableName': 'tasks', 'payload': <String, dynamic>{}},
          ],
        },
        token: apiKey,
      );
      expect(res.statusCode, HttpStatus.badRequest);
    });

    test('event payload not an object → 400', () async {
      final res = await h.postEvents(
        {
          'events': [
            {'tableName': 'tasks', 'rowId': 't1', 'payload': 'nope'},
          ],
        },
        token: apiKey,
      );
      expect(res.statusCode, HttpStatus.badRequest);
    });
  });

  group('batch size limit', () {
    test('POST /events with >200 events → 413', () async {
      final dir = await tempDir();
      final h = await Harness.start(
        logPath: '${dir.path}/log.ndjson',
        apiKey: apiKey,
      );
      addTearDown(h.stop);

      final events = [
        for (var i = 0; i < 201; i++) event('tasks', 't$i'),
      ];
      final res = await h.postEvents({'events': events}, token: apiKey);
      expect(res.statusCode, HttpStatus.requestEntityTooLarge);
      final json = await readJson(res);
      expect(json['maxBatch'], 200);
      expect(json['received'], 201);
    });

    test('POST /events with exactly 200 events → 200', () async {
      final dir = await tempDir();
      final h = await Harness.start(
        logPath: '${dir.path}/log.ndjson',
        apiKey: apiKey,
      );
      addTearDown(h.stop);

      final events = [
        for (var i = 0; i < 200; i++) event('tasks', 't$i'),
      ];
      final res = await h.postEvents({'events': events}, token: apiKey);
      expect(res.statusCode, HttpStatus.ok);
      final json = await readJson(res);
      expect(json['accepted'], 200);
      expect(json['firstSeq'], 1);
      expect(json['lastSeq'], 200);
    });
  });

  group('seq monotonicity across restart', () {
    test('restart continues seq; events survive', () async {
      final dir = await tempDir();
      final logPath = '${dir.path}/log.ndjson';

      final h1 = await Harness.start(logPath: logPath, apiKey: apiKey);
      final res1 = await h1.postEvents(
        {
          'events': [
            event('tasks', 'a'),
            event('tags', 'b'),
          ],
        },
        token: apiKey,
      );
      final json1 = await readJson(res1);
      expect(json1['firstSeq'], 1);
      expect(json1['lastSeq'], 2);
      await h1.stop();

      // Restart: new EventLog + server on the same path.
      final h2 = await Harness.start(logPath: logPath, apiKey: apiKey);
      addTearDown(h2.stop);

      final res2 = await h2.postEvents(
        {'events': [event('comments', 'c')]},
        token: apiKey,
      );
      final json2 = await readJson(res2);
      expect(json2['firstSeq'], 3, reason: 'seq continues after restart');

      final pull = await h2.getEvents(since: '0', token: apiKey);
      final pullJson = await readJson(pull);
      final events = pullJson['events'] as List;
      expect(events, hasLength(3));
      expect(events[0]['seq'], 1);
      expect(events[1]['seq'], 2);
      expect(events[2]['seq'], 3);
    });
  });

  group('pagination (since exclusive)', () {
    late Harness h;

    setUp(() async {
      final dir = await tempDir();
      h = await Harness.start(
        logPath: '${dir.path}/log.ndjson',
        apiKey: apiKey,
      );
      // 10 events, seq 1..10
      await h.postEvents(
        {
          'events': [
            for (var i = 1; i <= 10; i++) event('tasks', 't$i'),
          ],
        },
        token: apiKey,
      );
    });

    tearDown(() => h.stop());

    test('since=0 returns full page from the start', () async {
      final res = await h.getEvents(since: '0', limit: 3, token: apiKey);
      final json = await readJson(res);
      final events = json['events'] as List;
      expect(events.map((e) => e['seq']), [1, 2, 3]);
      expect(json['nextCursor'], '3');
      expect(json['hasMore'], isTrue);
    });

    test('since is exclusive — no gaps, no duplicates across pages', () async {
      final seqs = <int>[];
      var since = '0';
      var pages = 0;
      while (true) {
        final res = await h.getEvents(since: since, limit: 4, token: apiKey);
        final json = await readJson(res);
        final events = json['events'] as List;
        for (final e in events) {
          seqs.add(e['seq'] as int);
        }
        pages++;
        if (json['hasMore'] != true) break;
        since = json['nextCursor'] as String;
        expect(pages, lessThan(10), reason: 'pagination must terminate');
      }

      expect(seqs, [1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
          reason: 'no gaps, no duplicates');
      expect(pages, 3);
    });

    test('since at last seq returns empty page, cursor unchanged', () async {
      final res = await h.getEvents(since: '10', token: apiKey);
      final json = await readJson(res);
      expect(json['events'], isEmpty);
      expect(json['nextCursor'], '10');
      expect(json['hasMore'], isFalse);
    });

    test('limit above max is clamped to 1000', () async {
      final res = await h.getEvents(since: '0', limit: 5000, token: apiKey);
      final json = await readJson(res);
      expect(json['events'], hasLength(10));
    });

    test('invalid since → 400', () async {
      final res = await h.getEvents(since: 'abc', token: apiKey);
      expect(res.statusCode, HttpStatus.badRequest);
    });
  });

  group('durability', () {
    test('acknowledged event present after process-style restart', () async {
      final dir = await tempDir();
      final logPath = '${dir.path}/log.ndjson';

      final h1 = await Harness.start(logPath: logPath, apiKey: apiKey);
      final res = await h1.postEvents(
        {
          'events': [
            event('tasks', 'keep-me', payload: {
              'id': 'keep-me',
              'title': 'durable',
              'updatedAt': 123,
            }),
          ],
        },
        token: apiKey,
      );
      expect(res.statusCode, HttpStatus.ok);
      // Ack implies flush — kill the "process" without extra teardown.
      await h1.server.log.close();
      h1.client.close(force: true);

      final h2 = await Harness.start(logPath: logPath, apiKey: apiKey);
      addTearDown(h2.stop);

      final pull = await h2.getEvents(since: '0', token: apiKey);
      final json = await readJson(pull);
      final events = json['events'] as List;
      expect(events, hasLength(1));
      expect(events[0]['rowId'], 'keep-me');
      expect(events[0]['payload']['title'], 'durable');
    });
  });
}
