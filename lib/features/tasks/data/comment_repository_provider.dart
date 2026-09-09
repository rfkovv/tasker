import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../local_db/providers/database_provider.dart';
import '../domain/comment_repository.dart';
import 'comment_repository_impl.dart';

final commentRepositoryProvider = Provider<CommentRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return CommentRepositoryImpl(dao: db.commentsDao);
});