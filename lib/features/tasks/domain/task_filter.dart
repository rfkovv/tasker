import 'package:freezed_annotation/freezed_annotation.dart';

import 'task_priority.dart';
import 'task_status.dart';

part 'task_filter.freezed.dart';

@freezed
abstract class TaskFilter with _$TaskFilter {
  const factory TaskFilter({
    TaskStatus? status,
    TaskPriority? priority,
    String? tag,
    @Default(false) bool hideDone,
  }) = _TaskFilter;

  const TaskFilter._();

  static const TaskFilter none = TaskFilter();
}
