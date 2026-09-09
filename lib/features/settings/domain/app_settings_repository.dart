import 'app_settings_data.dart';

abstract class AppSettingsRepository {
  Future<AppSettingsData> load();

  Future<void> saveThemePreference(AppThemePreference theme);

  Future<void> saveLanguage(AppLanguage language);

  Future<void> saveDefaultDueTime(String value);

  Future<void> saveTimezone(String value);
}