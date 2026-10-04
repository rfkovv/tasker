import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskmaster/features/sync/sync.dart';
import 'package:taskmaster/local_db/database.dart' as db;
import 'package:taskmaster/local_db/synced_tables.dart';

import 'support/fake_timers.dart';

/// Backoff + initial full sync (8c layer 3).
///
/// Fake clock only — no real-time sleeps anywhere in this file.
class _Harness {
  _Harness({required this.transport, required this.timers, SyncJitter? jitter}) {
    database = db.AppDatabase(NativeDatabase.memory());
    push = _CountingPush(
      SyncPushEngineImpl(database: database, transport: transport),
    );
    pull = _CountingPull(
      SyncPullEngineImpl(database: database, transport: transport),
    );
    coordinator = SyncCoordinator(
      database: database,
      pushEngine: push,
      pullEngine: pull,
      debounce: const Duration(seconds: 3),
      baseBackoff: const Duration(seconds: 5),
      maxBackoff: const Duration(minutes: 15),
      backoffFactor: 2,
      timerFactory: timers.call,
      jitter: jitter ?? _noJitter,
      deferToPostFrame: (action) => action(),
      logger: logs.add,
    );
  }

  static Duration _noJitter(Duration base) => base;

  final FakeTimers timers;
  final InMemorySyncTransport transport;
  late final db.AppDatabase database;
  late final _CountingPush push;
  late final _CountingPull pull;
  late final SyncCoordinator coordinator;
  final List<String> logs = [];

  Future<void> close() => database.close();

  Future<void> setCursor(String cursor) =>
      database.storeSetting(SyncPullEngineImpl.cursorSettingKey, cursor);

  Future<String?> cursor() =>
      database.lookupSettings(SyncPullEngineImpl.cursorSettingKey);

  Future<void> seedTask(String id, {String title = 'T'}) async {
    await database.into(database.tasks).insert(
          db.TasksCompanion.insert(
            id: id,
            title: title,
            status: const Value('todo'),
            ownerId: 'o',
            createdAt: 1000,
            updatedAt: 2000,
          ),
        );
    await database.enqueueSyncEvent('tasks', id);
  }

  /// Inserts a row WITHOUT touching the outbox (fullPush coverage).
  Future<void> insertTaskNoOutbox(String id, {String title = 'T'}) async {
    await database.into(database.tasks).insert(
          db.TasksCompanion.insert(
            id: id,
            title: title,
            status: const Value('todo'),
            ownerId: 'o',
            createdAt: 1000,
            updatedAt: 2000,
          ),
        );
  }

  Future<void> insertTag(String id, String name) async {
    await database.into(database.tags).insert(
          db.TagsCompanion.insert(id: id, name: name),
        );
  }

  Future<void> insertContact(String id, String name) async {
    await database.into(database.contacts).insert(
          db.ContactsCompanion.insert(
            id: id,
            name: name,
            createdAt: 1000,
            updatedAt: 2000,
          ),
        );
  }

  Future<void> insertSubtask(String id, String taskId) async {
    await database.into(database.subtasks).insert(
          db.SubtasksCompanion.insert(
            id: id,
            taskId: taskId,
            title: 'sub',
            createdAt: 1000,
            updatedAt: 1000,
          ),
        );
  }

  Future<void> insertComment(String id, String taskId) async {
    await database.into(database.comments).insert(
          db.CommentsCompanion.insert(
            id: id,
            taskId: taskId,
            body: 'c',
            createdAt: 1000,
          ),
        );
  }

  Future<void> insertTaskTag(String taskId, String tagId) async {
    await database.into(database.taskTags).insert(
          db.TaskTagsCompanion.insert(taskId: taskId, tagId: tagId),
        );
  }

  Future<void> insertTaskContact(String taskId, String contactId) async {
    await database.into(database.taskContacts).insert(
          db.TaskContactsCompanion.insert(
            taskId: taskId,
            contactId: contactId,
          ),
        );
  }

