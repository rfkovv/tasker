import 'package:freezed_annotation/freezed_annotation.dart';

import 'task.dart';
import 'task_priority.dart';
import 'task_status.dart';

part 'task_filter.freezed.dart';

/// How to order tasks in the list. Defaults to [none] (repository order).
enum TaskSort {
  none,
  dueAsc,
  dueDesc,
  createdDesc,
  createdAsc,
}

/// Sorts [tasks] in place according to [sort] and returns them.
///
/// Due-date sorts place tasks without a due date at the END of the list,
/// never interleaved with dated tasks. [TaskSort.none] keeps order.
List<Task> sortTasks(List<Task> tasks, TaskSort sort) {
  switch (sort) {
    case TaskSort.none:
      return tasks;
    case TaskSort.dueAsc:
      tasks.sort(_byDueAscending);
    case TaskSort.dueDesc:
      tasks.sort(_byDueDescending);
    case TaskSort.createdDesc:
      tasks.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    case TaskSort.createdAsc:
      tasks.sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }
  return tasks;
}

int _byDueAscending(Task a, Task b) {
  final ad = a.dueDate;
  final bd = b.dueDate;
  if (ad == null && bd == null) return 0;
  if (ad == null) return 1; // undated last
  if (bd == null) return -1;
  return ad.compareTo(bd);
}

int _byDueDescending(Task a, Task b) {
  final ad = a.dueDate;
  final bd = b.dueDate;
  if (ad == null && bd == null) return 0;
  if (ad == null) return 1; // undated last
  if (bd == null) return -1;
  return bd.compareTo(ad);
}

@freezed
abstract class TaskFilter with _$TaskFilter {
  const factory TaskFilter({
    TaskStatus? status,
    TaskPriority? priority,
    String? tag,
    @Default(false) bool hideDone,
    @Default(false) bool noDueDate,
    @Default(TaskSort.none) TaskSort sort,
  }) = _TaskFilter;

  const TaskFilter._();

  static const TaskFilter none = TaskFilter();
}
