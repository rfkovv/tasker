import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskmaster/features/sync/sync.dart';
import 'package:taskmaster/features/tasks/data/comment_repository_impl.dart';
import 'package:taskmaster/features/tasks/data/task_repository_impl.dart';
import 'package:taskmaster/features/tasks/domain/task.dart';
import 'package:taskmaster/features/tasks/domain/task_priority.dart';
import 'package:taskmaster/features/tasks/domain/task_status.dart';
import 'package:taskmaster/local_db/database.dart' as db;

/// Resolves a `dart` executable usable under both `dart test` and
/// `flutter test` (the latter's `Platform.resolvedExecutable` is
/// flutter_tester, not dart).
String resolveDartExecutable() {
  final resolved = Platform.resolvedExecutable;
  final name = resolved.split(Platform.pathSeparator).last;
  if (name == 'dart' || name == 'dart.exe') return resolved;

  final path = Platform.environment['PATH'] ?? '';
  for (final dir in path.split(Platform.pathSeparator)) {
    if (dir.isEmpty) continue;
    final candidate = '$dir${Platform.pathSeparator}dart';
    if (File(candidate).existsSync()) return candidate;
    final exe = '$candidate.exe';
    if (File(exe).existsSync()) return exe;
  }

  final flutterRoot = Platform.environment['FLUTTER_ROOT'];
  if (flutterRoot != null) {
    final dart = '$flutterRoot${Platform.pathSeparator}bin'
        '${Platform.pathSeparator}dart';
    if (File(dart).existsSync()) return dart;
  }
  throw StateError('dart executable not found on PATH');
}

String serverDir() {
  // flutter test / dart test both run with cwd = package root.
  final dir = Directory('server');
  if (dir.existsSync()) return dir.absolute.path;
  throw StateError('server/ not found from ${Directory.current.path}');
}

Future<int> freePort() async {
  final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  final port = socket.port;
  await socket.close();
  return port;
}

class ServerProcess {
  ServerProcess._(this.process, this.port, this.apiKey, this.logPath);

  final Process process;
  final int port;
  final String apiKey;
  final String logPath;

  String get baseUrl => 'http://127.0.0.1:$port';

  static Future<ServerProcess> start({
    required String apiKey,
    String? logPath,
  }) async {
    final port = await freePort();
    final log = logPath ?? '${Directory.systemTemp.path}/sync_test_$port.ndjson';
    final process = await Process.start(
      resolveDartExecutable(),
      ['run', 'bin/server.dart'],
      workingDirectory: serverDir(),
      environment: <String, String>{
        ...Platform.environment,
        'SYNC_HOST': '127.0.0.1',
        'SYNC_PORT': '$port',
        'SYNC_API_KEY': apiKey,
        'SYNC_LOG_PATH': log,
      },
    );

    final ready = Completer<void>();
    process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
      // ignore: avoid_print
      print('[sync-server] $line');
      if (line.contains('listening on') && !ready.isCompleted) {
        ready.complete();
      }
    });
    process.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
      // ignore: avoid_print
      print('[sync-server:err] $line');
    });

    try {
      await ready.future.timeout(const Duration(seconds: 20));
    } on TimeoutException {
      process.kill(ProcessSignal.sigkill);
      throw StateError('sync server did not report readiness in time');
    }

    return ServerProcess._(process, port, apiKey, log);
  }

  Future<void> stop() async {
    if (_stopped) return;
    _stopped = true;
    process.kill(ProcessSignal.sigterm);
    try {
      await process.exitCode.timeout(const Duration(seconds: 5));
    } on TimeoutException {
      process.kill(ProcessSignal.sigkill);
    }
  }

  var _stopped = false;
}

SyncEvent makeEvent(int i, {String table = 'tasks'}) {
  return SyncEvent(
    tableName: table,
    rowId: 'row-$i',
    payload: <String, dynamic>{
      'id': 'row-$i',
      'title': 'title-$i',
      'seqHint': i,
      'updatedAt': 1000 + i,
    },
  );
}

Task buildTask({
  required String id,
  String title = 'T',
  DateTime? updatedAt,
}) {
  final now = updatedAt ?? DateTime.utc(2026, 1, 1);
  return Task(
    id: id,
    title: title,
    description: 'desc',
    tags: const <String>[],
    priority: TaskPriority.medium,
    status: TaskStatus.todo,
    createdAt: now.subtract(const Duration(minutes: 5)),
    updatedAt: now,
  );
}

