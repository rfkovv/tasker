import 'dart:async';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../database.dart';
import '../tables/contacts_table.dart';
import '../tables/task_contacts_table.dart';

part 'contacts_dao.g.dart';

@DriftAccessor(tables: [Contacts, TaskContacts])
class ContactsDao extends DatabaseAccessor<AppDatabase>
    with _$ContactsDaoMixin {
  ContactsDao(super.db);

  Stream<List<Contact>> watchAllContacts({String? nameFilter}) {
    var query = select(contacts)..where((c) => c.deletedAt.isNull());

    if (nameFilter != null && nameFilter.isNotEmpty) {
      query = query..where((c) => c.name.like('%$nameFilter%'));
    }

    query = query..orderBy([(c) => OrderingTerm.asc(c.name)]);

    return query.watch();
  }

  Stream<Contact?> watchContactById(String id) {
    final query = select(contacts)
      ..where((c) => c.id.equals(id) & c.deletedAt.isNull());
    return query.watchSingleOrNull();
  }

  Future<Contact> getContactById(String id) {
    return (select(contacts)..where((c) => c.id.equals(id))).getSingle();
  }

  Future<void> upsertContact(ContactsCompanion entry) async {
    await into(contacts).insertOnConflictUpdate(entry);
  }

  Future<void> softDeleteContact(String id, int now) async {
    await (update(contacts)..where((c) => c.id.equals(id))).write(
      ContactsCompanion(deletedAt: Value(now), updatedAt: Value(now)),
    );
  }

  Future<List<Contact>> contactsForTask(String taskId) async {
    final rows = await (select(taskContacts)
          ..where((tc) => tc.taskId.equals(taskId)))
        .join([innerJoin(contacts, contacts.id.equalsExp(taskContacts.contactId))])
        .get();
    return rows.map((r) => r.readTable(contacts)).toList();
  }

  Future<Map<String, List<Contact>>> contactsForTasks(List<String> taskIds) {
    if (taskIds.isEmpty) return Future.value(const {});
    return transaction(() async {
      final rows = await (select(taskContacts)
            ..where((tc) => tc.taskId.isIn(taskIds)))
          .join([
        innerJoin(contacts, contacts.id.equalsExp(taskContacts.contactId)),
      ]).get();
      final grouped = <String, List<Contact>>{};
      for (final row in rows) {
        final taskId = row.readTable(taskContacts).taskId;
        grouped.putIfAbsent(taskId, () => []).add(row.readTable(contacts));
      }
      return grouped;
    });
  }

  Future<void> replaceContactsForTask(
    String taskId,
    List<String> contactIds,
  ) async {
    await transaction(() async {
      await (delete(taskContacts)
            ..where((tc) => tc.taskId.equals(taskId)))
          .go();
      for (final contactId in contactIds) {
        await into(taskContacts).insert(
          TaskContactsCompanion.insert(
            taskId: taskId,
            contactId: contactId,
          ),
          onConflict: DoNothing(),
        );
      }
    });
  }

  Future<Contact> createContact({
    required String name,
    String? role,
    String? email,
    String? phone,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final id = const Uuid().v4();
    await into(contacts).insert(
      ContactsCompanion.insert(
        id: id,
        name: name,
        role: Value(role),
        email: Value(email),
        phone: Value(phone),
        createdAt: now,
        updatedAt: now,
      ),
    );
    return getContactById(id);
  }
}
