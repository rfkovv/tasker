import '../../../local_db/database.dart' as db;
import '../domain/subtask.dart' as domain;

class SubtaskMapper {
  domain.Subtask toDomain(db.Subtask row) {
    return domain.Subtask(
      id: row.id,
      taskId: row.taskId,
      title: row.title,
      isCompleted: row.isCompleted,
      position: row.position,
      createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(row.updatedAt),
    );
  }
}