class _Device {
  _Device(this.label, this.transport) {
    database = db.AppDatabase(NativeDatabase.memory());
    taskRepository = TaskRepositoryImpl(
      database: database,
      ownerIdLoader: () async => 'owner-$label',
    );
    commentRepository = CommentRepositoryImpl(dao: database.commentsDao);
    pushEngine = SyncPushEngineImpl(
      database: database,
      transport: transport,
    );
    pullEngine = SyncPullEngineImpl(
      database: database,
      transport: transport,
    );
  }

  final String label;
  final SyncTransport transport;
  late final db.AppDatabase database;
  late final TaskRepositoryImpl taskRepository;
  late final CommentRepositoryImpl commentRepository;
  late final SyncPushEngineImpl pushEngine;
  late final SyncPullEngineImpl pullEngine;

  Future<void> close() => database.close();

  Future<List<db.SyncOutboxData>> outbox() {
    return database.select(database.syncOutbox).get();
  }

  Future<db.Task?> taskRow(String id) {
    return (database.select(database.tasks)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }
}

void main() {
  const apiKey = 'http-transport-test-key';
  late ServerProcess server;
  late HttpSyncTransport transport;

  setUp(() async {
    server = await ServerProcess.start(apiKey: apiKey);
    transport = HttpSyncTransport(
      baseUrl: server.baseUrl,
      apiKey: apiKey,
      allowSelfSigned: false,
    );
  });

  tearDown(() async {
    transport.close(force: true);
    await server.stop();
  });

  test('pushBatch → 200; pullSince round-trips envelope exactly', () async {
    final events = [
      makeEvent(1),
      makeEvent(2, table: 'tags')..payload['name'] = 'work',
      makeEvent(3, table: 'comments')
        ..payload['body'] = 'hello'
        ..payload['deletedAt'] = null,
    ];

    await transport.pushBatch(events);

    final response = await transport.pullSince(null);
    expect(response.events, hasLength(3));

    for (var i = 0; i < events.length; i++) {
      expect(response.events[i].tableName, events[i].tableName);
      expect(response.events[i].rowId, events[i].rowId);
      expect(
        response.events[i].payload,
        events[i].payload,
        reason: 'payload JSON semantics must round-trip exactly',
      );
    }
    expect(response.nextCursor, isNotNull);
  });

  test('chunking: push 450 events → 3 POSTs; pull returns all in order',
      () async {
    final events = [for (var i = 0; i < 450; i++) makeEvent(i)];

    await transport.pushBatch(events);

    // Verify via a fresh pull — order preserved, all present.
    final response = await transport.pullSince(null);
    expect(response.events, hasLength(450));
    for (var i = 0; i < 450; i++) {
      expect(response.events[i].rowId, 'row-$i', reason: 'order at $i');
    }

    // Confirm server saw 3 chunks by checking lastSeq via health.
    final health = await _getHealth(server.baseUrl);
    expect(health['lastSeq'], 450);
  });

  test('pullSince pagination: 1200 events in one call; second pull empty',
      () async {
    final events = [for (var i = 0; i < 1200; i++) makeEvent(i)];
    // Seed via multiple pushes (server batch cap 200).
    for (var i = 0; i < events.length; i += 200) {
      await transport.pushBatch(
        events.sublist(i, i + 200 > events.length ? events.length : i + 200),
      );
    }

    final first = await transport.pullSince(null);
    expect(first.events, hasLength(1200));
    expect(first.nextCursor, '1200');
    expect(first.events.first.rowId, 'row-0');
    expect(first.events.last.rowId, 'row-1199');

    final second = await transport.pullSince(first.nextCursor);
    expect(second.events, isEmpty);
    expect(second.nextCursor, '1200');
  });

  test('since is exclusive: pull since seq of 3rd → only events 4,5',
      () async {
    await transport.pushBatch([
      makeEvent(1),
      makeEvent(2),
      makeEvent(3),
      makeEvent(4),
      makeEvent(5),
    ]);

    final all = await transport.pullSince(null);
    expect(all.events, hasLength(5));
    // Events are seq 1..5; cursor after the 3rd is "3".
    final afterThird = await transport.pullSince('3');
    expect(afterThird.events, hasLength(2));
    expect(afterThird.events[0].rowId, 'row-4');
    expect(afterThird.events[1].rowId, 'row-5');
    expect(afterThird.nextCursor, '5');
  });

  test('auth: wrong key throws; no key throws', () async {
    final bad = HttpSyncTransport(
      baseUrl: server.baseUrl,
      apiKey: 'wrong-key',
    );
    addTearDown(() => bad.close(force: true));
    await expectLater(
      bad.pushBatch([makeEvent(1)]),
      throwsA(isA<SyncTransportException>()),
    );
    await expectLater(
      bad.pullSince(null),
      throwsA(isA<SyncTransportException>()),
    );

    final missing = HttpSyncTransport(baseUrl: server.baseUrl, apiKey: '');
    addTearDown(() => missing.close(force: true));
    await expectLater(
      missing.pushBatch([makeEvent(1)]),
      throwsA(isA<SyncTransportException>()),
    );
  });

  test('server down: pushBatch throws; engine outbox stays intact', () async {
    final database = db.AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final engine = SyncPushEngineImpl(
      database: database,
      transport: transport,
    );

    await database.into(database.tasks).insert(
          db.TasksCompanion.insert(
            id: 't1',
            title: 'keep me',
            status: const Value('todo'),
            ownerId: 'o',
            createdAt: 1000,
            updatedAt: 2000,
          ),
        );
    await database.enqueueSyncEvent('tasks', 't1');

    // Kill the real server.
    await server.stop();

    await expectLater(
      engine.pushOutbox(),
      throwsA(isA<SyncTransportException>()),
    );

    final outbox = await database.select(database.syncOutbox).get();
    expect(outbox, hasLength(1), reason: 'outbox intact after transport fail');
  });

  test('malformed response → throws, no silent success', () async {
    final garbage = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => garbage.close(force: true));
    garbage.listen((request) async {
      request.response.statusCode = 200;
      request.response.headers.contentType = ContentType.json;
      request.response.write('this is not json {{{');
      await request.response.close();
    });

    final broken = HttpSyncTransport(
      baseUrl: 'http://127.0.0.1:${garbage.port}',
      apiKey: apiKey,
    );
    addTearDown(() => broken.close(force: true));

    await expectLater(
      broken.pushBatch([makeEvent(1)]),
      throwsA(isA<SyncTransportException>()),
    );
    await expectLater(
      broken.pullSince(null),
      throwsA(isA<SyncTransportException>()),
    );
  });

