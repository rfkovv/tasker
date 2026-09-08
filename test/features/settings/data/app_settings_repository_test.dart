import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskmaster/features/settings/data/app_settings_repository_impl.dart';
import 'package:taskmaster/features/settings/domain/app_settings_data.dart';
import 'package:taskmaster/local_db/database.dart' as db;

void main() {
  late db.AppDatabase database;
  late AppSettingsRepositoryImpl repository;

  setUp(() {
    database = db.AppDatabase(NativeDatabase.memory());
    repository = AppSettingsRepositoryImpl(db: database);
  });

  tearDown(() {
    database.close();
  });

  test('load returns defaults when nothing stored', () async {
    final settings = await repository.load();

    expect(settings.themePreference, AppThemePreference.system);
    expect(settings.language, AppLanguage.en);
  });

  test('saveThemePreference persists and loads back', () async {
    await repository.saveThemePreference(AppThemePreference.dark);

    final settings = await repository.load();
    expect(settings.themePreference, AppThemePreference.dark);
    expect(settings.language, AppLanguage.en);
  });

  test('saveLanguage persists and loads back', () async {
    await repository.saveLanguage(AppLanguage.pl);

    final settings = await repository.load();
    expect(settings.language, AppLanguage.pl);
    expect(settings.themePreference, AppThemePreference.system);
  });

  test('values are readable from a fresh repository over the same database',
      () async {
    await repository.saveThemePreference(AppThemePreference.light);
    await repository.saveLanguage(AppLanguage.pl);

    final reloaded = AppSettingsRepositoryImpl(db: database);
    final settings = await reloaded.load();
    expect(settings.themePreference, AppThemePreference.light);
    expect(settings.language, AppLanguage.pl);
  });
}