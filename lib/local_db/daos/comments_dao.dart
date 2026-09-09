import 'dart:async';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../database.dart';
import '../tables/comments_table.dart';

part 'comments_dao.g.dart';

@DriftAccessor(tables: [Comments])
class CommentsDao extends DatabaseAccessor<AppDatabase>
    with _$CommentsDaoMixin {
  CommentsDao(super.db);

  Stream<List<Comment>> watchCommentsForTask(String taskId) {
    final query = select(comments)
      ..where((c) => c.taskId.equals(taskId) & c.deletedAt.isNull())
      ..orderBy([(c) => OrderingTerm.asc(c.createdAt)]);
    return query.watch();
  }

  Future<Comment> getCommentById(String id) {
    return (select(comments)..where((c) => c.id.equals(id))).getSingle();
  }

  Future<Comment> createComment({
    required String taskId,
    required String body,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final id = const Uuid().v4();
    await into(comments).insert(
      CommentsCompanion.insert(
        id: id,
        taskId: taskId,
        body: body,
        createdAt: now,
      ),
    );
    return getCommentById(id);
  }

  Future<void> softDeleteComment(String id, int now) async {
    await (update(comments)..where((c) => c.id.equals(id))).write(
      CommentsCompanion(deletedAt: Value(now)),
    );
  }
}