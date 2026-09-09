import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/services.dart';
import 'package:taskmaster/app/app_shell.dart';
import 'package:taskmaster/features/contacts/contacts.dart' as contacts_feature;
import 'package:taskmaster/features/contacts/domain/contact.dart';
import 'package:taskmaster/features/contacts/domain/contact_repository.dart';
import 'package:taskmaster/features/search/presentation/screens/search_screen.dart';
import 'package:taskmaster/features/settings/domain/app_settings_data.dart';
import 'package:taskmaster/features/settings/presentation/providers/app_settings_provider.dart';
import 'package:taskmaster/features/tasks/data/subtask_repository_provider.dart';
import 'package:taskmaster/features/tasks/data/task_repository_provider.dart';
import 'package:taskmaster/features/tasks/domain/subtask.dart';
import 'package:taskmaster/features/tasks/domain/subtask_repository.dart';
import 'package:taskmaster/features/tasks/domain/task.dart';
import 'package:taskmaster/features/tasks/domain/task_filter.dart';
import 'package:taskmaster/features/tasks/domain/task_priority.dart';
import 'package:taskmaster/features/tasks/domain/task_repository.dart';
import 'package:taskmaster/features/tasks/domain/task_status.dart';
import 'package:taskmaster/features/tasks/presentation/screens/task_board_screen.dart';
import 'package:taskmaster/l10n/app_localizations.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;

class SearchTaskRepository implements TaskRepository {
  SearchTaskRepository(this._tasks, {this.contactLinks = const {}});

  final List<Task> _tasks;

  /// contactId -> linked task ids.
  final Map<String, List<String>> contactLinks;

  @override
  Stream<List<Task>> watchAll({TaskFilter filter = TaskFilter.none}) {
    final linked = filter.contactId == null
        ? null
        : contactLinks[filter.contactId]!.toSet();
    final q = filter.titleQuery?.trim().toLowerCase();
    final filtered = _tasks.where((t) {
      if (filter.status != null && t.status != filter.status) return false;
      if (filter.priority != null && t.priority != filter.priority) {
        return false;
      }
      if (filter.hideDone && t.status == TaskStatus.done) return false;
      if (filter.noDueDate && t.dueDate != null) return false;
      if (q != null && q.isNotEmpty && !t.title.toLowerCase().contains(q)) {
        return false;
      }
      if (linked != null && !linked.contains(t.id)) return false;
      return true;
    }).toList();
    return Stream.value(sortTasks(filtered, filter.sort));
  }

  @override
  Stream<Task?> watchById(String id) async* {
    for (final t in _tasks) {
      if (t.id == id) yield t;
    }
  }

  @override
  Future<Task> create(Task task) async => task;

  @override
  Future<Task> createWithContacts(Task task, List<String> contactIds) async =>
      task;

  @override
  Future<void> update(Task task) async {}

  @override
  Future<void> updateStatus(String id, TaskStatus status) async {}

  @override
  Future<void> delete(String id) async {
    _tasks.removeWhere((t) => t.id == id);
  }
}

class SearchContactRepository implements ContactRepository {
  SearchContactRepository(this._contacts);

  final List<Contact> _contacts;

  @override
  Stream<List<Contact>> watchAll({String? nameFilter}) {
    final q = nameFilter?.trim().toLowerCase();
    return Stream.value(_contacts.where((c) {
      if (q == null || q.isEmpty) return true;
      return c.name.toLowerCase().contains(q);
    }).toList());
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
    throw UnimplementedError();
  }

  @override
  Future<void> update(Contact contact) async {}

  @override
  Future<void> delete(String id) async {}

  @override
  Future<List<Contact>> contactsForTask(String taskId) async => const [];

  @override
  Future<Map<String, List<Contact>>> contactsByTaskIds(
      List<String> taskIds) async {
    return const {};
  }

  @override
  Future<void> replaceContactsForTask(
      String taskId, List<String> contactIds) async {}
}

class SearchSubtaskRepository implements SubtaskRepository {
  @override
  Stream<List<Subtask>> watchByTask(String taskId) =>
      Stream.value(const []);

  @override
  Future<Subtask> create({required String taskId, required String title}) async {
    throw UnimplementedError();
  }

  @override
  Future<void> toggle(String id, {required bool isCompleted}) async {}

  @override
  Future<void> delete(String id) async {}
}

class SeededAppSettings extends AppSettings {
  SeededAppSettings(this._data);

  final AppSettingsData _data;

  @override
  AppSettingsData build() => _data;
}

Task buildTask(String id, String title) {
  final now = DateTime.now();
  return Task(
    id: id,
    title: title,
    priority: TaskPriority.medium,
    status: TaskStatus.todo,
    createdAt: now,
    updatedAt: now,
  );
}

Contact buildContact(String id, String name) {
  final now = DateTime.now();
  return Contact(id: id, name: name, createdAt: now, updatedAt: now);
}

