import 'dart:async';

import 'subtask.dart';

abstract class SubtaskRepository {
  Stream<List<Subtask>> watchByTask(String taskId);

  Future<Subtask> create({required String taskId, required String title});

  Future<void> toggle(String id, {required bool isCompleted});

  Future<void> delete(String id);
}