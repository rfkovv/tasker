import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../local_db/providers/database_provider.dart';
import '../domain/app_settings_repository.dart';
import 'app_settings_repository_impl.dart';

final appSettingsRepositoryProvider = Provider<AppSettingsRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return AppSettingsRepositoryImpl(db: db);
});