  Future<void> insertDependency(String pred, String succ) async {
    await database.into(database.taskDependencies).insert(
          db.TaskDependenciesCompanion.insert(
            predecessorId: pred,
            successorId: succ,
          ),
        );
  }

  Future<List<db.SyncOutboxData>> outbox() {
    return database.select(database.syncOutbox).get();
  }

  Future<int?> lastSyncedAt() => coordinator.readLastSyncedAt();
}

class _CountingPush implements SyncPushEngine {
  _CountingPush(this._inner);

  final SyncPushEngine _inner;
  int outboxCalls = 0;
  int fullPushCalls = 0;

  @override
  Future<void> pushOutbox() async {
    outboxCalls++;
    return _inner.pushOutbox();
  }

  @override
  Future<void> fullPush() async {
    fullPushCalls++;
    return _inner.fullPush();
  }
}

class _CountingPull implements SyncPullEngine {
  _CountingPull(this._inner);

  final SyncPullEngine _inner;
  int calls = 0;
  final persistCursorFlags = <bool>[];

  @override
  Future<PullSummary> pullAndMerge({bool persistCursor = true}) {
    calls++;
    persistCursorFlags.add(persistCursor);
    return _inner.pullAndMerge(persistCursor: persistCursor);
  }
}

void main() {
  late FakeTimers timers;
  late InMemorySyncTransport transport;
  late _Harness h;

  Future<void> drainAsync([int turns = 20]) async {
    for (var i = 0; i < turns; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  setUp(() {
    timers = FakeTimers();
    transport = InMemorySyncTransport();
    h = _Harness(transport: transport, timers: timers);
  });

  tearDown(() async {
    await h.coordinator.dispose();
    await h.close();
  });

  group('backoff', () {
    test('first failure schedules ~5s with ±20% jitter bounds', () async {
      // Deterministic jitter that still exercises the bounds check path
      // via the real Random default is flaky; use recording jitter that
      // returns a value inside the allowed band and assert the timer.
      Duration? scheduled;
      final bounded = _Harness(
        transport: transport,
        timers: timers,
        jitter: (base) {
          scheduled = base;
          // Simulate a jitter pick at +10% (within ±20%).
          return Duration(
            milliseconds: (base.inMilliseconds * 1.1).round(),
          );
        },
      );
      addTearDown(() async {
        await bounded.coordinator.dispose();
        await bounded.close();
      });

      await bounded.setCursor('0');
      await bounded.seedTask('t1');
      transport.failNextCalls = 1;

      await bounded.coordinator.syncNow();
      await drainAsync();

      expect(scheduled, const Duration(seconds: 5),
          reason: 'first failure uses baseBackoff before jitter');
      expect(bounded.coordinator.hasPendingBackoff, isTrue);
      expect(timers.activeCount, 1);
      final delay = timers.activeDurations.single;
      expect(delay.inMilliseconds, greaterThanOrEqualTo(4000));
      expect(delay.inMilliseconds, lessThanOrEqualTo(6000),
          reason: '±20% of 5s → [4s, 6s]');
    });

    test('default jitter stays within ±20% of the backoff base', () async {
      final jittered = _Harness(
        transport: transport,
        timers: timers,
        // Leave jitter null → coordinator default Random ±20%.
      );
      // Rebuild without injected jitter.
      final db0 = db.AppDatabase(NativeDatabase.memory());
      final push0 = _CountingPush(
        SyncPushEngineImpl(database: db0, transport: transport),
      );
      final pull0 = _CountingPull(
        SyncPullEngineImpl(database: db0, transport: transport),
      );
      final coord = SyncCoordinator(
        database: db0,
        pushEngine: push0,
        pullEngine: pull0,
        timerFactory: timers.call,
        deferToPostFrame: (action) => action(),
      );
      addTearDown(() async {
        await coord.dispose();
        await db0.close();
      });

      await db0.storeSetting(SyncPullEngineImpl.cursorSettingKey, '0');
      await db0.into(db0.tasks).insert(
            db.TasksCompanion.insert(
              id: 't1',
              title: 'T',
              status: const Value('todo'),
              ownerId: 'o',
              createdAt: 1000,
              updatedAt: 2000,
            ),
          );
      await db0.enqueueSyncEvent('tasks', 't1');
      transport.failNextCalls = 1;

      await coord.syncNow();
      await drainAsync();

      expect(coord.hasPendingBackoff, isTrue);
      final delay = timers.activeDurations.single;
      expect(delay.inMilliseconds, greaterThanOrEqualTo(4000),
          reason: 'jitter lower bound 0.8 × 5s');
      expect(delay.inMilliseconds, lessThanOrEqualTo(6000),
          reason: 'jitter upper bound 1.2 × 5s');
      expect(jittered, isNotNull);
    });

    test('backoff doubles 5→10→20→… and caps at 15 min', () async {
      await h.setCursor('0');
      await h.seedTask('t1');
      transport.failNextCalls = 100;

      const expected = <Duration>[
        Duration(seconds: 5),
        Duration(seconds: 10),
        Duration(seconds: 20),
        Duration(seconds: 40),
        Duration(seconds: 80),
        Duration(seconds: 160),
        Duration(seconds: 320),
        Duration(seconds: 640),
        Duration(minutes: 15), // 1280s → capped
        Duration(minutes: 15),
        Duration(minutes: 15),
      ];

      // First failure arms the first backoff timer.
      await h.coordinator.syncNow();
      await drainAsync();

      for (final base in expected) {
        expect(h.coordinator.hasPendingBackoff, isTrue,
            reason: 'retry pending (base=$base)');
        expect(timers.activeDurations.single, base,
            reason: 'pre-jitter schedule uses exact base (no jitter)');
        // Timer fires → auto retry → fails → next backoff armed.
        timers.elapse(base);
        await drainAsync();
      }

      expect(h.coordinator.backoffAttempt,
          greaterThanOrEqualTo(expected.length));
      expect(h.coordinator.currentBackoffBase, const Duration(minutes: 15));
    });

    test('successful session resets backoff to 5s and cancels timers',
        () async {
      await h.setCursor('0');
      await h.seedTask('t1');
      transport.failNextCalls = 1;

      await h.coordinator.syncNow(); // fail 1 → arm 5s, attempt=1
      await drainAsync();
      expect(timers.activeDurations.single, const Duration(seconds: 5));

      timers.elapse(const Duration(seconds: 5)); // auto retry succeeds
      await drainAsync();

      expect(h.coordinator.backoffAttempt, 0);
      expect(h.coordinator.currentBackoffBase, const Duration(seconds: 5));
      expect(h.coordinator.hasPendingBackoff, isFalse);
      expect(timers.activeCount, 0, reason: 'no retry timers after success');

      // Next failure schedules ~5s again (not doubled).
      await h.seedTask('t2');
      transport.failNextCalls = 1;
      await h.coordinator.syncNow();
      await drainAsync();
      expect(timers.activeDurations.single, const Duration(seconds: 5));
    });

    test('mutation debounce cancels pending backoff (earlier event wins)',
        () async {
      await h.setCursor('0');
      await h.seedTask('t1');
      transport.failNextCalls = 1;

      await h.coordinator.syncNow(); // fails → backoff ~5s armed
      await drainAsync();
      expect(h.coordinator.hasPendingBackoff, isTrue);

      h.coordinator.start(startupSession: false);
      // New mutation arms debounce (~3s) — earlier than backoff (~5s).
      await h.seedTask('t2');
      await drainAsync();
      expect(timers.activeCount, 2, reason: 'debounce + backoff both pending');

      timers.elapse(const Duration(seconds: 3)); // debounce fires first
      await drainAsync();

      expect(h.coordinator.hasPendingBackoff, isFalse,
          reason: 'debounce session cancelled pending backoff');
      expect(h.push.outboxCalls, greaterThanOrEqualTo(1),
          reason: 'mutation session ran');
    });

    test('lifecycle: pause cancels timer; resume re-arms; no fire while '
        'backgrounded', () async {
      await h.setCursor('0');
      await h.seedTask('t1');
      transport.failNextCalls = 1;

      await h.coordinator.syncNow();
      await drainAsync();
      expect(h.coordinator.hasPendingBackoff, isTrue);
      final pendingBefore = timers.activeDurations.single;

      h.coordinator.notifyAppLifecycle(resumed: false);
      expect(h.coordinator.hasPendingBackoff, isFalse);
      expect(h.coordinator.isAppResumed, isFalse);
      expect(h.coordinator.state.phase, SyncPhase.idle);

      final pullsBefore = transport.pullCallCount;
      final outboxCallsBefore = h.push.outboxCalls;
      timers.elapse(const Duration(hours: 1));
      await drainAsync();
      expect(transport.pullCallCount, pullsBefore,
          reason: 'no retries while backgrounded');
      expect(h.push.outboxCalls, outboxCallsBefore,
          reason: 'no new push sessions while backgrounded');

      h.coordinator.notifyAppLifecycle(resumed: true);
      expect(h.coordinator.hasPendingBackoff, isTrue,
          reason: 'resume re-arms pending backoff');
      expect(timers.activeDurations.single, pendingBefore);

      timers.elapse(pendingBefore);
      await drainAsync();
      expect(transport.pullCallCount, greaterThan(pullsBefore),
          reason: 'retry runs after foreground');
    });
  });

  group('initial full sync', () {
    test('pull → fullPush → pull; cursor + lastSyncedAt persisted; outbox '
        'empty', () async {
      // Server already holds an event from "another device".
      await transport.pushBatch([
        SyncEvent(
          tableName: 'tasks',
          rowId: 'remote-1',
          payload: {
            'id': 'remote-1',
            'title': 'Remote',
            'description': null,
            'priority': 'medium',
            'status': 'todo',
            'dueDate': null,
            'startDate': null,
            'ownerId': 'o',
            'createdAt': 1000,
            'updatedAt': 2000,
            'deletedAt': null,
          },
        ),
      ]);

      await h.insertTaskNoOutbox('local-1', title: 'Local');
      await h.insertTaskNoOutbox('local-2', title: 'Also local');
      // Outbox non-empty (mutation before first sync) — must be cleared.
      await h.database.enqueueSyncEvent('tasks', 'local-1');

      await h.coordinator.syncNow();
      await drainAsync();

      expect(h.push.outboxCalls, 0, reason: 'initial sync skips pushOutbox');
      expect(h.push.fullPushCalls, 1);
      expect(h.pull.calls, 2, reason: 'pull → fullPush → pull');
      expect(h.pull.persistCursorFlags, [false, true],
          reason: 'cursor only persisted after fullPush');
      expect(transport.pullCallCount, 2);

      expect(await h.cursor(), isNotNull);
      expect(await h.lastSyncedAt(), isNotNull);
      expect(await h.outbox(), isEmpty,
          reason: 'outbox cleared after successful fullPush');

      // Remote row applied by the first pull.
      final remote = await (h.database.select(h.database.tasks)
            ..where((t) => t.id.equals('remote-1')))
          .getSingleOrNull();
      expect(remote, isNotNull, reason: 'full-log pull applied remote row');

      // Local rows were pushed (fullPush), not via outbox.
      expect(transport.deliveredEvents, isNotEmpty);
      expect(
        transport.deliveredEvents.map((e) => e.rowId),
        containsAll(['local-1', 'local-2']),
      );
    });

    test('fullPush orders parents first (entities → children → joins)',
        () async {
      // Parents first (FK), then joins before children — reverse of rank
      // for the non-entity ranks, to prove the engine re-sorts.
      await h.insertTaskNoOutbox('t1', title: 'Task');
      await h.insertContact('ct1', 'C');
      await h.insertTag('tg1', 'tag');
      await h.insertDependency('t1', 't2');
      await h.insertTaskContact('t1', 'ct1');
      await h.insertTaskTag('t1', 'tg1');
      await h.insertComment('c1', 't1');
      await h.insertSubtask('st1', 't1');

      await h.push.fullPush();
      await drainAsync();

      final delivered = transport.deliveredEvents;
      expect(delivered, isNotEmpty);

      final ranks = [
        for (final e in delivered) tableSyncRank(e.tableName),
      ];
      expect(ranks, equals([...ranks]..sort()),
          reason: 'non-decreasing rank order');

      // Rank 0 rows appear before any rank 1/2 row.
      final firstJoin = ranks.indexOf(2);
      final lastEntity = ranks.lastIndexOf(0);
      final lastChild = ranks.lastIndexOf(1);
      if (firstJoin >= 0) {
        expect(lastEntity, lessThan(firstJoin));
        expect(lastChild, lessThan(firstJoin));
      }
      if (lastChild >= 0) {
        expect(lastEntity, lessThan(lastChild));
      }

      // Composite keys for joins.
      final joinIds = [
        for (final e in delivered)
          if (e.tableName == 'task_tags' ||
              e.tableName == 'task_contacts' ||
              e.tableName == 'task_dependencies')
            (e.tableName, e.rowId),
      ];
      expect(joinIds, contains(('task_tags', joinRowId('t1', 'tg1'))));
      expect(
        joinIds,
        contains(('task_contacts', contactLinkRowId('t1', 'ct1'))),
      );
      expect(
        joinIds,
        contains(('task_dependencies', dependencyRowId('t1', 't2'))),
      );

      // fullPush never touches the outbox.
      expect(await h.outbox(), isEmpty);
    });

    test('fullPush failure mid-way → cursor NOT set → next session re-runs '
        'initial sync from scratch', () async {
      await h.insertTaskNoOutbox('local-1');
      transport.failNextCalls = 1; // fullPush will fail

      await h.coordinator.syncNow();
      await drainAsync();

      expect(h.push.fullPushCalls, 1);
      expect(await h.cursor(), isNull,
          reason: 'cursor not set when fullPush fails');
      expect(await h.lastSyncedAt(), isNull);
      expect(h.coordinator.hasPendingBackoff, isTrue);
      expect(h.pull.calls, 1, reason: 'first pull only (no second pull)');
      expect(h.pull.persistCursorFlags, [false]);

      // Retry: initial sync runs again from scratch (pull first).
      transport.failNextCalls = 0;
      final pullsBefore = transport.pullCallCount;
      await h.coordinator.syncNow();
      await drainAsync();

      expect(h.push.fullPushCalls, 2);
      expect(transport.pullCallCount, pullsBefore + 2,
          reason: 're-pull from scratch after failed initial sync');
      expect(await h.cursor(), isNotNull);
      expect(await h.lastSyncedAt(), isNotNull);
    });

    test('non-null cursor → incremental session; fullPush NEVER called',
        () async {
      await h.setCursor('5');
      await h.seedTask('t1');

      await h.coordinator.syncNow();
      await drainAsync();

      expect(h.push.fullPushCalls, 0);
      expect(h.push.outboxCalls, 1);
      expect(h.pull.calls, 1);
      expect(h.pull.persistCursorFlags, [true],
          reason: 'incremental pull persists cursor by default');
      expect(await h.outbox(), isEmpty);
      expect(await h.lastSyncedAt(), isNotNull);
      expect(await h.cursor(), isNotNull);
    });
  });
}
