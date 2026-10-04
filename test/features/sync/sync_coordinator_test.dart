import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskmaster/features/sync/sync.dart';
import 'package:taskmaster/local_db/database.dart' as db;
import 'package:taskmaster/local_db/providers/database_provider.dart';

import 'support/fake_timers.dart';

/// Push engine wrapper that counts sessions and can gate completion.
class CountingPushEngine implements SyncPushEngine {
  CountingPushEngine(this._inner);

  final SyncPushEngine _inner;
  int calls = 0;
  int fullPushCalls = 0;

  /// When set, push awaits this future before delegating (concurrency tests).
  Future<void>? gate;

  @override
  Future<void> pushOutbox() async {
    calls++;
    final g = gate;
    if (g != null) await g;
    return _inner.pushOutbox();
  }

  @override
  Future<void> fullPush() async {
    fullPushCalls++;
    final g = gate;
    if (g != null) await g;
    return _inner.fullPush();
  }
}

class CountingPullEngine implements SyncPullEngine {
  CountingPullEngine(this._inner);

  final SyncPullEngine _inner;
  int calls = 0;

  @override
  Future<PullSummary> pullAndMerge({bool persistCursor = true}) {
    calls++;
    return _inner.pullAndMerge(persistCursor: persistCursor);
  }
}

class _Harness {
  _Harness({
    required this.transport,
    required FakeTimers timers,
  }) {
    database = db.AppDatabase(NativeDatabase.memory());
    push = CountingPushEngine(
      SyncPushEngineImpl(database: database, transport: transport),
    );
    pull = CountingPullEngine(
      SyncPullEngineImpl(database: database, transport: transport),
    );
    coordinator = SyncCoordinator(
      database: database,
      pushEngine: push,
      pullEngine: pull,
      debounce: const Duration(seconds: 3),
      timerFactory: timers.call,
      // Deterministic backoff for existing session tests (no jitter).
      jitter: (base) => base,
      // Tests drive startup explicitly — no real SchedulerBinding.
      deferToPostFrame: (action) => action(),
      logger: logs.add,
    );
  }

  late final db.AppDatabase database;
  late final CountingPushEngine push;
  late final CountingPullEngine pull;
  late final SyncCoordinator coordinator;
  final List<String> logs = [];
  final InMemorySyncTransport transport;

  Future<void> close() => database.close();

  /// Forces the incremental path (non-null cursor) for session tests.
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

  Future<List<db.SyncOutboxData>> outbox() {
    return database.select(database.syncOutbox).get();
  }

  Future<int?> lastSyncedAt() => coordinator.readLastSyncedAt();
}

