import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../data/active_tasks_for_contact_provider.dart';
import '../../domain/contact.dart';
import '../../domain/linked_task.dart';

/// Inline expansion shown when a contact tile is tapped: the contact's ACTIVE
/// linked tasks as mini tiles plus a "see all tasks" deep link that jumps to
/// the task list filtered by this contact.
class ContactExpansion extends ConsumerWidget {
  const ContactExpansion({
    super.key,
    required this.contact,
    required this.onSeeAllTasks,
    this.onOpenTask,
  });

  final Contact contact;

  /// Deep-link to the task list pre-filtered by [contact.id].
  final VoidCallback onSeeAllTasks;

  final ValueChanged<String>? onOpenTask;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final tasksAsync = ref.watch(activeTasksForContactProvider(contact.id));

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextButton.icon(
            onPressed: onSeeAllTasks,
            icon: const Icon(Icons.arrow_forward, size: 16),
            label: Text(
              l10n.contactSeeAllTasks,
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(height: 4),
          tasksAsync.when(
            data: (tasks) {
              if (tasks.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    l10n.contactNoActiveTasks,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                  ),
                );
              }
              return Column(
                children: [
                  for (final task in tasks)
                    _MiniTaskTile(
                      task: task,
                      onTap: () => onOpenTask?.call(task.id),
                    ),
                ],
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                AppLocalizations.of(context).errorWithValue(e.toString()),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniTaskTile extends StatelessWidget {
  const _MiniTaskTile({required this.task, required this.onTap});

  final LinkedTask task;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      dense: true,
      leading: const Icon(Icons.checklist, size: 18),
      title: Text(
        task.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: task.dueAt == null
          ? null
          : Text(
              _dueLabel(context, task.dueAt!),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
      onTap: onTap,
    );
  }

  String _dueLabel(BuildContext context, DateTime dueAt) {
    final local = dueAt.toLocal();
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')} $hh:$mm';
  }
}