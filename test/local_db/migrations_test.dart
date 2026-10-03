import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:taskmaster/local_db/database.dart';

void main() {
  test('migration from schemaVersion 1 adds comments.deleted_at '
      'and comments.updated_at (lands on current schema)', () async {
    final raw = sqlite3.openInMemory();
    try {
      // Simulate a v1 database: comments table WITHOUT deleted_at/updated_at.
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
        // Opening the database triggers onUpgrade (1 -> current).
        await appDb.customStatement('SELECT 1');

        final rows =
            (await appDb.customSelect(
                  "SELECT name FROM pragma_table_info('comments')",
                ).get())
                .map((r) => r.data['name'] as String);
        expect(rows, contains('deleted_at'));
        expect(rows, contains('updated_at'));

        final version = await appDb
            .customSelect('PRAGMA user_version')
            .get();
        expect(version.single.data['user_version'], 4);
      } finally {
        await appDb.close();
      }
    } finally {
      raw.close();
    }
  });

  test('migration from schemaVersion 2 adds comments.updated_at '
      'and backfills from created_at (lands on current schema)', () async {
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
          created_at INTEGER NOT NULL,
          deleted_at INTEGER
        )
      ''');
      raw.execute('PRAGMA user_version = 2');
      raw.execute(
        'INSERT INTO tasks (id, title, status, priority, owner_id, '
        "created_at, updated_at) VALUES ('t1', 'T', 'todo', 'medium', "
        "'o', 1000, 1000)",
      );
      raw.execute(
        'INSERT INTO comments (id, task_id, body, created_at) '
        "VALUES ('c1', 't1', 'hello', 2000)",
      );

      final appDb = AppDatabase(NativeDatabase.opened(raw));
      try {
        await appDb.customStatement('SELECT 1');

        final version = await appDb
            .customSelect('PRAGMA user_version')
            .get();
        expect(version.single.data['user_version'], 4);

        final row = await appDb
            .customSelect('SELECT created_at, updated_at FROM comments')
            .getSingle();
        // Backfill: updated_at = created_at for pre-existing rows.
        expect(row.data['updated_at'], 2000);
        expect(row.data['created_at'], 2000);
      } finally {
        await appDb.close();
      }
    } finally {
      raw.close();
    }
  });
}
