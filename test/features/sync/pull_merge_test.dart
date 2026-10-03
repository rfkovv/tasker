import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskmaster/features/contacts/data/contact_repository_impl.dart';
import 'package:taskmaster/features/sync/sync.dart';
import 'package:taskmaster/features/tasks/data/comment_repository_impl.dart';
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
  DateTime? updatedAt,
}) {
  final now = updatedAt ?? DateTime.now();
  return Task(
    id: id ?? 'id-${now.microsecondsSinceEpoch}-$title',
    title: title,
    description: 'desc',
    tags: tags,
    priority: priority,
    status: status,
    createdAt: now.subtract(const Duration(minutes: 5)),
    updatedAt: now,
  );
}

class _Device {
  _Device(this.label, this.transport) {
    database = db.AppDatabase(NativeDatabase.memory());
    taskRepository = TaskRepositoryImpl(
      database: database,
      ownerIdLoader: () async => 'owner-$label',
    );
    contactRepository = ContactRepositoryImpl(dao: database.contactsDao);
    commentRepository = CommentRepositoryImpl(dao: database.commentsDao);
    pushEngine = SyncPushEngineImpl(
      database: database,
      transport: transport,
    );
    pullEngine = SyncPullEngineImpl(
      database: database,
      transport: transport,
    );
  }

  final String label;
  final InMemorySyncTransport transport;
  late final db.AppDatabase database;
  late final TaskRepositoryImpl taskRepository;
  late final ContactRepositoryImpl contactRepository;
  late final CommentRepositoryImpl commentRepository;
  late final SyncPushEngineImpl pushEngine;
  late final SyncPullEngineImpl pullEngine;

  Future<void> close() => database.close();

  Future<List<db.SyncOutboxData>> outbox() {
    return database.select(database.syncOutbox).get();
  }

  Future<void> clearOutbox() async {
    await database.delete(database.syncOutbox).go();
  }

  Future<String?> cursor() =>
      database.lookupSettings(SyncPullEngineImpl.cursorSettingKey);