void main() {
  tzdata.initializeTimeZones();

  String? openedTask;
  String? openedContact;

  GoRouter buildRouter(
    SearchTaskRepository taskRepo,
    SearchContactRepository contactRepo, {
    String initialLocation = '/search',
  }) {
    return GoRouter(
      initialLocation: initialLocation,
      routes: [
        ShellRoute(
          builder: (context, state, child) => AppShell(child: child),
          routes: [
            GoRoute(
              path: '/',
              builder: (context, state) {
                final params = state.uri.queryParameters;
                final contactId = params['contact'];
                final query = params['q'];
                final initialFilter = (contactId != null ||
                            (query != null && query.trim().isNotEmpty))
                    ? TaskFilter(
                        contactId: contactId,
                        titleQuery: (query == null || query.trim().isEmpty)
                            ? null
                            : query.trim(),
                      )
                    : null;
                return TaskBoardScreen(
                  initialFilter: initialFilter,
                  onOpenTask: (id) => context.push('/tasks/$id'),
                );
              },
            ),
            GoRoute(
              path: '/search',
              builder: (context, state) => const SearchScreen(),
            ),
            GoRoute(
              path: '/tasks/:id',
              builder: (context, state) {
                openedTask = state.pathParameters['id'];
                return const Scaffold(
                  body: Center(child: Text('task detail')),
                );
              },
            ),
            GoRoute(
              path: '/contacts/:id',
              builder: (context, state) {
                openedContact = state.pathParameters['id'];
                return const Scaffold(
                  body: Center(child: Text('contact detail')),
                );
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget buildApp(
    SearchTaskRepository taskRepo,
    SearchContactRepository contactRepo, {
    String initialLocation = '/search',
  }) {
    return ProviderScope(
      overrides: [
        taskRepositoryProvider.overrideWithValue(taskRepo),
        contacts_feature.contactRepositoryProvider
            .overrideWithValue(contactRepo),
        subtaskRepositoryProvider.overrideWithValue(SearchSubtaskRepository()),
        appSettingsProvider.overrideWith(
          () => SeededAppSettings(
            const AppSettingsData(
              defaultDueTime: '07:00',
              timezoneName: 'Europe/Warsaw',
            ),
          ),
        ),
      ],
      child: MaterialApp.router(
        routerConfig: buildRouter(taskRepo, contactRepo,
            initialLocation: initialLocation),
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    );
  }

  Future<void> search(WidgetTester tester, String query) async {
    final field = find.descendant(
      of: find.byType(SearchScreen),
      matching: find.byType(TextField),
    );
    expect(field, findsOneWidget);
    await tester.enterText(field, query);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
  }

  Future<void> sendCtrlK(WidgetTester tester) async {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
    await tester.pumpAndSettle();
  }

  testWidgets('finds tasks and contacts by partial name, grouped in sections',
      (tester) async {
    await tester.pumpWidget(buildApp(
      SearchTaskRepository([
        buildTask('1', 'Buy milk'),
        buildTask('2', 'Visit client'),
      ]),
      SearchContactRepository([buildContact('c1', 'Milk Man')]),
    ));
    await tester.pump();

    await search(tester, 'mil');

    Finder within(Finder f) => find.descendant(
          of: find.byType(SearchScreen),
          matching: f,
        );
    expect(within(find.text('Tasks')), findsOneWidget);
    expect(within(find.text('People')), findsOneWidget);
    expect(find.text('Buy milk'), findsOneWidget);
    expect(find.text('Milk Man'), findsOneWidget);
    expect(find.text('Visit client'), findsNothing);
  });

  testWidgets('does not list sections when query matches nothing',
      (tester) async {
    await tester.pumpWidget(buildApp(
      SearchTaskRepository([buildTask('1', 'Buy milk')]),
      SearchContactRepository([buildContact('c1', 'Milk Man')]),
    ));
    await tester.pump();

    await search(tester, 'zzz');

    expect(find.byType(SearchScreen), findsOneWidget);
    expect(find.textContaining('No results'), findsOneWidget);
    Finder within(Finder f) => find.descendant(
          of: find.byType(SearchScreen),
          matching: f,
        );
    expect(within(find.text('Tasks')), findsNothing);
    expect(within(find.text('People')), findsNothing);
  });

  testWidgets('tapping a task result opens the task detail', (tester) async {
    openedTask = null;
    await tester.pumpWidget(buildApp(
      SearchTaskRepository([buildTask('42', 'Fix bugs')]),
      SearchContactRepository([]),
    ));
    await tester.pump();

    await search(tester, 'fix');
    await tester.tap(find.text('Fix bugs'));
    await tester.pumpAndSettle();

    expect(openedTask, '42');
    expect(find.text('task detail'), findsOneWidget);
    // The search UI closes itself on navigation.
    expect(find.byType(SearchScreen), findsNothing);
  });

  testWidgets('tapping a contact result opens the contact', (tester) async {
    openedContact = null;
    await tester.pumpWidget(buildApp(
      SearchTaskRepository([buildTask('1', 'Something')]),
      SearchContactRepository([buildContact('c9', 'Ruth Miller')]),
    ));
    await tester.pump();

    await search(tester, 'ruth');
    await tester.tap(find.text('Ruth Miller'));
    await tester.pumpAndSettle();

    expect(openedContact, 'c9');
    expect(find.text('contact detail'), findsOneWidget);
    // The search UI closes itself on navigation.
    expect(find.byType(SearchScreen), findsNothing);
  });

  testWidgets('show all opens the task list pre-filtered by the text query',
      (tester) async {
    tester.view.physicalSize = const Size(2000, 1100);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildApp(
      SearchTaskRepository([
        for (final name in const [
          'Alpha',
          'Baker',
          'Charlie',
          'Delta',
          'Echo',
          'Foxtrot',
          'Golf',
          'Hotel',
          'India',
          'Juliet',
          'Kilo',
          'Lima',
        ])
          buildTask('t-$name', 'Task $name'),
        buildTask('99', 'Unrelated'),
      ]),
      SearchContactRepository([]),
    ));
    await tester.pump();

    await search(tester, 'task');

    // 12 matches exceed the per-section cap of 10 → "show all" is offered.
    expect(find.text('Show all (12)'), findsOneWidget);
    // The 11th item ("Task Kilo") is clipped from the overlay results.
    expect(find.text('Task Kilo'), findsNothing);

    await tester.tap(find.text('Show all (12)'));
    await tester.pumpAndSettle();

    // The task list shows every matching task, not the capped subset.
    expect(find.text('Task Lima'), findsOneWidget);
    expect(find.text('Task Kilo'), findsOneWidget);
    expect(find.text('Unrelated'), findsNothing);
    // The active-filter badge stays visible with the query.
    expect(find.textContaining('"task"'), findsWidgets);
  });

  testWidgets('contact deep link pre-filters the task list by that contact',
      (tester) async {
    tester.view.physicalSize = const Size(2000, 1100);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildApp(
      SearchTaskRepository(
        [buildTask('t1', 'Linked task'), buildTask('t2', 'Other task')],
        contactLinks: const {'c1': ['t1']},
      ),
      SearchContactRepository([buildContact('c1', 'Alice')]),
      initialLocation: '/?contact=c1',
    ));
    await tester.pumpAndSettle();

    expect(find.text('Linked task'), findsOneWidget);
    expect(find.text('Other task'), findsNothing);
    // Active filters from the list header stay visible (badge).
    expect(find.textContaining('Contact: Alice'), findsOneWidget);
  });

  testWidgets('magnifying-glass button opens the shared search UI and a '
      'result navigates to the task detail', (tester) async {
    tester.view.physicalSize = const Size(2000, 1100);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildApp(
      SearchTaskRepository([buildTask('42', 'Fix bugs')]),
      SearchContactRepository([]),
      initialLocation: '/',
    ));
    await tester.pumpAndSettle();

    // Single shared search entry: the magnifying-glass button.
    expect(find.byKey(const Key('global-search-button')), findsOneWidget);
    await tester.tap(find.byKey(const Key('global-search-button')));
    await tester.pumpAndSettle();

    expect(find.byType(SearchScreen), findsOneWidget);
    expect(find.byKey(const Key('search-back-button')), findsOneWidget);

    await search(tester, 'fix');
    await tester.tap(find.text('Fix bugs'));
    await tester.pumpAndSettle();

    expect(openedTask, '42');
    expect(find.text('task detail'), findsOneWidget);
    // Search UI closes itself on navigation.
    expect(find.byType(SearchScreen), findsNothing);
  });

  testWidgets('Ctrl+K opens the same shared search UI and a result '
      'navigates to the contact detail', (tester) async {
    tester.view.physicalSize = const Size(2000, 1100);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildApp(
      SearchTaskRepository([buildTask('1', 'Something')]),
      SearchContactRepository([buildContact('c9', 'Ruth Miller')]),
      initialLocation: '/',
    ));
    await tester.pumpAndSettle();

    await sendCtrlK(tester);

    expect(find.byType(SearchScreen), findsOneWidget);
    expect(find.byKey(const Key('search-back-button')), findsOneWidget);

    await search(tester, 'ruth');
    await tester.tap(find.text('Ruth Miller'));
    await tester.pumpAndSettle();

    expect(openedContact, 'c9');
    expect(find.text('contact detail'), findsOneWidget);
    // Search UI closes itself on navigation.
    expect(find.byType(SearchScreen), findsNothing);
  });

  testWidgets('back button returns to the previous screen', (tester) async {
    tester.view.physicalSize = const Size(2000, 1100);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildApp(
      SearchTaskRepository([]),
      SearchContactRepository([]),
      initialLocation: '/',
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('global-search-button')));
    await tester.pumpAndSettle();
    expect(find.byType(SearchScreen), findsOneWidget);

    await tester.tap(find.byKey(const Key('search-back-button')));
    await tester.pumpAndSettle();

    expect(find.byType(SearchScreen), findsNothing);
    expect(find.byKey(const Key('global-search-button')), findsOneWidget);
  });
}