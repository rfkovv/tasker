import 'package:freezed_annotation/freezed_annotation.dart';

part 'subtask.freezed.dart';

/// Aggregated completion state of a task's subtasks (used for the "x/y"
/// progress shown on the task list tile and the task detail screen).
class SubtaskProgress {
  const SubtaskProgress({required this.done, required this.total});

  /// Single source of truth for the "x/y" counter. Both the detail screen
  /// and the list tile must derive progress from the domain [Subtask] list
  /// through this factory, never from a separate query.
  factory SubtaskProgress.fromSubtasks(List<Subtask> subtasks) {
    var done = 0;
    for (final subtask in subtasks) {
      if (subtask.isCompleted) done++;
    }
    return SubtaskProgress(done: done, total: subtasks.length);
  }

  final int done;
  final int total;

  bool get isEmpty => total == 0;
}

@freezed
abstract class Subtask with _$Subtask {
  const factory Subtask({
    required String id,
    required String taskId,
    required String title,
    @Default(false) bool isCompleted,
    @Default(0) int position,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _Subtask;

  const Subtask._();
}
