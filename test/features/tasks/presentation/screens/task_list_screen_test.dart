import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskmaster/features/tasks/domain/task.dart';
import 'package:taskmaster/features/tasks/domain/task_filter.dart';
import 'package:taskmaster/features/tasks/domain/task_priority.dart';
import 'package:taskmaster/features/tasks/domain/task_repository.dart';
import 'package:taskmaster/features/tasks/domain/task_status.dart';
import 'package:taskmaster/features/tasks/presentation/screens/task_list_screen.dart';
import 'package:taskmaster/features/tasks/data/task_repository_provider.dart';

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

void main() {
  Widget buildApp(List<Task> tasks) {
    final repo = FakeTaskRepository(tasks);
    return ProviderScope(
      overrides: [
        taskRepositoryProvider.overrideWithValue(repo),
      ],
      child: const MaterialApp(home: TaskListScreen()),
    );
  }

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
    final repo = FakeTaskRepository([buildTask(id: '1', title: 'Task')]);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [taskRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp(
          home: TaskListScreen(onOpenTask: (id) => opened = id),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(Card));
    expect(opened, '1');
  });

  testWidgets('shows add task button', (tester) async {
    await tester.pumpWidget(buildApp([]));
    await tester.pumpAndSettle();

    expect(find.text('Add Task'), findsOneWidget);
  });
}