  Future<db.Task?> taskRow(String id) {
    return (database.select(database.tasks)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  Future<db.Comment?> commentRow(String id) {
    return (database.select(database.comments)..where((c) => c.id.equals(id)))
        .getSingleOrNull();
  }

  Future<db.Tag?> tagRow(String id) {
    return (database.select(database.tags)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  Future<db.TaskTag?> taskTagRow(String taskId, String tagId) {
    return (database.select(database.taskTags)
          ..where((tt) => tt.taskId.equals(taskId) & tt.tagId.equals(tagId)))
        .getSingleOrNull();
  }

  Future<void> writeTaskRow(
    String id, {
    String title = 'T',
    int updatedAt = 1000,
    int createdAt = 1000,
    int? deletedAt,
  }) async {
    await database.into(database.tasks).insert(
          db.TasksCompanion.insert(
            id: id,
            title: title,
            status: const Value('todo'),
            ownerId: 'o',
            createdAt: createdAt,
            updatedAt: updatedAt,
            deletedAt: deletedAt == null ? const Value.absent() : Value(deletedAt),
          ),
        );
  }

  Future<void> setTaskTitle(String id, String title, int updatedAt) async {
    await (database.update(database.tasks)..where((t) => t.id.equals(id)))
        .write(
      db.TasksCompanion(
        title: Value(title),
        updatedAt: Value(updatedAt),
      ),
    );
  }

  Future<void> insertTag(String id, String name) async {
    await database.into(database.tags).insert(
          db.TagsCompanion.insert(id: id, name: name),
        );
  }

  Future<void> insertTaskTag(String taskId, String tagId) async {
    await database.into(database.taskTags).insert(
          db.TaskTagsCompanion.insert(taskId: taskId, tagId: tagId),
          onConflict: DoNothing(),
        );
  }
}

void main() {
  late InMemorySyncTransport transport;
  late _Device a;
  late _Device b;

  setUp(() {
    transport = InMemorySyncTransport();
    a = _Device('A', transport);
    b = _Device('B', transport);
  });

  tearDown(() async {
    await a.close();
    await b.close();
  });

  test('two-engine: A pushes task; B pulls and inserts locally', () async {
    final task = await a.taskRepository.create(
      buildTask(id: 't1', title: 'From A'),
    );
    await a.pushEngine.pushOutbox();
    expect(await a.outbox(), isEmpty);

    final summary = await b.pullEngine.pullAndMerge();

    expect(summary.applied, 1);
    final row = await b.taskRow(task.id);
    expect(row, isNotNull);
    expect(row!.title, 'From A');
    expect(await b.outbox(), isEmpty, reason: 'no echo on pull');
    expect(await b.cursor(), isNotNull);
  });

  test('concurrent edit, A newer: B pulls → A version applied', () async {
    await a.writeTaskRow(
      't1',
      title: 'Shared',
      createdAt: 1000,
      updatedAt: 2000,
    );
    await a.database.enqueueSyncEvent('tasks', 't1');
    await a.pushEngine.pushOutbox();
    await b.pullEngine.pullAndMerge();
    expect((await b.taskRow('t1'))!.title, 'Shared');

    // A edits later (newer updatedAt) and pushes.
    await a.setTaskTitle('t1', 'A newer', 9000);
    await a.database.enqueueSyncEvent('tasks', 't1');
    await a.pushEngine.pushOutbox();

    // B also edited locally but with an older timestamp (stale write).
    await b.setTaskTitle('t1', 'B stale', 3000);

    final summary = await b.pullEngine.pullAndMerge();

    expect(summary.applied, 1);
    final row = await b.taskRow('t1');
    expect(row!.title, 'A newer', reason: 'incoming LWW strictly greater');
  });

  test('concurrent edit, B newer: local kept, incoming skipped', () async {
    await a.writeTaskRow('t1', title: 'Base', createdAt: 1000, updatedAt: 2000);
    await a.database.enqueueSyncEvent('tasks', 't1');
    await a.pushEngine.pushOutbox();
    await b.pullEngine.pullAndMerge();

    // B edits locally, newer than anything A has pushed.
    await b.setTaskTitle('t1', 'B newer', 9000);

    // A pushes an older edit.
    await a.setTaskTitle('t1', 'A older', 3000);
    await a.database.enqueueSyncEvent('tasks', 't1');
    await a.pushEngine.pushOutbox();

    final summary = await b.pullEngine.pullAndMerge();

    expect(summary.applied, 0);
    expect(summary.conflictLost, greaterThanOrEqualTo(1));
    final row = await b.taskRow('t1');
    expect(row!.title, 'B newer', reason: 'local LWW wins on >= score');
    expect(row.updatedAt, 9000);
  });

  test('soft-delete wins: newer incoming deletedAt applied', () async {
    await a.writeTaskRow(
      't1',
      title: 'Doomed',
      createdAt: 1000,
      updatedAt: 2000,
    );
    await a.database.enqueueSyncEvent('tasks', 't1');
    await a.pushEngine.pushOutbox();
    await b.pullEngine.pullAndMerge();

    // B keeps an older live version.
    expect((await b.taskRow('t1'))!.deletedAt, isNull);

    // A soft-deletes with a newer timestamp (delete is an edit under LWW).
    await (a.database.update(a.database.tasks)..where((t) => t.id.equals('t1')))
        .write(
      db.TasksCompanion(
        deletedAt: const Value(9000),
        updatedAt: const Value(9000),
      ),
    );
    await a.database.enqueueSyncEvent('tasks', 't1');
    await a.pushEngine.pushOutbox();

    final summary = await b.pullEngine.pullAndMerge();

    expect(summary.applied, 1);
    final row = await b.taskRow('t1');
    expect(row!.deletedAt, 9000);
  });

  test('comment with null updatedAt merges via coalesce rule', () async {
    // Parent task must exist (FK).
    await a.writeTaskRow('t1', title: 'Parent');
    await b.writeTaskRow('t1', title: 'Parent');

    // A inserts a comment with null updatedAt (pre-backfill shape).
    await a.database.into(a.database.comments).insert(
          db.CommentsCompanion.insert(
            id: 'c1',
            taskId: 't1',
            body: 'from A null-updatedAt',
            createdAt: 1000,
            updatedAt: const Value.absent(),
          ),
        );
    await a.database.enqueueSyncEvent('tasks', 't1');
    await a.database.enqueueSyncEvent('comments', 'c1');
    await a.pushEngine.pushOutbox();

    // B has the same comment with a NEWER explicit updatedAt.
    await b.database.into(b.database.comments).insert(
          db.CommentsCompanion.insert(
            id: 'c1',
            taskId: 't1',
            body: 'B body',
            createdAt: 1000,
            updatedAt: const Value(5000),
          ),
        );

    final summary = await b.pullEngine.pullAndMerge();

    // Incoming updatedAt null → coalesce uses createdAt (1000).
    // Local updatedAt 5000 is newer → local wins.
    expect(summary.conflictLost, greaterThanOrEqualTo(1));
    expect((await b.commentRow('c1'))!.body, 'B body');

    // Reverse: incoming has NEWER updatedAt; local has null updatedAt.
    await (a.database.update(a.database.comments)..where((c) => c.id.equals('c1')))
        .write(
      db.CommentsCompanion(
        body: const Value('A newer body'),
        updatedAt: const Value(9000),
        createdAt: const Value(1000),
      ),
    );
    await a.database.enqueueSyncEvent('comments', 'c1');
    await a.pushEngine.pushOutbox();

    await (b.database.update(b.database.comments)..where((c) => c.id.equals('c1')))
        .write(
      db.CommentsCompanion(
        body: const Value('B old'),
        updatedAt: const Value.absent(),
        createdAt: const Value(1000),
      ),
    );

    final summary2 = await b.pullEngine.pullAndMerge();
    expect(summary2.applied, greaterThanOrEqualTo(1));
    expect((await b.commentRow('c1'))!.body, 'A newer body',
        reason: 'incoming coalesce(updatedAt=9000) strictly greater than '
            'local coalesce(createdAt=1000)');
  });

  test('join table: remote link inserted; no echo (outbox empty)', () async {
    await a.taskRepository.create(
      buildTask(id: 't1', title: 'Tagged', tags: const ['work']),
    );
    await a.pushEngine.pushOutbox();

    final summary = await b.pullEngine.pullAndMerge();

    expect(summary.applied, greaterThanOrEqualTo(2));
    final linkEvent = a.transport.deliveredEvents
        .where((e) => e.tableName == 'task_tags')
        .single;
    final parts = linkEvent.rowId.split(':');
    expect(parts, hasLength(2));
    expect(await b.taskRow('t1'), isNotNull);
    expect(await b.tagRow(parts[1]), isNotNull);
    final link = await b.taskTagRow(parts[0], parts[1]);
    expect(link, isNotNull, reason: 'join link inserted on B');
    expect(await b.outbox(), isEmpty);
  });

  test(
      'join table: remote removal always skipped (option 1 add-wins)',
      () async {
    await b.writeTaskRow('t1', title: 'Local task');
    await b.insertTag('tag1', 'keep');
    await b.insertTaskTag('t1', 'tag1');
    await b.clearOutbox();

    // Removal-shaped server events — never applied under option 1.
    await transport.pushBatch(const [
      SyncEvent(
        tableName: 'task_tags',
        rowId: 't1:whatever',
        payload: {'removed': true},
      ),
      SyncEvent(
        tableName: 'task_tags',
        rowId: 't1:gone',
        payload: {'taskId': 't1'},
      ),
    ]);

    final summary = await b.pullEngine.pullAndMerge();

    expect(summary.conflictLost, 2);
    expect(summary.applied, 0);
    final remaining = await (b.database.select(b.database.taskTags)
          ..where((tt) => tt.taskId.equals('t1')))
        .get();
    expect(remaining, hasLength(1), reason: 'local link kept (add-wins)');
    expect(await b.taskTagRow('t1', 'tag1'), isNotNull);
    expect(await b.outbox(), isEmpty);
  });

  test('cursor: second pull does not re-apply; cursor advances', () async {
    await a.writeTaskRow('t1', title: 'First');
    await a.database.enqueueSyncEvent('tasks', 't1');
    await a.pushEngine.pushOutbox();

    final first = await b.pullEngine.pullAndMerge();
    expect(first.applied, 1);
    final cursorAfterFirst = await b.cursor();
    expect(cursorAfterFirst, isNotNull);

    // No new server events — second pull is a no-op.
    final second = await b.pullEngine.pullAndMerge();
    expect(second.applied, 0);
    expect(second.total, 0);
    expect(await b.cursor(), cursorAfterFirst);

    // New push → only the new event applies.
    await a.writeTaskRow('t2', title: 'Second');
    await a.database.enqueueSyncEvent('tasks', 't2');
    await a.pushEngine.pushOutbox();
    final third = await b.pullEngine.pullAndMerge();
    expect(third.applied, 1);
    expect(await b.taskRow('t1'), isNotNull);
    expect(await b.taskRow('t2'), isNotNull);
    expect(await b.cursor(), isNot(cursorAfterFirst));
  });

  test('transport failure mid-pull → cursor unchanged; retry succeeds',
      () async {
    await a.writeTaskRow('t1', title: 'Retry me');
    await a.database.enqueueSyncEvent('tasks', 't1');
    await a.pushEngine.pushOutbox();

    transport.failNextPullCalls = 1;
    await expectLater(
      b.pullEngine.pullAndMerge(),
      throwsA(isA<SyncTransportException>()),
    );
    expect(await b.cursor(), isNull, reason: 'cursor unchanged on failure');
    expect(await b.taskRow('t1'), isNull);

    final summary = await b.pullEngine.pullAndMerge();
    expect(summary.applied, 1);
    expect(await b.taskRow('t1'), isNotNull);
    expect(await b.cursor(), isNotNull);
  });

  test('pull never enqueues to outbox', () async {
    await a.taskRepository.create(
      buildTask(id: 't1', tags: const ['x']),
    );
    await a.commentRepository.create(taskId: 't1', body: 'c');
    await a.pushEngine.pushOutbox();

    expect(await b.outbox(), isEmpty);
    await b.pullEngine.pullAndMerge();
    expect(await b.outbox(), isEmpty);
    await b.pullEngine.pullAndMerge();
    expect(await b.outbox(), isEmpty);
  });

  test('roundtrip: A→B pull, B edits+pushes, A pulls → converges', () async {
    await a.writeTaskRow(
      't1',
      title: 'Original',
      createdAt: 1000,
      updatedAt: 2000,
    );
    await a.database.into(a.database.comments).insert(
          db.CommentsCompanion.insert(
            id: 'c1',
            taskId: 't1',
            body: 'hello',
            createdAt: 1500,
          ),
        );
    await a.database.enqueueSyncEvent('tasks', 't1');
    await a.database.enqueueSyncEvent('comments', 'c1');
    await a.pushEngine.pushOutbox();

    final first = await b.pullEngine.pullAndMerge();
    expect(first.applied, 2);
    expect((await b.taskRow('t1'))!.title, 'Original');
    expect((await b.commentRow('c1'))!.body, 'hello');

    // B edits and pushes.
    await b.setTaskTitle('t1', 'B revision', 9000);
    await b.database.enqueueSyncEvent('tasks', 't1');
    await b.pushEngine.pushOutbox();

    // A pulls.
    final summary = await a.pullEngine.pullAndMerge();
    expect(summary.applied, 1);
    final aRow = await a.taskRow('t1');
    expect(aRow!.title, 'B revision');

    // Both sides agree.
    final bRow = await b.taskRow('t1');
    expect(bRow!.title, aRow.title);
    expect(bRow.updatedAt, aRow.updatedAt);
  });
}
