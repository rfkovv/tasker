import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskmaster/features/tasks/domain/task.dart';
import 'package:taskmaster/features/tasks/domain/task_priority.dart';
import 'package:taskmaster/features/tasks/domain/task_status.dart';
import 'package:taskmaster/features/tasks/presentation/widgets/task_tile.dart';

Task buildTask({
  String title = 'Test',
  TaskStatus status = TaskStatus.todo,
  TaskPriority priority = TaskPriority.medium,
  List<String> tags = const [],
  DateTime? dueDate,
}) {
  final now = DateTime.now();
  return Task(
    id: 'id',
    title: title,
    tags: tags,
    priority: priority,
    dueDate: dueDate,
    status: status,
    createdAt: now,
    updatedAt: now,
  );
}

Widget wrap(Widget child) {
  return MaterialApp(home: Scaffold(body: child));
}

void main() {
  testWidgets('renders task title', (tester) async {
    await tester.pumpWidget(wrap(TaskTile(task: buildTask(title: 'Buy milk'))));

    expect(find.text('Buy milk'), findsOneWidget);
  });

  testWidgets('shows tags', (tester) async {
    await tester.pumpWidget(
      wrap(TaskTile(task: buildTask(tags: const ['work', 'urgent']))),
    );

    expect(find.text('work'), findsOneWidget);
    expect(find.text('urgent'), findsOneWidget);
  });

  testWidgets('shows priority badge', (tester) async {
    await tester.pumpWidget(
      wrap(TaskTile(task: buildTask(priority: TaskPriority.high))),
    );

    expect(find.text('High'), findsOneWidget);
  });

  testWidgets('shows overdue indicator when past due and not done',
      (tester) async {
    final past = DateTime.now().subtract(const Duration(days: 1));
    await tester
        .pumpWidget(wrap(TaskTile(task: buildTask(dueDate: past))));

    expect(find.text('Overdue'), findsOneWidget);
  });

  testWidgets('does not show overdue indicator when done', (tester) async {
    final past = DateTime.now().subtract(const Duration(days: 1));
    await tester.pumpWidget(
      wrap(TaskTile(task: buildTask(dueDate: past, status: TaskStatus.done))),
    );

    expect(find.text('Overdue'), findsNothing);
  });

  testWidgets('checkbox checked when done', (tester) async {
    await tester.pumpWidget(
      wrap(TaskTile(task: buildTask(status: TaskStatus.done))),
    );

    final checkbox = tester.widget<Checkbox>(find.byType(Checkbox));
    expect(checkbox.value, isTrue);
  });

  testWidgets('triggers onToggleDone when checkbox tapped', (tester) async {
    var toggled = false;
    await tester.pumpWidget(
      wrap(
        TaskTile(
          task: buildTask(),
          onToggleDone: (_) => toggled = true,
        ),
      ),
    );

    await tester.tap(find.byType(Checkbox));
    expect(toggled, isTrue);
  });

  testWidgets('triggers onTap when tile tapped', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      wrap(
        TaskTile(
          task: buildTask(),
          onTap: () => tapped = true,
        ),
      ),
    );

    await tester.tap(find.byType(Card));
    expect(tapped, isTrue);
  });
}
