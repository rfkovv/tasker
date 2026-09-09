import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../l10n/app_localizations.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  int _selectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    if (location.startsWith('/settings')) return 2;
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
    final l10n = AppLocalizations.of(context);
    final railIndex = selectedIndex >= 2 ? null : selectedIndex;
    final isSettingsSelected = selectedIndex == 2;

    return _GlobalSearchShortcut(
      child: Scaffold(
        body: Row(
          children: [
            Column(
              children: [
                Expanded(
                  child: NavigationRail(
                    selectedIndex: railIndex,
                    destinations: [
                      NavigationRailDestination(
                        icon: const Icon(Icons.checklist),
                        selectedIcon: const Icon(Icons.checklist),
                        label: Text(l10n.tasks),
                      ),
                      NavigationRailDestination(
                        icon: const Icon(Icons.contacts),
                        selectedIcon: const Icon(Icons.contacts),
                        label: Text(l10n.contacts),
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
                ),
                const Divider(height: 1),
                _RailSettingsEntry(
                  selected: isSettingsSelected,
                  onTap: () => context.go('/settings'),
                ),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}

class _GlobalSearchShortcut extends StatefulWidget {
  const _GlobalSearchShortcut({required this.child});

  final Widget child;

  @override
  State<_GlobalSearchShortcut> createState() => _GlobalSearchShortcutState();
}

class _GlobalSearchShortcutState extends State<_GlobalSearchShortcut> {
  bool _onKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.keyK &&
        HardwareKeyboard.instance.isControlPressed) {
      final decorated = GoRouterState.of(context).uri.path == '/search';
      if (!decorated) {
        context.push('/search');
      }
      return true;
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onKeyEvent);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKeyEvent);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _RailSettingsEntry extends StatelessWidget {
  const _RailSettingsEntry({
    required this.selected,
    required this.onTap,
  });

  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final labelStyle = Theme.of(context).textTheme.labelMedium;
    final color = selected ? scheme.onSecondaryContainer : scheme.onSurfaceVariant;

    return Material(
      color: selected ? scheme.secondaryContainer : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.settings, color: color),
              const SizedBox(height: 4),
              Text(
                l10n.settings,
                style: labelStyle?.copyWith(color: color),
              ),
            ],
          ),
        ),
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
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.checklist),
            label: l10n.tasks,
          ),
          NavigationDestination(
            icon: const Icon(Icons.contacts),
            label: l10n.contacts,
          ),
          NavigationDestination(
            icon: const Icon(Icons.settings),
            label: l10n.settings,
          ),
        ],
        onDestinationSelected: (index) {
          switch (index) {
            case 0:
              context.go('/');
            case 1:
              context.go('/contacts');
            case 2:
              context.go('/settings');
          }
        },
      ),
    );
  }
}