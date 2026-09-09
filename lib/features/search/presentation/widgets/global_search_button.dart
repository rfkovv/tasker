import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../l10n/app_localizations.dart';

/// The app's single shared search entry point. Opens the global search
/// overlay; placement is up to the top bar of whichever screen hosts it.
class GlobalSearchButton extends StatelessWidget {
  const GlobalSearchButton({super.key, this.onOpen});

  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return IconButton(
      key: const Key('global-search-button'),
      icon: const Icon(Icons.search),
      tooltip: l10n.search,
      onPressed: () {
        onOpen?.call();
        if (onOpen == null) {
          context.push('/search');
        }
      },
    );
  }
}