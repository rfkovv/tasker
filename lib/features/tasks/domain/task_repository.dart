import 'dart:async';

import 'task.dart';
import 'task_filter.dart';
import 'task_status.dart';

abstract class TaskRepository {
  Stream<List<Task>> watchAll({TaskFilter filter = TaskFilter.none});

  Stream<Task?> watchById(String id);

  Future<Task> create(Task task);

  Future<void> update(Task task);

  Future<void> updateStatus(String id, TaskStatus status);

  Future<void> delete(String id);
}