  test('integration: device A push → device B pull via real HTTP server',
      () async {
    final a = _Device('A', transport);
    final b = _Device('B', transport);
    addTearDown(() async {
      await a.close();
      await b.close();
    });

    final created = await a.taskRepository.create(
      buildTask(id: 't1', title: 'From A', updatedAt: DateTime.utc(2026, 1, 2)),
    );
    await a.commentRepository.create(taskId: 't1', body: 'hello from A');
    await a.pushEngine.pushOutbox();
    expect(await a.outbox(), isEmpty);

    final summary = await b.pullEngine.pullAndMerge();
    expect(summary.applied, greaterThanOrEqualTo(2));

    final row = await b.taskRow(created.id);
    expect(row, isNotNull);
    expect(row!.title, 'From A');
    expect(await b.outbox(), isEmpty, reason: 'no echo on pull');

    // B edits and pushes back; A pulls.
    await b.taskRepository.update(
      buildTask(
        id: 't1',
        title: 'B revision',
        updatedAt: DateTime.utc(2026, 1, 3),
      ),
    );
    await b.pushEngine.pushOutbox();

    final aSummary = await a.pullEngine.pullAndMerge();
    expect(aSummary.applied, 1);
    final aRow = await a.taskRow('t1');
    expect(aRow!.title, 'B revision');
    expect(aRow.updatedAt, DateTime.utc(2026, 1, 3).millisecondsSinceEpoch);
  });
}

Future<Map<String, dynamic>> _getHealth(String baseUrl) async {
  final client = HttpClient();
  addTearDown(() => client.close(force: true));
  final request = await client.getUrl(Uri.parse('$baseUrl/health'));
  final response = await request.close();
  final raw = await utf8.decoder.bind(response).join();
  return jsonDecode(raw) as Map<String, dynamic>;
}
