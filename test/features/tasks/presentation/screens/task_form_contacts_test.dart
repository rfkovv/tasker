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
import 'package:taskmaster/l10n/app_localizations.dart';

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
  _FakeTaskRepository({this.onCreateContactsFail = false});

  final bool onCreateContactsFail;
  bool _taskCreated = false;

  bool get taskCreated => _taskCreated;

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
  Future<Task> create(Task task) async {
    _taskCreated = true;
    return task;
  }

  @override
  Future<Task> createWithContacts(
    Task task,
    List<String> contactIds,
  ) async {
    if (onCreateContactsFail) throw Exception('link failed');
    _taskCreated = true;
    return task;
  }

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
    bool isNew = false,
  }) {
    return ProviderScope(
      overrides: [
        contactRepositoryProvider.overrideWithValue(
            contactRepo ?? _FakeContactRepository(contacts)),
        taskRepositoryProvider.overrideWithValue(
            taskRepo ?? _FakeTaskRepository()),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: TaskFormScreen(taskId: isNew ? 'new' : 't1'),
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

  // ── create-mode tests ──────────────────────────────────────────────────

  testWidgets('create mode shows contacts section', (tester) async {
    await tester.pumpWidget(
      buildApp(isNew: true, contacts: [buildContact()]),
    );
    await tester.pumpAndSettle();

    expect(find.text('Contacts'), findsOneWidget);
    expect(find.text('No contacts linked'), findsOneWidget);
  });

  testWidgets('create mode: link existing contact from sheet → chip appears',
      (tester) async {
    final repo = _FakeContactRepository([
      buildContact(id: 'c1', name: 'Alex'),
      buildContact(id: 'c2', name: 'Sam'),
    ]);
    await tester.pumpWidget(
      buildApp(isNew: true, contactRepo: repo, contacts: repo._contacts),
    );
    await tester.pumpAndSettle();

    // scroll to contacts section
    final scrollable = find.byType(SingleChildScrollView);
    await tester.drag(scrollable, const Offset(0, -400));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Link contact').first);
    await tester.pumpAndSettle();

    expect(find.text('Link Contact'), findsOneWidget);
    expect(find.text('Sam'), findsOneWidget);

    await tester.tap(find.text('Sam'));
    await tester.pumpAndSettle();

    expect(find.text('Sam'), findsOneWidget);
    expect(find.text('No contacts linked'), findsNothing);
  });

  testWidgets('create mode: inline create → chip appears', (tester) async {
    final repo = _FakeContactRepository([]);
    await tester.pumpWidget(
      buildApp(isNew: true, contactRepo: repo, contacts: repo._contacts),
    );
    await tester.pumpAndSettle();

    final scrollable = find.byType(SingleChildScrollView);
    await tester.drag(scrollable, const Offset(0, -400));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Link contact').first);
    await tester.pumpAndSettle();

    // no existing contacts → empty state with inline-create entry
    expect(find.text('No contacts available'), findsOneWidget);

    await tester.tap(find.text('Create new contact'));
    await tester.pumpAndSettle();

    // target the Name field inside the bottom sheet (labelText "Name")
    final nameField = find.descendant(
      of: find.byType(BottomSheet),
      matching: find.widgetWithText(TextField, 'Name'),
    );
    await tester.enterText(nameField, 'New Person');
    await tester.tap(find.text('Create & Link'));
    await tester.pumpAndSettle();

    expect(find.text('New Person'), findsOneWidget);
    expect(find.text('No contacts linked'), findsNothing);
  });

  testWidgets('save in create mode calls createWithContacts when contacts are linked',
      (tester) async {
    final fakeRepo = _FakeTaskRepository();
    final contactRepo = _FakeContactRepository([
      buildContact(id: 'c1', name: 'Alex'),
    ]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          contactRepositoryProvider.overrideWithValue(contactRepo),
          taskRepositoryProvider.overrideWithValue(fakeRepo),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const TaskFormScreen(taskId: 'new'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // enter title
    await tester.enterText(find.byType(TextField).first, 'New Task');
    await tester.pumpAndSettle();

    // link contact
    final scrollable = find.byType(SingleChildScrollView);
    await tester.drag(scrollable, const Offset(0, -400));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Link contact').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Alex'));
    await tester.pumpAndSettle();

    // save
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(fakeRepo.taskCreated, isTrue);
  });

  testWidgets('rollback: save opens form but does not pop when createWithContacts throws',
      (tester) async {
    final fakeRepo = _FakeTaskRepository(onCreateContactsFail: true);
    final contactRepo = _FakeContactRepository([
      buildContact(id: 'c1', name: 'Alex'),
    ]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          contactRepositoryProvider.overrideWithValue(contactRepo),
          taskRepositoryProvider.overrideWithValue(fakeRepo),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const TaskFormScreen(taskId: 'new'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // enter title + link contact
    await tester.enterText(find.byType(TextField).first, 'Task Fail');
    await tester.pumpAndSettle();
    final scrollable = find.byType(SingleChildScrollView);
    await tester.drag(scrollable, const Offset(0, -400));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Link contact').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Alex'));
    await tester.pumpAndSettle();

    // save — fails silently inside, form stays open
    await tester.tap(find.text('Save'));
    await tester.pump();

    // form is still visible (not popped) and no task was created
    expect(find.text('New Task'), findsOneWidget);
    expect(fakeRepo.taskCreated, isFalse);
  });
}
