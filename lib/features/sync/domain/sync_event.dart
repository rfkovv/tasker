/// One push-ready sync event: table + row identity + current row state.
///
/// JSON payload format (stable — the 8c HTTP adapter MUST reuse this
/// without protocol changes):
///
/// Payload keys are the drift DataClass `toJson()` camelCase names, and
/// EVERY column of the table is present (nullable columns appear as null).
/// Examples:
///
/// tasks: `id`, `title`, `description`, `priority`, `status`, `dueDate`,
///        `startDate`, `ownerId`, `createdAt`, `updatedAt`, `deletedAt`
/// tags: `id`, `name`
/// subtasks: `id`, `taskId`, `title`, `isCompleted`, `position`,
///           `createdAt`, `updatedAt`
/// comments: `id`, `taskId`, `body`, `createdAt`, `updatedAt`, `deletedAt`
/// contacts: `id`, `name`, `role`, `email`, `phone`, `createdAt`,
///           `updatedAt`, `deletedAt`
/// task_tags: `taskId`, `tagId`
/// task_contacts: `taskId`, `contactId`
/// task_dependencies: `predecessorId`, `successorId`
///
/// The payload is the CURRENT row state at push time (thin outbox), not
/// the state at enqueue time. Soft-deleted rows are still serialized —
/// `deletedAt` is the tombstone the server stores.
class SyncEvent {
  const SyncEvent({
    required this.tableName,
    required this.rowId,
    required this.payload,
  });

  /// Whitelisted table name (see `syncedTables` in local_db).
  final String tableName;

  /// Row UUID, or composite natural key for join tables
  /// (`taskId:tagId`, `taskId:contactId`, `predecessorId:successorId`).
  final String rowId;

  /// Full current row state — see class doc for the JSON format.
  final Map<String, dynamic> payload;

  @override
  String toString() => 'SyncEvent($tableName/$rowId)';
}
