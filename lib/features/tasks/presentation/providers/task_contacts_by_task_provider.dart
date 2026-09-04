import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../contacts/contacts.dart' as contacts_feature;

import '../../domain/task_filter.dart';
import 'task_list_provider.dart';

part 'task_contacts_by_task_provider.g.dart';

/// Maps each visible task id to its linked contacts (from the contacts feature).
///
/// Uses only the public contacts API exposed through the contacts barrel.
@riverpod
Future<Map<String, List<contacts_feature.Contact>>> taskContactsByTask(
  Ref ref,
  TaskFilter filter,
) async {
  final tasks = await ref.watch(taskListProvider(filter).future);
  final ids = tasks.map((t) => t.id).toList();
  if (ids.isEmpty) return const {};

  final repo = ref.watch(contacts_feature.contactRepositoryProvider);
  return repo.contactsByTaskIds(ids);
}
