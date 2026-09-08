import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskmaster/features/settings/data/app_settings_repository_provider.dart';
import 'package:taskmaster/features/settings/domain/app_settings_data.dart';
import 'package:taskmaster/features/settings/domain/app_settings_repository.dart';
import 'package:taskmaster/features/settings/presentation/providers/app_settings_provider.dart';

class _FakeSettingsRepository implements AppSettingsRepository {
  _FakeSettingsRepository(this._data);

  AppSettingsData _data;
  final List<AppThemePreference> savedThemes = [];
  final List<AppLanguage> savedLanguages = [];

  @override
  Future<AppSettingsData> load() async => _data;

  @override
  Future<void> saveThemePreference(AppThemePreference theme) async {
    savedThemes.add(theme);
    _data = _data.copyWith(themePreference: theme);
  }

  @override
  Future<void> saveLanguage(AppLanguage language) async {
    savedLanguages.add(language);
    _data = _data.copyWith(language: language);
  }
}

void main() {
  test('defaults when nothing has been seeded', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(appSettingsProvider).themePreference,
        AppThemePreference.system);
    expect(container.read(appSettingsProvider).language, AppLanguage.en);
  });

  test('seed loads persisted settings before app starts', () async {
    final repo = _FakeSettingsRepository(
      const AppSettingsData(
        themePreference: AppThemePreference.dark,
        language: AppLanguage.pl,
      ),
    );
    final container = ProviderContainer(
      overrides: [appSettingsRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);

    await container.read(appSettingsProvider.notifier).seed();

    expect(container.read(appSettingsProvider).themePreference,
        AppThemePreference.dark);
    expect(container.read(appSettingsProvider).language, AppLanguage.pl);
  });

  test('setThemePreference updates state and persists', () async {
    final repo = _FakeSettingsRepository(const AppSettingsData());
    final container = ProviderContainer(
      overrides: [appSettingsRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);

    await container
        .read(appSettingsProvider.notifier)
        .setThemePreference(AppThemePreference.dark);

    expect(container.read(appSettingsProvider).themePreference,
        AppThemePreference.dark);
    expect(repo.savedThemes, [AppThemePreference.dark]);
  });

  test('setLanguage updates state and persists', () async {
    final repo = _FakeSettingsRepository(const AppSettingsData());
    final container = ProviderContainer(
      overrides: [appSettingsRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);

    await container
        .read(appSettingsProvider.notifier)
        .setLanguage(AppLanguage.pl);

    expect(container.read(appSettingsProvider).language, AppLanguage.pl);
    expect(repo.savedLanguages, [AppLanguage.pl]);
  });
}