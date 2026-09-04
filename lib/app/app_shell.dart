import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  int _selectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    if (location.startsWith('/contacts')) return 1;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 900;
        if (isDesktop) {
          return _DesktopShell(
            selectedIndex: _selectedIndex(context),
            child: child,
          );
        }
        return _MobileShell(
          selectedIndex: _selectedIndex(context),
          child: child,
        );
      },
    );
  }
}

class _DesktopShell extends StatelessWidget {
  const _DesktopShell({required this.selectedIndex, required this.child});

  final int selectedIndex;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: selectedIndex,
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.checklist),
                selectedIcon: Icon(Icons.checklist),
                label: Text('Tasks'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.contacts),
                selectedIcon: Icon(Icons.contacts),
                label: Text('Contacts'),
              ),
            ],
            onDestinationSelected: (index) {
              switch (index) {
                case 0:
                  context.go('/');
                case 1:
                  context.go('/contacts');
              }
            },
          ),
          const VerticalDivider(width: 1),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _MobileShell extends StatelessWidget {
  const _MobileShell({required this.selectedIndex, required this.child});

  final int selectedIndex;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.checklist),
            label: 'Tasks',
          ),
          NavigationDestination(
            icon: Icon(Icons.contacts),
            label: 'Contacts',
          ),
        ],
        onDestinationSelected: (index) {
          switch (index) {
            case 0:
              context.go('/');
            case 1:
              context.go('/contacts');
          }
        },
      ),
    );
  }
}
