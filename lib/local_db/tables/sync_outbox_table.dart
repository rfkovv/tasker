import 'package:drift/drift.dart';

/// Thin sync outbox (Stage 8b layer 1).
///
/// Every mutation of a whitelisted table enqueues one row here, inside the
/// same drift transaction as the mutation. No payload column: the future
/// push layer reads current row state at send time.
///
/// NOTE (future push layer): for join tables, "row not found at push time"
/// is a NORMAL outcome — a row can be inserted and deleted before the
/// outbox batch is serialized. Skip and log; do not fail the batch.
class SyncOutbox extends Table {
  /// Local event id, FIFO order for push. Not a domain identifier.
  /// autoIncrement integer PK — SQLite rowid, inherently FIFO-ordered.
  IntColumn get id => integer().autoIncrement()();

  /// Whitelisted table name (see `syncedTables`). SQL column: table_name.
  TextColumn get eventTable => text().named('table_name')();

  /// The mutated row's UUID, or composite natural key for join tables
  /// (see `joinRowId` / `contactLinkRowId` / `dependencyRowId`).
  TextColumn get rowId => text()();

  /// Epoch millis when the event was enqueued.
  IntColumn get enqueuedAt => integer()();
}
