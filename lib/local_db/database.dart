import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'daos/contacts_dao.dart';
import 'daos/comments_dao.dart';
import 'daos/subtasks_dao.dart';
import 'daos/tasks_dao.dart';
import 'synced_tables.dart';
import 'tables/app_settings_table.dart';
import 'tables/comments_table.dart';
import 'tables/contacts_table.dart';
import 'tables/subtasks_table.dart';
import 'tables/sync_outbox_table.dart';
import 'tables/tags_table.dart';
import 'tables/task_contacts_table.dart';
import 'tables/task_dependencies_table.dart';
import 'tables/task_tags_table.dart';
import 'tables/tasks_table.dart';

part 'database.g.dart';

@DriftDatabase(
  tables: [
    Tasks,
    Tags,
    TaskTags,
    Subtasks,
    Comments,
    Contacts,
    TaskContacts,
    TaskDependencies,
    AppSettings,
    SyncOutbox,
  ],
  daos: [TasksDao, ContactsDao, SubtasksDao, CommentsDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
      : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_sync_outbox_id '
            'ON sync_outbox (id)',
          );
        },
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.addColumn(comments, comments.deletedAt);
          }
          if (from < 3) {
            await m.addColumn(comments, comments.updatedAt);
            await customStatement(
              'UPDATE comments SET updated_at = created_at '
              'WHERE updated_at IS NULL',
            );
          }
          if (from < 4) {
            // CREATE TABLE only — no backfill. Existing rows are handled
            // by initial full sync in a later layer.
            await m.createTable(syncOutbox);
            await customStatement(
              'CREATE INDEX IF NOT EXISTS idx_sync_outbox_id '
              'ON sync_outbox (id)',
            );
          }
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  /// Enqueues a sync_outbox event for [tableName]/[rowId].
  ///
  /// MUST be called inside the same drift transaction as the mutation it
  /// records — if the mutation rolls back, the outbox entry must not
  /// survive. Throws [StateError] for tables outside [syncedTables]:
  /// whitelist guard, app_settings writes must never reach the outbox.
  Future<void> enqueueSyncEvent(String tableName, String rowId) async {
    if (!syncedTables.contains(tableName)) {
      throw StateError(
        'Table "$tableName" is not whitelisted for sync outbox',
      );
    }
    await into(syncOutbox).insert(
      SyncOutboxCompanion.insert(
        eventTable: tableName,
        rowId: rowId,
        enqueuedAt: DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  Future<String?> lookupSettings(String key) async {
    final row = await (selectOnly(appSettings)
          ..addColumns([appSettings.value])
          ..where(appSettings.key.equals(key)))
        .getSingleOrNull();
    return row?.read(appSettings.value);
  }

  Future<void> storeSetting(String key, String value) async {
    await into(appSettings).insertOnConflictUpdate(
      AppSettingsCompanion(
        key: Value(key),
        value: Value(value),
      ),
    );
  }

  /// Creates a task, its tags and its contact links in a single atomic
  /// transaction. If any step fails, the whole write is rolled back and
  /// no orphan rows remain.
  Future<void> createTaskWithContacts({
    required TasksCompanion task,
    required List<String> tagNames,
    required List<String> contactIds,
  }) async {
    await transaction(() async {
      await tasksDao.upsertTask(task);
      await tasksDao.replaceTagsForTask(task.id.value, tagNames);
      await contactsDao.replaceContactsForTask(task.id.value, contactIds);
    });
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'taskmaster', 'taskmaster.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
