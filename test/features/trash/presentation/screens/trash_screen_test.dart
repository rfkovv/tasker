import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskmaster/features/contacts/domain/contact.dart';
import 'package:taskmaster/features/tasks/domain/task.dart';
import 'package:taskmaster/features/tasks/domain/task_status.dart';
import 'package:taskmaster/features/trash/data/trash_repository_provider.dart';
import 'package:taskmaster/features/trash/domain/trash_repository.dart';
import 'package:taskmaster/features/trash/presentation/screens/trash_screen.dart';
import 'package:taskmaster/l10n/app_localizations.dart';

Task buildTask({String? id, String title = 'Test task'}) {
  final now = DateTime.now();
  return Task(
    id: id ?? 'id-${now.microsecondsSinceEpoch}',
    title: title,
    status: TaskStatus.todo,
    createdAt: now,
    updatedAt: now,
  );
}

Contact buildContact({String? id, String name = 'Alice'}) {
  final now = DateTime.now();
  return Contact(
    id: id ?? 'c-${now.microsecondsSinceEpoch}',
    name: name,
    createdAt: now,
    updatedAt: now,
  );
}

class _ChangeStream<T> {
  _ChangeStream(this._current);

  T _current;
  late final StreamController<T> _controller = StreamController<T>.broadcast(
    onListen: _emitInitial,
  );

  void _emitInitial() {
    if (!_controller.isClosed) _controller.add(_current);
  }

  void update(T value) {
    _current = value;
    if (!_controller.isClosed) _controller.add(value);
  }

  Stream<T> get stream => _controller.stream;

  void close() => _controller.close();
}

class FakeTrashRepository implements TrashRepository {
  FakeTrashRepository({
    List<Task> deletedTasks = const [],
    List<Contact> deletedContacts = const [],
  }) : _tasks = List.of(deletedTasks),
       _contacts = List.of(deletedContacts),
       _tasksTracker = _ChangeStream<List<Task>>(List.of(deletedTasks)),
       _contactsTracker = _ChangeStream<List<Contact>>(
         List.of(deletedContacts),
       );

  final List<Task> _tasks;
  final List<Contact> _contacts;
  final _ChangeStream<List<Task>> _tasksTracker;
  final _ChangeStream<List<Contact>> _contactsTracker;
  final List<String> restoredTaskIds = [];
  final List<String> restoredContactIds = [];
  bool emptied = false;

  @override
  Stream<List<Task>> watchDeletedTasks() => _tasksTracker.stream;

  @override
  Stream<List<Contact>> watchDeletedContacts() => _contactsTracker.stream;

  @override
  Future<void> restoreTask(String id) async {
    restoredTaskIds.add(id);
    _tasks.removeWhere((t) => t.id == id);
    _tasksTracker.update(List.of(_tasks));
  }

  @override
  Future<void> restoreContact(String id) async {
    restoredContactIds.add(id);
    _contacts.removeWhere((c) => c.id == id);
    _contactsTracker.update(List.of(_contacts));
  }

  @override
  Future<void> emptyTrash() async {
    emptied = true;
    _tasks.clear();
    _contacts.clear();
    _tasksTracker.update(const []);
    _contactsTracker.update(const []);
  }
}

Widget buildApp(TrashRepository repo) {
  return ProviderScope(
    overrides: [trashRepositoryProvider.overrideWithValue(repo)],
    child: MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const TrashScreen(),
    ),
  );
}

