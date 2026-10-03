import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskmaster/features/contacts/data/contact_repository_impl.dart';
import 'package:taskmaster/features/tasks/data/comment_repository_impl.dart';
import 'package:taskmaster/features/tasks/data/subtask_repository_impl.dart';
import 'package:taskmaster/features/tasks/data/task_repository_impl.dart';
import 'package:taskmaster/features/tasks/domain/task.dart';
import 'package:taskmaster/features/tasks/domain/task_filter.dart';
import 'package:taskmaster/features/tasks/domain/task_priority.dart';
import 'package:taskmaster/features/tasks/domain/task_status.dart';
import 'package:taskmaster/features/trash/data/trash_repository_impl.dart';
import 'package:taskmaster/local_db/daos/comments_dao.dart';
import 'package:taskmaster/local_db/daos/contacts_dao.dart';
import 'package:taskmaster/local_db/daos/subtasks_dao.dart';
import 'package:taskmaster/local_db/daos/tasks_dao.dart';
import 'package:taskmaster/local_db/database.dart' as db;

Task buildTask({
  String? id,
  String title = 'Test task',
  TaskStatus status = TaskStatus.todo,
  TaskPriority priority = TaskPriority.medium,
  List<String> tags = const [],
  DateTime? dueDate,
}) {
  final now = DateTime.now();
  return Task(
    id: id ?? 'id-${now.microsecondsSinceEpoch}',
    title: title,
    description: 'desc',
    tags: tags,
    priority: priority,
    dueDate: dueDate,
    status: status,
    createdAt: now,
    updatedAt: now,
  );
}

class _InMemoryDatabase {
  _InMemoryDatabase() {
    database = db.AppDatabase(NativeDatabase.memory());
    tasksDao = database.tasksDao;
    contactsDao = database.contactsDao;
    commentsDao = database.commentsDao;
    subtasksDao = database.subtasksDao;
    taskRepository = TaskRepositoryImpl(
      database: database,
      ownerIdLoader: () async => 'owner-test',
    );
    contactRepository = ContactRepositoryImpl(dao: contactsDao);
    commentRepository = CommentRepositoryImpl(dao: commentsDao);
    subtaskRepository = SubtaskRepositoryImpl(dao: subtasksDao);
    trashRepository = TrashRepositoryImpl(database: database);
  }

  late final db.AppDatabase database;
  late final TasksDao tasksDao;
  late final ContactsDao contactsDao;
  late final CommentsDao commentsDao;
  late final SubtasksDao subtasksDao;
  late final TaskRepositoryImpl taskRepository;
  late final ContactRepositoryImpl contactRepository;
  late final CommentRepositoryImpl commentRepository;
  late final SubtaskRepositoryImpl subtaskRepository;
  late final TrashRepositoryImpl trashRepository;

  Future<void> close() => database.close();

  Future<void> insertDependency(
    String predecessorId,
    String successorId,
  ) async {
    await database
        .into(database.taskDependencies)
        .insert(
          db.TaskDependenciesCompanion.insert(
            predecessorId: predecessorId,
            successorId: successorId,
          ),
        );
  }
}

