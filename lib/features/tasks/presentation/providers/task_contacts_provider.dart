import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../contacts/contacts.dart';

part 'task_contacts_provider.g.dart';

@riverpod
Future<List<Contact>> taskContacts(Ref ref, String taskId) {
  return ref.watch(contactRepositoryProvider).contactsForTask(taskId);
}

@riverpod
class TaskContactsManager extends _$TaskContactsManager {
  @override
  AsyncValue<List<Contact>> build(String taskId) {
    return ref.watch(taskContactsProvider(taskId));
  }

  Future<void> attach(String contactId) async {
    final current = state.value ?? <Contact>[];
    final ids = [...current.map((c) => c.id), contactId];
    await _replace(ids);
  }

  Future<void> detach(String contactId) async {
    final current = state.value ?? <Contact>[];
    final ids = current
        .where((c) => c.id != contactId)
        .map((c) => c.id)
        .toList();
    await _replace(ids);
  }

  Future<void> _replace(List<String> ids) async {
    final repo = ref.read(contactRepositoryProvider);
    await repo.replaceContactsForTask(taskId, ids);
    final updated = await repo.contactsForTask(taskId);
    state = AsyncData(updated);
  }
}
