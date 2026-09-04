import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskmaster/features/contacts/data/contact_repository_impl.dart';
import 'package:taskmaster/local_db/database.dart' as db;
import 'package:taskmaster/local_db/daos/contacts_dao.dart';
import 'package:taskmaster/local_db/daos/tasks_dao.dart';
import 'package:uuid/uuid.dart';

class _InMemoryDatabase {
  _InMemoryDatabase() {
    database = db.AppDatabase(NativeDatabase.memory());
    dao = database.contactsDao;
    tasksDao = database.tasksDao;
    repository = ContactRepositoryImpl(dao: dao);
  }

  late final db.AppDatabase database;
  late final ContactsDao dao;
  late final TasksDao tasksDao;
  late final ContactRepositoryImpl repository;

  Future<void> close() => database.close();

  Future<String> createTestTask(String title) async {
    final id = const Uuid().v4();
    final now = DateTime.now().millisecondsSinceEpoch;
    await tasksDao.upsertTask(
      db.TasksCompanion.insert(
        id: id,
        title: title,
        ownerId: 'test-owner',
        createdAt: now,
        updatedAt: now,
      ),
    );
    return id;
  }
}

void main() {
  late _InMemoryDatabase harness;

  setUp(() {
    harness = _InMemoryDatabase();
  });

  tearDown(() {
    harness.close();
  });

  test('create and watch a contact', () async {
    final contact = await harness.repository.create(
      name: 'Alice Smith',
      role: 'Developer',
      email: 'alice@example.com',
      phone: '555-0100',
    );

    expect(contact.name, 'Alice Smith');
    expect(contact.role, 'Developer');
    expect(contact.email, 'alice@example.com');
    expect(contact.phone, '555-0100');

    final all = await harness.repository.watchAll().first;
    expect(all.length, 1);
    expect(all.first.name, 'Alice Smith');
  });

  test('create persists minimal contact', () async {
    final contact = await harness.repository.create(name: 'Bob');

    expect(contact.name, 'Bob');
    expect(contact.role, isNull);
    expect(contact.email, isNull);
    expect(contact.phone, isNull);

    final all = await harness.repository.watchAll().first;
    expect(all.length, 1);
  });

  test('watchById returns contact', () async {
    final contact = await harness.repository.create(name: 'Single');

    final watched = await harness.repository.watchById(contact.id).first;
    expect(watched, isNotNull);
    expect(watched!.name, 'Single');
  });

  test('update modifies contact', () async {
    final contact = await harness.repository.create(name: 'Before');
    final updated = contact.copyWith(name: 'After');
    await harness.repository.update(updated);

    final watched = await harness.repository.watchById(contact.id).first;
    expect(watched!.name, 'After');
  });

  test('delete soft-deletes and removes from list', () async {
    final contact = await harness.repository.create(name: 'Remove me');
    await harness.repository.delete(contact.id);

    final all = await harness.repository.watchAll().first;
    expect(all, isEmpty);
  });

  test('soft-deleted contact is not returned by watchById', () async {
    final contact = await harness.repository.create(name: 'Gone');
    await harness.repository.delete(contact.id);

    final watched = await harness.repository.watchById(contact.id).first;
    expect(watched, isNull);
  });

  test('name filter works', () async {
    await harness.repository.create(name: 'Alice');
    await harness.repository.create(name: 'Bob');
    await harness.repository.create(name: 'Alice2');

    final filtered =
        await harness.repository.watchAll(nameFilter: 'Alice').first;
    expect(filtered.length, 2);
  });

  test('link contact to task and retrieve', () async {
    final taskId = await harness.createTestTask('Test Task');
    final contact = await harness.repository.create(name: 'Linked');
    await harness.repository.replaceContactsForTask(taskId, [contact.id]);

    final linked = await harness.repository.contactsForTask(taskId);
    expect(linked.length, 1);
    expect(linked.first.name, 'Linked');
  });

  test('replace contacts for task', () async {
    final taskId = await harness.createTestTask('Test Task');
    final c1 = await harness.repository.create(name: 'First');
    final c2 = await harness.repository.create(name: 'Second');
    await harness.repository.replaceContactsForTask(taskId, [c1.id, c2.id]);

    var linked = await harness.repository.contactsForTask(taskId);
    expect(linked.length, 2);

    final c3 = await harness.repository.create(name: 'Third');
    await harness.repository.replaceContactsForTask(taskId, [c3.id]);

    linked = await harness.repository.contactsForTask(taskId);
    expect(linked.length, 1);
    expect(linked.first.name, 'Third');
  });
}
