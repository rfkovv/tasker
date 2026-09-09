import '../../../local_db/database.dart' as db;
import '../domain/comment.dart' as domain;

class CommentMapper {
  domain.Comment toDomain(db.Comment row) {
    return domain.Comment(
      id: row.id,
      taskId: row.taskId,
      body: row.body,
      createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt),
      deletedAt: row.deletedAt != null
          ? DateTime.fromMillisecondsSinceEpoch(row.deletedAt!)
          : null,
    );
  }
}