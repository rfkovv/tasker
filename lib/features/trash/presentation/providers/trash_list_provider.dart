import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../contacts/domain/contact.dart';
import '../../../tasks/domain/task.dart';
import '../../data/trash_repository_provider.dart';

part 'trash_list_provider.g.dart';

/// Which trash tab is active: false = tasks, true = contacts.
@riverpod
class TrashTab extends _$TrashTab {
  @override
  bool build() => false;

  void setContacts(bool value) => state = value;
}

/// Soft-deleted tasks surfaced by Kosz.
@riverpod
Stream<List<Task>> deletedTasks(Ref ref) {
  return ref.watch(trashRepositoryProvider).watchDeletedTasks();
}

/// Soft-deleted contacts surfaced by Kosz.
@riverpod
Stream<List<Contact>> deletedContacts(Ref ref) {
  return ref.watch(trashRepositoryProvider).watchDeletedContacts();
}
