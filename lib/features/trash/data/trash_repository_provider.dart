import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../local_db/providers/database_provider.dart';
import '../domain/trash_repository.dart';
import 'trash_repository_impl.dart';

final trashRepositoryProvider = Provider<TrashRepository>(
  (ref) => TrashRepositoryImpl(database: ref.watch(databaseProvider)),
);
