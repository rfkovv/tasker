import 'dart:async';

import '../../../local_db/daos/contacts_dao.dart';
import '../../../local_db/daos/tasks_dao.dart';
import '../../../local_db/database.dart' as db;
import '../domain/task.dart';
import '../domain/task_filter.dart';
import '../domain/task_repository.dart';
import '../domain/task_status.dart';
import 'task_mapper.dart';

class TaskRepositoryImpl implements TaskRepository {
  TaskRepositoryImpl({
    required db.AppDatabase database,
    required Future<String> Function() ownerIdLoader,
  })  : _db = database,
        _dao = database.tasksDao,
        _contactsDao = database.contactsDao,
        _ownerIdLoader = ownerIdLoader;

  final db.AppDatabase _db;
  final TasksDao _dao;
  final ContactsDao _contactsDao;
  final Future<String> Function() _ownerIdLoader;
  final _mapper = TaskMapper();

  @override
  Stream<List<Task>> watchAll({TaskFilter filter = TaskFilter.none}) async* {
    final status = filter.status?.dbValue;
    final priority = filter.priority?.dbValue;
    final contactId = filter.contactId;
    final titleLike = filter.titleQuery?.trim();
    final effectiveTitle =
        (titleLike == null || titleLike.isEmpty) ? null : titleLike;

    yield* _dao
        .watchAllTasks(
          status: status,
          priority: priority,
          titleLike: effectiveTitle,
        )
        .asyncMap(
      (rows) async {
        // Resolve the set of task ids linked to the requested contact (if any)
        // ahead of filtering so linked tasks are matched by their ids.
        final contactTaskIds = contactId == null
            ? null
            : (await _contactsDao.taskIdsForContact(contactId)).toSet();
        final tagMap =
            await _dao.tagsForTasks(rows.map((r) => r.id).toList());
        final tasks = rows
            .map((row) => _mapper.toDomain(row, tagMap[row.id] ?? const []))
            .where((task) {
          if (filter.hideDone && task.status == TaskStatus.done) return false;
          if (filter.tag != null && !task.tags.contains(filter.tag)) {
            return false;
          }
          if (filter.noDueDate && task.dueDate != null) return false;
          if (contactTaskIds != null && !contactTaskIds.contains(task.id)) {
            return false;
          }
          return true;
        })
            .toList();
        return sortTasks(tasks, filter.sort);
      },
    );
  }

  @override
  Stream<Task?> watchById(String id) async* {
    yield* _dao.watchTaskById(id).asyncMap((row) async {
      if (row == null) return null;
      final tags = await _dao.tagsForTask(row.id);
      return _mapper.toDomain(row, tags);
    });
  }

  @override
  Future<Task> create(Task task) async {
    final ownerId = await _ownerIdLoader();
    await _dao.upsertTask(_mapper.toCompanion(task, ownerId: ownerId));
    if (task.tags.isNotEmpty) {
      await _dao.replaceTagsForTask(task.id, task.tags);
    }
    final row = await _dao.getTaskById(task.id);
    final tags = await _dao.tagsForTask(task.id);
    return _mapper.toDomain(row, tags);
  }

  @override
  Future<Task> createWithContacts(
    Task task,
    List<String> contactIds,
  ) async {
    final ownerId = await _ownerIdLoader();
    final companion = _mapper.toCompanion(task, ownerId: ownerId);
    await _db.createTaskWithContacts(
      task: companion,
      tagNames: task.tags,
      contactIds: contactIds,
    );
    final row = await _dao.getTaskById(task.id);
    final tags = await _dao.tagsForTask(task.id);
    return _mapper.toDomain(row, tags);
  }

  @override
  Future<void> update(Task task) async {
    final ownerId = await _ownerIdLoader();
    await _dao.upsertTask(_mapper.toCompanion(task, ownerId: ownerId));
    await _dao.replaceTagsForTask(task.id, task.tags);
  }

  @override
  Future<void> updateStatus(String id, TaskStatus status) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _dao.updateStatus(id, status.dbValue, now);
  }

  @override
  Future<void> delete(String id) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _dao.softDeleteTask(id, now);
  }
}
