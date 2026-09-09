import 'dart:async';

import 'task.dart';
import 'task_filter.dart';
import 'task_status.dart';

abstract class TaskRepository {
  Stream<List<Task>> watchAll({TaskFilter filter = TaskFilter.none});

  Stream<Task?> watchById(String id);

  Future<Task> create(Task task);

  /// Creates a task and links it to [contactIds] in a single atomic
  /// transaction. If any step fails the entire write is rolled back.
  Future<Task> createWithContacts(Task task, List<String> contactIds);

  Future<void> update(Task task);

  Future<void> updateStatus(String id, TaskStatus status);

  Future<void> delete(String id);
}
