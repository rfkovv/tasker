import 'dart:async';

import 'package:flutter/scheduler.dart';

import '../../../local_db/database.dart' as db;
import '../domain/sync_pull_engine.dart';
import '../domain/sync_push_engine.dart';
import '../domain/sync_state.dart';

/// Creates a one-shot timer. Injectable so tests use a fake clock
/// (no real-time sleeps).
typedef SyncTimerFactory = Timer Function(
  Duration duration,
  void Function() callback,
);

/// Orchestrates full sync sessions and lifecycle triggers (8b layer 4).
///
/// A **session** = push → (on success) pull → persist `lastSynced_at`.
/// Sessions never block the UI; the app is fully functional offline.
///
/// ## Concurrency: COALESCE (not queue)
/// Re-entrant [syncNow] while a session is running returns the same
/// Future — one session at a time, no unbounded queue growth from the
/// outbox observer. Justification: a burst of mutations must produce at
/// most one in-flight session; queueing would serialize redundant work.
///
/// ## Triggers
/// (a) Outbox observer — drift watch on `sync_outbox`; non-empty rows
///     schedule a session after [debounce] (rapid mutations reset the
///     timer). Empty outbox → no session from this trigger.
/// (b) App startup — one session after first frame (never blocks startup).
/// (c) Pull-after-push — part of the session definition above.
///
/// ## Failure
/// Any transport failure → log, state returns to idle, outbox/cursor
/// untouched (layers 2–3), `lastSynced_at` unchanged. Next trigger
/// retries. No retry timers or backoff (8c).
class SyncCoordinator {
  SyncCoordinator({
    required db.AppDatabase database,
    required SyncPushEngine pushEngine,
    required SyncPullEngine pullEngine,
    this.debounce = const Duration(seconds: 3),
    SyncTimerFactory? timerFactory,
    void Function(void Function() action)? deferToPostFrame,
    void Function(String message)? logger,
  })  : _db = database,
        _push = pushEngine,
        _pull = pullEngine,
        _timerFactory = timerFactory ?? _defaultTimer,
        _defer = deferToPostFrame ?? _postFrame,
        _logger = logger ?? _ignore;

  /// app_settings key for the last successful session (epoch millis).
  static const lastSyncedAtKey = 'last_synced_at';

  static const SyncState initialState = SyncState.idle();

  final db.AppDatabase _db;
  final SyncPushEngine _push;
  final SyncPullEngine _pull;
  final Duration debounce;
  final SyncTimerFactory _timerFactory;
  final void Function(void Function() action) _defer;
  final void Function(String message) _logger;

  static Timer _defaultTimer(Duration d, void Function() cb) =>
      Timer(d, cb);

  static void _postFrame(void Function() action) {
    SchedulerBinding.instance.addPostFrameCallback((_) => action());
  }

  static void _ignore(String message) {}

  SyncState state = initialState;

  /// Notified whenever [state] changes (Riverpod layer / tests).
  void Function(SyncState state)? onStateChanged;

  Future<void>? _runningSession;
  StreamSubscription<List<db.SyncOutboxData>>? _outboxSub;
  Timer? _debounceTimer;
  var _started = false;

  bool get isRunning => _runningSession != null;

  /// Wires triggers (a) and (b). Idempotent.
  void start({bool startupSession = true}) {
    if (_started) return;
    _started = true;

    _outboxSub = _db.select(_db.syncOutbox).watch().listen((rows) {
      if (rows.isEmpty) {
        _debounceTimer?.cancel();
        _debounceTimer = null;
        return;
      }
      // Non-empty: (re)arm debounce — rapid mutations reset the timer.
      _debounceTimer?.cancel();
      _debounceTimer = _timerFactory(debounce, () {
        _debounceTimer = null;
        unawaited(_onDebounceFire());
      });
    });

    if (startupSession) {
      _defer(() {
        unawaited(syncNow());
      });
    }
  }

  /// Cancels triggers. Does not cancel an in-flight session.
  Future<void> dispose() async {
    _debounceTimer?.cancel();
    _debounceTimer = null;
    await _outboxSub?.cancel();
    _outboxSub = null;
  }

  /// Manual trigger (future 8c UI). Bypasses debounce.
  ///
  /// Coalesces into a running session: concurrent calls share one Future.
  Future<void> syncNow() {
    return _runningSession ??= _runSession().whenComplete(() {
      _runningSession = null;
    });
  }

  Future<void> _onDebounceFire() async {
    // Re-check: no session if outbox emptied during the debounce window.
    final rows = await _db.select(_db.syncOutbox).get();
    if (rows.isEmpty) return;
    await syncNow();
  }

  Future<void> _runSession() async {
    final previous = state;
    _setState(SyncState.syncing(lastSyncedAt: previous.lastSyncedAt));

    try {
      await _push.pushOutbox();
    } catch (error) {
      _logger('sync session: push failed ($error); state → idle');
      _setState(SyncState.idle(lastSyncedAt: previous.lastSyncedAt));
      return;
    }

    try {
      await _pull.pullAndMerge();
    } catch (error) {
      _logger('sync session: pull failed ($error); state → idle');
      _setState(SyncState.idle(lastSyncedAt: previous.lastSyncedAt));
      return;
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.storeSetting(lastSyncedAtKey, now.toString());
    _setState(SyncState.idle(lastSyncedAt: now));
  }

  Future<int?> readLastSyncedAt() async {
    final raw = await _db.lookupSettings(lastSyncedAtKey);
    return raw == null ? null : int.tryParse(raw);
  }

  void _setState(SyncState next) {
    if (next == state) return;
    state = next;
    onStateChanged?.call(next);
  }
}
