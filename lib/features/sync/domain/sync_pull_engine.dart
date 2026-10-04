/// Counts returned by a pull session, for logging and tests.
class PullSummary {
  const PullSummary({
    required this.applied,
    required this.skipped,
    required this.conflictLost,
    required this.cursor,
  });

  /// Remote changes written to the local database.
  final int applied;

  /// Events that caused no local change (benign no-ops, malformed keys).
  final int skipped;

  /// Incoming events rejected in favor of local state:
  /// - data-table LWW: local score >= incoming score
  /// - join tables: remote "link removed" never applied (option 1)
  final int conflictLost;

  /// Cursor after this pull (null when the transport returned no cursor).
  /// Only persisted to app_settings when [persistCursor] was true.
  final String? cursor;

  int get total => applied + skipped + conflictLost;

  @override
  String toString() =>
      'PullSummary(applied: $applied, skipped: $skipped, '
      'conflictLost: $conflictLost, cursor: $cursor)';
}

/// Client-side pull + merge engine (Stage 8b layer 3).
///
/// The local database is the single source of truth. Pull is background
/// reconciliation only — nothing in the app blocks on transport.
abstract class SyncPullEngine {
  /// One pull session:
  /// 1. Read local cursor from app_settings (per-device, not synced).
  /// 2. transport.pullSince(cursor).
  /// 3. Apply each event with client-side merge rules (no outbox echo).
  /// 4. When [persistCursor] is true (default), persist nextCursor on
  ///    transport success.
  ///
  /// [persistCursor] = false is used by the coordinator's initial full
  /// sync so the cursor is only written after pull → fullPush → pull
  /// have all succeeded.
  ///
  /// On transport failure the cursor is unchanged. Per-event apply errors
  /// are logged and counted; applies are independent and idempotent.
  Future<PullSummary> pullAndMerge({bool persistCursor = true});
}
