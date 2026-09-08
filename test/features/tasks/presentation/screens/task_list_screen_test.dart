import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskmaster/features/contacts/contacts.dart' as contacts_feature;
import 'package:taskmaster/features/contacts/domain/contact.dart';
import 'package:taskmaster/features/contacts/domain/contact_repository.dart';
import 'package:taskmaster/features/tasks/domain/task.dart';
import 'package:taskmaster/features/tasks/domain/task_filter.dart';
import 'package:taskmaster/features/tasks/domain/task_priority.dart';
import 'package:taskmaster/features/tasks/domain/task_repository.dart';
import 'package:taskmaster/features/tasks/domain/task_status.dart';
import 'package:taskmaster/features/tasks/presentation/screens/task_list_screen.dart';
import 'package:taskmaster/features/tasks/presentation/widgets/task_tile.dart';
import 'package:taskmaster/features/tasks/data/task_repository_provider.dart';
import 'package:taskmaster/l10n/app_localizations.dart';

class FakeTaskRepository implements TaskRepository {
  FakeTaskRepository(this._tasks);

  final List<Task> _tasks;

  @override
  Stream<List<Task>> watchAll({TaskFilter filter = TaskFilter.none}) {
    final filtered = _tasks.where((t) {
      if (filter.status != null && t.status != filter.status) return false;
      if (filter.priority != null && t.priority != filter.priority) {
        return false;
      }
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
  Future<void> update(Task task) async {}

  @override
  Future<void> updateStatus(String id, TaskStatus status) async {
    final index = _tasks.indexWhere((t) => t.id == id);
    if (index != -1) {
      _tasks[index] = _tasks[index].copyWith(status: status);
    }
  }

  @override
  Future<void> delete(String id) async {
    _tasks.removeWhere((t) => t.id == id);
  }
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

Task buildTask({
  String? id,
  String title = 'Task',
  TaskStatus status = TaskStatus.todo,
}) {
  final now = DateTime.now();
  return Task(
    id: id ?? 'id',
    title: title,
    tags: const [],
    priority: TaskPriority.medium,
    status: status,
    createdAt: now,
    updatedAt: now,
  );
}

Widget buildApp(
  List<Task> tasks, {
  ValueChanged<String>? onOpenTask,
}) {
  return ProviderScope(
    overrides: [
      taskRepositoryProvider.overrideWithValue(FakeTaskRepository(tasks)),
      contacts_feature.contactRepositoryProvider
          .overrideWithValue(FakeContactRepository()),
    ],
    child: MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: TaskListScreen(onOpenTask: onOpenTask),
    ),
  );
}

void main() {
  testWidgets('shows empty state when no tasks', (tester) async {
    await tester.pumpWidget(buildApp([]));
    await tester.pumpAndSettle();

    expect(find.text('No tasks yet'), findsOneWidget);
  });

  testWidgets('renders task titles', (tester) async {
    await tester.pumpWidget(buildApp([
      buildTask(id: '1', title: 'First'),
      buildTask(id: '2', title: 'Second'),
    ]));
    await tester.pumpAndSettle();

    expect(find.text('First'), findsOneWidget);
    expect(find.text('Second'), findsOneWidget);
  });

  testWidgets('tapping task tile invokes onOpenTask', (tester) async {
    String? opened;
    await tester.pumpWidget(buildApp(
      [buildTask(id: '1', title: 'Task')],
      onOpenTask: (id) => opened = id,
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(TaskTile).first);
    expect(opened, '1');
  });

  testWidgets('shows Add Task as footer tile and no Add Contact',
      (tester) async {
    await tester.pumpWidget(buildApp([buildTask(id: '1', title: 'Task')]));
    await tester.pumpAndSettle();

    expect(find.text('Add Task'), findsOneWidget);
    expect(find.text('Add Contact'), findsNothing);
  });

  testWidgets('does not show FAB when list fits the window', (tester) async {
    await tester.pumpWidget(buildApp([buildTask(id: '1', title: 'Task')]));
    await tester.pumpAndSettle();

    final fab = find.byType(FloatingActionButton);
    expect(fab, findsOneWidget);
    final wrapper = find.ancestor(
      of: fab,
      matching: find.byType(AnimatedOpacity),
    );
    final opacity = tester.widget<AnimatedOpacity>(wrapper);
    expect(opacity.opacity, 0);
    expect(tester.widget<FloatingActionButton>(fab).onPressed, isNull);
  });

  testWidgets('shows FAB when list overflows the window', (tester) async {
    await tester.pumpWidget(buildApp([
      for (var i = 0; i < 30; i++) buildTask(id: '$i', title: 'Task $i'),
    ]));
    await tester.pumpAndSettle();

    final fab = find.byType(FloatingActionButton);
    expect(fab, findsOneWidget);
    final wrapper = find.ancestor(
      of: fab,
      matching: find.byType(AnimatedOpacity),
    );
    final opacity = tester.widget<AnimatedOpacity>(wrapper);
    expect(opacity.opacity, 1);
    expect(tester.widget<FloatingActionButton>(fab).onPressed, isNotNull);
  });
}
