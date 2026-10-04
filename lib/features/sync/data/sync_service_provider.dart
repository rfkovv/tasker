import 'dart:async';

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
final syncServiceProvider =
    NotifierProvider<SyncService, SyncState>(SyncService.new);

class SyncService extends Notifier<SyncState> {
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
    ref.onDispose(() {
      unawaited(coordinator.dispose());
    });
    _coordinator = coordinator;
    return coordinator.state;
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
