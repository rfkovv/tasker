import 'dart:async';

import 'package:drift/drift.dart';

import '../../../local_db/database.dart' as db;
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
      final now = DateTime.now().millisecondsSinceEpoch;
      await (_db.update(_db.tasks)..where((t) => t.id.equals(id))).write(
        db.TasksCompanion(deletedAt: Value(null), updatedAt: Value(now)),
      );
      await (_db.update(_db.comments)
            ..where((c) => c.taskId.equals(id) & c.deletedAt.isNotNull()))
          .write(db.CommentsCompanion(deletedAt: Value(null)));
    });
  }

  @override
  Future<void> restoreContact(String id) async {
    await _db.transaction(() async {
      final now = DateTime.now().millisecondsSinceEpoch;
      await (_db.update(_db.contacts)..where((c) => c.id.equals(id))).write(
        db.ContactsCompanion(deletedAt: Value(null), updatedAt: Value(now)),
      );
    });
  }

  @override
  Future<void> emptyTrash() async {
    await _db.transaction(() async {
      // Hard-delete ALL soft-deleted comments (including those whose
      // tasks are still live — individually soft-deleted comments).
      await (_db.delete(
        _db.comments,
      )..where((c) => c.deletedAt.isNotNull())).go();

      // Hard-delete soft-deleted tasks + dangling references.
      final deletedTasks = await (_db.select(
        _db.tasks,
      )..where((t) => t.deletedAt.isNotNull())).get();
      final taskIds = deletedTasks.map((t) => t.id).toList();
      if (taskIds.isNotEmpty) {
        await (_db.delete(
          _db.subtasks,
        )..where((s) => s.taskId.isIn(taskIds))).go();
        await (_db.delete(
          _db.taskTags,
        )..where((tt) => tt.taskId.isIn(taskIds))).go();
        await (_db.delete(_db.taskDependencies)..where(
              (td) =>
                  td.predecessorId.isIn(taskIds) | td.successorId.isIn(taskIds),
            ))
            .go();
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
