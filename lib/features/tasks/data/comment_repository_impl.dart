import 'dart:async';

import '../../../local_db/daos/comments_dao.dart';
import '../domain/comment.dart';
import '../domain/comment_repository.dart';
import 'comment_mapper.dart';

class CommentRepositoryImpl implements CommentRepository {
  CommentRepositoryImpl({required CommentsDao dao}) : _dao = dao;

  final CommentsDao _dao;
  final _mapper = CommentMapper();

  @override
  Stream<List<Comment>> watchByTask(String taskId) async* {
    yield* _dao.watchCommentsForTask(taskId).map(
          (rows) => rows.map(_mapper.toDomain).toList(),
        );
  }

  @override
  Future<Comment> create({required String taskId, required String body}) async {
    final row = await _dao.createComment(taskId: taskId, body: body);
    return _mapper.toDomain(row);
  }

  @override
  Future<void> delete(String id) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _dao.softDeleteComment(id, now);
  }
}