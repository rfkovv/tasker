import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/app_shell.dart' show isCompactMode, isMobileLayout;
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/destination_header.dart';
import '../../../contacts/domain/contact.dart';
import '../../../tasks/domain/task.dart';
import '../../data/trash_repository_provider.dart';
import '../providers/trash_list_provider.dart';

/// Kosz — the recoverable-deletion destination.
///
/// Header hierarchy per ARCHITECTURE.md: title "Kosz" on top, toolbar
/// below with segmented Zadania|Kontakty + "Opróżnij kosz" button.
/// NO search trigger (trash is not searchable in MVP).
/// Portrait scroll-hide, desktop static, compact — same rules as every
/// destination.
class TrashScreen extends ConsumerWidget {
  const TrashScreen({super.key});

  Future<void> _confirmEmptyTrash(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.emptyTrashConfirmTitle),
        content: Text(l10n.emptyTrashConfirmMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(trashRepositoryProvider).emptyTrash();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final compact = isCompactMode(context);
    final showContactsTab = ref.watch(trashTabProvider);
    final tasksAsync = ref.watch(deletedTasksProvider);
    final contactsAsync = ref.watch(deletedContactsProvider);
    final tasks = tasksAsync.value ?? const <Task>[];
    final contacts = contactsAsync.value ?? const <Contact>[];
    final hasAny = tasks.isNotEmpty || contacts.isNotEmpty;

    return Scaffold(
      body: DestinationBody(
        title: l10n.trash,
        showTitle: !compact,
        hideOnScroll: isMobileLayout(context),
        toolbar: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            key: const Key('mobile-toolbar'),
            children: [
              Expanded(
                child: SegmentedButton<bool>(
                  showSelectedIcon: false,
                  segments: [
                    ButtonSegment(value: false, label: Text(l10n.tasks)),
                    ButtonSegment(value: true, label: Text(l10n.contacts)),
                  ],
                  selected: {showContactsTab},
                  onSelectionChanged: (selection) => ref
                      .read(trashTabProvider.notifier)
                      .setContacts(selection.first),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: hasAny
                    ? () => _confirmEmptyTrash(context, ref)
                    : null,
                icon: const Icon(Icons.delete_sweep_outlined),
                label: Text(l10n.emptyTrash),
              ),
            ],
          ),
        ),
        child: showContactsTab
            ? contactsAsync.when(
                data: (items) => items.isEmpty
                    ? _TrashEmptyState(
                        icon: Icons.contacts,
                        title: l10n.trashEmptyContacts,
                        hint: l10n.trashEmptyContactsHint,
                      )
                    : _ContactTrashList(contacts: items),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) =>
                    Center(child: Text(l10n.errorWithValue(e.toString()))),
              )
            : tasksAsync.when(
                data: (items) => items.isEmpty
                    ? _TrashEmptyState(
                        icon: Icons.checklist,
                        title: l10n.trashEmptyTasks,
                        hint: l10n.trashEmptyTasksHint,
                      )
                    : _TaskTrashList(tasks: items),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) =>
                    Center(child: Text(l10n.errorWithValue(e.toString()))),
              ),
      ),
    );
  }
}

class _TaskTrashList extends ConsumerWidget {
  const _TaskTrashList({required this.tasks});

  final List<Task> tasks;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: tasks.length,
      itemBuilder: (context, index) {
        final task = tasks[index];
        return ListTile(
          leading: Icon(Icons.checklist, color: theme.colorScheme.outline),
          title: Text(task.title, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: task.deletedAt != null
              ? Text(
                  l10n.delete,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                )
              : null,
          trailing: IconButton(
            key: Key('restore-${task.id}'),
            tooltip: l10n.restore,
            icon: const Icon(Icons.restore),
            onPressed: () =>
                ref.read(trashRepositoryProvider).restoreTask(task.id),
          ),
        );
      },
    );
  }
}

class _ContactTrashList extends ConsumerWidget {
  const _ContactTrashList({required this.contacts});

  final List<Contact> contacts;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: contacts.length,
      itemBuilder: (context, index) {
        final contact = contacts[index];
        return ListTile(
          leading: Icon(Icons.contacts, color: theme.colorScheme.outline),
          title: Text(
            contact.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: (contact.role?.isNotEmpty ?? false)
              ? Text(
                  contact.role!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                )
              : null,
          trailing: IconButton(
            key: Key('restore-${contact.id}'),
            tooltip: l10n.restore,
            icon: const Icon(Icons.restore),
            onPressed: () =>
                ref.read(trashRepositoryProvider).restoreContact(contact.id),
          ),
        );
      },
    );
  }
}

class _TrashEmptyState extends StatelessWidget {
  const _TrashEmptyState({
    required this.icon,
    required this.title,
    required this.hint,
  });

  final IconData icon;
  final String title;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 64, color: theme.colorScheme.outline),
          const SizedBox(height: 16),
          Text(title, style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            hint,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }
}
