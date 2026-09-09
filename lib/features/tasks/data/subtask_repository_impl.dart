import 'dart:async';

import '../../../local_db/daos/subtasks_dao.dart';
import '../domain/subtask.dart';
import '../domain/subtask_repository.dart';
import 'subtask_mapper.dart';

class SubtaskRepositoryImpl implements SubtaskRepository {
  SubtaskRepositoryImpl({required SubtasksDao dao}) : _dao = dao;

  final SubtasksDao _dao;
  final _mapper = SubtaskMapper();

  @override
  Stream<List<Subtask>> watchByTask(String taskId) async* {
    yield* _dao.watchSubtasksForTask(taskId).map(
          (rows) => rows.map(_mapper.toDomain).toList(),
        );
  }

  @override
  Future<Subtask> create({required String taskId, required String title}) async {
    final row = await _dao.createSubtask(taskId: taskId, title: title);
    return _mapper.toDomain(row);
  }

  @override
  Future<void> toggle(String id, {required bool isCompleted}) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _dao.setSubtaskCompleted(id, isCompleted, now);
  }

  @override
  Future<void> delete(String id) async {
    await _dao.deleteSubtask(id);
  }
}