import 'package:freezed_annotation/freezed_annotation.dart';

part 'app_settings_data.freezed.dart';

enum AppThemePreference {
  system('system'),
  light('light'),
  dark('dark');

  const AppThemePreference(this.dbValue);

  final String dbValue;

  static AppThemePreference fromDbValue(String value) {
    return AppThemePreference.values.firstWhere(
      (t) => t.dbValue == value,
      orElse: () => AppThemePreference.system,
    );
  }
}

enum AppLanguage {
  en('en'),
  pl('pl');

  const AppLanguage(this.dbValue);

  final String dbValue;

  static AppLanguage fromDbValue(String value) {
    return AppLanguage.values.firstWhere(
      (l) => l.dbValue == value,
      orElse: () => AppLanguage.en,
    );
  }
}

@freezed
abstract class AppSettingsData with _$AppSettingsData {
  const factory AppSettingsData({
    @Default(AppThemePreference.system) AppThemePreference themePreference,
    @Default(AppLanguage.en) AppLanguage language,
    @Default('07:00') String defaultDueTime,
    @Default('') String timezoneName,
  }) = _AppSettingsData;

  const AppSettingsData._();
}