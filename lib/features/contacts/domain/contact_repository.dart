import 'dart:async';

import 'contact.dart';

abstract class ContactRepository {
  Stream<List<Contact>> watchAll({String? nameFilter});

  Stream<Contact?> watchById(String id);

  Future<Contact> create({
    required String name,
    String? role,
    String? email,
    String? phone,
  });

  Future<void> update(Contact contact);

  Future<void> delete(String id);

  Future<List<Contact>> contactsForTask(String taskId);

  /// Contacts per task for the given task ids, keyed by task id.
  Future<Map<String, List<Contact>>> contactsByTaskIds(List<String> taskIds);

  Future<void> replaceContactsForTask(String taskId, List<String> contactIds);
}
