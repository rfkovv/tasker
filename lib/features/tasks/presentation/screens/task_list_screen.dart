import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../contacts/contacts.dart' as contacts_feature;
import '../../../../app/app_shell.dart' show isCompactMode;
import '../../../../l10n/app_localizations.dart';
import '../../../search/search.dart' show GlobalSearchButton;

import '../../data/task_repository_provider.dart';
import '../../domain/subtask.dart';
import '../../domain/task_status.dart';
import '../providers/subtask_progress_by_task_provider.dart';
import '../providers/task_contacts_by_task_provider.dart';
import '../providers/task_list_provider.dart';
import '../widgets/calendar_task_tile.dart';
import '../widgets/task_filter_bar.dart';
import '../widgets/task_tile.dart';

class TaskListScreen extends ConsumerStatefulWidget {
  const TaskListScreen({super.key, this.onOpenTask, this.showFilterBar = true});

  final ValueChanged<String>? onOpenTask;

  /// When false, the filter bar is not rendered — the parent (unified
  /// mobile toolbar on the task board) owns the filter controls.
  /// Desktop / standalone usage keeps the default `true`.
  final bool showFilterBar;

  @override
  ConsumerState<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends ConsumerState<TaskListScreen> {
  final _scrollController = ScrollController();
  bool _showFab = false;
  bool _checkScheduled = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_updateFabVisibility);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _handleAddTask() => widget.onOpenTask?.call('new');

  void _scheduleScrollabilityCheck() {
    if (_checkScheduled) return;
    _checkScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkScheduled = false;
      _updateFabVisibility();
    });
  }

  void _updateFabVisibility() {
    if (!mounted) return;
    final scrollable =
        _scrollController.hasClients &&
        _scrollController.position.maxScrollExtent > 0;
    if (scrollable != _showFab) {
      setState(() => _showFab = scrollable);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(taskFilterStateProvider);
    final tasksAsync = ref.watch(taskListProvider(filter));
    final contactsAsync = ref.watch(taskContactsByTaskProvider(filter));
    final contactsByTask =
        contactsAsync.value ?? const <String, List<contacts_feature.Contact>>{};
    final subtaskProgressAsync = ref.watch(
      subtaskProgressByTaskProvider(filter),
    );
    final subtaskProgressByTask =
        subtaskProgressAsync.value ?? const <String, SubtaskProgress>{};

    final compact = isCompactMode(context);

    return Scaffold(
      appBar: compact
          ? null
          : AppBar(
              centerTitle: true,
              title: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      AppLocalizations.of(context).tasks,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const GlobalSearchButton(),
                ],
              ),
            ),
      body: Stack(
        children: [
          Column(
            children: [
              if (widget.showFilterBar) ...[
                const TaskFilterBar(),
                const Divider(height: 1),
              ],
              Expanded(
                child: tasksAsync.when(
                  data: (tasks) {
                    _scheduleScrollabilityCheck();
                    return Stack(
                      children: [
                        Positioned.fill(
                          child: ListView.builder(
                            controller: _scrollController,
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
                                return _FooterTile(onAddTask: _handleAddTask);
                              }
                              if (index == tasks.length) {
                                return _FooterTile(onAddTask: _handleAddTask);
                              }
                              final task = tasks[index];
                              final links =
                                  contactsByTask[task.id] ??
                                  const <contacts_feature.Contact>[];
                              final tile = TaskTile(
                                task: task,
                                contacts: links,
                                subtaskProgress: subtaskProgressByTask[task.id],
                                onTap: () => widget.onOpenTask?.call(task.id),
                                onToggleDone: (done) async {
                                  final repo = ref.read(taskRepositoryProvider);
                                  await repo.updateStatus(
                                    task.id,
                                    done ? TaskStatus.done : TaskStatus.todo,
                                  );
                                },
                              );
                              return DraggableTask(task: task, child: tile);
                            },
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
                    );
                  },
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
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: Theme.of(context).colorScheme.outline),
          ),
        ],
      ),
    );
  }
}
