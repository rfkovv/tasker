import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskmaster/features/tasks/data/comment_repository_impl.dart';
import 'package:taskmaster/features/tasks/domain/comment_repository.dart';
import 'package:taskmaster/local_db/database.dart' as db;
import 'package:taskmaster/local_db/daos/comments_dao.dart';
import 'package:taskmaster/local_db/daos/tasks_dao.dart';
import 'package:uuid/uuid.dart';

class _InMemoryDatabase {
  _InMemoryDatabase() {
    database = db.AppDatabase(NativeDatabase.memory());
    dao = database.commentsDao;
    tasksDao = database.tasksDao;
    repository = CommentRepositoryImpl(dao: dao);
  }

  late final db.AppDatabase database;
  late final CommentsDao dao;
  late final TasksDao tasksDao;
  late final CommentRepository repository;

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

  test('create and watch a comment for a task', () async {
    final taskId = await harness.createTestTask('Test Task');

    final comment =
        await harness.repository.create(taskId: taskId, body: 'Hello');

    expect(comment.body, 'Hello');
    expect(comment.deletedAt, isNull);

    final all = await harness.repository.watchByTask(taskId).first;
    expect(all.length, 1);
    expect(all.first.body, 'Hello');
  });

  test('comments are ordered chronologically', () async {
    final taskId = await harness.createTestTask('Test Task');

    await harness.repository.create(taskId: taskId, body: 'First');
    await harness.repository.create(taskId: taskId, body: 'Second');
    await harness.repository.create(taskId: taskId, body: 'Third');

    final all = await harness.repository.watchByTask(taskId).first;
    expect(all.map((c) => c.body), ['First', 'Second', 'Third']);
  });

  test('watchByTask only returns comments of that task', () async {
    final t1 = await harness.createTestTask('Task one');
    final t2 = await harness.createTestTask('Task two');

    await harness.repository.create(taskId: t1, body: 'A');
    await harness.repository.create(taskId: t2, body: 'B');

    final t1Comments = await harness.repository.watchByTask(t1).first;
    expect(t1Comments.length, 1);
    expect(t1Comments.first.body, 'A');
  });

  test('soft delete removes comment from list', () async {
    final taskId = await harness.createTestTask('Test Task');
    final comment =
        await harness.repository.create(taskId: taskId, body: 'Remove me');

    await harness.repository.delete(comment.id);

    final all = await harness.repository.watchByTask(taskId).first;
    expect(all, isEmpty);
  });

  test('soft-deleted comment row still exists with deletedAt set', () async {
    final taskId = await harness.createTestTask('Test Task');
    final comment =
        await harness.repository.create(taskId: taskId, body: 'Gone');

    await harness.repository.delete(comment.id);

    final row = await harness.dao.getCommentById(comment.id);
    expect(row.deletedAt, isNotNull);
  });
}