void main() {
  late FakeTimers timers;
  late InMemorySyncTransport transport;
  late _Harness h;

  /// Drains microtasks/stream events without real-time sleeps.
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

  test('session = push then pull; lastSyncedAt only after both succeed',
      () async {
    await h.setCursor('0');
    await h.seedTask('t1');

    final states = <SyncState>[];
    h.coordinator.onStateChanged = states.add;

    await h.coordinator.syncNow();

    expect(h.push.calls, 1);
    expect(h.push.fullPushCalls, 0, reason: 'non-null cursor → no fullPush');
    expect(h.pull.calls, 1);
    expect(await h.outbox(), isEmpty, reason: 'push drained outbox');
    final last = await h.lastSyncedAt();
    expect(last, isNotNull);
    expect(h.coordinator.state, SyncState.idle(lastSyncedAt: last));
    expect(states.first.isSyncing, isTrue);
    expect(states.last.isSyncing, isFalse);
  });

  test('session does not persist lastSyncedAt when pull fails', () async {
    await h.setCursor('0');
    await h.seedTask('t1');
    transport.failNextPullCalls = 1;

    await h.coordinator.syncNow();

    expect(h.push.calls, 1);
    expect(h.pull.calls, 1);
    expect(await h.lastSyncedAt(), isNull);
    expect(h.coordinator.state, const SyncState.idle(lastSyncedAt: null));
  });

  test('outbox insert → session runs after debounce (fake clock)', () async {
    await h.setCursor('0');
    h.coordinator.start(startupSession: false);
    await h.seedTask('t1');
    await drainAsync();

    // Watch emission rearm the debounce timer; session must not run yet.
    expect(timers.activeCount, 1);
    expect(h.push.calls, 0);

    timers.elapse(const Duration(seconds: 2));
    await drainAsync();
    expect(h.push.calls, 0, reason: 'not yet past debounce');

    timers.elapse(const Duration(seconds: 1));
    await drainAsync();
    expect(h.push.calls, 1);
    expect(h.pull.calls, 1);
  });

  test('debounce coalescing: 5 mutations within 3s → exactly 1 session',
      () async {
    await h.setCursor('0');
    h.coordinator.start(startupSession: false);

    for (var i = 0; i < 5; i++) {
      await h.seedTask('t$i', title: 'Task $i');
      await drainAsync();
    }

    // Each mutation rearms the timer; only the latest is pending.
    expect(timers.activeCount, 1);
    expect(h.push.calls, 0);

    timers.fireAll();
    await drainAsync();

    expect(h.push.calls, 1, reason: 'one session for the whole burst');
    expect(h.pull.calls, 1);
    expect(await h.outbox(), isEmpty);
  });

  test(
      'transport failure → idle, outbox intact, lastSyncedAt unchanged; '
      'next trigger retries', () async {
    await h.setCursor('0');
    await h.seedTask('t1');
    transport.failNextCalls = 1;

    await h.coordinator.syncNow();

    expect(h.coordinator.state.phase, SyncPhase.idle);
    expect(await h.lastSyncedAt(), isNull);
    expect(await h.outbox(), hasLength(1), reason: 'outbox untouched');

    // Next trigger retries and succeeds.
    await h.coordinator.syncNow();
    expect(h.push.calls, 2);
    expect(h.pull.calls, 1);
    expect(await h.outbox(), isEmpty);
    expect(await h.lastSyncedAt(), isNotNull);
  });

  test('serialized sessions: coalesce, no concurrent transport calls',
      () async {
    await h.setCursor('0');
    await h.seedTask('t1');

    final gate = Completer<void>();
    h.push.gate = gate.future;

    final first = h.coordinator.syncNow();
    final second = h.coordinator.syncNow();
    final third = h.coordinator.syncNow();

    // All three share one session — only one push in flight.
    await drainAsync();
    expect(h.push.calls, 1);
    expect(h.pull.calls, 0, reason: 'push still gated');

    gate.complete();
    await Future.wait([first, second, third]);

    expect(h.push.calls, 1, reason: 'coalesced into one session');
    expect(h.pull.calls, 1);
  });

  test('syncNow() runs a session immediately, bypassing debounce', () async {
    await h.setCursor('0');
    h.coordinator.start(startupSession: false);
    await h.seedTask('t1');
    await drainAsync();

    // A debounce timer may be armed; we never fire it.
    await h.coordinator.syncNow();

    expect(h.push.calls, 1, reason: 'session ran without elapsing debounce');
    expect(h.pull.calls, 1);

    // A later mutation still goes through the debounce path.
    await h.seedTask('t2');
    await drainAsync();
    expect(timers.activeCount, 1);
    expect(h.push.calls, 1, reason: 'no second session until debounce fires');
  });

  test('empty outbox at startup → initial full sync, no errors', () async {
    expect(await h.outbox(), isEmpty);

    h.coordinator.start(startupSession: true);
    await drainAsync();

    // Null cursor → pull → fullPush → pull. Empty DB: fullPush is a no-op.
    expect(h.push.calls, 0, reason: 'no pushOutbox on initial sync');
    expect(h.push.fullPushCalls, 1);
    expect(h.pull.calls, 2);
    expect(transport.attemptedBatches, isEmpty,
        reason: 'no transport push on empty DB');
    expect(transport.pullCallCount, 2);
    expect(await h.cursor(), isNotNull, reason: 'cursor persisted');
    expect(await h.lastSyncedAt(), isNotNull);
    expect(h.logs.where((l) => l.contains('failed')), isEmpty);
  });

  test('empty outbox debounce fire → no session', () async {
    await h.setCursor('0');
    h.coordinator.start(startupSession: false);
    // Simulate a watch emission that saw rows, then rows vanished before
    // the timer fired: seed then delete outbox rows directly.
    await h.seedTask('t1');
    await drainAsync();
    expect(timers.activeCount, 1);

    await h.database.delete(h.database.syncOutbox).go();
    await drainAsync();

    timers.fireAll();
    await drainAsync();

    expect(h.push.calls, 0);
    expect(h.pull.calls, 0);
  });

  test('syncServiceProvider exposes state and syncNow', () async {
    final dbOverride = db.AppDatabase(NativeDatabase.memory());
    final localTransport = InMemorySyncTransport();
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(dbOverride),
        syncTransportProvider.overrideWithValue(localTransport),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await dbOverride.close();
    });

    final service = container.read(syncServiceProvider.notifier);
    expect(container.read(syncServiceProvider), const SyncState.idle());

    await dbOverride.into(dbOverride.tasks).insert(
          db.TasksCompanion.insert(
            id: 't1',
            title: 'via provider',
            status: const Value('todo'),
            ownerId: 'o',
            createdAt: 1000,
            updatedAt: 2000,
          ),
        );
    await dbOverride.enqueueSyncEvent('tasks', 't1');

    await service.syncNow();

    final state = container.read(syncServiceProvider);
    expect(state.phase, SyncPhase.idle);
    expect(state.lastSyncedAt, isNotNull);
    expect(await service.readLastSyncedAt(), state.lastSyncedAt);
    expect(
      await dbOverride.select(dbOverride.syncOutbox).get(),
      isEmpty,
    );
  });
}
