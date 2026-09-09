import 'package:freezed_annotation/freezed_annotation.dart';

part 'subtask.freezed.dart';

/// Aggregated completion state of a task's subtasks (used for the "x/y"
/// progress shown on the task list tile).
class SubtaskProgress {
  const SubtaskProgress({required this.done, required this.total});

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
