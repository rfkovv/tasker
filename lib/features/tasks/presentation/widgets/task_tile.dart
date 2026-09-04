import 'package:flutter/material.dart';

import '../../../contacts/contacts.dart' as contacts_feature;

import '../../domain/task.dart';
import 'overdue_indicator.dart';
import 'task_priority_badge.dart';

class TaskTile extends StatelessWidget {
  const TaskTile({
    super.key,
    required this.task,
    this.contacts = const [],
    this.onTap,
    this.onToggleDone,
  });

  final Task task;
  final List<contacts_feature.Contact> contacts;
  final VoidCallback? onTap;
  final ValueChanged<bool>? onToggleDone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final titleStyle = task.isDone
        ? theme.textTheme.titleMedium?.copyWith(
            decoration: TextDecoration.lineThrough,
            color: theme.colorScheme.outline,
          )
        : theme.textTheme.titleMedium;

    final dueDateColor = task.isOverdue
        ? theme.colorScheme.error
        : theme.colorScheme.outline;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 16, 8),
          child: Row(
            children: [
              Checkbox(
                value: task.isDone,
                onChanged: onToggleDone == null
                    ? null
                    : (v) => onToggleDone!(v ?? false),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(task.title, style: titleStyle),
                    if (task.description?.isNotEmpty ?? false) ...[
                      const SizedBox(height: 4),
                      Text(
                        task.description!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                    ],
                    if (task.dueDate != null) ...[
                      const SizedBox(height: 6),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.calendar_today,
                              size: 14, color: dueDateColor),
                          const SizedBox(width: 4),
                          Text(
                            _formatDate(task.dueDate!),
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: dueDateColor,
                              fontWeight: task.isOverdue
                                  ? FontWeight.w600
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 8),
                          OverdueIndicator(task: task),
                        ],
                      ),
                    ],
                    if (task.tags.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: [
                          for (final tag in task.tags)
                            Chip(
                              label: Text(tag),
                              visualDensity: VisualDensity.compact,
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                            ),
                        ],
                      ),
                    ],
                    if (contacts.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Relevant Persons',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.outline,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: [
                          for (final contact in contacts)
                            Chip(
                              avatar: CircleAvatar(
                                child: Text(
                                  contact.name.isNotEmpty
                                      ? contact.name[0].toUpperCase()
                                      : '?',
                                ),
                              ),
                              label: Text(contact.name),
                              visualDensity: VisualDensity.compact,
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                            ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        TaskPriorityBadge(priority: task.priority),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: theme.colorScheme.outline,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final local = date.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(local.year, local.month, local.day);

    if (day == today) return 'Today';
    if (day == today.add(const Duration(days: 1))) return 'Tomorrow';

    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[local.month - 1]} ${local.day}';
  }
}
