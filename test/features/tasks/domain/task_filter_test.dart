import 'package:flutter_test/flutter_test.dart';
import 'package:taskmaster/features/tasks/domain/task.dart';
import 'package:taskmaster/features/tasks/domain/task_filter.dart';
import 'package:taskmaster/features/tasks/domain/task_priority.dart';
import 'package:taskmaster/features/tasks/domain/task_status.dart';

Task task({
  required String id,
  DateTime? dueDate,
  DateTime? createdAt,
}) {
  final base = createdAt ?? DateTime.utc(2026, 1, 1);
  return Task(
    id: id,
    title: 'Task $id',
    priority: TaskPriority.medium,
    status: TaskStatus.todo,
    dueDate: dueDate,
    createdAt: base,
    updatedAt: base,
  );
}

void main() {
  final undated = task(id: 'u');
  final overdue = task(
    id: 'over',
    dueDate: DateTime.utc(2026, 1, 10),
    createdAt: DateTime.utc(2026, 1, 1, 1),
  );
  final soon = task(
    id: 'soon',
    dueDate: DateTime.utc(2026, 2, 1),
    createdAt: DateTime.utc(2026, 1, 2),
  );
  final far = task(
    id: 'far',
    dueDate: DateTime.utc(2026, 4, 1),
    createdAt: DateTime.utc(2026, 1, 3),
  );

  List<String> ids(Iterable<Task> t) => t.map((e) => e.id).toList();

  group('sortTasks', () {
    test('none keeps order', () {
      final input = [overdue, undated, soon];
      expect(ids(sortTasks(input, TaskSort.none)), ['over', 'u', 'soon']);
    });

    test('dueAsc puts nearest/overdue first and undated last', () {
      final input = [far, undated, overdue, soon];
      expect(ids(sortTasks(input, TaskSort.dueAsc)), ['over', 'soon', 'far', 'u']);
    });

    test('dueDesc puts farthest first and undated last', () {
      final input = [undated, overdue, far, soon];
      expect(ids(sortTasks(input, TaskSort.dueDesc)), ['far', 'soon', 'over', 'u']);
    });

    test('createdDesc newest first, createdAsc oldest first', () {
      final input = [overdue, soon, far]; // created 01-01, 01-02, 01-03
      expect(
        ids(sortTasks(input, TaskSort.createdDesc)),
        ['far', 'soon', 'over'],
      );
      expect(
        ids(sortTasks(input, TaskSort.createdAsc)),
        ['over', 'soon', 'far'],
      );
    });

    test('multiple undated tasks remain grouped at the end', () {
      final u2 = task(id: 'u2');
      final input = [u2, overdue, undated];
      expect(
        ids(sortTasks(input, TaskSort.dueAsc)),
        ['over', 'u2', 'u'],
      );
    });

    test('does not crash on empty list', () {
      final input = <Task>[];
      expect(ids(sortTasks(input, TaskSort.dueAsc)), isEmpty);
    });

    test('sorts are stable/idempotent for undated under any due sort', () {
      final u1 = task(id: 'u1');
      final u2 = task(id: 'u2');
      final once = sortTasks([u1, u2, overdue], TaskSort.dueAsc);
      final twice = sortTasks(once, TaskSort.dueAsc);
      expect(ids(once), ids(twice));
    });
  });
}