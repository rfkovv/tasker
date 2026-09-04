import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/task_repository_provider.dart';
import '../../domain/task_filter.dart';
import '../../domain/task_priority.dart';
import '../../domain/task_status.dart';
import '../providers/task_list_provider.dart';
import '../widgets/task_tile.dart';

class TaskListScreen extends ConsumerWidget {
  const TaskListScreen({super.key, this.onOpenTask});

  final ValueChanged<String>? onOpenTask;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(taskListProvider(ref.watch(taskFilterStateProvider)));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tasks'),
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
                    data: (tasks) => tasks.isEmpty
                        ? const _EmptyState()
                        : ListView.builder(
                            padding: const EdgeInsets.only(bottom: 16),
                            itemCount: tasks.length,
                            itemBuilder: (context, index) {
                              final task = tasks[index];
                              return TaskTile(
                                task: task,
                                onTap: () => onOpenTask?.call(task.id),
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
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(child: Text('Error: $e')),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          _BottomBar(onAddTask: () => onOpenTask?.call('new')),
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
              Text('Filters', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 16),
              Text('Status', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final status in [null, ...TaskStatus.values])
                    ChoiceChip(
                      label: Text(status?.name ?? 'All'),
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
              Text('Priority', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final priority in [null, ...TaskPriority.values])
                    ChoiceChip(
                      label: Text(priority?.name ?? 'All'),
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
                  child: const Text('Reset filters'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.onAddTask});

  final VoidCallback onAddTask;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            FilledButton.icon(
              onPressed: onAddTask,
              icon: const Icon(Icons.add),
              label: const Text('Add Task'),
            ),
          ],
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
          Text('No tasks yet', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Tap "Add Task" to create your first task',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
          ),
        ],
      ),
    );
  }
}
