import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskmaster/features/contacts/data/contact_repository_impl.dart';
import 'package:taskmaster/features/sync/sync.dart';
import 'package:taskmaster/features/tasks/data/comment_repository_impl.dart';
import 'package:taskmaster/features/tasks/data/subtask_repository_impl.dart';
import 'package:taskmaster/features/tasks/data/task_repository_impl.dart';
import 'package:taskmaster/features/tasks/domain/task.dart';
import 'package:taskmaster/features/tasks/domain/task_priority.dart';
import 'package:taskmaster/features/tasks/domain/task_status.dart';
import 'package:taskmaster/local_db/database.dart' as db;

Task buildTask({
  String? id,
  String title = 'Test task',
  TaskStatus status = TaskStatus.todo,
  TaskPriority priority = TaskPriority.medium,
  List<String> tags = const [],
}) {
  final now = DateTime.now();
  return Task(
    id: id ?? 'id-${now.microsecondsSinceEpoch}-$title',
    title: title,
    description: 'desc',
    tags: tags,
    priority: priority,
    status: status,
    createdAt: now,
    updatedAt: now,
  );
}

class _Harness {
  _Harness() {
    database = db.AppDatabase(NativeDatabase.memory());
    taskRepository = TaskRepositoryImpl(
      database: database,
      ownerIdLoader: () async => 'owner-test',
    );
    contactRepository = ContactRepositoryImpl(dao: database.contactsDao);
    commentRepository = CommentRepositoryImpl(dao: database.commentsDao);
    subtaskRepository = SubtaskRepositoryImpl(dao: database.subtasksDao);
    transport = InMemorySyncTransport();
    engine = SyncPushEngineImpl(
      database: database,
      transport: transport,
      logger: logs.add,
    );
  }

  late final db.AppDatabase database;
  late final TaskRepositoryImpl taskRepository;
  late final ContactRepositoryImpl contactRepository;
  late final CommentRepositoryImpl commentRepository;
  late final SubtaskRepositoryImpl subtaskRepository;
  late final InMemorySyncTransport transport;
  late final SyncPushEngineImpl engine;
  final logs = <String>[];

  Future<void> close() => database.close();

  Future<List<db.SyncOutboxData>> outbox() {
    return database.select(database.syncOutbox).get();
  }

  Future<void> insertTaskRow(
    String id, {
    String title = 'T',
    String status = 'todo',
    int updatedAt = 1000,
  }) async {
    await database.into(database.tasks).insert(
          db.TasksCompanion.insert(
            id: id,
            title: title,
            status: Value(status),
            ownerId: 'o',
            createdAt: 1000,
            updatedAt: updatedAt,
          ),
        );
  }

  Future<void> insertCommentRow(String id, String taskId, String body) async {
    await database.into(database.comments).insert(
          db.CommentsCompanion.insert(
            id: id,
            taskId: taskId,
            body: body,
            createdAt: 1000,
          ),
        );
  }

  Future<void> insertSubtaskRow(String id, String taskId, String title) async {
    await database.into(database.subtasks).insert(
          db.SubtasksCompanion.insert(
            id: id,
            taskId: taskId,
            title: title,
            createdAt: 1000,
            updatedAt: 1000,
          ),
        );
  }
}

