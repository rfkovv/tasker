import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskmaster/features/contacts/contacts.dart' as contacts_feature;
import 'package:taskmaster/features/contacts/domain/contact.dart';
import 'package:taskmaster/features/contacts/domain/contact_repository.dart';
import 'package:taskmaster/features/settings/domain/app_settings_data.dart';
import 'package:taskmaster/features/settings/presentation/providers/app_settings_provider.dart';
import 'package:taskmaster/features/tasks/data/subtask_repository_provider.dart';
import 'package:taskmaster/features/tasks/data/task_repository_provider.dart';
import 'package:taskmaster/features/tasks/domain/subtask.dart';
import 'package:taskmaster/features/tasks/domain/subtask_repository.dart';
import 'package:taskmaster/features/tasks/domain/calendar.dart';
import 'package:taskmaster/features/tasks/domain/task.dart';
import 'package:taskmaster/features/tasks/domain/task_filter.dart';
import 'package:taskmaster/features/tasks/domain/task_priority.dart';
import 'package:taskmaster/features/tasks/domain/task_repository.dart';
import 'package:taskmaster/features/tasks/domain/task_status.dart';
import 'package:taskmaster/features/tasks/presentation/providers/task_list_provider.dart';
import 'package:taskmaster/features/tasks/presentation/screens/task_board_screen.dart';
import 'package:taskmaster/features/tasks/presentation/screens/task_list_screen.dart';
import 'package:taskmaster/features/tasks/presentation/widgets/calendar_pane.dart';
import 'package:taskmaster/features/tasks/presentation/widgets/calendar_task_tile.dart';
import 'package:taskmaster/features/tasks/presentation/widgets/day_cell.dart';
import 'package:taskmaster/features/tasks/presentation/widgets/task_tile.dart';
import 'package:taskmaster/l10n/app_localizations.dart';
import 'package:taskmaster/shared/hide_on_scroll_header.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

class CapturingTaskRepository implements TaskRepository {
  CapturingTaskRepository(this._tasks);

  final List<Task> _tasks;
  final List<Task> updated = [];

