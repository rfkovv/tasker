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
      dao: dao,
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

  test('soft-deleted task is not returned by watchById', () async {
    final task = buildTask(title: 'Gone');
    await harness.repository.create(task);

    await harness.repository.delete(task.id);

    final watched = await harness.repository.watchById(task.id).first;
    expect(watched, isNull);
  });
}
