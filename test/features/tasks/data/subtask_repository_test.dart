import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskmaster/features/tasks/data/subtask_repository_impl.dart';
import 'package:taskmaster/features/tasks/domain/subtask_repository.dart';
import 'package:taskmaster/local_db/database.dart' as db;
import 'package:taskmaster/local_db/daos/subtasks_dao.dart';
import 'package:taskmaster/local_db/daos/tasks_dao.dart';
import 'package:uuid/uuid.dart';

class _InMemoryDatabase {
  _InMemoryDatabase() {
    database = db.AppDatabase(NativeDatabase.memory());
    dao = database.subtasksDao;
    tasksDao = database.tasksDao;
    repository = SubtaskRepositoryImpl(dao: dao);
  }

  late final db.AppDatabase database;
  late final SubtasksDao dao;
  late final TasksDao tasksDao;
  late final SubtaskRepository repository;

  Future<void> close() => database.close();

  Future<String> createTestTask(String title) async {
    final id = const Uuid().v4();
    final now = DateTime.now().millisecondsSinceEpoch;
    await tasksDao.upsertTask(
      db.TasksCompanion.insert(
        id: id,
        title: title,
        ownerId: 'test-owner',
        createdAt: now,
        updatedAt: now,
      ),
    );
    return id;
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

  test('create and watch a subtask for a task', () async {
    final taskId = await harness.createTestTask('Test Task');

    final subtask =
        await harness.repository.create(taskId: taskId, title: 'First');

    expect(subtask.title, 'First');
    expect(subtask.isCompleted, isFalse);

    final all = await harness.repository.watchByTask(taskId).first;
    expect(all.length, 1);
    expect(all.first.title, 'First');
  });

  test('watchByTask only returns subtasks of that task', () async {
    final t1 = await harness.createTestTask('Task one');
    final t2 = await harness.createTestTask('Task two');

    await harness.repository.create(taskId: t1, title: 'A');
    await harness.repository.create(taskId: t2, title: 'B');

    final t1Subs = await harness.repository.watchByTask(t1).first;
    expect(t1Subs.length, 1);
    expect(t1Subs.first.title, 'A');
  });

  test('new subtasks get incrementing positions', () async {
    final taskId = await harness.createTestTask('Test Task');

    final first =
        await harness.repository.create(taskId: taskId, title: 'One');
    final second =
        await harness.repository.create(taskId: taskId, title: 'Two');

    expect(first.position, 1);
    expect(second.position, 2);

    final all = await harness.repository.watchByTask(taskId).first;
    expect(all.map((s) => s.title), ['One', 'Two']);
  });

  test('toggle changes completion and propagates to watch', () async {
    final taskId = await harness.createTestTask('Test Task');
    final subtask =
        await harness.repository.create(taskId: taskId, title: 'Do it');

    await harness.repository.toggle(subtask.id, isCompleted: true);

    final all = await harness.repository.watchByTask(taskId).first;
    expect(all.first.isCompleted, isTrue);

    await harness.repository.toggle(subtask.id, isCompleted: false);
    final again = await harness.repository.watchByTask(taskId).first;
    expect(again.first.isCompleted, isFalse);
  });

  test('delete removes subtask', () async {
    final taskId = await harness.createTestTask('Test Task');
    final subtask =
        await harness.repository.create(taskId: taskId, title: 'Gone');

    await harness.repository.delete(subtask.id);

    final all = await harness.repository.watchByTask(taskId).first;
    expect(all, isEmpty);
  });

  test('deleting a task cascades? no — subtask remains orphan-free via FK',
      () async {
    // Foreign keys are enforced; inserting a subtask for a missing task
    // must throw.
    await expectLater(
      () => harness.repository.create(taskId: 'missing', title: 'X'),
      throwsA(anything),
    );
  });
}