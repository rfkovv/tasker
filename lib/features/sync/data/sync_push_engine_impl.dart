import 'package:drift/drift.dart';

import '../../../local_db/database.dart' as db;
import '../../../local_db/synced_tables.dart';
import '../domain/sync_event.dart';
import '../domain/sync_push_engine.dart';
import '../domain/sync_transport.dart';
import 'sync_row_serializer.dart';

/// Push-session engine over the thin sync_outbox.
///
/// Ordering: parent rows precede children where detectable —
/// rank 0 entities (tasks, tags, contacts), rank 1 task children
/// (subtasks, comments), rank 2 joins (task_tags, task_contacts,
/// task_dependencies). Within a rank, FIFO outbox order is preserved.
class SyncPushEngineImpl implements SyncPushEngine {
  SyncPushEngineImpl({
    required db.AppDatabase database,
    required SyncTransport transport,
    SyncRowSerializer? serializer,
    void Function(String message)? logger,
  })  : _db = database,
        _transport = transport,
        _serializer = serializer ?? SyncRowSerializer(database),
        _logger = logger ?? _ignore;

  final db.AppDatabase _db;
  final SyncTransport _transport;
  final SyncRowSerializer _serializer;
  final void Function(String message) _logger;

  static void _ignore(String message) {}

  @override
  Future<void> pushOutbox() async {
    final outboxRows = await (_db.select(_db.syncOutbox)
          ..orderBy([(o) => OrderingTerm.asc(o.id)]))
        .get();
    if (outboxRows.isEmpty) return;

    final processedIds = [for (final row in outboxRows) row.id];

    // Dedup by (tableName, rowId). LinkedHashMap keeps first-seen (FIFO)
    // order; payload is read at send time so the survivor always carries
    // the latest row state.
    final byKey = <(String, String), db.SyncOutboxData>{};
    for (final row in outboxRows) {
      byKey.putIfAbsent((row.eventTable, row.rowId), () => row);
    }

    final sendable = <SyncEvent>[];
    for (final entry in byKey.entries) {
      final (tableName, rowId) = entry.key;
      final payload = await _serializer.readCurrentState(tableName, rowId);
      if (payload == null) {
        _logger(
          'sync push: skip $tableName/$rowId — row not found at push time',
        );
        continue;
      }
      sendable.add(
        SyncEvent(tableName: tableName, rowId: rowId, payload: payload),
      );
    }

    final ordered = orderSyncEventsParentsFirst(sendable);

    try {
      if (ordered.isNotEmpty) {
        await _transport.pushBatch(ordered);
      }
    } catch (error) {
      _logger('sync push: transport failed ($error); outbox untouched');
      rethrow;
    }

    // Batch clear after successful session (or vacuous success when every
    // event was skipped): entire processed set, one transaction.
    await _db.transaction(() async {
      await (_db.delete(_db.syncOutbox)..where((o) => o.id.isIn(processedIds)))
          .go();
    });
  }

  /// Initial-sync path — ALL whitelisted rows, no outbox involvement.
  ///
  /// LWW: the server may already hold rows we push; the next pull's merge
  /// dedupes by `(tableName, rowId)`. Soft-deleted rows are included so
  /// peers learn tombstones. Join rows use composite natural keys.
  @override
  Future<void> fullPush() async {
    final events = <SyncEvent>[];

    final tasks = await _db.select(_db.tasks).get();
    for (final row in tasks) {
      events.add(
        SyncEvent(tableName: 'tasks', rowId: row.id, payload: row.toJson()),
      );
    }

    final tags = await _db.select(_db.tags).get();
    for (final row in tags) {
      events.add(
        SyncEvent(tableName: 'tags', rowId: row.id, payload: row.toJson()),
      );
    }

    final contacts = await _db.select(_db.contacts).get();
    for (final row in contacts) {
      events.add(
        SyncEvent(
          tableName: 'contacts',
          rowId: row.id,
          payload: row.toJson(),
        ),
      );
    }

    final subtasks = await _db.select(_db.subtasks).get();
    for (final row in subtasks) {
      events.add(
        SyncEvent(
          tableName: 'subtasks',
          rowId: row.id,
          payload: row.toJson(),
        ),
      );
    }

    final comments = await _db.select(_db.comments).get();
    for (final row in comments) {
      events.add(
        SyncEvent(
          tableName: 'comments',
          rowId: row.id,
          payload: row.toJson(),
        ),
      );
    }

    final taskTags = await _db.select(_db.taskTags).get();
    for (final row in taskTags) {
      events.add(
        SyncEvent(
          tableName: 'task_tags',
          rowId: joinRowId(row.taskId, row.tagId),
          payload: row.toJson(),
        ),
      );
    }

    final taskContacts = await _db.select(_db.taskContacts).get();
    for (final row in taskContacts) {
      events.add(
        SyncEvent(
          tableName: 'task_contacts',
          rowId: contactLinkRowId(row.taskId, row.contactId),
          payload: row.toJson(),
        ),
      );
    }

    final taskDependencies = await _db.select(_db.taskDependencies).get();
    for (final row in taskDependencies) {
      events.add(
        SyncEvent(
          tableName: 'task_dependencies',
          rowId: dependencyRowId(row.predecessorId, row.successorId),
          payload: row.toJson(),
        ),
      );
    }

    final ordered = orderSyncEventsParentsFirst(events);
    if (ordered.isEmpty) return;

    try {
      await _transport.pushBatch(ordered);
    } catch (error) {
      _logger('sync fullPush: transport failed ($error)');
      rethrow;
    }
  }
}
