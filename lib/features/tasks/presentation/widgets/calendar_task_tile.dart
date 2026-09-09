import 'package:flutter/material.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../domain/task.dart';
import 'task_drag_feedback.dart';

/// Compact task representation on a calendar day: time + title. Reuses the
/// task tile's visual conventions for overdue (error colors) and done
/// (strikethrough) instead of duplicating [TaskTile].
class CalendarTaskTile extends StatelessWidget {
  const CalendarTaskTile({
    super.key,
    required this.task,
    required this.zone,
    this.onTap,
  });

  final Task task;
  final tz.Location zone;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final due = task.dueDate!;
    final local = tz.TZDateTime.from(due, zone);
    final overdue = task.isOverdue;

    final background = overdue
        ? scheme.errorContainer.withValues(alpha: 0.45)
        : scheme.surfaceContainerHighest.withValues(alpha: 0.7);
    final foreground = task.isDone
        ? scheme.outline
        : (overdue ? scheme.error : scheme.onSurface);

    return Material(
      color: background,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Row(
            children: [
              if (overdue) ...[
                Icon(Icons.warning_amber_rounded, size: 12, color: scheme.error),
                const SizedBox(width: 3),
              ],
              Text(
                '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: foreground,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  task.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: foreground,
                    decoration:
                        task.isDone ? TextDecoration.lineThrough : null,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Makes [child] long-press draggable, producing [TaskDragFeedback] while
/// dragging. Shared source wrapper for backlog tiles and calendar chips.
class DraggableTask extends StatelessWidget {
  const DraggableTask({super.key, required this.task, required this.child});

  final Task task;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LongPressDraggable<Task>(
      data: task,
      feedback: TaskDragFeedback(task: task),
      childWhenDragging: Opacity(opacity: 0.4, child: child),
      child: child,
    );
  }
}