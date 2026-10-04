import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app_router.dart';
import 'features/settings/domain/app_settings_data.dart';
import 'features/settings/presentation/providers/app_settings_provider.dart';
import 'features/sync/sync.dart';
import 'l10n/app_localizations.dart';
import 'shared/timezone_util.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  initAppTimeZones();

  final container = ProviderContainer();
  try {
    await container.read(appSettingsProvider.notifier).seed();
  } catch (_) {
    // Fall back to defaults when settings cannot be read.
  }

  // Sync lifecycle (8b layer 4): outbox debounce + startup session.
  // Background only — the app is fully functional offline; sync never
  // blocks startup or UI. Transport is the in-process fake until 8c.
  container.read(syncServiceProvider.notifier).start();

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const TaskMasterApp(),
    ),
  );
}

Locale _languageLocale(AppLanguage language) {
  return switch (language) {
    AppLanguage.en => const Locale('en'),
    AppLanguage.pl => const Locale('pl'),
  };
}

class TaskMasterApp extends ConsumerWidget {
  const TaskMasterApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);

    return MaterialApp.router(
      title: 'TaskMaster',
      locale: _languageLocale(settings.language),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.light,
        ),
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
      routerConfig: appRouter,
    );
  }
}