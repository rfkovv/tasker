import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../local_db/providers/database_provider.dart';
import '../domain/sync_state.dart';
import 'sync_coordinator.dart';
import 'sync_pull_engine_impl.dart';
import 'sync_push_engine_impl.dart';
import 'sync_transport_provider.dart';

/// Riverpod entry point for sync lifecycle (8b layer 4).
///
/// - `ref.watch(syncServiceProvider)` → [SyncState] (idle/syncing + lastSyncedAt)
/// - `ref.read(syncServiceProvider.notifier).syncNow()` → manual session
/// - `ref.read(syncServiceProvider.notifier).start()` → activate triggers
///   (outbox debounce + startup session); called once from `main()`.
/// - App lifecycle is forwarded to the coordinator so backoff timers pause
///   while backgrounded and re-arm on resume (8c layer 3).
final syncServiceProvider =
    NotifierProvider<SyncService, SyncState>(SyncService.new);

class SyncService extends Notifier<SyncState> with WidgetsBindingObserver {
  SyncCoordinator? _coordinator;

  @override
  SyncState build() {
    final database = ref.watch(databaseProvider);
    final transport = ref.watch(syncTransportProvider);

    final coordinator = SyncCoordinator(
      database: database,
      pushEngine: SyncPushEngineImpl(
        database: database,
        transport: transport,
      ),
      pullEngine: SyncPullEngineImpl(
        database: database,
        transport: transport,
      ),
    );
    coordinator.onStateChanged = (s) => state = s;

    // Lifecycle wiring is best-effort: pure Riverpod unit tests have no
    // WidgetsBinding. Backoff stays armed (default resumed) without it.
    final binding = _tryBinding();
    binding?.addObserver(this);

    ref.onDispose(() {
      binding?.removeObserver(this);
      unawaited(coordinator.dispose());
    });
    _coordinator = coordinator;
    return coordinator.state;
  }

  static WidgetsBinding? _tryBinding() {
    try {
      return WidgetsBinding.instance;
    } catch (_) {
      return null;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _coordinator?.notifyAppLifecycle(
      resumed: state == AppLifecycleState.resumed,
    );
  }

  /// Activates lifecycle triggers. Idempotent. Never blocks the caller.
  void start() => _coordinator?.start();

  /// Manual trigger (bypasses debounce). Coalesces into a running session.
  Future<void> syncNow() {
    final coordinator = _coordinator;
    if (coordinator == null) return Future<void>.value();
    return coordinator.syncNow();
  }

  /// Epoch millis of the last successful session, or null.
  Future<int?> readLastSyncedAt() =>
      _coordinator?.readLastSyncedAt() ?? Future<int?>.value();
}
