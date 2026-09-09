import 'dart:async';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../database.dart';
import '../tables/subtasks_table.dart';

part 'subtasks_dao.g.dart';

@DriftAccessor(tables: [Subtasks])
class SubtasksDao extends DatabaseAccessor<AppDatabase>
    with _$SubtasksDaoMixin {
  SubtasksDao(super.db);

  Stream<List<Subtask>> watchSubtasksForTask(String taskId) {
    final query = select(subtasks)
      ..where((s) => s.taskId.equals(taskId))
      ..orderBy([(s) => OrderingTerm.asc(s.position)]);
    return query.watch();
  }

  Future<Subtask> getSubtaskById(String id) {
    return (select(subtasks)..where((s) => s.id.equals(id))).getSingle();
  }

  Future<void> upsertSubtask(SubtasksCompanion entry) async {
    await into(subtasks).insertOnConflictUpdate(entry);
  }

  Future<void> setSubtaskCompleted(String id, bool completed, int now) async {
    await (update(subtasks)..where((s) => s.id.equals(id))).write(
      SubtasksCompanion(isCompleted: Value(completed), updatedAt: Value(now)),
    );
  }

  Future<void> deleteSubtask(String id) async {
    await (delete(subtasks)..where((s) => s.id.equals(id))).go();
  }

  Future<int> nextPosition(String taskId) async {
    final expr = subtasks.position.max();
    final row = await (selectOnly(subtasks)
          ..addColumns([expr])
          ..where(subtasks.taskId.equals(taskId)))
        .getSingleOrNull();
    final max = row?.read(expr);
    return (max ?? 0) + 1;
  }

  Future<Subtask> createSubtask({
    required String taskId,
    required String title,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final id = const Uuid().v4();
    final position = await nextPosition(taskId);
    await into(subtasks).insert(
      SubtasksCompanion.insert(
        id: id,
        taskId: taskId,
        title: title,
        position: Value(position),
        createdAt: now,
        updatedAt: now,
      ),
    );
    return getSubtaskById(id);
  }
}