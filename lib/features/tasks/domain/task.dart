import 'package:freezed_annotation/freezed_annotation.dart';

import 'task_priority.dart';
import 'task_status.dart';

part 'task.freezed.dart';

@freezed
abstract class Task with _$Task {
  const factory Task({
    required String id,
    required String title,
    String? description,
    @Default(<String>[]) List<String> tags,
    @Default(TaskPriority.medium) TaskPriority priority,
    DateTime? dueDate,
    @Default(TaskStatus.todo) TaskStatus status,
    required DateTime createdAt,
    required DateTime updatedAt,
    DateTime? deletedAt,
  }) = _Task;

  const Task._();

  bool get isDone => status == TaskStatus.done;

  bool get isOverdue {
    final due = dueDate;
    if (due == null) return false;
    if (isDone) return false;
    final now = DateTime.now();
    return due.isBefore(now);
  }
}
