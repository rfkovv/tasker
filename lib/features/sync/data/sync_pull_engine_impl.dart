import 'package:drift/drift.dart';

import '../../../local_db/database.dart' as db;
import '../domain/sync_event.dart';
import '../domain/sync_pull_engine.dart';
import '../domain/sync_transport.dart';

/// Applies remote events onto the local database — the single source of
/// truth. Never enqueues into sync_outbox (no echo loop).
///
/// ## Data-table LWW
/// Score = max(coalesce(updatedAt, createdAt), coalesce(deletedAt, 0)).
/// Local wins when localScore >= incomingScore; incoming wins only when
/// strictly greater. Soft-delete participates (deletedAt is an edit).
/// On write, JSON values are stored as-is — updatedAt is NOT bumped.
///
/// ## Join tables — OPTION 1 (pure add-wins)
/// Incoming link missing locally → insert; present → no-op.
/// Incoming "link removed" → ALWAYS skip (counted as conflictLost).
///
/// KNOWN LIMITATION (documented per decision; update ARCHITECTURE.md in
/// 8c): link removals do not converge across devices in this layer.
/// Resolution is deferred to the 8c protocol, where the server log's
/// total order disambiguates join-table purges. No timestamps or proxies
/// are invented for join rows.
class SyncPullEngineImpl implements SyncPullEngine {
  SyncPullEngineImpl({
    required db.AppDatabase database,
    required SyncTransport transport,
    void Function(String message)? logger,
  })  : _db = database,
        _transport = transport,
        _logger = logger ?? _ignore;

  static const cursorSettingKey = 'last_pulled_cursor';

  final db.AppDatabase _db;
  final SyncTransport _transport;
  final void Function(String message) _logger;

  static void _ignore(String message) {}

  @override
  Future<PullSummary> pullAndMerge() async {
    final cursor = await _readCursor();
    final response = await _transport.pullSince(cursor);

    var applied = 0;
    var skipped = 0;
    var conflictLost = 0;

    for (final event in response.events) {
      try {
        final outcome = await _applyRemoteEvent(event);
        switch (outcome) {
          case _ApplyOutcome.applied:
            applied++;
          case _ApplyOutcome.skipped:
            skipped++;
          case _ApplyOutcome.conflictLost:
            conflictLost++;
        }
      } catch (error) {
        _logger('sync pull: apply failed for ${event.tableName}/'
            '${event.rowId}: $error');
        skipped++;
      }
    }

    // Cursor advances only when the pull itself succeeded (we got here).
    // Apply failures already applied what they could — events are
    // idempotent, so a later session re-pulling the same range is safe.
    final nextCursor = response.nextCursor;
    await _persistCursor(nextCursor);

    return PullSummary(
      applied: applied,
      skipped: skipped,
      conflictLost: conflictLost,
      cursor: nextCursor,
    );
  }

  /// Applies one remote event.
  Future<_ApplyOutcome> _applyRemoteEvent(SyncEvent event) {
    switch (event.tableName) {
      case 'tasks':
        return _mergeDataRow(
          tableName: 'tasks',
          rowId: event.rowId,
          payload: event.payload,
        );
      case 'tags':
        return _mergeDataRow(
          tableName: 'tags',
          rowId: event.rowId,
          payload: event.payload,
        );
      case 'subtasks':
        return _mergeDataRow(
          tableName: 'subtasks',
          rowId: event.rowId,
          payload: event.payload,
        );
      case 'comments':
        return _mergeDataRow(
          tableName: 'comments',
          rowId: event.rowId,
          payload: event.payload,
        );
      case 'contacts':
        return _mergeDataRow(
          tableName: 'contacts',
          rowId: event.rowId,
          payload: event.payload,
        );
      case 'task_tags':
      case 'task_contacts':
      case 'task_dependencies':
        return _mergeJoinRow(
          tableName: event.tableName,
          rowId: event.rowId,
          payload: event.payload,
        );
      default:
        _logger('sync pull: unknown table ${event.tableName} — skipped');
        return Future.value(_ApplyOutcome.skipped);
    }
  }

