import 'dart:async';

import 'comment.dart';

abstract class CommentRepository {
  Stream<List<Comment>> watchByTask(String taskId);

  Future<Comment> create({required String taskId, required String body});

  /// Soft-deletes the comment (sets [Comment.deletedAt]).
  Future<void> delete(String id);
}