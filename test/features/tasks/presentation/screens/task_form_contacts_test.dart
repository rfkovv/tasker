import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskmaster/features/contacts/data/contact_repository_provider.dart';
import 'package:taskmaster/features/contacts/domain/contact.dart';
import 'package:taskmaster/features/contacts/domain/contact_repository.dart';
import 'package:taskmaster/features/tasks/data/task_repository_provider.dart';
import 'package:taskmaster/features/tasks/domain/task.dart';
import 'package:taskmaster/features/tasks/domain/task_filter.dart';
import 'package:taskmaster/features/tasks/domain/task_priority.dart';
import 'package:taskmaster/features/tasks/domain/task_status.dart';
import 'package:taskmaster/features/tasks/domain/task_repository.dart';
import 'package:taskmaster/features/tasks/presentation/screens/task_form_screen.dart';

class _FakeContactRepository implements ContactRepository {
  _FakeContactRepository(this._contacts);

  final List<Contact> _contacts;
  final Map<String, List<String>> _links = {};

  @override
  Stream<List<Contact>> watchAll({String? nameFilter}) {
    final filtered = _contacts.where((c) {
      if (nameFilter == null) return true;
      final name = c.name.toLowerCase();
      return name.contains(nameFilter.toLowerCase());
    }).toList();
    return Stream.value(filtered);
  }

  @override
  Stream<Contact?> watchById(String id) async* {
    for (final c in _contacts) {
      if (c.id == id) yield c;
    }
  }

  @override
  Future<Contact> create({
    required String name,
    String? role,
    String? email,
    String? phone,
  }) async {
    final contact = Contact(
      id: 'new-$name',
      name: name,
      role: role,
      email: email,
      phone: phone,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    _contacts.add(contact);
    return contact;
  }

  @override
  Future<void> update(Contact contact) async {}

  @override
  Future<void> delete(String id) async {
    _contacts.removeWhere((c) => c.id == id);
  }

  @override
  Future<List<Contact>> contactsForTask(String taskId) async {
    final ids = _links[taskId] ?? const <String>[];
    return _contacts.where((c) => ids.contains(c.id)).toList();
  }

  @override
  Future<Map<String, List<Contact>>> contactsByTaskIds(
      List<String> taskIds) async {
    final result = <String, List<Contact>>{};
    for (final taskId in taskIds) {
      result[taskId] = await contactsForTask(taskId);
    }
    return result;
  }

  @override
  Future<void> replaceContactsForTask(
      String taskId, List<String> contactIds) async {
    _links[taskId] = List.of(contactIds);
  }
}

class _FakeTaskRepository implements TaskRepository {
  @override
  Stream<List<Task>> watchAll({TaskFilter filter = TaskFilter.none}) {
    return const Stream.empty();
  }

  @override
  Stream<Task?> watchById(String id) async* {
    final now = DateTime.now();
    yield Task(
      id: id,
      title: 'Existing Task',
      tags: const [],
      priority: TaskPriority.medium,
      status: TaskStatus.todo,
      createdAt: now,
      updatedAt: now,
    );
  }

  @override
  Future<Task> create(Task task) async => task;

  @override
  Future<void> update(Task task) async {}

  @override
  Future<void> updateStatus(String id, TaskStatus status) async {}

  @override
  Future<void> delete(String id) async {}
}

Contact buildContact({String? id, String name = 'Alex'}) {
  final now = DateTime.now();
  return Contact(
    id: id ?? 'c1',
    name: name,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  Widget buildApp({
    List<Contact> contacts = const [],
    ContactRepository? contactRepo,
    TaskRepository? taskRepo,
  }) {
    return ProviderScope(
      overrides: [
        contactRepositoryProvider.overrideWithValue(
            contactRepo ?? _FakeContactRepository(contacts)),
        taskRepositoryProvider.overrideWithValue(
            taskRepo ?? _FakeTaskRepository()),
      ],
      child: const MaterialApp(
        home: TaskFormScreen(taskId: 't1'),
      ),
    );
  }

  testWidgets('shows no contacts linked when task has none', (tester) async {
    await tester.pumpWidget(buildApp(contacts: [buildContact()]));
    await tester.pumpAndSettle();

    expect(find.text('Contacts'), findsOneWidget);
    expect(find.text('No contacts linked'), findsOneWidget);
  });

  testWidgets('renders linked contacts as chips', (tester) async {
    final repo = _FakeContactRepository([buildContact(name: 'Alex')]);
    repo.replaceContactsForTask('t1', ['c1']);
    await tester.pumpWidget(
      buildApp(contactRepo: repo, contacts: repo._contacts),
    );
    await tester.pumpAndSettle();

    expect(find.text('Alex'), findsOneWidget);
    expect(find.text('No contacts linked'), findsNothing);
  });

  testWidgets('linking a contact from the sheet adds a chip', (tester) async {
    final repo = _FakeContactRepository([
      buildContact(id: 'c1', name: 'Alex'),
      buildContact(id: 'c2', name: 'Sam'),
    ]);
    await tester.pumpWidget(buildApp(contactRepo: repo, contacts: repo._contacts));
    await tester.pumpAndSettle();

    expect(find.text('No contacts linked'), findsOneWidget);

    final formScrollable = find.byType(SingleChildScrollView);
    await tester.drag(formScrollable, const Offset(0, -400));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Link contact').first);
    await tester.pumpAndSettle();

    expect(find.text('Link Contact'), findsOneWidget);
    expect(find.text('Alex'), findsOneWidget);
    expect(find.text('Sam'), findsOneWidget);

    await tester.tap(find.text('Sam'));
    await tester.pumpAndSettle();

    expect(find.text('Sam'), findsOneWidget);
    expect(find.text('No contacts linked'), findsNothing);
  });
}
