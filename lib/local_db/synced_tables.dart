/// Tables whitelisted for sync outbox enqueue (Stage 8b).
///
/// `app_settings` and `sync_outbox` are intentionally excluded: settings
/// are per-device (ARCHITECTURE.md SYNC), and the outbox itself is
/// transport state, not domain data.
const syncedTables = <String>{
  'tasks',
  'tags',
  'task_tags',
  'subtasks',
  'comments',
  'contacts',
  'task_contacts',
  'task_dependencies',
};

/// Natural-key encoding for join tables that have no UUID row id.
///
/// Fixed delimiter (`:`) and fixed field order — future layers must parse
/// with the same format:
/// - `task_tags`:         `taskId:tagId`
/// - `task_contacts`:     `taskId:contactId`
/// - `task_dependencies`: `predecessorId:successorId`
///
/// NOTE (future push layer): for join tables, "row not found at push time"
/// is a NORMAL outcome — a row can be inserted and deleted before the
/// outbox batch is serialized. Skip and log; do not fail the batch.
String joinRowId(String taskId, String tagId) => '$taskId:$tagId';

String contactLinkRowId(String taskId, String contactId) =>
    '$taskId:$contactId';

String dependencyRowId(String predecessorId, String successorId) =>
    '$predecessorId:$successorId';
