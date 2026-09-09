import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/subtask_repository_provider.dart';
import '../../domain/subtask.dart';
import '../../domain/task_filter.dart';
import 'task_list_provider.dart';

part 'subtask_progress_by_task_provider.g.dart';

/// Maps each visible task id to its subtask completion progress ("x/y").
///
/// Only tasks that actually have subtasks are present in the map.
@riverpod
Future<Map<String, SubtaskProgress>> subtaskProgressByTask(
  Ref ref,
  TaskFilter filter,
) async {
  final tasks = await ref.watch(taskListProvider(filter).future);
  final ids = tasks.map((t) => t.id).toList();
  if (ids.isEmpty) return const {};

  final progress =
      await ref.watch(subtaskRepositoryProvider).progressForTasks(ids);
  return {
    for (final entry in progress.entries)
      if (!entry.value.isEmpty) entry.key: entry.value,
  };
}