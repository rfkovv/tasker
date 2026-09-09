import '../../../local_db/database.dart';
import '../domain/app_settings_data.dart';
import '../domain/app_settings_repository.dart';

class AppSettingsRepositoryImpl implements AppSettingsRepository {
  AppSettingsRepositoryImpl({required AppDatabase db}) : _db = db;

  static const _themeKey = 'theme';
  static const _languageKey = 'language';
  static const _defaultDueTimeKey = 'default_due_time';
  static const _timezoneKey = 'timezone';

  final AppDatabase _db;

  @override
  Future<AppSettingsData> load() async {
    final theme = await _db.lookupSettings(_themeKey);
    final language = await _db.lookupSettings(_languageKey);
    final defaultDueTime = await _db.lookupSettings(_defaultDueTimeKey);
    final timezone = await _db.lookupSettings(_timezoneKey);
    return AppSettingsData(
      themePreference: AppThemePreference.fromDbValue(theme ?? ''),
      language: AppLanguage.fromDbValue(language ?? ''),
      defaultDueTime: defaultDueTime ?? '07:00',
      timezoneName: timezone ?? '',
    );
  }

  @override
  Future<void> saveThemePreference(AppThemePreference theme) {
    return _db.storeSetting(_themeKey, theme.dbValue);
  }

  @override
  Future<void> saveLanguage(AppLanguage language) {
    return _db.storeSetting(_languageKey, language.dbValue);
  }

  @override
  Future<void> saveDefaultDueTime(String value) {
    return _db.storeSetting(_defaultDueTimeKey, value);
  }

  @override
  Future<void> saveTimezone(String value) {
    return _db.storeSetting(_timezoneKey, value);
  }
}