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
}