void main() {
  late _Harness h;

  setUp(() {
    h = _Harness();
  });

  tearDown(() async {
    await h.close();
  });

  test('mutation → push session delivers full row JSON; outbox empty', () async {
    final task = await h.taskRepository.create(
      buildTask(id: 't1', title: 'Ship it'),
    );

    await h.engine.pushOutbox();

    expect(h.transport.attemptedBatches, hasLength(1));
    final batch = h.transport.deliveredBatches.single;
    expect(batch, hasLength(1));
    final event = batch.single;
    expect(event.tableName, 'tasks');
    expect(event.rowId, task.id);

    // All columns present (camelCase drift toJson format).
    expect(event.payload.keys, containsAll([
      'id',
      'title',
      'description',
      'priority',
      'status',
      'dueDate',
      'startDate',
      'ownerId',
      'createdAt',
      'updatedAt',
      'deletedAt',
    ]));
    expect(event.payload['id'], 't1');
    expect(event.payload['title'], 'Ship it');
    expect(event.payload['description'], 'desc');
    expect(event.payload['ownerId'], 'owner-test');
    expect(event.payload['deletedAt'], isNull);

    expect(await h.outbox(), isEmpty);
  });

  test('multiple mutations of same row → one deduped event, latest state',
      () async {
    await h.taskRepository.create(buildTask(id: 't1', title: 'v1'));
    await h.taskRepository.update(
      buildTask(id: 't1', title: 'v2'),
    );
    await h.taskRepository.update(
      buildTask(id: 't1', title: 'v3'),
    );
    expect(await h.outbox(), hasLength(3));

    await h.engine.pushOutbox();

    expect(h.transport.deliveredBatches, hasLength(1));
    final batch = h.transport.deliveredBatches.single;
    expect(batch, hasLength(1), reason: 'dedup by (tableName, rowId)');
    expect(batch.single.rowId, 't1');
    expect(batch.single.payload['title'], 'v3', reason: 'latest state wins');
    expect(await h.outbox(), isEmpty);
  });

  test('row deleted before push → skipped, logged, outbox cleared', () async {
    await h.taskRepository.create(buildTask(id: 't1', title: 'Gone soon'));
    // Hard-delete the row directly — no outbox enqueue (bypass write path).
    await (h.database.delete(h.database.tasks)
          ..where((t) => t.id.equals('t1')))
        .go();

    await h.engine.pushOutbox();

    expect(
      h.logs.any((l) => l.contains('skip') && l.contains('t1')),
      isTrue,
      reason: 'missing row is logged as a normal skip',
    );
    expect(h.transport.attemptedBatches, isEmpty,
        reason: 'nothing sendable — no transport call');
    expect(h.transport.deliveredEvents, isEmpty);
    expect(await h.outbox(), isEmpty,
        reason: 'processed events cleared even when skipped');
  });

  test('transport throws → outbox intact; retry succeeds, no duplicates',
      () async {
    await h.taskRepository.create(buildTask(id: 't1', title: 'Reliable'));
    h.transport.failNextCalls = 1;

    await expectLater(
      h.engine.pushOutbox(),
      throwsA(isA<SyncTransportException>()),
    );

    expect(await h.outbox(), hasLength(1), reason: 'outbox untouched');
    expect(h.transport.deliveredEvents, isEmpty,
        reason: 'failed batch was not delivered');

    await h.engine.pushOutbox();

    expect(await h.outbox(), isEmpty);
    expect(h.transport.attemptedBatches, hasLength(2));
    expect(h.transport.deliveredBatches, hasLength(1),
        reason: 'only the successful attempt delivered');
    expect(h.transport.deliveredEvents.map((e) => e.rowId), ['t1']);
  });

  test('ordering: task event precedes its comment and subtask events',
      () async {
    await h.insertTaskRow('t1');
    await h.insertCommentRow('c1', 't1', 'hello');
    await h.insertSubtaskRow('s1', 't1', 'step');
    // Enqueue children BEFORE the parent — rank ordering must still win.
    await h.database.enqueueSyncEvent('comments', 'c1');
    await h.database.enqueueSyncEvent('subtasks', 's1');
    await h.database.enqueueSyncEvent('tasks', 't1');

    await h.engine.pushOutbox();

    final batch = h.transport.deliveredBatches.single;
    expect(batch.map((e) => e.tableName).toList(), [
      'tasks',
      'comments',
      'subtasks',
    ]);
    expect(batch.map((e) => e.rowId).toList(), ['t1', 'c1', 's1']);
    expect(await h.outbox(), isEmpty);
  });

  test('multi-table batch: several tables in one session, all cleared',
      () async {
    await h.taskRepository.create(
      buildTask(id: 't1', title: 'With people', tags: const ['work']),
    );
    await h.contactRepository.create(name: 'Alice');
    await h.commentRepository.create(taskId: 't1', body: 'note');
    await h.subtaskRepository.create(taskId: 't1', title: 'sub');

    final enqueued = await h.outbox();
    expect(enqueued.length, greaterThanOrEqualTo(4),
        reason: 'tasks + tags + task_tags + contacts + comments + subtasks');

    await h.engine.pushOutbox();

    final tables =
        h.transport.deliveredEvents.map((e) => e.tableName).toSet();
    expect(tables, containsAll(['tasks', 'tags', 'contacts', 'comments', 'subtasks']));
    expect(tables, contains('task_tags'));
    expect(await h.outbox(), isEmpty);
  });

  test('empty outbox → no transport call', () async {
    expect(await h.outbox(), isEmpty);

    await h.engine.pushOutbox();

    expect(h.transport.attemptedBatches, isEmpty);
    expect(h.transport.deliveredBatches, isEmpty);
  });

  test('join-table composite key round-trips through serialization', () async {
    await h.taskRepository.create(
      buildTask(id: 't1', title: 'Tagged', tags: const ['alpha']),
    );

    await h.engine.pushOutbox();

    final tagEvent = h.transport.deliveredEvents
        .where((e) => e.tableName == 'task_tags')
        .single;
    expect(tagEvent.rowId, startsWith('t1:'));
    final tagId = tagEvent.rowId.split(':').last;
    expect(tagEvent.payload['taskId'], 't1');
    expect(tagEvent.payload['tagId'], tagId);

    final tagRowEvent = h.transport.deliveredEvents
        .where((e) => e.tableName == 'tags')
        .single;
    expect(tagRowEvent.rowId, tagId);
    expect(tagRowEvent.payload['name'], 'alpha');
  });

  test('soft-deleted row still serializes (tombstone with deletedAt)',
      () async {
    final task = await h.taskRepository.create(buildTask(id: 't1'));
    await h.taskRepository.delete(task.id);

    await h.engine.pushOutbox();

    final event = h.transport.deliveredEvents
        .where((e) => e.tableName == 'tasks')
        .single;
    expect(event.payload['deletedAt'], isNotNull,
        reason: 'soft-delete is a tombstone, not a skip');
    expect(await h.outbox(), isEmpty);
  });
}
