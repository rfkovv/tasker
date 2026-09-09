// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'comments_dao.dart';

// ignore_for_file: type=lint
mixin _$CommentsDaoMixin on DatabaseAccessor<AppDatabase> {
  $TasksTable get tasks => attachedDatabase.tasks;
  $CommentsTable get comments => attachedDatabase.comments;
  CommentsDaoManager get managers => CommentsDaoManager(this);
}

class CommentsDaoManager {
  final _$CommentsDaoMixin _db;
  CommentsDaoManager(this._db);
  $$TasksTableTableManager get tasks =>
      $$TasksTableTableManager(_db.attachedDatabase, _db.tasks);
  $$CommentsTableTableManager get comments =>
      $$CommentsTableTableManager(_db.attachedDatabase, _db.comments);
}
