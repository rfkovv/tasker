import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskmaster/features/tasks/domain/task.dart';
import 'package:taskmaster/features/tasks/domain/task_filter.dart';
import 'package:taskmaster/features/tasks/domain/task_priority.dart';
import 'package:taskmaster/features/tasks/domain/task_status.dart';
import 'package:taskmaster/features/tasks/data/task_repository_impl.dart';
import 'package:taskmaster/local_db/database.dart' as db;
import 'package:taskmaster/local_db/daos/tasks_dao.dart';

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
    dao = database.tasksDao;
    repository = TaskRepositoryImpl(
      database: database,
      ownerIdLoader: () async => 'owner-test',
    );
  }

  late final db.AppDatabase database;
  late final TasksDao dao;
  late final TaskRepositoryImpl repository;

  Future<void> close() => database.close();
}

void main() {
  late _InMemoryDatabase harness;

  setUp(() {
    harness = _InMemoryDatabase();
  });

  tearDown(() {
    harness.close();
  });

  test('create and watch a task', () async {
    final task = buildTask(title: 'Buy milk');

    final created = await harness.repository.create(task);

    expect(created.id, task.id);
    expect(created.title, 'Buy milk');

    final all = await harness.repository.watchAll().first;
    expect(all.length, 1);
    expect(all.first.title, 'Buy milk');
    expect(all.first.status, TaskStatus.todo);
  });

  test('create persists tags', () async {
    final task = buildTask(title: 'Ship feature', tags: ['work', 'urgent']);

    await harness.repository.create(task);

    final all = await harness.repository.watchAll().first;
    expect(all.first.tags, containsAll(['work', 'urgent']));
  });

  test('watchById returns task', () async {
    final task = buildTask(title: 'Single');

    await harness.repository.create(task);

    final watched = await harness.repository.watchById(task.id).first;
    expect(watched, isNotNull);
    expect(watched!.title, 'Single');
  });

  test('update modifies task', () async {
    final task = buildTask(title: 'Before');
    await harness.repository.create(task);

    final updated = task.copyWith(title: 'After');
    await harness.repository.update(updated);

    final watched = await harness.repository.watchById(task.id).first;
    expect(watched!.title, 'After');
  });

  test('updateStatus changes status', () async {
    final task = buildTask(title: 'Do this');
    await harness.repository.create(task);

    await harness.repository.updateStatus(task.id, TaskStatus.inProgress);

    final watched = await harness.repository.watchById(task.id).first;
    expect(watched!.status, TaskStatus.inProgress);
  });

  test('delete soft-deletes and removes from list', () async {
    final task = buildTask(title: 'Remove me');
    await harness.repository.create(task);

    await harness.repository.delete(task.id);

    final all = await harness.repository.watchAll().first;
    expect(all, isEmpty);
  });

  test('filter by status', () async {
    await harness.repository.create(buildTask(title: 'Todo', status: TaskStatus.todo));
    await harness.repository.create(buildTask(title: 'Done', status: TaskStatus.done));

    final done = await harness.repository
        .watchAll(filter: const TaskFilter(status: TaskStatus.done))
        .first;
    expect(done.length, 1);
    expect(done.first.title, 'Done');
  });

  test('filter by priority', () async {
    await harness.repository.create(
      buildTask(title: 'Urgent', priority: TaskPriority.urgent),
    );
    await harness.repository
        .create(buildTask(title: 'Low', priority: TaskPriority.low));

    final urgent = await harness.repository
        .watchAll(filter: const TaskFilter(priority: TaskPriority.urgent))
        .first;
    expect(urgent.length, 1);
    expect(urgent.first.title, 'Urgent');
  });

  test('filter by tag', () async {
    await harness.repository
        .create(buildTask(title: 'Work', tags: ['work']));
    await harness.repository.create(buildTask(title: 'Personal'));

    final work = await harness.repository
        .watchAll(filter: const TaskFilter(tag: 'work'))
        .first;
    expect(work.length, 1);
    expect(work.first.title, 'Work');
  });

  test('hide done filter removes done tasks', () async {
    await harness.repository
        .create(buildTask(title: 'Todo', status: TaskStatus.todo));
    await harness.repository
        .create(buildTask(title: 'Done', status: TaskStatus.done));

    final visible = await harness.repository
        .watchAll(filter: const TaskFilter(hideDone: true))
        .first;
    expect(visible.length, 1);
    expect(visible.first.title, 'Todo');
  });

  test('titleQuery filters titles case-insensitively (LIKE)', () async {
    await harness.repository.create(buildTask(title: 'Buy milk'));
    await harness.repository.create(buildTask(title: 'BUY juice'));
    await harness.repository.create(buildTask(title: 'Shopping'));

    final results = await harness.repository
        .watchAll(filter: const TaskFilter(titleQuery: 'buy'))
        .first;
    expect(results.length, 2);
    expect(results.map((t) => t.title), containsAll(['Buy milk', 'BUY juice']));
  });

  test('empty titleQuery returns every task', () async {
    await harness.repository.create(buildTask(title: 'Anything'));

    final results = await harness.repository
        .watchAll(filter: const TaskFilter(titleQuery: '  '))
        .first;
    expect(results.length, 1);
  });

  test('contactId filter returns only tasks linked to that contact', () async {
    final alice = await harness.database.contactsDao.createContact(
      name: 'Alice',
    );
    final linkedTask = buildTask(title: 'Linked task');
    final otherTask = buildTask(title: 'Other task');
    await harness.repository.create(linkedTask);
    await harness.repository.create(otherTask);
    await harness.database.contactsDao.replaceContactsForTask(
      linkedTask.id,
      [alice.id],
    );

    final results = await harness.repository
        .watchAll(filter: TaskFilter(contactId: alice.id))
        .first;
    expect(results.length, 1);
    expect(results.single.title, 'Linked task');
  });

  test('soft-deleted task is not returned by watchById', () async {
    final task = buildTask(title: 'Gone');
    await harness.repository.create(task);

    await harness.repository.delete(task.id);

    final watched = await harness.repository.watchById(task.id).first;
    expect(watched, isNull);
  });

  test('createWithContacts creates task and links contacts atomically', () async {
    // Insert real contacts so FK constraints are satisfied.
    await harness.database.contactsDao.createContact(
      name: 'Alice',
    );
    await harness.database.contactsDao.createContact(
      name: 'Bob',
    );
    final contacts = await harness.database.contactsDao.watchAllContacts().first;
    final contactIds = contacts.map((c) => c.id).toList();
    final task = buildTask(title: 'With contacts');

    final created =
        await harness.repository.createWithContacts(task, contactIds);

    expect(created.title, 'With contacts');

    final links = await harness.database.contactsDao
        .contactsForTask(task.id);
    expect(links.length, 2);
    expect(links.map((c) => c.id).toSet(), contactIds.toSet());
  });

  test('createWithContacts rolls back on link failure', () async {
    final harness2 = _InMemoryDatabase();
    final task = buildTask(title: 'Should rollback');

    // Close the database before the call to force a failure during the
    // transaction.  This verifies that the outer transaction rolls back
    // the task insert as well — no orphan task row is left behind.
    await harness2.database.close();

    await expectLater(
      () => harness2.repository.createWithContacts(task, ['ct-x']),
      throwsA(anything),
    );

    // Verify no task row was created (the DB is closed so we re-open
    // a fresh one to query).
    final fresh = db.AppDatabase(NativeDatabase.memory());
    try {
      final all = await fresh.tasksDao.watchAllTasks().first;
      expect(all, isEmpty);
    } finally {
      await fresh.close();
    }
  });
}
