import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

import '../../../local_db/database.dart' as db;
import '../domain/sync_pull_engine.dart';
import '../domain/sync_push_engine.dart';
import '../domain/sync_state.dart';
import 'sync_pull_engine_impl.dart';

/// Creates a one-shot timer. Injectable so tests use a fake clock
/// (no real-time sleeps).
typedef SyncTimerFactory = Timer Function(
  Duration duration,
  void Function() callback,
);

/// Jitter applied to a backoff base delay. Injectable for deterministic
/// tests; production default is ±20% via [Random].
typedef SyncJitter = Duration Function(Duration base);

/// Orchestrates full sync sessions and lifecycle triggers.
///
/// A **session** (non-null cursor) = push → (on success) pull → persist
/// `lastSynced_at`. A **session** (null cursor) = initial full sync:
/// pull → fullPush → pull → persist cursor + `lastSynced_at`.
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
/// (d) Backoff retry — after a failed session, when [notifyAppLifecycle]
///     reports the app resumed.
///
/// ## Failure & backoff (8c layer 3)
/// Any transport failure → log, state returns to idle, outbox/cursor
/// untouched (layers 2–3), `lastSynced_at` unchanged, and a retry is
/// scheduled with exponential backoff: [baseBackoff] × [backoffFactor]^n,
/// capped at [maxBackoff], ±20% jitter (or injectable [jitter]).
/// Backoff state is in-memory only — a process restart starts fresh at
/// [baseBackoff]. A fully successful session resets the attempt counter
/// and cancels any pending retry timer.
///
/// ## Lifecycle
/// The backoff timer is paused when the app is backgrounded and re-armed
/// on resume. No retries fire while backgrounded. A mutation-triggered
/// session (debounce) cancels a pending backoff timer — the earlier event
/// wins.
class SyncCoordinator {
  SyncCoordinator({
    required db.AppDatabase database,
    required SyncPushEngine pushEngine,
    required SyncPullEngine pullEngine,
    this.debounce = const Duration(seconds: 3),
    this.baseBackoff = defaultBaseBackoff,
    this.maxBackoff = defaultMaxBackoff,
    this.backoffFactor = defaultBackoffFactor,
    SyncTimerFactory? timerFactory,
    SyncJitter? jitter,
    Random? random,
    void Function(void Function() action)? deferToPostFrame,
    void Function(String message)? logger,
  })  : _db = database,
        _push = pushEngine,
        _pull = pullEngine,
        _timerFactory = timerFactory ?? _defaultTimer,
        _random = random ?? Random(),
        _jitterOverride = jitter,
        _defer = deferToPostFrame ?? _postFrame,
        _logger = logger ?? _ignore;

  /// app_settings key for the last successful session (epoch millis).
  static const lastSyncedAtKey = 'last_synced_at';

  static const SyncState initialState = SyncState.idle();

  static const Duration defaultBaseBackoff = Duration(seconds: 5);
  static const Duration defaultMaxBackoff = Duration(minutes: 15);
  static const int defaultBackoffFactor = 2;

  final db.AppDatabase _db;
  final SyncPushEngine _push;
  final SyncPullEngine _pull;
  final Duration debounce;

  /// First-failure delay before jitter. Doubles each subsequent failure.
  final Duration baseBackoff;

  /// Hard cap on the pre-jitter backoff delay.
  final Duration maxBackoff;

  /// Multiplier applied per consecutive failure.
  final int backoffFactor;

  final SyncTimerFactory _timerFactory;
  final Random _random;
  final SyncJitter? _jitterOverride;
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
  Timer? _backoffTimer;
  var _started = false;

  /// Consecutive failed sessions (in-memory only; reset on success).
  var _backoffAttempt = 0;

  /// Jittered delay armed for the next retry, or null when none pending.
  Duration? _pendingBackoffDelay;

  /// False while the app is backgrounded — no backoff timer may fire.
  var _appResumed = true;

  bool get isRunning => _runningSession != null;

  /// Whether a backoff retry timer is currently armed.
  @visibleForTesting
  bool get hasPendingBackoff => _backoffTimer?.isActive ?? false;

  /// Whether the app is considered foregrounded.
  @visibleForTesting
  bool get isAppResumed => _appResumed;

  /// Consecutive failure count driving the next backoff base.
  @visibleForTesting
  int get backoffAttempt => _backoffAttempt;

