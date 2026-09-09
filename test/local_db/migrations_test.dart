import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:taskmaster/local_db/database.dart';

void main() {
  test('migration from schemaVersion 1 to 2 adds comments.deleted_at',
      () async {
    final raw = sqlite3.openInMemory();
    try {
      // Simulate a v1 database: comments table WITHOUT deleted_at.
      raw.execute('''
        CREATE TABLE tasks (
          id TEXT NOT NULL PRIMARY KEY,
          title TEXT NOT NULL,
          description TEXT NOT NULL DEFAULT '',
          status TEXT NOT NULL,
          priority TEXT NOT NULL,
          due_date INTEGER,
          owner_id TEXT NOT NULL,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL
        )
      ''');
      raw.execute('''
        CREATE TABLE comments (
          id TEXT NOT NULL PRIMARY KEY,
          task_id TEXT NOT NULL REFERENCES tasks(id),
          body TEXT NOT NULL,
          created_at INTEGER NOT NULL
        )
      ''');
      raw.execute('PRAGMA user_version = 1');

      final appDb = AppDatabase(NativeDatabase.opened(raw));
      try {
        // Opening the database triggers onUpgrade (1 -> 2).
        await appDb.customStatement('SELECT 1');

        final rows =
            (await appDb.customSelect(
                  "SELECT name FROM pragma_table_info('comments')",
                ).get())
                .map((r) => r.data['name'] as String);
        expect(rows, contains('deleted_at'));

        final version = await appDb
            .customSelect('PRAGMA user_version')
            .get();
        expect(version.single.data['user_version'], 2);
      } finally {
        await appDb.close();
      }
    } finally {
      raw.close();
    }
  });
}