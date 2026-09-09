import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../local_db/providers/database_provider.dart';
import '../../../local_db/value_objects/owner_id.dart';
import '../domain/task_repository.dart';
import 'task_repository_impl.dart';

final taskRepositoryProvider = Provider<TaskRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return TaskRepositoryImpl(
    database: db,
    ownerIdLoader: () async => await ref.read(ownerIdProvider.future),
  );
});
