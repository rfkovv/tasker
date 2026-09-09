import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../local_db/providers/database_provider.dart';
import '../domain/subtask_repository.dart';
import 'subtask_repository_impl.dart';

final subtaskRepositoryProvider = Provider<SubtaskRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return SubtaskRepositoryImpl(dao: db.subtasksDao);
});