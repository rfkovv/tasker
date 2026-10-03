import 'dart:async';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../database.dart';
import '../synced_tables.dart';
import '../tables/tags_table.dart';
import '../tables/task_tags_table.dart';
import '../tables/tasks_table.dart';

part 'tasks_dao.g.dart';

@DriftAccessor(tables: [Tasks, Tags, TaskTags])
class TasksDao extends DatabaseAccessor<AppDatabase> with _$TasksDaoMixin {
  TasksDao(super.db);

  Stream<List<Task>> watchAllTasks({
    String? status,
    String? priority,
    String? titleLike,
  }) {
    var query = select(tasks)..where((t) => t.deletedAt.isNull());

    if (status != null) {
      query = query..where((t) => t.status.equals(status));
    }
    if (priority != null) {
      query = query..where((t) => t.priority.equals(priority));
    }
    if (titleLike != null) {
      final pattern = '%$titleLike%';
      query = query..where((t) => t.title.lower().like(pattern));
    }

    query = query..orderBy([(t) => OrderingTerm.desc(t.createdAt)]);

    return query.watch();
  }

  Stream<Task?> watchTaskById(String id) {
    final query = select(tasks)..where((t) => t.id.equals(id) & t.deletedAt.isNull());
    return query.watchSingleOrNull();
  }

  Future<Task> getTaskById(String id) {
    return (select(tasks)..where((t) => t.id.equals(id))).getSingle();
  }

  Future<void> upsertTask(TasksCompanion entry) async {
    await transaction(() async {
      await into(tasks).insertOnConflictUpdate(entry);
      await attachedDatabase.enqueueSyncEvent('tasks', entry.id.value);
    });
  }

  Future<void> softDeleteTask(String id, int now) async {
    await transaction(() async {
      await (update(tasks)..where((t) => t.id.equals(id))).write(
        TasksCompanion(deletedAt: Value(now), updatedAt: Value(now)),
      );
      await attachedDatabase.enqueueSyncEvent('tasks', id);
    });
  }

  Future<void> updateStatus(String id, String status, int now) async {
    await transaction(() async {
      await (update(tasks)..where((t) => t.id.equals(id))).write(
        TasksCompanion(status: Value(status), updatedAt: Value(now)),
      );
      await attachedDatabase.enqueueSyncEvent('tasks', id);
    });
  }

  Future<List<Tag>> tagsForTask(String taskId) async {
    final rows = await (select(taskTags)
          ..where((tt) => tt.taskId.equals(taskId)))
        .join([innerJoin(tags, tags.id.equalsExp(taskTags.tagId))])
        .get();
    return rows.map((r) => r.readTable(tags)).toList();
  }

  Future<Map<String, List<Tag>>> tagsForTasks(List<String> taskIds) async {
    if (taskIds.isEmpty) return const {};
    final rows = await (select(taskTags)
          ..where((tt) => tt.taskId.isIn(taskIds)))
        .join([innerJoin(tags, tags.id.equalsExp(taskTags.tagId))])
        .get();
    final grouped = <String, List<Tag>>{};
    for (final row in rows) {
      final taskId = row.readTable(taskTags).taskId;
      grouped.putIfAbsent(taskId, () => []).add(row.readTable(tags));
    }
    return grouped;
  }

  /// Replaces all task_tags links for [taskId].
  ///
  /// One outbox event per row-level change: every DELETE of an old link and
  /// every INSERT of a new link enqueues its own event, within the same
  /// transaction. Newly-created tags enqueue their own `tags` events via
  /// [ensureTag].
  Future<void> replaceTagsForTask(
    String taskId,
    List<String> tagNames,
  ) async {
    await transaction(() async {
      final previous = await (select(taskTags)
            ..where((tt) => tt.taskId.equals(taskId)))
          .get();
      await (delete(taskTags)..where((tt) => tt.taskId.equals(taskId))).go();
      for (final link in previous) {
        await attachedDatabase.enqueueSyncEvent(
          'task_tags',
          joinRowId(link.taskId, link.tagId),
        );
      }
      for (final name in tagNames) {
        final tag = await ensureTag(name);
        await into(taskTags).insert(
          TaskTagsCompanion.insert(
            taskId: taskId,
            tagId: tag.id,
          ),
          onConflict: DoNothing(),
        );
        await attachedDatabase.enqueueSyncEvent(
          'task_tags',
          joinRowId(taskId, tag.id),
        );
      }
    });
  }

  Future<Tag> ensureTag(String name) async {
    final existing = await (select(tags)..where((t) => t.name.equals(name)))
        .getSingleOrNull();
    if (existing != null) return existing;
    final tag = TagsCompanion.insert(
      id: const Uuid().v4(),
      name: name,
    );
    await transaction(() async {
      await into(tags).insert(tag);
      await attachedDatabase.enqueueSyncEvent('tags', tag.id.value);
    });
    return (select(tags)..where((t) => t.name.equals(name))).getSingle();
  }
}
