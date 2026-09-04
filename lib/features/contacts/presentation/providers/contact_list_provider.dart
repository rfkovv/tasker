import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/contact_repository_provider.dart';
import '../../domain/contact.dart';

part 'contact_list_provider.g.dart';

@riverpod
Stream<List<Contact>> contactList(Ref ref, String? nameFilter) {
  return ref.watch(contactRepositoryProvider).watchAll(nameFilter: nameFilter);
}

@riverpod
Stream<Contact?> watchContactById(Ref ref, String id) {
  return ref.watch(contactRepositoryProvider).watchById(id);
}
