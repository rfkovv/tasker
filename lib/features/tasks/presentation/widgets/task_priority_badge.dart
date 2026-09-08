import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';

import '../../domain/task_priority.dart';

String taskPriorityLabel(BuildContext context, TaskPriority priority) {
  final l10n = AppLocalizations.of(context);
  return switch (priority) {
    TaskPriority.low => l10n.priorityLow,
    TaskPriority.medium => l10n.priorityMedium,
    TaskPriority.high => l10n.priorityHigh,
    TaskPriority.urgent => l10n.priorityUrgent,
  };
}

class TaskPriorityBadge extends StatelessWidget {
  const TaskPriorityBadge({super.key, required this.priority});

  final TaskPriority priority;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final label = taskPriorityLabel(context, priority);
    final color = switch (priority) {
      TaskPriority.low => scheme.outline,
      TaskPriority.medium => scheme.tertiary,
      TaskPriority.high => scheme.errorContainer,
      TaskPriority.urgent => scheme.error,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: Theme.of(context)
            .textTheme
            .labelSmall
            ?.copyWith(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}