  /// Pre-jitter delay that would be used for the next failure.
  @visibleForTesting
  Duration get currentBackoffBase {
    var d = baseBackoff;
    for (var i = 0; i < _backoffAttempt; i++) {
      d = Duration(milliseconds: d.inMilliseconds * backoffFactor);
      if (d >= maxBackoff) return maxBackoff;
    }
    return d > maxBackoff ? maxBackoff : d;
  }

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
      // The earlier event wins: a debounce fire cancels any pending
      // backoff timer (mutation supersedes retry).
      _debounceTimer?.cancel();
      _debounceTimer = _timerFactory(debounce, () {
        _debounceTimer = null;
        _cancelBackoff();
        unawaited(_onDebounceFire());
      });
    });

    if (startupSession) {
      _defer(() {
        unawaited(syncNow());
      });
    }
  }

  /// Lifecycle gate for backoff timers. Called from the app lifecycle
  /// observer (SyncService). [resumed] true = foreground.
  void notifyAppLifecycle({required bool resumed}) {
    if (resumed == _appResumed) return;
    _appResumed = resumed;
    if (!resumed) {
      _backoffTimer?.cancel();
      _backoffTimer = null;
      // Keep _pendingBackoffDelay — re-armed on resume.
    } else {
      final pending = _pendingBackoffDelay;
      if (pending != null && _backoffTimer == null) {
        _armBackoff(pending);
      }
    }
  }

  /// Cancels triggers. Does not cancel an in-flight session.
  Future<void> dispose() async {
    _debounceTimer?.cancel();
    _debounceTimer = null;
    _cancelBackoff();
    await _outboxSub?.cancel();
    _outboxSub = null;
  }

  /// Manual trigger (future 8c UI). Bypasses debounce.
  ///
  /// Coalesces into a running session: concurrent calls share one Future.
  /// Cancels any pending backoff timer — an explicit session supersedes
  /// the scheduled retry.
  Future<void> syncNow() {
    _cancelBackoff();
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

    final cursor = await _readCursor();

    try {
      if (cursor == null) {
        await _runInitialFullSync();
      } else {
        await _runIncrementalSession();
      }
    } catch (error) {
      _logger('sync session: failed ($error); state → idle');
      _setState(SyncState.idle(lastSyncedAt: previous.lastSyncedAt));
      _onSessionFailure();
      return;
    }

    _resetBackoff();
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.storeSetting(lastSyncedAtKey, now.toString());
    _setState(SyncState.idle(lastSyncedAt: now));
  }

  /// Non-null cursor: pushOutbox → pull → lastSyncedAt.
  Future<void> _runIncrementalSession() async {
    await _push.pushOutbox();
    await _pull.pullAndMerge();
  }

  /// Null cursor: pull → fullPush → pull → lastSyncedAt.
  ///
  /// First pull must NOT persist the cursor: if fullPush fails mid-way the
  /// next session re-runs initial sync from scratch. The second pull
  /// persists nextCursor only after fullPush has succeeded.
  ///
  /// Empty server log → transport returns nextCursor null; persist '0' so
  /// the next session takes the incremental path (null cursor means
  /// "never pulled").
  ///
  /// After a successful fullPush the outbox is cleared — every whitelisted
  /// row's current state is on the server, so remaining outbox entries are
  /// redundant.
  Future<void> _runInitialFullSync() async {
    await _pull.pullAndMerge(persistCursor: false);
    await _push.fullPush();
    await _db.delete(_db.syncOutbox).go();
    await _pull.pullAndMerge(persistCursor: true);
    if (await _readCursor() == null) {
      await _db.storeSetting(SyncPullEngineImpl.cursorSettingKey, '0');
    }
  }

  void _onSessionFailure() {
    final delay = _jitter(currentBackoffBase);
    _backoffAttempt++;
    if (!_appResumed) {
      _pendingBackoffDelay = delay;
      _logger('sync: app backgrounded — backoff timer paused');
      return;
    }
    _armBackoff(delay);
  }

  Duration _jitter(Duration base) {
    final override = _jitterOverride;
    if (override != null) return override(base);
    // ±20%.
    final factor = 0.8 + _random.nextDouble() * 0.4;
    return Duration(milliseconds: (base.inMilliseconds * factor).round());
  }

  void _armBackoff(Duration delay) {
    _backoffTimer?.cancel();
    _pendingBackoffDelay = delay;
    _backoffTimer = _timerFactory(delay, () {
      _backoffTimer = null;
      _pendingBackoffDelay = null;
      _debounceTimer?.cancel();
      _debounceTimer = null;
      unawaited(syncNow());
    });
  }

  void _cancelBackoff() {
    _backoffTimer?.cancel();
    _backoffTimer = null;
    _pendingBackoffDelay = null;
  }

  void _resetBackoff() {
    _backoffAttempt = 0;
    _cancelBackoff();
  }

  Future<String?> _readCursor() =>
      _db.lookupSettings(SyncPullEngineImpl.cursorSettingKey);

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
