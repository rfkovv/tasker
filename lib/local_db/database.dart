import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'daos/tasks_dao.dart';
import 'tables/app_settings_table.dart';
import 'tables/comments_table.dart';
import 'tables/contacts_table.dart';
import 'tables/subtasks_table.dart';
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
  ],
  daos: [TasksDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
      : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
        },
        onUpgrade: (m, from, to) async {
          // Future migrations go here
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

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
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'taskmaster', 'taskmaster.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
