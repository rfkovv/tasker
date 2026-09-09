import 'package:flutter/material.dart';

import '../../domain/task.dart';

/// Floating visual shown while a task is being dragged (from the backlog
/// list or between calendar days). Kept intentionally small.
class TaskDragFeedback extends StatelessWidget {
  const TaskDragFeedback({super.key, required this.task});

  final Task task;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      elevation: 6,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 240),
          child: Text(
            task.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}