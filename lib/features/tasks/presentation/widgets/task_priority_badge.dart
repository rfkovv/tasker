import 'package:flutter/material.dart';

import '../../domain/task_priority.dart';

class TaskPriorityBadge extends StatelessWidget {
  const TaskPriorityBadge({super.key, required this.priority});

  final TaskPriority priority;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (color, label) = switch (priority) {
      TaskPriority.low => (scheme.outline, 'Low'),
      TaskPriority.medium => (scheme.tertiary, 'Medium'),
      TaskPriority.high => (scheme.errorContainer, 'High'),
      TaskPriority.urgent => (scheme.error, 'Urgent'),
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
