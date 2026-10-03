import 'package:drift/drift.dart';

import '../../../local_db/database.dart' as db;

/// Reads CURRENT row state for thin-outbox events.
///
/// Payload format: drift DataClass `toJson()` — camelCase keys, every
/// column present (nulls included). See [SyncEvent] in domain for the
/// per-table key list. The 8c HTTP adapter must reuse this format.
///
/// Join-table [rowId]s are composite natural keys with a fixed `:`
/// delimiter (see `synced_tables.dart`). A missing or malformed key, or a
/// row that no longer exists, returns null — the push engine treats that
/// as a normal skip, not an error.
class SyncRowSerializer {
  SyncRowSerializer(this._db);

  final db.AppDatabase _db;

  /// Returns the current row as a JSON-ready map, or null when the row
  /// does not exist (purged, join link removed, or malformed rowId).
  Future<Map<String, dynamic>?> readCurrentState(
    String tableName,
    String rowId,
  ) async {
    switch (tableName) {
      case 'tasks':
        final row = await (_db.select(_db.tasks)
              ..where((t) => t.id.equals(rowId)))
            .getSingleOrNull();
        return row?.toJson();
      case 'tags':
        final row = await (_db.select(_db.tags)
              ..where((t) => t.id.equals(rowId)))
            .getSingleOrNull();
        return row?.toJson();
      case 'subtasks':
        final row = await (_db.select(_db.subtasks)
              ..where((s) => s.id.equals(rowId)))
            .getSingleOrNull();
        return row?.toJson();
      case 'comments':
        final row = await (_db.select(_db.comments)
              ..where((c) => c.id.equals(rowId)))
            .getSingleOrNull();
        return row?.toJson();
      case 'contacts':
        final row = await (_db.select(_db.contacts)
              ..where((c) => c.id.equals(rowId)))
            .getSingleOrNull();
        return row?.toJson();
      case 'task_tags':
        final key = _splitComposite(rowId);
        if (key == null) return null;
        final row = await (_db.select(_db.taskTags)
              ..where((tt) =>
                  tt.taskId.equals(key[0]) & tt.tagId.equals(key[1])))
            .getSingleOrNull();
        return row?.toJson();
      case 'task_contacts':
        final key = _splitComposite(rowId);
        if (key == null) return null;
        final row = await (_db.select(_db.taskContacts)
              ..where((tc) =>
                  tc.taskId.equals(key[0]) & tc.contactId.equals(key[1])))
            .getSingleOrNull();
        return row?.toJson();
      case 'task_dependencies':
        final key = _splitComposite(rowId);
        if (key == null) return null;
        final row = await (_db.select(_db.taskDependencies)
              ..where((td) =>
                  td.predecessorId.equals(key[0]) &
                  td.successorId.equals(key[1])))
            .getSingleOrNull();
        return row?.toJson();
      default:
        return null;
    }
  }

  /// Splits a composite join key `a:b` into `[a, b]`, or null when the
  /// format is invalid (wrong arity or empty segment).
  List<String>? _splitComposite(String rowId) {
    final parts = rowId.split(':');
    if (parts.length != 2) return null;
    if (parts.any((p) => p.isEmpty)) return null;
    return parts;
  }
}
