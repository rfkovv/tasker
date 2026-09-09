import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/subtask_repository_provider.dart';
import '../../domain/subtask.dart';

part 'subtask_list_provider.g.dart';

@riverpod
Stream<List<Subtask>> subtaskList(Ref ref, String taskId) {
  return ref.watch(subtaskRepositoryProvider).watchByTask(taskId);
}