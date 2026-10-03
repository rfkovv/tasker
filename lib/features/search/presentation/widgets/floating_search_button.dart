import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'global_search_button.dart';

/// Floating circular search trigger for compact mode (design decision 2b).
///
/// Anchored top-end of the hosting content area by the enclosing [Stack]
/// (this widget returns a [Positioned.fill] + top-end alignment). Inside
/// [SafeArea] with a 12 dp margin, ≥ 48 dp touch target. Opens the SAME
/// shared search overlay as [GlobalSearchButton] — never a forked UI.
///
/// Hidden while the search overlay route (`/search`) is open.
class FloatingSearchButton extends StatelessWidget {
  const FloatingSearchButton({super.key, this.margin = 12});

  /// Margin from the safe-area edge to the button.
  final double margin;

  @override
  Widget build(BuildContext context) {
    final router = GoRouter.maybeOf(context);

    final trigger = Material(
      key: const Key('floating-search-button'),
      color: Theme.of(context).colorScheme.surfaceContainerHighest
          .withValues(alpha: 0.85),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: const GlobalSearchButton(),
    );

    Widget child = trigger;
    if (router != null) {
      child = ListenableBuilder(
        // routerDelegate notifies on both push and pop; routeInformation-
        // provider does not reliably update on pop within a ShellRoute.
        listenable: router.routerDelegate,
        builder: (context, _) {
          if (router.state.uri.path == '/search') {
            return const SizedBox.shrink();
          }
          return trigger;
        },
      );
    }

    return Positioned.fill(
      child: Align(
        alignment: AlignmentDirectional.topEnd,
        child: SafeArea(
          top: true,
          right: true,
          bottom: false,
          left: false,
          child: Padding(padding: EdgeInsets.all(margin), child: child),
        ),
      ),
    );
  }
}