void main() {
  late _InMemoryDatabase harness;

  setUp(() {
    harness = _InMemoryDatabase();
  });

  tearDown(() {
    harness.close();
  });

  group('STEP 0 audit: visibility invariants', () {
    test('deleted task excluded from watchAll (task list)', () async {
      final task = await harness.taskRepository.create(buildTask(title: 'T1'));
      await harness.taskRepository.delete(task.id);

      final all = await harness.taskRepository.watchAll().first;
      expect(all, isEmpty);
    });

    test('deleted task excluded from watchAll with filter (calendar uses '
        'TaskFilter.none)', () async {
      final task = await harness.taskRepository.create(buildTask(title: 'T1'));
      await harness.taskRepository.delete(task.id);

      final all = await harness.taskRepository
          .watchAll(filter: TaskFilter.none)
          .first;
      expect(all, isEmpty);
    });

    test('deleted task excluded from watchById', () async {
      final task = await harness.taskRepository.create(buildTask(title: 'T1'));
      await harness.taskRepository.delete(task.id);

      final watched = await harness.taskRepository.watchById(task.id).first;
      expect(watched, isNull);
    });

    test('deleted contact excluded from watchAll', () async {
      final contact = await harness.contactRepository.create(name: 'Alice');
      await harness.contactRepository.delete(contact.id);

      final all = await harness.contactRepository.watchAll().first;
      expect(all, isEmpty);
    });

    test('deleted comment excluded from watchCommentsForTask', () async {
      final task = await harness.taskRepository.create(buildTask(title: 'T1'));
      final comment = await harness.commentRepository.create(
        taskId: task.id,
        body: 'hi',
      );
      await harness.commentRepository.delete(comment.id);

      final comments = await harness.commentsDao
          .watchCommentsForTask(task.id)
          .first;
      expect(comments, isEmpty);
    });

    test('deleted task NOT surfaced by search-style titleQuery', () async {
      final task = await harness.taskRepository.create(
        buildTask(title: 'secret plan'),
      );
      await harness.taskRepository.delete(task.id);

      final found = await harness.taskRepository
          .watchAll(filter: TaskFilter(titleQuery: 'secret'))
          .first;
      expect(found, isEmpty);
    });
  });

  group('Kosz surfaces deleted rows', () {
    test('watchDeletedTasks returns soft-deleted tasks', () async {
      final live = await harness.taskRepository.create(
        buildTask(title: 'Live'),
      );
      final dead = await harness.taskRepository.create(
        buildTask(title: 'Dead'),
      );
      await harness.taskRepository.delete(dead.id);

      final deleted = await harness.trashRepository.watchDeletedTasks().first;
      expect(deleted.length, 1);
      expect(deleted.first.id, dead.id);
      expect(deleted.first.title, 'Dead');

      final liveStill = await harness.taskRepository.watchAll().first;
      expect(liveStill.length, 1);
      expect(liveStill.first.id, live.id);
    });

    test('watchDeletedContacts returns soft-deleted contacts', () async {
      final live = await harness.contactRepository.create(name: 'Live');
      final dead = await harness.contactRepository.create(name: 'Dead');
      await harness.contactRepository.delete(dead.id);

      final deleted = await harness.trashRepository
          .watchDeletedContacts()
          .first;
      expect(deleted.length, 1);
      expect(deleted.first.id, dead.id);
      expect(deleted.first.name, 'Dead');

      final liveStill = await harness.contactRepository.watchAll().first;
      expect(liveStill.length, 1);
      expect(liveStill.first.id, live.id);
    });
  });

  group('restore roundtrip: task with subtasks, comments, tags, links', () {
    test('task + all references visible again after restore', () async {
      final now = DateTime.now();
      final task = buildTask(title: 'Roundtrip', tags: ['work']);
      final created = await harness.taskRepository.create(task);

      // Subtask
      final subtask = await harness.subtaskRepository.create(
        taskId: created.id,
        title: 'step 1',
      );
      await harness.subtaskRepository.toggle(subtask.id, isCompleted: true);

      // Comment (cascade soft-deleted with the task)
      await harness.commentRepository.create(
        taskId: created.id,
        body: 'a note',
      );

      // Dependency
      final other = await harness.taskRepository.create(
        buildTask(title: 'Other'),
      );
      await harness.insertDependency(other.id, created.id);

      // Contact link
      final contact = await harness.contactRepository.create(name: 'Partner');
      await harness.contactRepository.replaceContactsForTask(created.id, [
        contact.id,
      ]);

      // Soft-delete the task (cascade soft-deletes comments)
      await harness.taskRepository.delete(created.id);

      // Visibility: gone from list, search; present in trash
      final listAfterDelete = await harness.taskRepository.watchAll().first;
      expect(listAfterDelete.length, 1);
      expect(listAfterDelete.first.id, other.id);
      final trashAfterDelete = await harness.trashRepository
          .watchDeletedTasks()
          .first;
      expect(trashAfterDelete.length, 1);
      expect(trashAfterDelete.first.id, created.id);

      // Restore
      await harness.trashRepository.restoreTask(created.id);

      // Visible again in the task list
      final listAfterRestore = await harness.taskRepository.watchAll().first;
      expect(listAfterRestore.length, 2);
      final restored = listAfterRestore.firstWhere((t) => t.id == created.id);
      expect(restored.title, 'Roundtrip');
      expect(restored.tags, ['work']);
      expect(restored.deletedAt, isNull);
      expect(
        restored.updatedAt.millisecondsSinceEpoch,
        greaterThanOrEqualTo(now.millisecondsSinceEpoch),
      );

      // Gone from trash
      final trashAfterRestore = await harness.trashRepository
          .watchDeletedTasks()
          .first;
      expect(trashAfterRestore, isEmpty);

      // Subtask counter x/y correct (subtasks were never soft-deleted)
      final subtasks = await harness.subtasksDao
          .watchSubtasksForTask(created.id)
          .first;
      expect(subtasks.length, 1);
      expect(subtasks.first.isCompleted, isTrue);

      // Comments restored (cascade soft-delete cleared on restore)
      final comments = await harness.commentsDao
          .watchCommentsForTask(created.id)
          .first;
      expect(comments.length, 1);
      expect(comments.first.body, 'a note');
      expect(comments.first.deletedAt, isNull);

      // Tags intact
      final tags = await harness.tasksDao.tagsForTask(created.id);
      expect(tags.map((t) => t.name), ['work']);

      // Contact links intact
      final linked = await harness.contactRepository.contactsForTask(
        created.id,
      );
      expect(linked.length, 1);
      expect(linked.first.name, 'Partner');
    });

    test(
      'calendar shows restored task again (taskListProvider filter none)',
      () async {
        final now = DateTime.now();
        final day = DateTime(now.year, now.month, now.day, 10);
        final task = buildTask(title: 'Meeting', dueDate: day);
        final created = await harness.taskRepository.create(task);
        await harness.taskRepository.delete(created.id);

        var visible = await harness.taskRepository
            .watchAll(filter: TaskFilter.none)
            .first;
        expect(visible, isEmpty);

        await harness.trashRepository.restoreTask(created.id);

        visible = await harness.taskRepository
            .watchAll(filter: TaskFilter.none)
            .first;
        expect(visible.length, 1);
        expect(visible.first.dueDate, day);
      },
    );
  });

  group('restore contact: links back, tasks NOT resurrected', () {
    test('contact restore brings links back but not the tasks', () async {
      final contact = await harness.contactRepository.create(name: 'Alice');
      final task = await harness.taskRepository.create(
        buildTask(title: 'Linked task'),
      );
      await harness.contactRepository.replaceContactsForTask(task.id, [
        contact.id,
      ]);

      // Soft-delete BOTH the contact and the task
      await harness.contactRepository.delete(contact.id);
      await harness.taskRepository.delete(task.id);

      // Contact gone from list; link hidden (contact deletedAt filter)
      final contactsAfterDelete = await harness.contactRepository
          .watchAll()
          .first;
      expect(contactsAfterDelete, isEmpty);
      final linksAfterDelete = await harness.contactRepository.contactsForTask(
        task.id,
      );
      expect(linksAfterDelete, isEmpty);

      // Restore ONLY the contact
      await harness.trashRepository.restoreContact(contact.id);

      // Contact visible again
      final contactsAfterRestore = await harness.contactRepository
          .watchAll()
          .first;
      expect(contactsAfterRestore.length, 1);
      expect(contactsAfterRestore.first.name, 'Alice');
      expect(contactsAfterRestore.first.deletedAt, isNull);

      // Contact gone from trash
      final trashContacts = await harness.trashRepository
          .watchDeletedContacts()
          .first;
      expect(trashContacts, isEmpty);

      // Link row still exists — contact is linked to the task id again
      final taskIds = await harness.contactsDao.taskIdsForContact(contact.id);
      expect(taskIds, [task.id]);

      // BUT the task itself is NOT resurrected (still in trash / excluded
      // from the live list)
      final tasksAfterRestore = await harness.taskRepository.watchAll().first;
      expect(tasksAfterRestore, isEmpty);
      final trashTasks = await harness.trashRepository
          .watchDeletedTasks()
          .first;
      expect(trashTasks.length, 1);
      expect(trashTasks.first.id, task.id);

      // contactsForTask now returns the restored contact (live join)
      final links = await harness.contactRepository.contactsForTask(task.id);
      expect(links.length, 1);
      expect(links.first.name, 'Alice');
    });
  });

  group('empty trash: hard DELETE', () {
    test('hard-deletes all soft-deleted rows; gone from trash too', () async {
      final liveTask = await harness.taskRepository.create(
        buildTask(title: 'Keep'),
      );
      final deadTask = await harness.taskRepository.create(
        buildTask(title: 'Drop'),
      );
      final deadComment = await harness.commentRepository.create(
        taskId: deadTask.id,
        body: 'gone with it',
      );
      await harness.subtaskRepository.create(
        taskId: deadTask.id,
        title: 'sub',
      );
      final liveContact = await harness.contactRepository.create(name: 'KeepC');
      final deadContact = await harness.contactRepository.create(name: 'DropC');
      await harness.contactRepository.replaceContactsForTask(deadTask.id, [
        deadContact.id,
      ]);
      await harness.contactRepository.replaceContactsForTask(liveTask.id, [
        liveContact.id,
      ]);

      await harness.taskRepository.delete(deadTask.id);
      await harness.contactRepository.delete(deadContact.id);
      // Individually soft-delete a comment on the LIVE task
      final liveComment = await harness.commentRepository.create(
        taskId: liveTask.id,
        body: 'soft',
      );
      await harness.commentRepository.delete(liveComment.id);

      // Trash has: deadTask, deadContact, liveComment (soft-deleted comment)
      final trashTasks = await harness.trashRepository
          .watchDeletedTasks()
          .first;
      expect(trashTasks.length, 1);
      final trashContacts = await harness.trashRepository
          .watchDeletedContacts()
          .first;
      expect(trashContacts.length, 1);

      await harness.trashRepository.emptyTrash();

      // Trash empty
      expect(await harness.trashRepository.watchDeletedTasks().first, isEmpty);
      expect(
        await harness.trashRepository.watchDeletedContacts().first,
        isEmpty,
      );

      // Rows physically gone
      final deadTaskRow = await (harness.database.select(
        harness.database.tasks,
      )..where((t) => t.id.equals(deadTask.id))).getSingleOrNull();
      expect(deadTaskRow, isNull);

      final deadContactRow = await (harness.database.select(
        harness.database.contacts,
      )..where((c) => c.id.equals(deadContact.id))).getSingleOrNull();
      expect(deadContactRow, isNull);

      // Cascade: subtask + links of dead task gone
      final subRows = await (harness.database.select(
        harness.database.subtasks,
      )..where((s) => s.taskId.equals(deadTask.id))).get();
      expect(subRows, isEmpty);
      final linkRows = await (harness.database.select(
        harness.database.taskContacts,
      )..where((tc) => tc.taskId.equals(deadTask.id))).get();
      expect(linkRows, isEmpty);

      // Soft-deleted comment on live task also hard-deleted
      final commentRow = await (harness.database.select(
        harness.database.comments,
      )..where((c) => c.id.equals(deadComment.id))).getSingleOrNull();
      expect(commentRow, isNull);
      final liveCommentRow = await (harness.database.select(
        harness.database.comments,
      )..where((c) => c.id.equals(liveComment.id))).getSingleOrNull();
      expect(liveCommentRow, isNull);

      // Live data untouched
      final liveTasks = await harness.taskRepository.watchAll().first;
      expect(liveTasks.length, 1);
      expect(liveTasks.first.id, liveTask.id);
      final liveContacts = await harness.contactRepository.watchAll().first;
      expect(liveContacts.length, 1);
      expect(liveContacts.first.id, liveContact.id);
      // Live task's link to live contact intact
      final liveLinks = await harness.contactRepository.contactsForTask(
        liveTask.id,
      );
      expect(liveLinks.length, 1);
    });
  });

  group('contact join leak regression (STEP 0 audit fix)', () {
    test('soft-deleted contact excluded from contactsForTask', () async {
      final task = await harness.taskRepository.create(buildTask(title: 'T'));
      final contact = await harness.contactRepository.create(name: 'Ghost');
      await harness.contactRepository.replaceContactsForTask(task.id, [
        contact.id,
      ]);

      var linked = await harness.contactRepository.contactsForTask(task.id);
      expect(linked.length, 1);

      await harness.contactRepository.delete(contact.id);

      linked = await harness.contactRepository.contactsForTask(task.id);
      expect(linked, isEmpty, reason: 'soft-deleted contact must not leak');
    });

    test('soft-deleted contact excluded from contactsByTaskIds', () async {
      final task = await harness.taskRepository.create(buildTask(title: 'T'));
      final contact = await harness.contactRepository.create(name: 'Ghost');
      await harness.contactRepository.replaceContactsForTask(task.id, [
        contact.id,
      ]);

      var grouped = await harness.contactRepository.contactsByTaskIds([
        task.id,
      ]);
      expect(grouped[task.id]?.length, 1);

      await harness.contactRepository.delete(contact.id);

      grouped = await harness.contactRepository.contactsByTaskIds([task.id]);
      expect(
        grouped[task.id] ?? [],
        isEmpty,
        reason: 'soft-deleted contact must not leak into task chips',
      );
    });
  });

  group('anty-zombie restore + updatedAt symmetry', () {
    test('cascade delete: comment updatedAt == deletedAt == task.deletedAt',
        () async {
      final task = await harness.taskRepository.create(buildTask(title: 'T'));
      final comment = await harness.commentRepository.create(
        taskId: task.id,
        body: 'batch',
      );

      await harness.taskRepository.delete(task.id);

      final taskRow = await harness.tasksDao.getTaskById(task.id);
      final commentRow = await harness.commentsDao.getCommentById(
        comment.id,
      );
      expect(taskRow.deletedAt, isNotNull);
      expect(commentRow.deletedAt, taskRow.deletedAt);
      expect(commentRow.updatedAt, taskRow.deletedAt);
      expect(commentRow.updatedAt, taskRow.updatedAt);
    });

    test(
        'restore after cascade: comments restored AND updatedAt > old '
        'updatedAt', () async {
      final task = await harness.taskRepository.create(buildTask(title: 'T'));
      final comment = await harness.commentRepository.create(
        taskId: task.id,
        body: 'note',
      );
      // Force a clearly old updatedAt so the restore bump is strictly
      // greater regardless of same-millisecond operations.
      const oldUpdatedAt = 1000;
      await (harness.database.update(harness.database.comments)
            ..where((c) => c.id.equals(comment.id)))
          .write(db.CommentsCompanion(updatedAt: const Value(oldUpdatedAt)));

      await harness.taskRepository.delete(task.id);
      await harness.trashRepository.restoreTask(task.id);

      final restored = await harness.commentsDao.getCommentById(comment.id);
      expect(restored.deletedAt, isNull);
      expect(restored.updatedAt, isNotNull);
      expect(restored.updatedAt!, greaterThan(oldUpdatedAt));
    });

    test(
        'anty-zombie: individually deleted comment stays deleted after '
        'task restore', () async {
      final task = await harness.taskRepository.create(buildTask(title: 'T'));
      final cascadeComment = await harness.commentRepository.create(
        taskId: task.id,
        body: 'cascade batch',
      );
      final zombieComment = await harness.commentRepository.create(
        taskId: task.id,
        body: 'deleted before task',
      );

      // Individually soft-delete with a distinctive past timestamp so it
      // can never collide with the later cascade batch identity.
      const individualTs = 5000;
      await (harness.database.update(harness.database.comments)
            ..where((c) => c.id.equals(zombieComment.id)))
          .write(
        db.CommentsCompanion(
          deletedAt: const Value(individualTs),
          updatedAt: const Value(individualTs),
        ),
      );

      await harness.taskRepository.delete(task.id);
      await harness.trashRepository.restoreTask(task.id);

      // Cascade-batch comment restored.
      final cascadeRow = await harness.commentsDao.getCommentById(
        cascadeComment.id,
      );
      expect(cascadeRow.deletedAt, isNull);

      // Individually deleted comment STAYS deleted with its own timestamp.
      final zombieRow = await harness.commentsDao.getCommentById(
        zombieComment.id,
      );
      expect(zombieRow.deletedAt, individualTs);
      expect(zombieRow.updatedAt, individualTs);
    });

    test('restoreTask on live task is a no-op (no writes)', () async {
      final task = await harness.taskRepository.create(buildTask(title: 'L'));
      final comment = await harness.commentRepository.create(
        taskId: task.id,
        body: 'c',
      );
      final taskBefore = await harness.tasksDao.getTaskById(task.id);
      final commentBefore = await harness.commentsDao.getCommentById(
        comment.id,
      );

      await harness.trashRepository.restoreTask(task.id);

      final taskAfter = await harness.tasksDao.getTaskById(task.id);
      final commentAfter = await harness.commentsDao.getCommentById(
        comment.id,
      );
      expect(taskAfter.updatedAt, taskBefore.updatedAt);
      expect(taskAfter.deletedAt, taskBefore.deletedAt);
      expect(commentAfter.updatedAt, commentBefore.updatedAt);
      expect(commentAfter.deletedAt, commentBefore.deletedAt);
    });

    test('restoreTask on nonexistent task is a no-op', () async {
      final live = await harness.taskRepository.create(buildTask(title: 'X'));
      final liveBefore = await harness.tasksDao.getTaskById(live.id);

      await harness.trashRepository.restoreTask('no-such-id');

      final liveAfter = await harness.tasksDao.getTaskById(live.id);
      expect(liveAfter.updatedAt, liveBefore.updatedAt);
      expect(await harness.trashRepository.watchDeletedTasks().first, isEmpty);
    });
  });
}
