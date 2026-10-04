import 'sync_event.dart';
import 'sync_transport.dart';

/// Local push engine: drains the sync outbox through a [SyncTransport].
abstract class SyncPushEngine {
  /// Runs one push session:
  /// 1. Read all outbox events FIFO by id.
  /// 2. Dedup by `(tableName, rowId)` — send one event per key with the
  ///    current row state (latest wins).
  /// 3. Skip rows that no longer exist (log; normal outcome).
  /// 4. Order parents before children where detectable.
  /// 5. Send the deduped batch via transport.
  /// 6. On success, delete the entire processed event set in one
  ///    transaction. On transport failure, outbox untouched.
  Future<void> pushOutbox();

  /// Initial-sync path: serialize and push ALL rows of the whitelisted
  /// tables **without** going through sync_outbox.
  ///
  /// Parent-first rank ordering is reused. Does not enqueue or clear the
  /// outbox. LWW already guarantees correctness of duplicates — the
  /// server may hold rows we also push; the next pull's merge dedupes by
  /// `(tableName, rowId)`.
  Future<void> fullPush();
}

/// Stable parent-before-child ordering. Dart's List.sort is unstable, so
/// the original (FIFO within rank) index is the tiebreaker.
List<SyncEvent> orderSyncEventsParentsFirst(List<SyncEvent> events) {
  final indexed = [
    for (var i = 0; i < events.length; i++) (i, events[i]),
  ];
  indexed.sort((a, b) {
    final rank = tableSyncRank(a.$2.tableName)
        .compareTo(tableSyncRank(b.$2.tableName));
    if (rank != 0) return rank;
    return a.$1.compareTo(b.$1);
  });
  return [for (final pair in indexed) pair.$2];
}

/// Rank 0 entities, rank 1 task children, rank 2 joins, default 3.
int tableSyncRank(String tableName) {
  switch (tableName) {
    case 'tasks':
    case 'tags':
    case 'contacts':
      return 0;
    case 'subtasks':
    case 'comments':
      return 1;
    case 'task_tags':
    case 'task_contacts':
    case 'task_dependencies':
      return 2;
    default:
      return 3;
  }
}
