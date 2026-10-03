import 'package:drift/drift.dart';

import '../../../local_db/database.dart' as db;
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

    final ordered = _orderParentsFirst(sendable);

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

  /// Stable parent-before-child ordering. Dart's List.sort is unstable, so
  /// the original (FIFO within rank) index is the tiebreaker.
  List<SyncEvent> _orderParentsFirst(List<SyncEvent> events) {
    final indexed = [
      for (var i = 0; i < events.length; i++) (i, events[i]),
    ];
    indexed.sort((a, b) {
      final rank = _tableRank(a.$2.tableName)
          .compareTo(_tableRank(b.$2.tableName));
      if (rank != 0) return rank;
      return a.$1.compareTo(b.$1);
    });
    return [for (final pair in indexed) pair.$2];
  }

  static int _tableRank(String tableName) {
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
}
