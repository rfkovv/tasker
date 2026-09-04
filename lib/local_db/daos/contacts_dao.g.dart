// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'contacts_dao.dart';

// ignore_for_file: type=lint
mixin _$ContactsDaoMixin on DatabaseAccessor<AppDatabase> {
  $ContactsTable get contacts => attachedDatabase.contacts;
  $TasksTable get tasks => attachedDatabase.tasks;
  $TaskContactsTable get taskContacts => attachedDatabase.taskContacts;
  ContactsDaoManager get managers => ContactsDaoManager(this);
}

class ContactsDaoManager {
  final _$ContactsDaoMixin _db;
  ContactsDaoManager(this._db);
  $$ContactsTableTableManager get contacts =>
      $$ContactsTableTableManager(_db.attachedDatabase, _db.contacts);
  $$TasksTableTableManager get tasks =>
      $$TasksTableTableManager(_db.attachedDatabase, _db.tasks);
  $$TaskContactsTableTableManager get taskContacts =>
      $$TaskContactsTableTableManager(_db.attachedDatabase, _db.taskContacts);
}
