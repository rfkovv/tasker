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
            path: '/trash',
            builder: (context, state) => const _Page(label: 'Trash'),
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

  testWidgets(
    'renders rail with three destinations and settings pinned to bottom on /',
    (tester) async {
      await pumpShell(tester);

      expect(find.byType(NavigationRail), findsOneWidget);
      expect(rail(tester).selectedIndex, 0);
      expect(rail(tester).destinations.length, 3);
      expect(
        find.descendant(
          of: find.byType(NavigationRail),
          matching: find.text('Settings'),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byType(NavigationRail),
          matching: find.text('Trash'),
        ),
        findsOneWidget,
      );
      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Home'), findsOneWidget);
    },
  );

  testWidgets('navigating to /settings keeps rail unselected and renders', (
    tester,
  ) async {
    await pumpShell(tester);

    router.go('/settings');
    await tester.pumpAndSettle();

    expect(rail(tester).selectedIndex, isNull);
    expect(find.text('Settings'), findsWidgets);
  });

  testWidgets('tapping bottom settings entry navigates to /settings', (
    tester,
  ) async {
    await pumpShell(tester);

    await tester.tap(find.byIcon(Icons.settings));
    await tester.pumpAndSettle();

    expect(rail(tester).selectedIndex, isNull);
    expect(find.text('Settings'), findsWidgets);
  });

  testWidgets('navigating to /contacts selects contacts destination', (
    tester,
  ) async {
    await pumpShell(tester);

    router.go('/contacts');
    await tester.pumpAndSettle();

    expect(rail(tester).selectedIndex, 1);
  });

  testWidgets('navigating to /trash selects trash destination', (tester) async {
    await pumpShell(tester);

    router.go('/trash');
    await tester.pumpAndSettle();

    expect(rail(tester).selectedIndex, 2);
    expect(find.text('Trash'), findsWidgets);
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

    // The shortcut pushes the shared search page (same flow as the button).
    expect(find.text('Search'), findsOneWidget);
  });

  testWidgets('programmatic push renders the search page', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpShell(tester);

    router.push('/search');
    await tester.pumpAndSettle();

    expect(find.text('Search'), findsOneWidget);
  });

  testWidgets('mobile layout shows bottom NavigationBar instead of rail', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router,
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
  });

  testWidgets('mobile compact mode NavigationBar hides labels (icons only)', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(500, 400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router,
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    );
    await tester.pumpAndSettle();

    final navBar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(navBar.destinations.length, 4);
    expect(navBar.labelBehavior, NavigationDestinationLabelBehavior.alwaysHide);
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('landscape phone (872x390): mobile branch active, compact '
      'NavigationBar', (tester) async {
    tester.view.physicalSize = const Size(872, 390);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router,
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    );
    await tester.pumpAndSettle();

    // Mobile branch (width < kDesktopBreakpoint) → bottom NavigationBar,
    // not the desktop rail.
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);

    // Compact (height < kCompactHeightLimit) → labels hidden, short height.
    final navBar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(navBar.labelBehavior, NavigationDestinationLabelBehavior.alwaysHide);
    expect(navBar.height, lessThanOrEqualTo(64));
  });
}