  Future<_ApplyOutcome> _mergeDataRow({
    required String tableName,
    required String rowId,
    required Map<String, dynamic> payload,
  }) async {
    switch (tableName) {
      case 'tasks':
        final local = await (_db.select(_db.tasks)
              ..where((t) => t.id.equals(rowId)))
            .getSingleOrNull();
        if (local == null) {
          final incoming = db.Task.fromJson(payload);
          await _db.into(_db.tasks).insert(incoming.toCompanion(false));
          return _ApplyOutcome.applied;
        }
        final localScore = _lwwScore(
          updatedAt: local.updatedAt,
          createdAt: local.createdAt,
          deletedAt: local.deletedAt,
        );
        final incomingScore = _lwwScore(
          updatedAt: _asInt(payload['updatedAt']),
          createdAt: _asInt(payload['createdAt']),
          deletedAt: _asInt(payload['deletedAt']),
        );
        if (incomingScore > localScore) {
          final incoming = db.Task.fromJson(payload);
          await (_db.update(_db.tasks)..where((t) => t.id.equals(rowId)))
              .write(incoming.toCompanion(false));
          return _ApplyOutcome.applied;
        }
        return _ApplyOutcome.conflictLost;

      case 'tags':
        final local = await (_db.select(_db.tags)
              ..where((t) => t.id.equals(rowId)))
            .getSingleOrNull();
        if (local == null) {
          final incoming = db.Tag.fromJson(payload);
          await _db.into(_db.tags).insert(incoming.toCompanion(false));
          return _ApplyOutcome.applied;
        }
        // Tags have no timestamps — scores are both 0 → local wins.
        return _ApplyOutcome.conflictLost;

      case 'subtasks':
        final local = await (_db.select(_db.subtasks)
              ..where((s) => s.id.equals(rowId)))
            .getSingleOrNull();
        if (local == null) {
          final incoming = db.Subtask.fromJson(payload);
          await _db.into(_db.subtasks).insert(incoming.toCompanion(false));
          return _ApplyOutcome.applied;
        }
        final localScore = _lwwScore(
          updatedAt: local.updatedAt,
          createdAt: local.createdAt,
        );
        final incomingScore = _lwwScore(
          updatedAt: _asInt(payload['updatedAt']),
          createdAt: _asInt(payload['createdAt']),
        );
        if (incomingScore > localScore) {
          final incoming = db.Subtask.fromJson(payload);
          await (_db.update(_db.subtasks)..where((s) => s.id.equals(rowId)))
              .write(incoming.toCompanion(false));
          return _ApplyOutcome.applied;
        }
        return _ApplyOutcome.conflictLost;

      case 'comments':
        final local = await (_db.select(_db.comments)
              ..where((c) => c.id.equals(rowId)))
            .getSingleOrNull();
        if (local == null) {
          final incoming = db.Comment.fromJson(payload);
          await _db.into(_db.comments).insert(incoming.toCompanion(false));
          return _ApplyOutcome.applied;
        }
        final localScore = _lwwScore(
          updatedAt: local.updatedAt,
          createdAt: local.createdAt,
          deletedAt: local.deletedAt,
        );
        final incomingScore = _lwwScore(
          updatedAt: _asInt(payload['updatedAt']),
          createdAt: _asInt(payload['createdAt']),
          deletedAt: _asInt(payload['deletedAt']),
        );
        if (incomingScore > localScore) {
          final incoming = db.Comment.fromJson(payload);
          await (_db.update(_db.comments)..where((c) => c.id.equals(rowId)))
              .write(incoming.toCompanion(false));
          return _ApplyOutcome.applied;
        }
        return _ApplyOutcome.conflictLost;

      case 'contacts':
        final local = await (_db.select(_db.contacts)
              ..where((c) => c.id.equals(rowId)))
            .getSingleOrNull();
        if (local == null) {
          final incoming = db.Contact.fromJson(payload);
          await _db.into(_db.contacts).insert(incoming.toCompanion(false));
          return _ApplyOutcome.applied;
        }
        final localScore = _lwwScore(
          updatedAt: local.updatedAt,
          createdAt: local.createdAt,
          deletedAt: local.deletedAt,
        );
        final incomingScore = _lwwScore(
          updatedAt: _asInt(payload['updatedAt']),
          createdAt: _asInt(payload['createdAt']),
          deletedAt: _asInt(payload['deletedAt']),
        );
        if (incomingScore > localScore) {
          final incoming = db.Contact.fromJson(payload);
          await (_db.update(_db.contacts)..where((c) => c.id.equals(rowId)))
              .write(incoming.toCompanion(false));
          return _ApplyOutcome.applied;
        }
        return _ApplyOutcome.conflictLost;

      default:
        return _ApplyOutcome.skipped;
    }
  }

