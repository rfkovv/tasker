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
import 'package:taskmaster/features/tasks/presentation/screens/task_board_screen.dart';
import 'package:taskmaster/features/tasks/presentation/screens/task_list_screen.dart';
import 'package:taskmaster/l10n/app_localizations.dart';
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
      return true;
    }).toList();
    return Stream.value(filtered);
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
      List<String> taskIds) async {
    return const {};
  }

  @override
  Future<void> replaceContactsForTask(
      String taskId, List<String> contactIds) async {}
}

class SeededAppSettings extends AppSettings {
  SeededAppSettings(this._data);

  final AppSettingsData _data;

  @override
  AppSettingsData build() => _data;
}

Task buildTask({
  String? id,
  String title = 'Task',
  DateTime? dueDate,
}) {
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
        contacts_feature.contactRepositoryProvider
            .overrideWithValue(FakeContactRepository()),
        appSettingsProvider.overrideWith(
          () => SeededAppSettings(seeded),
        ),
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

  testWidgets('dragging unsigned task onto a day sets its due date',
      (tester) async {
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

  testWidgets('dragging a scheduled chip back to the list clears due date',
      (tester) async {
    tester.view.physicalSize = const Size(2000, 1100);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final now = DateTime.now();
    final due = DateTime.utc(now.year, now.month, 10, 5, 0);
    final repo = CapturingTaskRepository(
      [buildTask(id: '1', title: 'Scheduled', dueDate: due)],
    );
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

  testWidgets(
      'dragging a scheduled chip to another day changes its due date '
      'keeping local time', (tester) async {
    tester.view.physicalSize = const Size(2000, 1100);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final now = DateTime.now();
    final due = tz.TZDateTime(
      warsaw,
      now.year,
      now.month,
      10,
      9,
      30,
    ).toUtc();
    final repo = CapturingTaskRepository(
      [buildTask(id: '1', title: 'Move me', dueDate: due)],
    );
    await tester.pumpWidget(buildApp(repo));
    await tester.pumpAndSettle();

    final targetDay = tz.TZDateTime(
      warsaw,
      now.year,
      now.month,
      20,
      12,
      0,
    );
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
    expect(find.byWidgetPredicate((w) => w.key?.toString().contains('day-cell') ?? false), findsNWidgets(42));

    await tester.tap(find.text('Week'));
    await tester.pumpAndSettle();

    // Week view: exactly 7 day cells.
    expect(find.byWidgetPredicate((w) => w.key?.toString().contains('day-cell') ?? false), findsNWidgets(7));

    await tester.tap(find.text('Month'));
    await tester.pumpAndSettle();
    expect(find.byWidgetPredicate((w) => w.key?.toString().contains('day-cell') ?? false), findsNWidgets(42));
  });
}