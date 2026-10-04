/// Sync lifecycle state exposed by `syncServiceProvider`.
///
/// `lastSyncedAt` is epoch millis from app_settings (`last_synced_at`,
/// per-device, NOT synced). Null = never completed a full session.
enum SyncPhase { idle, syncing }

class SyncState {
  const SyncState.idle({this.lastSyncedAt})
      : phase = SyncPhase.idle;

  const SyncState.syncing({this.lastSyncedAt})
      : phase = SyncPhase.syncing;

  const SyncState._({required this.phase, required this.lastSyncedAt});

  final SyncPhase phase;

  /// Epoch millis of the last successful push+pull session, or null.
  final int? lastSyncedAt;

  bool get isSyncing => phase == SyncPhase.syncing;

  SyncState copyWith({SyncPhase? phase, int? lastSyncedAt}) {
    return SyncState._(
      phase: phase ?? this.phase,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is SyncState &&
        other.phase == phase &&
        other.lastSyncedAt == lastSyncedAt;
  }

  @override
  int get hashCode => Object.hash(phase, lastSyncedAt);

  @override
  String toString() => 'SyncState($phase, lastSyncedAt: $lastSyncedAt)';
}
