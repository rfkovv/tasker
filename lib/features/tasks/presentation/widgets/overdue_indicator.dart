import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';

import '../../domain/task.dart';

class OverdueIndicator extends StatelessWidget {
  const OverdueIndicator({super.key, required this.task});

  final Task task;

  @override
  Widget build(BuildContext context) {
    if (!task.isOverdue) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.warning_amber_rounded, size: 16, color: scheme.error),
        const SizedBox(width: 4),
        Text(
          AppLocalizations.of(context).overdue,
          style: Theme.of(context)
              .textTheme
              .labelSmall
              ?.copyWith(color: scheme.error, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
