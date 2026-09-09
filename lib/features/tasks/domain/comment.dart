import 'package:freezed_annotation/freezed_annotation.dart';

part 'comment.freezed.dart';

@freezed
abstract class Comment with _$Comment {
  const factory Comment({
    required String id,
    required String taskId,
    required String body,
    required DateTime createdAt,
    DateTime? deletedAt,
  }) = _Comment;

  const Comment._();
}