  @override
  Stream<List<Task>> watchAll({TaskFilter filter = TaskFilter.none}) {
    final filtered = _tasks.where((t) {
      if (filter.status != null && t.status != filter.status) return false;
      if (filter.priority != null && t.priority != filter.priority) {
        return false;
      }
      if (filter.hideDone && t.status == TaskStatus.done) return false;
      if (filter.noDueDate && t.dueDate != null) return false;
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
  Future<void> update(Task task) async {
    final index = _tasks.indexWhere((t) => t.id == task.id);
    if (index != -1) _tasks[index] = task;
    updated.add(task);
  }

  @override
  Future<void> updateStatus(String id, TaskStatus status) async {}

  @override
  Future<void> delete(String id) async {
    _tasks.removeWhere((t) => t.id == id);
  }
}

class FakeSubtaskRepository implements SubtaskRepository {
  @override
  Stream<List<Subtask>> watchByTask(String taskId) => Stream.value(const []);

  @override
  Future<Subtask> create({
    required String taskId,
    required String title,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<void> toggle(String id, {required bool isCompleted}) async {}

  @override
  Future<void> delete(String id) async {}
}

class FakeContactRepository implements ContactRepository {
  @override
  Stream<List<Contact>> watchAll({String? nameFilter}) => const Stream.empty();

  @override
  Stream<Contact?> watchById(String id) async* {}

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
    List<String> taskIds,
  ) async {
    return const {};
  }

  @override
  Future<void> replaceContactsForTask(
    String taskId,
    List<String> contactIds,
  ) async {}
}

class SeededAppSettings extends AppSettings {
  SeededAppSettings(this._data);

  final AppSettingsData _data;

  @override
  AppSettingsData build() => _data;
}

Task buildTask({String? id, String title = 'Task', DateTime? dueDate}) {
  final now = DateTime.now();
  return Task(
    id: id ?? 'id',
    title: title,
    priority: TaskPriority.medium,
    status: TaskStatus.todo,
    dueDate: dueDate,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  tzdata.initializeTimeZones();
  final warsaw = tz.getLocation('Europe/Warsaw');

  Widget buildApp(
    CapturingTaskRepository repo, {
    AppSettingsData seeded = const AppSettingsData(
      defaultDueTime: '07:00',
      timezoneName: 'Europe/Warsaw',
    ),
  }) {
    return ProviderScope(
      overrides: [
        taskRepositoryProvider.overrideWithValue(repo),
        subtaskRepositoryProvider.overrideWithValue(FakeSubtaskRepository()),
        contacts_feature.contactRepositoryProvider.overrideWithValue(
          FakeContactRepository(),
        ),
        appSettingsProvider.overrideWith(() => SeededAppSettings(seeded)),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const TaskBoardScreen(),
      ),
    );
  }

  String cellKey(DateTime day) =>
      'day-cell-${day.year}-${day.month}-${day.day}';

  // Long-press drag the given source onto the given target.
  // Flutter's LongPressDraggable requires the pointer to stay near the source
  // long enough for the long-press recognizer (kLongPressTimeout ≈ 500 ms),
  // then gradually move to the target.
  Future<void> dragTo(WidgetTester tester, Finder source, Finder target) async {
    final from = tester.getCenter(source);
    final to = tester.getCenter(target);
    final gesture = await tester.startGesture(from);
    // Hold for ~550 ms with tiny jitter so the gesture isn't dismissed.
    for (var i = 0; i < 6; i++) {
      await gesture.moveBy(const Offset(0.5, 0));
      await tester.pump(const Duration(milliseconds: 100));
    }
    // Move gradually to the target center.
    final steps = 10;
    final dx = (to.dx - from.dx) / steps;
    final dy = (to.dy - from.dy) / steps;
    for (var i = 0; i < steps; i++) {
      await gesture.moveBy(Offset(dx, dy));
      await tester.pump(const Duration(milliseconds: 50));
    }
    await gesture.up();
    await tester.pumpAndSettle();
  }

  testWidgets('dragging unsigned task onto a day sets its due date', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(2000, 1100);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final today = DateTime.now();
    final repo = CapturingTaskRepository([
      buildTask(id: '1', title: 'Unscheduled'),
      buildTask(
        id: '2',
        title: 'Already scheduled',
        dueDate: DateTime.utc(today.year, today.month, 5, 4, 0),
      ),
    ]);
    await tester.pumpWidget(buildApp(repo));
    await tester.pumpAndSettle();
    expect(find.text('Unscheduled'), findsOneWidget);

    // Day cell 15th of the current month — always in the 42-day grid.
    final targetDay = tz.TZDateTime(warsaw, today.year, today.month, 15);
    await dragTo(
      tester,
      find.text('Unscheduled').first,
      find.byKey(ValueKey(cellKey(targetDay))),
    );

    expect(repo.updated, hasLength(1));
    final updated = repo.updated.single;
    expect(updated.id, '1');
    expect(updated.dueDate, isNotNull);
    // 07:00 already applied (existing list time in Warsaw today).
    final local = tz.TZDateTime.from(updated.dueDate!, warsaw);
    expect(local.hour, 7);
    expect(local.minute, 0);
  });

  testWidgets('dragging a scheduled chip back to the list clears due date', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(2000, 1100);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final now = DateTime.now();
    final due = DateTime.utc(now.year, now.month, 10, 5, 0);
    final repo = CapturingTaskRepository([
      buildTask(id: '1', title: 'Scheduled', dueDate: due),
    ]);
    await tester.pumpWidget(buildApp(repo));
    await tester.pumpAndSettle();

    // The chip is in the calendar grid; target the list pane's center.
    await dragTo(
      tester,
      find.text('Scheduled').first,
      find.byType(TaskListScreen),
    );

    expect(repo.updated, hasLength(1));
    expect(repo.updated.single.dueDate, isNull);
  });

  testWidgets('dragging a scheduled chip to another day changes its due date '
      'keeping local time', (tester) async {
    tester.view.physicalSize = const Size(2000, 1100);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final now = DateTime.now();
    final due = tz.TZDateTime(warsaw, now.year, now.month, 10, 9, 30).toUtc();
    final repo = CapturingTaskRepository([
      buildTask(id: '1', title: 'Move me', dueDate: due),
    ]);
    await tester.pumpWidget(buildApp(repo));
    await tester.pumpAndSettle();

    final targetDay = tz.TZDateTime(warsaw, now.year, now.month, 20, 12, 0);
    await dragTo(
      tester,
      find.text('Move me').at(1),
      find.byKey(ValueKey(cellKey(targetDay))),
    );

    expect(repo.updated, hasLength(1));
    final moved = repo.updated.single;
    final local = tz.TZDateTime.from(moved.dueDate!, warsaw);
    // Same day moved, local time (09:30) preserved.
    expect(local.year, now.year);
    expect(local.month, now.month);
    expect(local.day, 20);
    expect(local.hour, 9);
    expect(local.minute, 30);
  });

  testWidgets('mode toggle switches to week and month', (tester) async {
    tester.view.physicalSize = const Size(2000, 1100);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final now = DateTime.now();
    final repo = CapturingTaskRepository([
      buildTask(
        id: '2',
        title: 'Scheduled',
        dueDate: DateTime.utc(now.year, now.month, 5, 5, 0),
      ),
    ]);
    await tester.pumpWidget(buildApp(repo));
    await tester.pumpAndSettle();

    // Month default: the full 42-day grid is present.
    expect(find.byType(SegmentedButton<CalendarViewMode>), findsOneWidget);
    // 42 day cells in month view.
    expect(
      find.byWidgetPredicate(
        (w) => w.key?.toString().contains('day-cell') ?? false,
      ),
      findsNWidgets(42),
    );

    await tester.tap(find.text('Week'));
    await tester.pumpAndSettle();

    // Week view: exactly 7 day cells.
    expect(
      find.byWidgetPredicate(
        (w) => w.key?.toString().contains('day-cell') ?? false,
      ),
      findsNWidgets(7),
    );

    await tester.tap(find.text('Month'));
    await tester.pumpAndSettle();
    expect(
      find.byWidgetPredicate(
        (w) => w.key?.toString().contains('day-cell') ?? false,
      ),
      findsNWidgets(42),
    );
  });

  testWidgets('no-due-date filter does not hide the calendar pane', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(2000, 1100);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final now = DateTime.now();
    final repo = CapturingTaskRepository([
      buildTask(
        id: 'scheduled',
        title: 'Scheduled',
        dueDate: DateTime.utc(now.year, now.month, 5, 5, 0),
      ),
      buildTask(id: 'undated', title: 'Undated'),
    ]);
    await tester.pumpWidget(buildApp(repo));
    await tester.pumpAndSettle();

    // Calendar pane present before filtering.
    expect(find.byType(CalendarPane), findsOneWidget);
    expect(find.byType(DayCell), findsWidgets);

    // Apply the "No due date" list filter directly (as the dropdown does).
    final container = ProviderScope.containerOf(
      tester.element(find.byType(TaskBoardScreen)),
    );
    container
        .read(taskFilterStateProvider.notifier)
        .setFilter(TaskFilter(noDueDate: true));
    await tester.pumpAndSettle();

    // Confirm the filter actually took effect in the LIST pane (scheduled
    // tile gone from the list, only the undated one remains).
    final listTiles = tester
        .widgetList<TaskTile>(find.byType(TaskTile))
        .map((t) => t.task.title)
        .toList();
    expect(listTiles, ['Undated']);

    // The two-pane layout and calendar grid must remain visible regardless
    // of the list filter — the filter only changes the list pane contents.
    expect(find.byType(CalendarPane), findsOneWidget);
    expect(find.byType(DayCell), findsWidgets);
    expect(
      find.byType(CalendarTaskTile),
      findsOneWidget,
    ); // scheduled task still on the grid
  });

  testWidgets('calendar pane renders with empty task list', (tester) async {
    tester.view.physicalSize = const Size(2000, 1100);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repo = CapturingTaskRepository([]);
    await tester.pumpWidget(buildApp(repo));
    await tester.pumpAndSettle();

    expect(find.byType(CalendarPane), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (w) => w.key?.toString().contains('day-cell') ?? false,
      ),
      findsNWidgets(42),
    );
  });

  testWidgets('calendar pane renders when all tasks are undated', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(2000, 1100);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repo = CapturingTaskRepository([
      buildTask(id: '1', title: 'No date'),
      buildTask(id: '2', title: 'Also no date'),
    ]);
    await tester.pumpWidget(buildApp(repo));
    await tester.pumpAndSettle();

    expect(find.byType(CalendarPane), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (w) => w.key?.toString().contains('day-cell') ?? false,
      ),
      findsNWidgets(42),
    );
    expect(find.byType(CalendarTaskTile), findsNothing);
  });

  testWidgets(
    'calendar pane renders when noDueDate filter hides all dated tasks',
    (tester) async {
      tester.view.physicalSize = const Size(2000, 1100);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final now = DateTime.now();
      final repo = CapturingTaskRepository([
        buildTask(
          id: '1',
          title: 'Dated',
          dueDate: DateTime.utc(now.year, now.month, 10),
        ),
        buildTask(id: '2', title: 'Undated'),
      ]);
      await tester.pumpWidget(buildApp(repo));
      await tester.pumpAndSettle();

      // Apply noDueDate filter — list shows only undated, but calendar keeps grid.
      final container = ProviderScope.containerOf(
        tester.element(find.byType(TaskBoardScreen)),
      );
      container
          .read(taskFilterStateProvider.notifier)
          .setFilter(TaskFilter(noDueDate: true));
      await tester.pumpAndSettle();

      expect(find.byType(CalendarPane), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (w) => w.key?.toString().contains('day-cell') ?? false,
        ),
        findsNWidgets(42),
      );
      expect(
        find.byType(CalendarTaskTile),
        findsOneWidget,
      ); // dated task still on grid
    },
  );

  testWidgets('calendar pane renders with normal mixed tasks', (tester) async {
    tester.view.physicalSize = const Size(2000, 1100);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final now = DateTime.now();
    final repo = CapturingTaskRepository([
      buildTask(
        id: '1',
        title: 'Dated',
        dueDate: DateTime.utc(now.year, now.month, 15, 7),
      ),
      buildTask(id: '2', title: 'Undated'),
    ]);
    await tester.pumpWidget(buildApp(repo));
    await tester.pumpAndSettle();

    expect(find.byType(CalendarPane), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (w) => w.key?.toString().contains('day-cell') ?? false,
      ),
      findsNWidgets(42),
    );
    expect(find.byType(CalendarTaskTile), findsOneWidget);
    expect(find.text('Dated'), findsWidgets);
  });

  // --- Narrow layout tests (segmented control) ---

  testWidgets('narrow layout shows segmented control with List and Calendar', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1100);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repo = CapturingTaskRepository([
      buildTask(id: '1', title: 'My Task'),
    ]);
    await tester.pumpWidget(buildApp(repo));
    await tester.pumpAndSettle();

    expect(find.byType(SegmentedButton<bool>), findsOneWidget);
    expect(find.text('List'), findsOneWidget);
    expect(find.text('Calendar'), findsOneWidget);
    // Defaults to list view.
    expect(find.text('My Task'), findsOneWidget);
  });

  testWidgets('narrow layout: tapping Calendar shows calendar pane', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1100);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final now = DateTime.now();
    final repo = CapturingTaskRepository([
      buildTask(
        id: '1',
        title: 'Scheduled',
        dueDate: DateTime.utc(now.year, now.month, 15, 7),
      ),
    ]);
    await tester.pumpWidget(buildApp(repo));
    await tester.pumpAndSettle();

    // Initially list view — calendar not visible.
    expect(find.byType(CalendarPane), findsNothing);
    expect(find.text('Scheduled'), findsOneWidget);

    // Tap Calendar tab.
    await tester.tap(find.text('Calendar'));
    await tester.pumpAndSettle();

    // Calendar pane visible, list hidden.
    expect(find.byType(CalendarPane), findsOneWidget);
    expect(find.byType(CalendarTaskTile), findsOneWidget);
  });

  testWidgets('narrow layout: tapping List shows list view', (tester) async {
    tester.view.physicalSize = const Size(800, 1100);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repo = CapturingTaskRepository([
      buildTask(id: '1', title: 'My Task'),
    ]);
    await tester.pumpWidget(buildApp(repo));
    await tester.pumpAndSettle();

    // Switch to calendar first.
    await tester.tap(find.text('Calendar'));
    await tester.pumpAndSettle();
    expect(find.byType(CalendarPane), findsOneWidget);

    // Switch back to list.
    await tester.tap(find.text('List'));
    await tester.pumpAndSettle();
    expect(find.byType(CalendarPane), findsNothing);
    expect(find.text('My Task'), findsOneWidget);
  });

  testWidgets('tap-to-schedule: tap task then tap day sets due date', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1100);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final now = DateTime.now();
    final due = tz.TZDateTime(warsaw, now.year, now.month, 5, 9, 0).toUtc();
    final repo = CapturingTaskRepository([
      buildTask(id: '1', title: 'Move me', dueDate: due),
    ]);
    await tester.pumpWidget(buildApp(repo));
    await tester.pumpAndSettle();

    // Switch to Calendar view.
    await tester.tap(find.text('Calendar'));
    await tester.pumpAndSettle();
    expect(find.byType(CalendarPane), findsOneWidget);

    // No scheduling hint yet.
    expect(find.text('Tap a day to schedule'), findsNothing);

    // Tap the task tile to enter scheduling mode.
    await tester.tap(find.text('Move me'));
    await tester.pumpAndSettle();

    // Scheduling hint bar visible.
    expect(find.text('Tap a day to schedule'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);

    // Tap day cell 20th to reschedule.
    final targetDay = tz.TZDateTime(warsaw, now.year, now.month, 20);
    await tester.tap(find.byKey(ValueKey(cellKey(targetDay))));
    await tester.pumpAndSettle();

    // Task got new due date, hint dismissed.
    expect(repo.updated, hasLength(1));
    final updated = repo.updated.single;
    expect(updated.id, '1');
    expect(updated.dueDate, isNotNull);
    final local = tz.TZDateTime.from(updated.dueDate!, warsaw);
    expect(local.day, 20);
    expect(local.hour, 9); // kept existing time
    expect(find.text('Tap a day to schedule'), findsNothing);
  });

  testWidgets('tap-to-schedule: cancel dismisses scheduling mode', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1100);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final now = DateTime.now();
    final due = tz.TZDateTime(warsaw, now.year, now.month, 8, 7, 0).toUtc();
    final repo = CapturingTaskRepository([
      buildTask(id: '1', title: 'Scheduled task', dueDate: due),
    ]);
    await tester.pumpWidget(buildApp(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Calendar'));
    await tester.pumpAndSettle();

    // Enter scheduling mode.
    await tester.tap(find.text('Scheduled task'));
    await tester.pumpAndSettle();
    expect(find.text('Tap a day to schedule'), findsOneWidget);

    // Cancel.
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Tap a day to schedule'), findsNothing);
    expect(repo.updated, isEmpty);
  });

  testWidgets('calendar task tiles meet 48px minimum touch target', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1100);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final now = DateTime.now();
    final repo = CapturingTaskRepository([
      buildTask(
        id: '1',
        title: 'Touch me',
        dueDate: DateTime.utc(now.year, now.month, 15, 7),
      ),
    ]);
    await tester.pumpWidget(buildApp(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Calendar'));
    await tester.pumpAndSettle();

    final renderBox = tester.renderObject<RenderBox>(
      find.byType(CalendarTaskTile),
    );
    expect(renderBox.size.height, greaterThanOrEqualTo(48.0));
  });

  // --- Compact mode tests (size-based, never orientation-based) ---

  testWidgets('narrow-portrait: title above toolbar, floating search, no '
      'AppBar', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repo = CapturingTaskRepository([
      buildTask(id: '1', title: 'My Task'),
    ]);
    await tester.pumpWidget(buildApp(repo));
    await tester.pumpAndSettle();

    // Header hierarchy: title row above the controls toolbar.
    expect(find.byType(AppBar), findsNothing);
    final title = find.byKey(const Key('destination-title'));
    expect(title, findsOneWidget);
    expect(find.text('Tasks'), findsOneWidget);
    expect(find.byKey(const Key('mobile-toolbar')), findsOneWidget);
    final titleRect = tester.getRect(title);
    final toolbarRect = tester.getRect(find.byKey(const Key('mobile-toolbar')));
    expect(
      titleRect.bottom <= toolbarRect.top,
      isTrue,
      reason: 'title row must sit above the toolbar',
    );
    // Search trigger = floating button (portrait).
    expect(find.byKey(const Key('floating-search-button')), findsOneWidget);
    expect(find.byKey(const Key('global-search-button')), findsOneWidget);
  });

  testWidgets('narrow-low-height: compact, AppBar absent, floating search '
      'button present', (tester) async {
    tester.view.physicalSize = const Size(500, 400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repo = CapturingTaskRepository([
      buildTask(id: '1', title: 'My Task'),
    ]);
    await tester.pumpWidget(buildApp(repo));
    await tester.pumpAndSettle();

    expect(find.byType(AppBar), findsNothing);
    final floating = find.byKey(const Key('floating-search-button'));
    expect(floating, findsOneWidget);
    // Same shared trigger widget inside the floating button.
    expect(
      find.descendant(
        of: floating,
        matching: find.byKey(const Key('global-search-button')),
      ),
      findsOneWidget,
    );
    // Segmented control present, search NOT inside it anymore.
    expect(find.byType(SegmentedButton<bool>), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(SegmentedButton<bool>),
        matching: find.byIcon(Icons.search),
      ),
      findsNothing,
    );
    // Touch target ≥ 48 dp.
    final size = tester.getSize(floating);
    expect(size.width, greaterThanOrEqualTo(48.0));
    expect(size.height, greaterThanOrEqualTo(48.0));
  });

  testWidgets('wide desktop: title above toolbar static, floating search '
      'on list pane', (tester) async {
    tester.view.physicalSize = const Size(2000, 1100);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repo = CapturingTaskRepository([
      buildTask(id: '1', title: 'My Task'),
    ]);
    await tester.pumpWidget(buildApp(repo));
    await tester.pumpAndSettle();

    // Two-pane wide layout intact; header hierarchy on the list pane.
    expect(find.byType(CalendarPane), findsOneWidget);
    expect(find.byType(TaskListScreen), findsOneWidget);
    expect(find.byType(AppBar), findsNothing);
    final title = find.byKey(const Key('destination-title'));
    expect(title, findsOneWidget);
    expect(find.text('Tasks'), findsOneWidget);
    expect(find.text('Filter'), findsOneWidget);
    final titleRect = tester.getRect(title);
    final filterRect = tester.getRect(find.text('Filter'));
    expect(titleRect.bottom <= filterRect.top, isTrue);
    // Desktop: static rows, floating search on the list pane.
    expect(find.byType(HideOnScrollHeader), findsNothing);
    expect(find.byKey(const Key('mobile-toolbar')), findsNothing);
    expect(find.byKey(const Key('floating-search-button')), findsOneWidget);
    expect(find.byKey(const Key('global-search-button')), findsOneWidget);
  });

  testWidgets('compact mode: calendar pane still renders (invariant)', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(500, 400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repo = CapturingTaskRepository([]);
    await tester.pumpWidget(buildApp(repo));
    await tester.pumpAndSettle();

    // Switch to Calendar view in compact mode.
    await tester.tap(find.text('Calendar'));
    await tester.pumpAndSettle();

    // Calendar pane renders even with zero tasks (invariant).
    expect(find.byType(CalendarPane), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (w) => w.key?.toString().contains('day-cell') ?? false,
      ),
      findsNWidgets(42),
    );
  });

  testWidgets('compact: floating search button never overlaps calendar view '
      'switcher', (tester) async {
    tester.view.physicalSize = const Size(500, 400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repo = CapturingTaskRepository([
      buildTask(id: '1', title: 'My Task'),
    ]);
    await tester.pumpWidget(buildApp(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Calendar'));
    await tester.pumpAndSettle();

    final searchRect = tester.getRect(
      find.byKey(const Key('floating-search-button')),
    );
    final switcherRect = tester.getRect(
      find.byType(SegmentedButton<CalendarViewMode>),
    );
    final overlap = searchRect.intersect(switcherRect);
    expect(
      overlap.width <= 0 || overlap.height <= 0,
      isTrue,
      reason:
          'floating search ($searchRect) must not cover the calendar '
          'view switcher ($switcherRect)',
    );
  });

  testWidgets('compact: floating search button does not collide with '
      'Add FAB', (tester) async {
    tester.view.physicalSize = const Size(500, 400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repo = CapturingTaskRepository([
      for (var i = 0; i < 30; i++) buildTask(id: '$i', title: 'Task $i'),
    ]);
    await tester.pumpWidget(buildApp(repo));
    await tester.pumpAndSettle();

    final searchRect = tester.getRect(
      find.byKey(const Key('floating-search-button')),
    );
    final fab = find.byType(FloatingActionButton);
    final fabWrapper = find.ancestor(
      of: fab,
      matching: find.byType(AnimatedOpacity),
    );
    final opacity = tester.widget<AnimatedOpacity>(fabWrapper).opacity;
    expect(opacity, 1); // list overflows → FAB visible
    final fabRect = tester.getRect(fab);
    final overlap = searchRect.intersect(fabRect);
    expect(
      overlap.width <= 0 || overlap.height <= 0,
      isTrue,
      reason:
          'floating search ($searchRect) must not collide with the '
          'Add FAB ($fabRect)',
    );
  });

  testWidgets('landscape phone (872x390): compact — AppBar absent, floating '
      'search button present', (tester) async {
    tester.view.physicalSize = const Size(872, 390);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repo = CapturingTaskRepository([
      buildTask(id: '1', title: 'My Task'),
    ]);
    await tester.pumpWidget(buildApp(repo));
    await tester.pumpAndSettle();

    // Wide-but-short phone viewport: mobile branch (872 < 1000) + low
    // height (390 < 600) → compact mode must activate.
    expect(find.byType(AppBar), findsNothing);
    expect(find.byKey(const Key('floating-search-button')), findsOneWidget);
    expect(find.byType(SegmentedButton<bool>), findsOneWidget);
    // Same shared trigger inside the floating button.
    expect(
      find.descendant(
        of: find.byKey(const Key('floating-search-button')),
        matching: find.byKey(const Key('global-search-button')),
      ),
      findsOneWidget,
    );
  });

  // --- Unified mobile toolbar (segmented + filter, hide-on-scroll) ---

  testWidgets('portrait mobile: ONE merged toolbar row (Lista|Kalendarz + '
      'Filtruj), no separate filter row', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repo = CapturingTaskRepository([
      buildTask(id: '1', title: 'My Task'),
    ]);
    await tester.pumpWidget(buildApp(repo));
    await tester.pumpAndSettle();

    final toolbar = find.byKey(const Key('mobile-toolbar'));
    expect(toolbar, findsOneWidget);
    // Segmented control AND filter button live in the SAME toolbar row.
    expect(
      find.descendant(
        of: toolbar,
        matching: find.byType(SegmentedButton<bool>),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: toolbar, matching: find.text('Filter')),
      findsOneWidget,
    );
    // Exactly one Filter button in the whole screen — the list no longer
    // renders its own filter row (showFilterBar: false).
    expect(find.text('Filter'), findsOneWidget);
    // Title row above the toolbar (hierarchy), floating search present.
    expect(find.byKey(const Key('destination-title')), findsOneWidget);
    expect(find.text('Tasks'), findsOneWidget);
    expect(find.byKey(const Key('floating-search-button')), findsOneWidget);
  });

  testWidgets('portrait mobile: title AND toolbar hide together on scroll '
      'down and reappear on scroll up', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repo = CapturingTaskRepository([
      for (var i = 0; i < 30; i++) buildTask(id: '$i', title: 'Task $i'),
    ]);
    await tester.pumpWidget(buildApp(repo));
    await tester.pumpAndSettle();

    final title = find.byKey(const Key('destination-title'));
    final toolbar = find.byKey(const Key('mobile-toolbar'));
    expect(title, findsOneWidget);
    expect(toolbar, findsOneWidget);

    // Scroll down → title AND toolbar hide together.
    await tester.drag(find.byType(ListView), const Offset(0, -400));
    await tester.pumpAndSettle();
    expect(title, findsNothing, reason: 'title must hide on scroll down');
    expect(toolbar, findsNothing, reason: 'toolbar must hide on scroll down');

    // Scroll up → both reappear.
    await tester.drag(find.byType(ListView), const Offset(0, 400));
    await tester.pumpAndSettle();
    expect(title, findsOneWidget, reason: 'title must reappear on scroll up');
    expect(
      toolbar,
      findsOneWidget,
      reason: 'toolbar must reappear on scroll up',
    );
  });

  testWidgets('landscape compact: merged toolbar present, floating search '
      'visible and outside the toolbar', (tester) async {
    tester.view.physicalSize = const Size(872, 390);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repo = CapturingTaskRepository([
      buildTask(id: '1', title: 'My Task'),
    ]);
    await tester.pumpWidget(buildApp(repo));
    await tester.pumpAndSettle();

    final toolbar = find.byKey(const Key('mobile-toolbar'));
    expect(toolbar, findsOneWidget);
    expect(
      find.descendant(of: toolbar, matching: find.text('Filter')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: toolbar,
        matching: find.byType(SegmentedButton<bool>),
      ),
      findsOneWidget,
    );

    // Floating search button still visible, NOT inside the toolbar.
    final floating = find.byKey(const Key('floating-search-button'));
    expect(floating, findsOneWidget);
    expect(find.descendant(of: toolbar, matching: floating), findsNothing);
  });

  testWidgets('desktop wide: static header hierarchy — no mobile toolbar '
      'key, filter in DestinationBody toolbar, floating search', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(2000, 1100);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repo = CapturingTaskRepository([
      buildTask(id: '1', title: 'My Task'),
    ]);
    await tester.pumpWidget(buildApp(repo));
    await tester.pumpAndSettle();

    // Desktop must not use the compact mobile toolbar key or scroll-hide.
    expect(find.byKey(const Key('mobile-toolbar')), findsNothing);
    expect(find.byType(HideOnScrollHeader), findsNothing);
    // Static title row + filter toolbar on the list pane.
    expect(find.byKey(const Key('destination-title')), findsOneWidget);
    expect(find.text('Tasks'), findsOneWidget);
    expect(find.text('Filter'), findsOneWidget);
    // Floating search trigger on desktop (decision 2).
    expect(find.byKey(const Key('floating-search-button')), findsOneWidget);
  });

  testWidgets('unified toolbar: filter dropdown still opens under Filtruj '
      'and active badge appears in the same row', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repo = CapturingTaskRepository([
      buildTask(id: '1', title: 'Open task'),
      buildTask(id: '2', title: 'Done task').copyWith(status: TaskStatus.done),
    ]);
    await tester.pumpWidget(buildApp(repo));
    await tester.pumpAndSettle();

    final toolbar = find.byKey(const Key('mobile-toolbar'));
    await tester.tap(
      find.descendant(of: toolbar, matching: find.text('Filter')),
    );
    await tester.pumpAndSettle();

    // Dropdown opens with filter sections (same menu as before).
    expect(find.text('Status'), findsOneWidget);
    expect(find.text('Done'), findsWidgets);

    // Apply "Hide done" → list filters, badge appears in the toolbar row.
    await tester.tap(find.text('Hide done'));
    await tester.pumpAndSettle();
    expect(find.text('Open task'), findsOneWidget);
    expect(find.text('Done task'), findsNothing);
    expect(
      find.descendant(of: toolbar, matching: find.text('Hide done')),
      findsOneWidget,
      reason: 'active filter badge must stay visible in the unified toolbar',
    );
  });
}
