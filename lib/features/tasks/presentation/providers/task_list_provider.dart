import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/task_repository_provider.dart';
import '../../domain/task.dart';
import '../../domain/task_filter.dart';

part 'task_list_provider.g.dart';

@riverpod
Stream<List<Task>> taskList(Ref ref, TaskFilter filter) {
  return ref.watch(taskRepositoryProvider).watchAll(filter: filter);
}

@riverpod
Stream<Task?> watchTaskById(Ref ref, String id) {
  return ref.watch(taskRepositoryProvider).watchById(id);
}

@riverpod
class TaskFilterState extends _$TaskFilterState {
  @override
  TaskFilter build() => TaskFilter.none;

  void setFilter(TaskFilter filter) => state = filter;
}
