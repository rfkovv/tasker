import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../domain/subtask.dart';
import '../../domain/task_filter.dart';
import 'subtask_list_provider.dart';
import 'task_list_provider.dart';

part 'subtask_progress_by_task_provider.g.dart';

/// Maps each visible task id to its subtask completion progress ("x/y").
///
/// Derives progress from the same domain [Subtask] list (via
/// [subtaskListProvider]) that the task detail screen renders, so both
/// surfaces always agree. Only tasks that actually have subtasks are
/// present in the map.
@riverpod
Future<Map<String, SubtaskProgress>> subtaskProgressByTask(
  Ref ref,
  TaskFilter filter,
) async {
  final tasks = await ref.watch(taskListProvider(filter).future);
  final ids = tasks.map((t) => t.id).toList();

  final result = <String, SubtaskProgress>{};
  for (final id in ids) {
    final subtasks = await ref.watch(subtaskListProvider(id).future);
    if (subtasks.isEmpty) continue;
    result[id] = SubtaskProgress.fromSubtasks(subtasks);
  }
  return result;
}