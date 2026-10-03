import 'dart:async';

import 'package:drift/drift.dart';

import '../../../local_db/database.dart' as db;
import '../../../local_db/synced_tables.dart';
import '../../contacts/data/contact_mapper.dart';
import '../../contacts/domain/contact.dart';
import '../../tasks/data/task_mapper.dart';
import '../../tasks/domain/task.dart';
import '../domain/trash_repository.dart';

class TrashRepositoryImpl implements TrashRepository {
  TrashRepositoryImpl({required db.AppDatabase database})
    : _db = database,
      _taskMapper = TaskMapper(),
      _contactMapper = ContactMapper();

  final db.AppDatabase _db;
  final TaskMapper _taskMapper;
  final ContactMapper _contactMapper;

  @override
  Stream<List<Task>> watchDeletedTasks() {
    final query = _db.select(_db.tasks)
      ..where((t) => t.deletedAt.isNotNull())
      ..orderBy([(t) => OrderingTerm.desc(t.deletedAt)]);
    // Plain .map (not .asyncMap): trash tiles only surface the title —
    // tags are not rendered — and a sync map avoids pending-timer noise
    // from drift stream cleanup in widget tests.
    return query.watch().map(
      (rows) => rows.map((row) => _taskMapper.toDomain(row, const [])).toList(),
    );
  }

  @override
  Stream<List<Contact>> watchDeletedContacts() {
    final query = _db.select(_db.contacts)
      ..where((c) => c.deletedAt.isNotNull())
      ..orderBy([(c) => OrderingTerm.desc(c.deletedAt)]);
    return query.watch().map(
      (rows) => rows.map(_contactMapper.toDomain).toList(),
    );
  }

  @override
  Future<void> restoreTask(String id) async {
    await _db.transaction(() async {
      final task =
          await (_db.select(_db.tasks)..where((t) => t.id.equals(id)))
              .getSingleOrNull();
      // No-op for live/nonexistent tasks: no writes at all.
      if (task == null || task.deletedAt == null) return;
      final cascadeAt = task.deletedAt!;
      final now = DateTime.now().millisecondsSinceEpoch;
      await (_db.update(_db.tasks)..where((t) => t.id.equals(id))).write(
        db.TasksCompanion(deletedAt: Value(null), updatedAt: Value(now)),
      );
      await _db.enqueueSyncEvent('tasks', id);
      // Anty-zombie: restore ONLY the cascade batch — comments whose
      // deletedAt equals the task's deletedAt. Individually deleted
      // comments (different deletedAt) stay deleted.
      final restoredComments = await (_db.select(_db.comments)
            ..where((c) =>
                c.taskId.equals(id) & c.deletedAt.equals(cascadeAt)))
          .get();
      await (_db.update(_db.comments)
            ..where((c) =>
                c.taskId.equals(id) & c.deletedAt.equals(cascadeAt)))
          .write(
        db.CommentsCompanion(deletedAt: Value(null), updatedAt: Value(now)),
      );
      for (final comment in restoredComments) {
        await _db.enqueueSyncEvent('comments', comment.id);
      }
    });
  }

  @override
  Future<void> restoreContact(String id) async {
    await _db.transaction(() async {
      final now = DateTime.now().millisecondsSinceEpoch;
      await (_db.update(_db.contacts)..where((c) => c.id.equals(id))).write(
        db.ContactsCompanion(deletedAt: Value(null), updatedAt: Value(now)),
      );
      await _db.enqueueSyncEvent('contacts', id);
    });
  }

  /// Hard-deletes every soft-deleted row (the only irreversible action).
  ///
  /// Purge events are data too (server log keeps tombstones): every
  /// hard-deleted rowId enqueues its own outbox event in the same
  /// transaction. Join-table purges use composite natural keys.
  @override
  Future<void> emptyTrash() async {
    await _db.transaction(() async {
      // Hard-delete ALL soft-deleted comments (including those whose
      // tasks are still live — individually soft-deleted comments).
      final deletedComments = await (_db.select(_db.comments)
            ..where((c) => c.deletedAt.isNotNull()))
          .get();
      for (final comment in deletedComments) {
        await _db.enqueueSyncEvent('comments', comment.id);
      }
      await (_db.delete(
        _db.comments,
      )..where((c) => c.deletedAt.isNotNull())).go();

      // Hard-delete soft-deleted tasks + dangling references.
      final deletedTasks = await (_db.select(
        _db.tasks,
      )..where((t) => t.deletedAt.isNotNull())).get();
      final taskIds = deletedTasks.map((t) => t.id).toList();
      if (taskIds.isNotEmpty) {
        for (final task in deletedTasks) {
          await _db.enqueueSyncEvent('tasks', task.id);
        }

        final purgedSubtasks = await (_db.select(
          _db.subtasks,
        )..where((s) => s.taskId.isIn(taskIds))).get();
        for (final subtask in purgedSubtasks) {
          await _db.enqueueSyncEvent('subtasks', subtask.id);
        }
        await (_db.delete(
          _db.subtasks,
        )..where((s) => s.taskId.isIn(taskIds))).go();

        final purgedTaskTags = await (_db.select(
          _db.taskTags,
        )..where((tt) => tt.taskId.isIn(taskIds))).get();
        for (final link in purgedTaskTags) {
          await _db.enqueueSyncEvent(
            'task_tags',
            joinRowId(link.taskId, link.tagId),
          );
        }
        await (_db.delete(
          _db.taskTags,
        )..where((tt) => tt.taskId.isIn(taskIds))).go();

        final purgedDependencies = await (_db.select(_db.taskDependencies)
              ..where((td) =>
                  td.predecessorId.isIn(taskIds) |
                  td.successorId.isIn(taskIds)))
            .get();
        for (final dep in purgedDependencies) {
          await _db.enqueueSyncEvent(
            'task_dependencies',
            dependencyRowId(dep.predecessorId, dep.successorId),
          );
        }
        await (_db.delete(_db.taskDependencies)..where(
              (td) =>
                  td.predecessorId.isIn(taskIds) | td.successorId.isIn(taskIds),
            ))
            .go();

        final purgedTaskContacts = await (_db.select(
          _db.taskContacts,
        )..where((tc) => tc.taskId.isIn(taskIds))).get();
        for (final link in purgedTaskContacts) {
          await _db.enqueueSyncEvent(
            'task_contacts',
            contactLinkRowId(link.taskId, link.contactId),
          );
        }
        await (_db.delete(
          _db.taskContacts,
        )..where((tc) => tc.taskId.isIn(taskIds))).go();

        await (_db.delete(_db.tasks)..where((t) => t.id.isIn(taskIds))).go();
      }

      // Hard-delete soft-deleted contacts + their links.
      final deletedContacts = await (_db.select(
        _db.contacts,
      )..where((c) => c.deletedAt.isNotNull())).get();
      final contactIds = deletedContacts.map((c) => c.id).toList();
      if (contactIds.isNotEmpty) {
        for (final contact in deletedContacts) {
          await _db.enqueueSyncEvent('contacts', contact.id);
        }

        final purgedLinks = await (_db.select(
          _db.taskContacts,
        )..where((tc) => tc.contactId.isIn(contactIds))).get();
        for (final link in purgedLinks) {
          await _db.enqueueSyncEvent(
            'task_contacts',
            contactLinkRowId(link.taskId, link.contactId),
          );
        }
        await (_db.delete(
          _db.taskContacts,
        )..where((tc) => tc.contactId.isIn(contactIds))).go();

        await (_db.delete(
          _db.contacts,
        )..where((c) => c.id.isIn(contactIds))).go();
      }
    });
  }
}
