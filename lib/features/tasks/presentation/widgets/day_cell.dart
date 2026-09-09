import 'package:flutter/material.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../domain/task.dart';
import 'calendar_task_tile.dart';

/// A single calendar day cell: a drop target for [Task]s plus the tasks
/// scheduled on that day.
class DayCell extends StatelessWidget {
  const DayCell({
    super.key,
    required this.day,
    required this.tasks,
    required this.zone,
    required this.isCurrentMonth,
    required this.isToday,
    required this.onDropTask,
    this.onTapTask,
  });

  /// Date-only `DateTime` identifying this cell in the display zone.
  final DateTime day;

  final List<Task> tasks;
  final tz.Location zone;
  final bool isCurrentMonth;
  final bool isToday;

  /// Called when a task is dropped on this cell.
  final ValueChanged<Task> onDropTask;
  final ValueChanged<String>? onTapTask;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dayNumberStyle =
        Theme.of(context).textTheme.labelSmall?.copyWith(
              color: isCurrentMonth
                  ? (isToday ? scheme.onPrimary : scheme.onSurfaceVariant)
                  : scheme.outlineVariant,
              fontWeight: isToday ? FontWeight.w800 : null,
            );

    final highlighted = isCurrentMonth && isToday;

    return DragTarget<Task>(
      onWillAcceptWithDetails: (_) => true,
      onAcceptWithDetails: (details) => onDropTask(details.data),
      builder: (context, candidates, _) {
        final isCandidate = candidates.isNotEmpty;
        return Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: isCandidate
                  ? scheme.primary
                  : scheme.outlineVariant.withValues(alpha: 0.5),
              width: isCandidate ? 2 : 1,
            ),
            color: highlighted
                ? scheme.primaryContainer.withValues(alpha: 0.4)
                : null,
          ),
          padding: const EdgeInsets.all(2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: CircleAvatar(
                  radius: 10,
                  backgroundColor:
                      highlighted ? scheme.primary : Colors.transparent,
                  child: Text('${day.day}', style: dayNumberStyle),
                ),
              ),
              const SizedBox(height: 2),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    for (final task in tasks)
                      DraggableTask(
                        task: task,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: CalendarTaskTile(
                            task: task,
                            zone: zone,
                            onTap: onTapTask == null
                                ? null
                                : () => onTapTask!(task.id),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}