import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:taskmaster/features/contacts/data/contact_repository_impl.dart';
import 'package:taskmaster/features/settings/data/app_settings_repository_impl.dart';
import 'package:taskmaster/features/settings/domain/app_settings_data.dart';
import 'package:taskmaster/features/tasks/data/comment_repository_impl.dart';
import 'package:taskmaster/features/tasks/data/subtask_repository_impl.dart';
import 'package:taskmaster/features/tasks/data/task_repository_impl.dart';
import 'package:taskmaster/features/tasks/domain/task.dart';
import 'package:taskmaster/features/tasks/domain/task_priority.dart';
import 'package:taskmaster/features/tasks/domain/task_status.dart';
import 'package:taskmaster/features/trash/data/trash_repository_impl.dart';
import 'package:taskmaster/local_db/database.dart' as db;
import 'package:taskmaster/local_db/synced_tables.dart';

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
    trashRepository = TrashRepositoryImpl(database: database);
    settingsRepository = AppSettingsRepositoryImpl(db: database);
  }

  late final db.AppDatabase database;
  late final TaskRepositoryImpl taskRepository;
  late final ContactRepositoryImpl contactRepository;
  late final CommentRepositoryImpl commentRepository;
  late final SubtaskRepositoryImpl subtaskRepository;
  late final TrashRepositoryImpl trashRepository;
  late final AppSettingsRepositoryImpl settingsRepository;

  Future<void> close() => database.close();

  Future<List<db.SyncOutboxData>> outbox() {
    return database.select(database.syncOutbox).get();
  }

  Future<void> clearOutbox() async {
    await database.delete(database.syncOutbox).go();
  }

  Future<List<(String, String)>> outboxKeys() async {
    final rows = await outbox();
    return rows.map((r) => (r.eventTable, r.rowId)).toList();
  }

  Future<void> insertDependency(
    String predecessorId,
    String successorId,
  ) async {
    await database.into(database.taskDependencies).insert(
          db.TaskDependenciesCompanion.insert(
            predecessorId: predecessorId,
            successorId: successorId,
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

  group('schema v4: sync_outbox', () {
    test('table exists with expected columns after fresh create', () async {
      final columns = await h.database
          .customSelect("SELECT name FROM pragma_table_info('sync_outbox')")
          .get();
      final names =
          columns.map((r) => r.data['name'] as String).toSet();
      expect(
        names,
        containsAll(['id', 'table_name', 'row_id', 'enqueued_at']),
      );
    });

    test('index on id exists (FIFO order for push)', () async {
      final indexes = await h.database
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type='index' "
            "AND tbl_name='sync_outbox'",
          )
          .get();
      final names = indexes.map((r) => r.data['name'] as String).toSet();
      expect(names, contains('idx_sync_outbox_id'));
    });
  });

  group('whitelist guard', () {
    test('enqueueSyncEvent rejects non-whitelisted tables', () async {
      await expectLater(
        h.database.enqueueSyncEvent('app_settings', 'theme'),
        throwsA(isA<StateError>()),
      );
      await expectLater(
        h.database.enqueueSyncEvent('sync_outbox', '1'),
        throwsA(isA<StateError>()),
      );
      expect(await h.outbox(), isEmpty);
    });

    test('app_settings writes do not enqueue', () async {
      await h.settingsRepository.saveThemePreference(AppThemePreference.dark);
      await h.settingsRepository.saveLanguage(AppLanguage.pl);
      await h.settingsRepository.saveDefaultDueTime('09:00');
      expect(await h.outbox(), isEmpty);
    });

    test('whitelistedTables constant matches spec', () {
      expect(syncedTables, {
        'tasks',
        'tags',
        'task_tags',
        'subtasks',
        'comments',
        'contacts',
        'task_contacts',
        'task_dependencies',
      });
      expect(syncedTables, isNot(contains('app_settings')));
      expect(syncedTables, isNot(contains('sync_outbox')));
    });
  });

  group('per-table enqueue: tasks', () {
    test('create enqueues tasks event with row UUID', () async {
      final task = await h.taskRepository.create(
        buildTask(id: 't1', title: 'Hello'),
      );
      expect(await h.outboxKeys(), [('tasks', task.id)]);
    });

    test('updateStatus enqueues tasks event', () async {
      final task = await h.taskRepository.create(buildTask(id: 't1'));
      await h.clearOutbox();
      await h.taskRepository.updateStatus(task.id, TaskStatus.done);
      expect(await h.outboxKeys(), [('tasks', 't1')]);
    });

    test('soft-delete (Kosz) enqueues task + each cascaded comment',
        () async {
      final task = await h.taskRepository.create(
        buildTask(id: 't1', tags: const []),
      );
      final c1 = await h.commentRepository.create(taskId: task.id, body: 'a');
      final c2 = await h.commentRepository.create(taskId: task.id, body: 'b');
      // Individually deleted comment stays out of the cascade batch.
      final c3 = await h.commentRepository.create(taskId: task.id, body: 'c');
      await h.commentRepository.delete(c3.id);
      await h.clearOutbox();

      await h.taskRepository.delete(task.id);

      final keys = await h.outboxKeys();
      expect(keys, containsAll([('tasks', 't1'), ('comments', c1.id), ('comments', c2.id)]));
      expect(keys, isNot(contains(('comments', c3.id))));
      expect(keys.length, 3);
    });
  });

  group('per-table enqueue: tags + task_tags', () {
    test('replaceTagsForTask enqueues one event per row-level change',
        () async {
      await h.taskRepository.create(
        buildTask(id: 't1', tags: const ['alpha', 'beta']),
      );
      final alphaTag = await _tagIdNamed(h, 'alpha');
      final betaTag = await _tagIdNamed(h, 'beta');
      await h.clearOutbox();

      // Replace with ['alpha', 'gamma']: beta link deleted, alpha link
      // delete+insert (new tag row same id → still two task_tags events),
      // gamma is a brand-new tag (tags event + task_tags insert).
      await h.taskRepository.update(
        buildTask(id: 't1', tags: const ['alpha', 'gamma']),
      );

      final keys = await h.outboxKeys();
      final tagLinks =
          keys.where((k) => k.$1 == 'task_tags').map((k) => k.$2).toList();

      expect(tagLinks, contains(joinRowId('t1', betaTag)));
      expect(
        tagLinks.where((id) => id == joinRowId('t1', alphaTag)),
        hasLength(2),
        reason: 'alpha link is deleted then re-inserted — two events',
      );
      expect(keys.where((k) => k.$1 == 'tags'), hasLength(1),
          reason: 'gamma is a new tag');
      expect(
        tagLinks.any((id) => id != joinRowId('t1', alphaTag) &&
            id != joinRowId('t1', betaTag)),
        isTrue,
        reason: 'gamma link insert enqueued',
      );
    });

    test('ensureTag on existing tag does not enqueue a tags event', () async {
      await h.taskRepository.create(
        buildTask(id: 't1', tags: const ['shared']),
      );
      final sharedTag = await _tagIdNamed(h, 'shared');
      await h.clearOutbox();

      await h.taskRepository.create(
        buildTask(id: 't2', tags: const ['shared']),
      );

      final keys = await h.outboxKeys();
      expect(keys.where((k) => k.$1 == 'tags'), isEmpty);
      expect(
        keys,
        contains(('task_tags', joinRowId('t2', sharedTag))),
      );
    });
  });

  group('per-table enqueue: contacts + task_contacts', () {
    test('create/update/soft-delete enqueue contacts events', () async {
      final contact = await h.contactRepository.create(name: 'Alice');
      expect(await h.outboxKeys(), [('contacts', contact.id)]);

      await h.clearOutbox();
      await h.contactRepository.update(
        contact.copyWith(name: 'Alice 2', updatedAt: DateTime.now()),
      );
      expect(await h.outboxKeys(), [('contacts', contact.id)]);

      await h.clearOutbox();
      await h.contactRepository.delete(contact.id);
      expect(await h.outboxKeys(), [('contacts', contact.id)]);
    });

    test('replaceContactsForTask enqueues per link change', () async {
      final c1 = await h.contactRepository.create(name: 'A');
      final c2 = await h.contactRepository.create(name: 'B');
      await h.taskRepository.create(buildTask(id: 't1'));
      await h.contactRepository.replaceContactsForTask('t1', [c1.id, c2.id]);
      await h.clearOutbox();

      await h.contactRepository.replaceContactsForTask('t1', [c2.id]);

      final keys = await h.outboxKeys();
      // c1 link deleted, c2 link deleted + re-inserted.
      expect(
        keys,
        containsAll([
          ('task_contacts', contactLinkRowId('t1', c1.id)),
          ('task_contacts', contactLinkRowId('t1', c2.id)),
        ]),
      );
      expect(
        keys.where((k) => k.$1 == 'task_contacts').length,
        greaterThanOrEqualTo(2),
      );
    });
  });

  group('per-table enqueue: subtasks + comments', () {
    test('subtask create/toggle/delete enqueue subtasks events', () async {
      await h.taskRepository.create(buildTask(id: 't1'));
      await h.clearOutbox();
      final sub = await h.subtaskRepository.create(taskId: 't1', title: 'S');
      expect(await h.outboxKeys(), [('subtasks', sub.id)]);

      await h.clearOutbox();
      await h.subtaskRepository.toggle(sub.id, isCompleted: true);
      expect(await h.outboxKeys(), [('subtasks', sub.id)]);

      await h.clearOutbox();
      await h.subtaskRepository.delete(sub.id);
      expect(await h.outboxKeys(), [('subtasks', sub.id)]);
    });

    test('comment create/soft-delete enqueue comments events', () async {
      await h.taskRepository.create(buildTask(id: 't1'));
      await h.clearOutbox();
      final comment =
          await h.commentRepository.create(taskId: 't1', body: 'hello');
      expect(await h.outboxKeys(), [('comments', comment.id)]);

      await h.clearOutbox();
      await h.commentRepository.delete(comment.id);
      expect(await h.outboxKeys(), [('comments', comment.id)]);
    });
  });

  group('multiple mutations, no coalescing', () {
    test('same row mutated twice → two outbox rows', () async {
      final task = await h.taskRepository.create(buildTask(id: 't1'));
      await h.clearOutbox();

      await h.taskRepository.updateStatus(task.id, TaskStatus.done);
      await h.taskRepository.updateStatus(task.id, TaskStatus.todo);
      await h.taskRepository.updateStatus(task.id, TaskStatus.done);

      final keys = await h.outboxKeys();
      expect(keys, [('tasks', 't1'), ('tasks', 't1'), ('tasks', 't1')]);
    });

    test('delete then restore → separate events for same row', () async {
      final task = await h.taskRepository.create(buildTask(id: 't1'));
      await h.clearOutbox();
      await h.taskRepository.delete(task.id);
      await h.trashRepository.restoreTask(task.id);

      final keys = await h.outboxKeys();
      expect(keys.where((k) => k == ('tasks', 't1')).length, 2);
    });
  });

  group('trash: restore + emptyTrash purge events', () {
    test('restoreTask enqueues task + restored cascade comments', () async {
      await h.taskRepository.create(buildTask(id: 't1'));
      final c1 = await h.commentRepository.create(taskId: 't1', body: 'x');
      await h.commentRepository.create(taskId: 't1', body: 'y'); // cascaded
      final cInd = await h.commentRepository.create(taskId: 't1', body: 'z');
      await h.commentRepository.delete(cInd.id);
      // Distinct deletedAt from the cascade batch (millisecond clock).
      await Future<void>.delayed(const Duration(milliseconds: 2));
      await h.taskRepository.delete('t1');
      await h.clearOutbox();

      await h.trashRepository.restoreTask('t1');

      final keys = await h.outboxKeys();
      expect(keys, contains(('tasks', 't1')));
      expect(keys, contains(('comments', c1.id)));
      // Anty-zombie: individually deleted comment is NOT restored → no event.
      expect(keys.where((k) => k.$2 == cInd.id), isEmpty);
    });

    test('restoreContact enqueues contacts event', () async {
      final contact = await h.contactRepository.create(name: 'Alice');
      await h.contactRepository.delete(contact.id);
      await h.clearOutbox();

      await h.trashRepository.restoreContact(contact.id);

      expect(await h.outboxKeys(), [('contacts', contact.id)]);
    });

    test('emptyTrash enqueues purge events for every hard-deleted row',
        () async {
      await h.taskRepository.create(
        buildTask(id: 't1', tags: const ['tag-a']),
      );
      final tagA = await _tagIdNamed(h, 'tag-a');
      final c1 = await h.commentRepository.create(taskId: 't1', body: 'a');
      final sub =
          await h.subtaskRepository.create(taskId: 't1', title: 'S');
      final contact = await h.contactRepository.create(name: 'Alice');
      await h.contactRepository.replaceContactsForTask('t1', [contact.id]);
      await h.insertDependency('t1', 't-other');
      await h.taskRepository.delete('t1');
      await h.contactRepository.delete(contact.id);
      // Individually soft-deleted comment on a live task.
      final liveTask = await h.taskRepository.create(buildTask(id: 't-live'));
      final cLive =
          await h.commentRepository.create(taskId: liveTask.id, body: 'L');
      await h.commentRepository.delete(cLive.id);
      await h.clearOutbox();

      await h.trashRepository.emptyTrash();

      final keys = await h.outboxKeys();
      expect(
        keys,
        containsAll([
          ('tasks', 't1'),
          ('comments', c1.id),
          ('comments', cLive.id),
          ('subtasks', sub.id),
          ('contacts', contact.id),
          ('task_tags', joinRowId('t1', tagA)),
          ('task_contacts', contactLinkRowId('t1', contact.id)),
          ('task_dependencies', dependencyRowId('t1', 't-other')),
        ]),
      );
    });
  });

  group('atomicity: rolled-back mutation leaves no outbox row', () {
    test('createTaskWithContacts with bad contactId rolls back everything',
        () async {
      await expectLater(
        h.database.createTaskWithContacts(
          task: db.TasksCompanion.insert(
            id: 't1',
            title: 'T',
            ownerId: 'o',
            createdAt: 1,
            updatedAt: 1,
          ),
          tagNames: const [],
          contactIds: ['nonexistent-contact'],
        ),
        throwsA(anything),
      );

      expect(await h.outbox(), isEmpty);
      final tasks = await h.database.select(h.database.tasks).get();
      expect(tasks, isEmpty);
    });

    test('explicit transaction rollback discards enqueued events', () async {
      await expectLater(
        h.database.transaction(() async {
          await h.database.enqueueSyncEvent('tasks', 't1');
          throw StateError('forced failure inside transaction');
        }),
        throwsA(isA<StateError>()),
      );

      expect(await h.outbox(), isEmpty);
    });
  });

  group('migration v3 → v4', () {
    test('creates sync_outbox, sets user_version 4, no backfill', () async {
      final raw = sqlite3.openInMemory();
      try {
        raw.execute('PRAGMA user_version = 3');
        final appDb = db.AppDatabase(NativeDatabase.opened(raw));
        try {
          await appDb.customStatement('SELECT 1');

          final version =
              await appDb.customSelect('PRAGMA user_version').get();
          expect(version.single.data['user_version'], 4);

          final tables = await appDb
              .customSelect(
                "SELECT name FROM sqlite_master WHERE type='table' "
                "AND name='sync_outbox'",
              )
              .get();
          expect(tables, hasLength(1));

          final columns = await appDb
              .customSelect("SELECT name FROM pragma_table_info('sync_outbox')")
              .get();
          final names =
              columns.map((r) => r.data['name'] as String).toSet();
          expect(
            names,
            containsAll(['id', 'table_name', 'row_id', 'enqueued_at']),
          );

          final indexes = await appDb
              .customSelect(
                "SELECT name FROM sqlite_master WHERE type='index' "
                "AND tbl_name='sync_outbox'",
              )
              .get();
          expect(
            indexes.map((r) => r.data['name'] as String),
            contains('idx_sync_outbox_id'),
          );

          // CREATE TABLE only — no backfill.
          final count = await appDb
              .customSelect('SELECT COUNT(*) AS c FROM sync_outbox')
              .getSingle();
          expect(count.data['c'], 0);
        } finally {
          await appDb.close();
        }
      } finally {
        raw.close();
      }
    });

    test('existing v3 rows survive; outbox stays empty until new writes',
        () async {
      final raw = sqlite3.openInMemory();
      try {
        raw.execute('''
          CREATE TABLE tasks (
            id TEXT NOT NULL PRIMARY KEY,
            title TEXT NOT NULL,
            description TEXT NOT NULL DEFAULT '',
            status TEXT NOT NULL,
            priority TEXT NOT NULL,
            due_date INTEGER,
            start_date INTEGER,
            owner_id TEXT NOT NULL,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL,
            deleted_at INTEGER
          )
        ''');
        raw.execute(
          'INSERT INTO tasks (id, title, status, priority, owner_id, '
          "created_at, updated_at) VALUES ('pre', 'Old', 'todo', 'medium', "
          "'o', 1000, 1000)",
        );
        raw.execute('PRAGMA user_version = 3');

        final appDb = db.AppDatabase(NativeDatabase.opened(raw));
        try {
          await appDb.customStatement('SELECT 1');

          final tasks = await appDb.select(appDb.tasks).get();
          expect(tasks, hasLength(1));
          expect(tasks.single.id, 'pre');

          final count = await appDb
              .customSelect('SELECT COUNT(*) AS c FROM sync_outbox')
              .getSingle();
          expect(count.data['c'], 0);

          // A new write after migration enqueues normally.
          await appDb.enqueueSyncEvent('tasks', 'post');
          final rows = await appDb.select(appDb.syncOutbox).get();
          expect(rows, hasLength(1));
          expect(rows.single.rowId, 'post');
        } finally {
          await appDb.close();
        }
      } finally {
        raw.close();
      }
    });
  });

  group('join-row key encoding', () {
    test('composite keys use fixed delimiter and order', () {
      expect(joinRowId('task-1', 'tag-1'), 'task-1:tag-1');
      expect(contactLinkRowId('task-1', 'contact-1'), 'task-1:contact-1');
      expect(dependencyRowId('pred-1', 'succ-1'), 'pred-1:succ-1');
    });
  });
}

Future<String> _tagIdNamed(_Harness h, String name) async {
  final row = await (h.database.select(h.database.tags)
        ..where((t) => t.name.equals(name)))
      .getSingle();
  return row.id;
}
