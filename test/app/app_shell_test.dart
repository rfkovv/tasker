import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:taskmaster/app/app_shell.dart';
import 'package:taskmaster/l10n/app_localizations.dart';

class _Page extends StatelessWidget {
  const _Page({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: Center(child: Text(label)));
  }
}

GoRouter buildRouter() {
  return GoRouter(
    initialLocation: '/',
    routes: [
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const _Page(label: 'Home'),
          ),
          GoRoute(
            path: '/tasks/:id',
            builder: (context, state) => const _Page(label: 'Task'),
          ),
          GoRoute(
            path: '/contacts',
            builder: (context, state) => const _Page(label: 'Contacts'),
          ),
          GoRoute(
            path: '/settings',
            builder: (context, state) => const _Page(label: 'Settings'),
          ),
          GoRoute(
            path: '/search',
            builder: (context, state) => const _Page(label: 'Search'),
          ),
        ],
      ),
    ],
  );
}

void main() {
  late GoRouter router;

  setUp(() {
    router = buildRouter();
  });

  Future<void> pumpShell(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router,
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    );
    await tester.pumpAndSettle();
  }

  NavigationRail rail(WidgetTester tester) {
    return tester.widget<NavigationRail>(find.byType(NavigationRail));
  }

  testWidgets('renders rail with two destinations and settings pinned to bottom on /',
      (tester) async {
    await pumpShell(tester);

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(rail(tester).selectedIndex, 0);
    expect(rail(tester).destinations.length, 2);
    expect(
      find.descendant(
        of: find.byType(NavigationRail),
        matching: find.text('Settings'),
      ),
      findsNothing,
    );
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
  });

  testWidgets('navigating to /settings keeps rail unselected and renders',
      (tester) async {
    await pumpShell(tester);

    router.go('/settings');
    await tester.pumpAndSettle();

    expect(rail(tester).selectedIndex, isNull);
    expect(find.text('Settings'), findsWidgets);
  });

  testWidgets('tapping bottom settings entry navigates to /settings',
      (tester) async {
    await pumpShell(tester);

    await tester.tap(find.byIcon(Icons.settings));
    await tester.pumpAndSettle();

    expect(rail(tester).selectedIndex, isNull);
    expect(find.text('Settings'), findsWidgets);
  });

  testWidgets('navigating to /contacts selects contacts destination',
      (tester) async {
    await pumpShell(tester);

    router.go('/contacts');
    await tester.pumpAndSettle();

    expect(rail(tester).selectedIndex, 1);
  });

  testWidgets('unmapped route defaults to first destination', (tester) async {
    await pumpShell(tester);

    router.go('/tasks/123');
    await tester.pumpAndSettle();

    expect(rail(tester).selectedIndex, 0);
  });

  testWidgets('Ctrl+K opens the global search overlay', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpShell(tester);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
    await tester.pumpAndSettle();

    expect(find.text('Search'), findsOneWidget);
    expect(router.routerDelegate.currentConfiguration.uri.path, '/search');
  });
}