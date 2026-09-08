import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../contacts/contacts.dart' as contacts_feature;
import '../../../../l10n/app_localizations.dart';

import '../../data/task_repository_provider.dart';
import '../../domain/task.dart';
import '../../domain/task_filter.dart';
import '../../domain/task_priority.dart';
import '../../domain/task_status.dart';
import '../providers/task_contacts_by_task_provider.dart';
import '../providers/task_list_provider.dart';
import '../widgets/task_priority_badge.dart';
import '../widgets/task_tile.dart';

String taskStatusLabel(BuildContext context, TaskStatus status) {
  final l10n = AppLocalizations.of(context);
  return switch (status) {
    TaskStatus.todo => l10n.statusTodo,
    TaskStatus.inProgress => l10n.statusInProgress,
    TaskStatus.done => l10n.statusDone,
  };
}

class TaskListScreen extends ConsumerStatefulWidget {
  const TaskListScreen({super.key, this.onOpenTask});

  final ValueChanged<String>? onOpenTask;

  @override
  ConsumerState<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends ConsumerState<TaskListScreen> {
  bool _showFab = false;

  void _handleAddTask() => widget.onOpenTask?.call('new');

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(taskFilterStateProvider);
    final tasksAsync = ref.watch(taskListProvider(filter));
    final contactsAsync = ref.watch(taskContactsByTaskProvider(filter));
    final contactsByTask =
        contactsAsync.value ?? const <String, List<contacts_feature.Contact>>{};

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).tasks),
      ),
      body: Column(
        children: [
          const _FilterBar(),
          const Divider(height: 1),
          Expanded(
            child: tasksAsync.when(
              data: (tasks) => Stack(
                children: [
                  Positioned.fill(
                    child: NotificationListener<ScrollMetricsNotification>(
                      onNotification: (notification) {
                        final scrollable =
                            notification.metrics.maxScrollExtent > 0;
                        if (scrollable != _showFab && mounted) {
                          setState(() => _showFab = scrollable);
                        }
                        return false;
                      },
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: tasks.isEmpty ? 2 : tasks.length + 1,
                        itemBuilder: (context, index) {
                          if (tasks.isEmpty) {
                            if (index == 0) {
                              return const Padding(
                                padding: EdgeInsets.all(32),
                                child: _EmptyState(),
                              );
                            }
                            return _FooterTile(
                              onAddTask: _handleAddTask,
                            );
                          }
                          if (index == tasks.length) {
                            return _FooterTile(
                              onAddTask: _handleAddTask,
                            );
                          }
                          final task = tasks[index];
                          final links =
                              contactsByTask[task.id] ??
                                  const <contacts_feature.Contact>[];
                          return TaskTile(
                            task: task,
                            contacts: links,
                            onTap: () => widget.onOpenTask?.call(task.id),
                            onToggleDone: (done) async {
                              final repo = ref.read(taskRepositoryProvider);
                              await repo.updateStatus(
                                task.id,
                                done ? TaskStatus.done : TaskStatus.todo,
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ),
                  if (tasks.isNotEmpty)
                    Positioned(
                      right: 16,
                      bottom: 16,
                      child: AnimatedOpacity(
                        opacity: _showFab ? 1 : 0,
                        duration: const Duration(milliseconds: 150),
                        child: FloatingActionButton.small(
                          onPressed: _showFab ? _handleAddTask : null,
                          child: const Icon(Icons.add_task),
                        ),
                      ),
                    ),
                ],
              ),
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Text(
                  AppLocalizations.of(context).errorWithValue(e.toString()),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FooterTile extends StatelessWidget {
  const _FooterTile({required this.onAddTask});

  final VoidCallback onAddTask;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
      child: Card(
        margin: EdgeInsets.zero,
        child: ListTile(
          leading: Icon(Icons.add_task, color: theme.colorScheme.primary),
          title: Text(AppLocalizations.of(context).addTask),
          onTap: onAddTask,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.checklist,
            size: 64,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            AppLocalizations.of(context).noTasksYet,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            AppLocalizations.of(context).noTasksHint,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
          ),
        ],
      ),
    );
  }
}

sealed class _FilterOption {
  const _FilterOption();
}

final class _StatusFilterOption extends _FilterOption {
  const _StatusFilterOption(this.status);

  final TaskStatus? status;
}

final class _PriorityFilterOption extends _FilterOption {
  const _PriorityFilterOption(this.priority);

  final TaskPriority? priority;
}

final class _TagFilterOption extends _FilterOption {
  const _TagFilterOption(this.tag);

  final String tag;
}

final class _HideDoneFilterOption extends _FilterOption {
  const _HideDoneFilterOption();
}

final class _ResetFilterOption extends _FilterOption {
  const _ResetFilterOption();
}

class _FilterBar extends ConsumerWidget {
  const _FilterBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final filter = ref.watch(taskFilterStateProvider);
    final allTasks = ref.watch(taskListProvider(TaskFilter.none)).value ??
        const <Task>[];
    final tags = (allTasks.expand((task) => task.tags)).toSet().toList()
      ..sort();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Builder(
            builder: (buttonContext) => OutlinedButton.icon(
              onPressed: () =>
                  _openFilterMenu(buttonContext, ref, filter, tags),
              icon: const Icon(Icons.filter_alt_outlined),
              label: Text(l10n.filter),
            ),
          ),
          if (filter != TaskFilter.none) ...[
            const SizedBox(width: 12),
            Expanded(
              child: Chip(
                avatar: const Icon(Icons.check, size: 16),
                label: Text(_filterSummary(context, filter)),
                visualDensity: VisualDensity.compact,
                onDeleted: () => ref
                    .read(taskFilterStateProvider.notifier)
                    .setFilter(TaskFilter.none),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

Future<void> _openFilterMenu(
  BuildContext context,
  WidgetRef ref,
  TaskFilter filter,
  List<String> tags,
) async {
  final l10n = AppLocalizations.of(context);
  final sectionStyle = Theme.of(context).textTheme.labelSmall;

  final items = <PopupMenuEntry<_FilterOption>>[
    PopupMenuItem(
      enabled: false,
      child: Text(l10n.filterStatus, style: sectionStyle),
    ),
    for (final status in [null, ...TaskStatus.values])
      PopupMenuItem(
        value: _StatusFilterOption(status),
        child: _MenuValueRow(
          selected: filter.status == status,
          label: status == null
              ? l10n.filterAll
              : taskStatusLabel(context, status),
        ),
      ),
    PopupMenuItem(
      enabled: false,
      child: Text(l10n.filterPriority, style: sectionStyle),
    ),
    for (final priority in [null, ...TaskPriority.values])
      PopupMenuItem(
        value: _PriorityFilterOption(priority),
        child: _MenuValueRow(
          selected: filter.priority == priority,
          label: priority == null
              ? l10n.filterAll
              : taskPriorityLabel(context, priority),
        ),
      ),
    PopupMenuItem(
      enabled: false,
      child: Text(l10n.filterTags, style: sectionStyle),
    ),
    if (tags.isEmpty)
      PopupMenuItem(enabled: false, child: Text(l10n.noTags))
    else
      for (final tag in tags)
        PopupMenuItem(
          value: _TagFilterOption(tag),
          child: _MenuValueRow(
            selected: filter.tag == tag,
            label: '#$tag',
          ),
        ),
    const PopupMenuDivider(),
    PopupMenuItem(
      value: const _HideDoneFilterOption(),
      child: _MenuValueRow(
        selected: filter.hideDone,
        label: l10n.hideDone,
      ),
    ),
    if (filter != TaskFilter.none) ...[
      const PopupMenuDivider(),
      PopupMenuItem(
        value: const _ResetFilterOption(),
        child: Text(l10n.resetFilters),
      ),
    ],
  ];

  final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
  final box = context.findRenderObject() as RenderBox;
  final option = await showMenu<_FilterOption>(
    context: context,
    position: RelativeRect.fromRect(
      Rect.fromPoints(
        box.localToGlobal(Offset.zero, ancestor: overlay),
        box.localToGlobal(
          box.size.bottomRight(Offset.zero),
          ancestor: overlay,
        ),
      ),
      Offset.zero & overlay.size,
    ),
    items: items,
  );
  if (option != null) {
    _applyFilter(ref, option);
  }
}

void _applyFilter(WidgetRef ref, _FilterOption option) {
  final notifier = ref.read(taskFilterStateProvider.notifier);
  final filter = ref.read(taskFilterStateProvider);
  switch (option) {
    case _StatusFilterOption(:final status):
      notifier.setFilter(
        filter.copyWith(status: filter.status == status ? null : status),
      );
    case _PriorityFilterOption(:final priority):
      notifier.setFilter(
        filter.copyWith(
          priority: filter.priority == priority ? null : priority,
        ),
      );
    case _TagFilterOption(:final tag):
      notifier.setFilter(
        filter.copyWith(tag: filter.tag == tag ? null : tag),
      );
    case _HideDoneFilterOption():
      notifier.setFilter(filter.copyWith(hideDone: !filter.hideDone));
    case _ResetFilterOption():
      notifier.setFilter(TaskFilter.none);
  }
}

String _filterSummary(BuildContext context, TaskFilter filter) {
  final l10n = AppLocalizations.of(context);
  final parts = <String>[
    if (filter.status != null) taskStatusLabel(context, filter.status!),
    if (filter.priority != null) taskPriorityLabel(context, filter.priority!),
    if (filter.tag != null) '#${filter.tag}',
    if (filter.hideDone) l10n.hideDone,
  ];
  return parts.join(' · ');
}

class _MenuValueRow extends StatelessWidget {
  const _MenuValueRow({required this.selected, required this.label});

  final bool selected;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.check,
          size: 18,
          color: selected
              ? Theme.of(context).colorScheme.primary
              : Colors.transparent,
        ),
        const SizedBox(width: 8),
        Text(label),
      ],
    );
  }
}
