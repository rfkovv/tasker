import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/comment_repository_provider.dart';
import '../../domain/comment.dart';

part 'comment_list_provider.g.dart';

@riverpod
Stream<List<Comment>> commentList(Ref ref, String taskId) {
  return ref.watch(commentRepositoryProvider).watchByTask(taskId);
}