void main() {
  testWidgets('header hierarchy: title above toolbar, segmented + empty '
      'trash, no search trigger', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repo = FakeTrashRepository(
      deletedTasks: [buildTask(id: 't1', title: 'Dead')],
    );

    await tester.pumpWidget(buildApp(repo));
    await tester.pumpAndSettle();

    // Title row on top.
    final title = find.byKey(const Key('destination-title'));
    expect(title, findsOneWidget);
    expect(find.text('Trash'), findsOneWidget);

    // Toolbar below: segmented Zadania|Kontakty + Empty trash button.
    final toolbar = find.byKey(const Key('mobile-toolbar'));
    expect(toolbar, findsOneWidget);
    expect(
      find.descendant(
        of: toolbar,
        matching: find.byType(SegmentedButton<bool>),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: toolbar, matching: find.text('Tasks')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: toolbar, matching: find.text('Contacts')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: toolbar, matching: find.text('Empty trash')),
      findsOneWidget,
    );

    // Title above toolbar geometrically.
    final titleRect = tester.getRect(title);
    final toolbarRect = tester.getRect(toolbar);
    expect(titleRect.bottom <= toolbarRect.top, isTrue);

    // NO search trigger in Kosz (decision 1).
    expect(find.byKey(const Key('floating-search-button')), findsNothing);
    expect(find.byKey(const Key('global-search-button')), findsNothing);
  });

  testWidgets('portrait: title and toolbar hide together on scroll, return '
      'on scroll up', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repo = FakeTrashRepository(
      deletedTasks: [for (var i = 0; i < 30; i++) buildTask(title: 'T$i')],
    );

    await tester.pumpWidget(buildApp(repo));
    await tester.pumpAndSettle();

    final title = find.byKey(const Key('destination-title'));
    final toolbar = find.byKey(const Key('mobile-toolbar'));
    expect(title, findsOneWidget);
    expect(toolbar, findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(0, -400));
    await tester.pumpAndSettle();
    expect(title, findsNothing, reason: 'title must hide on scroll down');
    expect(toolbar, findsNothing, reason: 'toolbar must hide on scroll down');

    await tester.drag(find.byType(ListView), const Offset(0, 400));
    await tester.pumpAndSettle();
    expect(title, findsOneWidget, reason: 'title must return on scroll up');
    expect(toolbar, findsOneWidget, reason: 'toolbar must return on scroll up');
  });

  testWidgets('desktop: title above toolbar static, floating search absent', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(2000, 1100);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repo = FakeTrashRepository(
      deletedTasks: [buildTask(id: 't1', title: 'Dead')],
    );

    await tester.pumpWidget(buildApp(repo));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('destination-title')), findsOneWidget);
    expect(find.text('Trash'), findsOneWidget);
    expect(find.text('Empty trash'), findsOneWidget);
    expect(find.byKey(const Key('floating-search-button')), findsNothing);
  });

  testWidgets('tasks tab lists deleted tasks with restore button; contacts '
      'tab empty state', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repo = FakeTrashRepository(
      deletedTasks: [buildTask(id: 't1', title: 'Ghost task')],
    );

    await tester.pumpWidget(buildApp(repo));
    await tester.pumpAndSettle();

    // Tasks tab: deleted task listed with restore button.
    expect(find.text('Ghost task'), findsOneWidget);
    expect(find.byKey(const Key('restore-t1')), findsOneWidget);

    // Switch to contacts tab → empty state.
    await tester.tap(find.text('Contacts'));
    await tester.pumpAndSettle();
    expect(find.text('No deleted contacts'), findsOneWidget);
    expect(find.text('Deleted contacts will appear here'), findsOneWidget);
  });

  testWidgets('restore button restores the task from trash', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repo = FakeTrashRepository(
      deletedTasks: [buildTask(id: 't1', title: 'Restore me')],
    );

    await tester.pumpWidget(buildApp(repo));
    await tester.pumpAndSettle();
    expect(find.text('Restore me'), findsOneWidget);

    await tester.tap(find.byKey(const Key('restore-t1')));
    await tester.pumpAndSettle();

    expect(repo.restoredTaskIds, ['t1']);
    // Gone from trash list → empty state shown.
    expect(find.text('No deleted tasks'), findsOneWidget);
  });

  testWidgets('empty trash shows confirm dialog; confirming hard-deletes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repo = FakeTrashRepository(
      deletedTasks: [buildTask(id: 't1', title: 'Doomed')],
    );

    await tester.pumpWidget(buildApp(repo));
    await tester.pumpAndSettle();
    expect(find.text('Doomed'), findsOneWidget);

    // Tap Empty trash → confirm dialog appears.
    await tester.tap(find.text('Empty trash'));
    await tester.pumpAndSettle();
    expect(find.text('Empty trash?'), findsOneWidget);
    expect(
      find.text(
        'All items in the trash will be permanently deleted. '
        'This cannot be undone.',
      ),
      findsOneWidget,
    );
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);

    // Confirm → emptyTrash called, trash empty.
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(repo.emptied, isTrue);
    expect(find.text('No deleted tasks'), findsOneWidget);
  });

  testWidgets('cancel dismisses the dialog without emptying trash', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repo = FakeTrashRepository(
      deletedTasks: [buildTask(id: 't1', title: 'Safe')],
    );

    await tester.pumpWidget(buildApp(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Empty trash'));
    await tester.pumpAndSettle();
    expect(find.text('Empty trash?'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(repo.emptied, isFalse);
    expect(find.text('Safe'), findsOneWidget);
  });

  testWidgets('empty trash disabled when trash is empty', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repo = FakeTrashRepository();

    await tester.pumpWidget(buildApp(repo));
    await tester.pumpAndSettle();

    expect(find.text('No deleted tasks'), findsOneWidget);
    final button = tester.widget<OutlinedButton>(
      find.ancestor(
        of: find.text('Empty trash'),
        matching: find.byType(OutlinedButton),
      ),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('contacts tab lists deleted contacts with restore button', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repo = FakeTrashRepository(
      deletedContacts: [buildContact(id: 'c1', name: 'Ghost contact')],
    );

    await tester.pumpWidget(buildApp(repo));
    await tester.pumpAndSettle();

    // Default tab is tasks → empty state.
    expect(find.text('No deleted tasks'), findsOneWidget);

    await tester.tap(find.text('Contacts'));
    await tester.pumpAndSettle();

    expect(find.text('Ghost contact'), findsOneWidget);
    expect(find.byKey(const Key('restore-c1')), findsOneWidget);

    await tester.tap(find.byKey(const Key('restore-c1')));
    await tester.pumpAndSettle();
    expect(repo.restoredContactIds, ['c1']);
  });
}
