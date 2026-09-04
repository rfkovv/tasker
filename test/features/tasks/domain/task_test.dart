import 'package:flutter_test/flutter_test.dart';
import 'package:taskmaster/features/tasks/domain/task.dart';
import 'package:taskmaster/features/tasks/domain/task_priority.dart';
import 'package:taskmaster/features/tasks/domain/task_status.dart';

Task buildTask({
  DateTime? dueDate,
  TaskStatus status = TaskStatus.todo,
}) {
  final now = DateTime.now();
  return Task(
    id: 'id',
    title: 't',
    tags: const [],
    priority: TaskPriority.medium,
    dueDate: dueDate,
    status: status,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  group('Task.isDone', () {
    test('true when status is done', () {
      final task = buildTask(status: TaskStatus.done);
      expect(task.isDone, isTrue);
    });

    test('false when not done', () {
      expect(buildTask(status: TaskStatus.todo).isDone, isFalse);
      expect(buildTask(status: TaskStatus.inProgress).isDone, isFalse);
    });
  });

  group('Task.isOverdue', () {
    test('false when no due date', () {
      expect(buildTask().isOverdue, isFalse);
    });

    test('false when due in the future', () {
      final future = DateTime.now().add(const Duration(days: 1));
      expect(buildTask(dueDate: future).isOverdue, isFalse);
    });

    test('true when due in the past', () {
      final past = DateTime.now().subtract(const Duration(days: 1));
      expect(buildTask(dueDate: past).isOverdue, isTrue);
    });

    test('false when done even if past due', () {
      final past = DateTime.now().subtract(const Duration(days: 1));
      final task = buildTask(dueDate: past, status: TaskStatus.done);
      expect(task.isOverdue, isFalse);
    });
  });
}
