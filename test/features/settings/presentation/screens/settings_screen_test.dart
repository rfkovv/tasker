import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskmaster/features/settings/data/app_settings_repository_provider.dart';
import 'package:taskmaster/features/settings/domain/app_settings_data.dart';
import 'package:taskmaster/features/settings/domain/app_settings_repository.dart';
import 'package:taskmaster/features/settings/presentation/providers/app_settings_provider.dart';
import 'package:taskmaster/features/settings/presentation/screens/settings_screen.dart';
import 'package:taskmaster/l10n/app_localizations.dart';

class _FakeSettingsRepository implements AppSettingsRepository {
  _FakeSettingsRepository(this._data);

  AppSettingsData _data;
  final List<AppLanguage> savedLanguages = [];

  @override
  Future<AppSettingsData> load() async => _data;

  @override
  Future<void> saveThemePreference(AppThemePreference theme) async {
    _data = _data.copyWith(themePreference: theme);
  }

  @override
  Future<void> saveLanguage(AppLanguage language) async {
    savedLanguages.add(language);
    _data = _data.copyWith(language: language);
  }
}

class _Harness extends ConsumerWidget {
  const _Harness();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    return MaterialApp(
      locale: settings.language == AppLanguage.pl
          ? const Locale('pl')
          : const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: switch (settings.themePreference) {
        AppThemePreference.system => ThemeMode.system,
        AppThemePreference.light => ThemeMode.light,
        AppThemePreference.dark => ThemeMode.dark,
      },
      home: const SettingsScreen(),
    );
  }
}

Widget buildApp(AppSettingsRepository repository) {
  return ProviderScope(
    overrides: [
      appSettingsRepositoryProvider.overrideWithValue(repository),
    ],
    child: const _Harness(),
  );
}

void main() {
  testWidgets('shows theme and language sections', (tester) async {
    await tester.pumpWidget(buildApp(_FakeSettingsRepository(
      const AppSettingsData(),
    )));
    await tester.pumpAndSettle();

    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Theme'), findsOneWidget);
    expect(find.text('System'), findsOneWidget);
    expect(find.text('Dark'), findsOneWidget);
    expect(find.text('Language'), findsOneWidget);
    expect(find.text('English'), findsOneWidget);
    expect(find.text('Polish'), findsOneWidget);
  });

  testWidgets('switching theme to dark applies dark theme instantly',
      (tester) async {
    await tester.pumpWidget(buildApp(_FakeSettingsRepository(
      const AppSettingsData(),
    )));
    await tester.pumpAndSettle();

    expect(
      Theme.of(tester.element(find.byType(SettingsScreen))).brightness,
      Brightness.light,
    );

    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();

    expect(
      Theme.of(tester.element(find.byType(SettingsScreen))).brightness,
      Brightness.dark,
    );
  });

  testWidgets('switching language to Polish translates the UI instantly',
      (tester) async {
    final repo = _FakeSettingsRepository(const AppSettingsData());
    await tester.pumpWidget(buildApp(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Polish'));
    await tester.pumpAndSettle();

    expect(find.text('Ustawienia'), findsOneWidget);
    expect(find.text('Motyw'), findsOneWidget);
    expect(find.text('Język'), findsOneWidget);
    expect(repo.savedLanguages, [AppLanguage.pl]);
  });
}