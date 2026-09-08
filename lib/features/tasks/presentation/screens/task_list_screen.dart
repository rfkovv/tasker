import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../contacts/contacts.dart' as contacts_feature;
import '../../../../l10n/app_localizations.dart';

import '../../data/task_repository_provider.dart';
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
          Expanded(
            child: Row(
              children: [
                const _FilterSidebar(),
                const VerticalDivider(width: 1),
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
                                  onTap: () =>
                                      widget.onOpenTask?.call(task.id),
                                  onToggleDone: (done) async {
                                    final repo =
                                        ref.read(taskRepositoryProvider);
                                    await repo.updateStatus(
                                      task.id,
                                      done
                                          ? TaskStatus.done
                                          : TaskStatus.todo,
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
                                onPressed:
                                    _showFab ? _handleAddTask : null,
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
                        AppLocalizations.of(context).errorWithValue(
                          e.toString(),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
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

class _FilterSidebar extends ConsumerWidget {
  const _FilterSidebar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(taskFilterStateProvider);

    return SizedBox(
      width: 240,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppLocalizations.of(context).filters,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              Text(
                AppLocalizations.of(context).filterStatus,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final status in [null, ...TaskStatus.values])
                    ChoiceChip(
                      label: Text(
                        status == null
                            ? AppLocalizations.of(context).filterAll
                            : taskStatusLabel(context, status),
                      ),
                      selected: filter.status == status,
                      onSelected: (_) {
                        ref.read(taskFilterStateProvider.notifier).setFilter(
                              filter.copyWith(
                                status:
                                    filter.status == status ? null : status,
                              ),
                            );
                      },
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                AppLocalizations.of(context).filterPriority,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final priority in [null, ...TaskPriority.values])
                    ChoiceChip(
                      label: Text(
                        priority == null
                            ? AppLocalizations.of(context).filterAll
                            : taskPriorityLabel(context, priority),
                      ),
                      selected: filter.priority == priority,
                      onSelected: (_) {
                        ref.read(taskFilterStateProvider.notifier).setFilter(
                              filter.copyWith(
                                priority: filter.priority == priority
                                    ? null
                                    : priority,
                              ),
                            );
                      },
                    ),
                ],
              ),
              if (filter != TaskFilter.none) ...[
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () {
                    ref
                        .read(taskFilterStateProvider.notifier)
                        .setFilter(TaskFilter.none);
                  },
                  child: Text(AppLocalizations.of(context).resetFilters),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