  /// Join tables — option 1, pure add-wins. See class doc.
  Future<_ApplyOutcome> _mergeJoinRow({
    required String tableName,
    required String rowId,
    required Map<String, dynamic> payload,
  }) async {
    if (_looksLikeJoinRemoval(tableName, payload)) {
      // Option 1: never apply remote removals (see KNOWN LIMITATION).
      _logger('sync pull: skip $tableName/$rowId — remote link removal '
          'not applied (add-wins; see sync_pull_engine_impl docs)');
      return _ApplyOutcome.conflictLost;
    }

    final key = _parseJoinKey(tableName, rowId, payload);
    if (key == null) {
      _logger('sync pull: skip $tableName/$rowId — malformed join key');
      return _ApplyOutcome.skipped;
    }

    switch (tableName) {
      case 'task_tags':
        final existing = await (_db.select(_db.taskTags)
              ..where((tt) =>
                  tt.taskId.equals(key[0]) & tt.tagId.equals(key[1])))
            .getSingleOrNull();
        if (existing != null) return _ApplyOutcome.skipped;
        await _db.into(_db.taskTags).insert(
              db.TaskTagsCompanion.insert(taskId: key[0], tagId: key[1]),
              onConflict: DoNothing(),
            );
        return _ApplyOutcome.applied;

      case 'task_contacts':
        final existing = await (_db.select(_db.taskContacts)
              ..where((tc) =>
                  tc.taskId.equals(key[0]) & tc.contactId.equals(key[1])))
            .getSingleOrNull();
        if (existing != null) return _ApplyOutcome.skipped;
        await _db.into(_db.taskContacts).insert(
              db.TaskContactsCompanion.insert(
                taskId: key[0],
                contactId: key[1],
              ),
              onConflict: DoNothing(),
            );
        return _ApplyOutcome.applied;

      case 'task_dependencies':
        final existing = await (_db.select(_db.taskDependencies)
              ..where((td) =>
                  td.predecessorId.equals(key[0]) &
                  td.successorId.equals(key[1])))
            .getSingleOrNull();
        if (existing != null) return _ApplyOutcome.skipped;
        await _db.into(_db.taskDependencies).insert(
              db.TaskDependenciesCompanion.insert(
                predecessorId: key[0],
                successorId: key[1],
              ),
              onConflict: DoNothing(),
            );
        return _ApplyOutcome.applied;

      default:
        return _ApplyOutcome.skipped;
    }
  }

  /// Detects removal-shaped join payloads under option 1.
  ///
  /// Link-exists events carry the composite key columns in the payload
  /// (matching the stable SyncEvent JSON format). Anything else — empty
  /// payload, explicit `removed: true`, or missing key columns — is
  /// treated as a remote removal and never applied.
  bool _looksLikeJoinRemoval(String tableName, Map<String, dynamic> payload) {
    if (payload['removed'] == true) return true;
    switch (tableName) {
      case 'task_tags':
        return payload['taskId'] == null || payload['tagId'] == null;
      case 'task_contacts':
        return payload['taskId'] == null || payload['contactId'] == null;
      case 'task_dependencies':
        return payload['predecessorId'] == null ||
            payload['successorId'] == null;
      default:
        return true;
    }
  }

  /// Prefers payload key columns; falls back to parsing the composite rowId.
  List<String>? _parseJoinKey(
    String tableName,
    String rowId,
    Map<String, dynamic> payload,
  ) {
    String? a;
    String? b;
    switch (tableName) {
      case 'task_tags':
        a = payload['taskId'] as String?;
        b = payload['tagId'] as String?;
      case 'task_contacts':
        a = payload['taskId'] as String?;
        b = payload['contactId'] as String?;
      case 'task_dependencies':
        a = payload['predecessorId'] as String?;
        b = payload['successorId'] as String?;
      default:
        return null;
    }
    if (a != null && b != null && a.isNotEmpty && b.isNotEmpty) {
      return [a, b];
    }
    final parts = rowId.split(':');
    if (parts.length == 2 && parts.every((p) => p.isNotEmpty)) {
      return parts;
    }
    return null;
  }

  /// LWW score: max(coalesce(updatedAt, createdAt), coalesce(deletedAt, 0)).
  static int _lwwScore({int? updatedAt, int? createdAt, int? deletedAt}) {
    final ts = updatedAt ?? createdAt ?? 0;
    final del = deletedAt ?? 0;
    return ts > del ? ts : del;
  }

  static int? _asInt(Object? value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return null;
  }

  Future<String?> _readCursor() => _db.lookupSettings(cursorSettingKey);

  Future<void> _persistCursor(String? cursor) async {
    if (cursor == null) {
      await (_db.delete(_db.appSettings)
            ..where((s) => s.key.equals(cursorSettingKey)))
          .go();
      return;
    }
    await _db.storeSetting(cursorSettingKey, cursor);
  }
}

enum _ApplyOutcome { applied, skipped, conflictLost }
