import 'dart:async';

import '../../../local_db/daos/contacts_dao.dart';
import '../domain/contact.dart';
import '../domain/contact_repository.dart';
import 'contact_mapper.dart';

class ContactRepositoryImpl implements ContactRepository {
  ContactRepositoryImpl({required ContactsDao dao}) : _dao = dao;

  final ContactsDao _dao;
  final _mapper = ContactMapper();

  @override
  Stream<List<Contact>> watchAll({String? nameFilter}) async* {
    yield* _dao.watchAllContacts(nameFilter: nameFilter).map(
          (rows) => rows.map(_mapper.toDomain).toList(),
        );
  }

  @override
  Stream<Contact?> watchById(String id) async* {
    yield* _dao.watchContactById(id).map(
          (row) => row != null ? _mapper.toDomain(row) : null,
        );
  }

  @override
  Future<Contact> create({
    required String name,
    String? role,
    String? email,
    String? phone,
  }) async {
    final row = await _dao.createContact(
      name: name,
      role: role,
      email: email,
      phone: phone,
    );
    return _mapper.toDomain(row);
  }

  @override
  Future<void> update(Contact contact) async {
    final updated = contact.copyWith(updatedAt: DateTime.now());
    await _dao.upsertContact(_mapper.toCompanion(updated));
  }

  @override
  Future<void> delete(String id) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _dao.softDeleteContact(id, now);
  }

  @override
  Future<List<Contact>> contactsForTask(String taskId) async {
    final rows = await _dao.contactsForTask(taskId);
    return rows.map(_mapper.toDomain).toList();
  }

  @override
  Future<Map<String, List<Contact>>> contactsByTaskIds(
    List<String> taskIds,
  ) async {
    final grouped = await _dao.contactsForTasks(taskIds);
    return grouped.map((taskId, rows) => MapEntry(
          taskId,
          rows.map(_mapper.toDomain).toList(),
        ));
  }

  @override
  Future<void> replaceContactsForTask(
    String taskId,
    List<String> contactIds,
  ) async {
    await _dao.replaceContactsForTask(taskId, contactIds);
  }
}
