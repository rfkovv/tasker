import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/app_settings_repository_provider.dart';
import '../../domain/app_settings_data.dart';

part 'app_settings_provider.g.dart';

@Riverpod(keepAlive: true)
class AppSettings extends _$AppSettings {
  @override
  AppSettingsData build() => const AppSettingsData();

  Future<void> seed() async {
    state = await ref.read(appSettingsRepositoryProvider).load();
  }

  Future<void> setThemePreference(AppThemePreference theme) async {
    await ref.read(appSettingsRepositoryProvider).saveThemePreference(theme);
    state = state.copyWith(themePreference: theme);
  }

  Future<void> setLanguage(AppLanguage language) async {
    await ref.read(appSettingsRepositoryProvider).saveLanguage(language);
    state = state.copyWith(language: language);
  }

  Future<void> setDefaultDueTime(String value) async {
    await ref.read(appSettingsRepositoryProvider).saveDefaultDueTime(value);
    state = state.copyWith(defaultDueTime: value);
  }

  Future<void> setTimezone(String value) async {
    await ref.read(appSettingsRepositoryProvider).saveTimezone(value);
    state = state.copyWith(timezoneName: value);
  }
}