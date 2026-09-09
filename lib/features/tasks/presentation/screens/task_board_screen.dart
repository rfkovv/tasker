import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/task_repository_provider.dart';
import '../../domain/task.dart';
import '../../domain/task_filter.dart';
import '../providers/task_list_provider.dart';
import '../widgets/calendar_pane.dart';
import 'task_list_screen.dart';

/// Two-pane tasks screen: the existing task list (backlog) on the left and
/// the calendar grid on the right. Dragging a scheduled tile onto the list
/// clears its due date.
class TaskBoardScreen extends ConsumerStatefulWidget {
  const TaskBoardScreen({super.key, this.onOpenTask, this.initialFilter});

  final ValueChanged<String>? onOpenTask;

  /// Applied ONCE after mount (then user adjustments win). Used by deep links
  /// from global search ("show all") and contact expansion ("see all tasks").
  final TaskFilter? initialFilter;

  @override
  ConsumerState<TaskBoardScreen> createState() => _TaskBoardScreenState();
}

class _TaskBoardScreenState extends ConsumerState<TaskBoardScreen> {
  bool _seedApplied = false;

  void _seedFilterOnce() {
    final seed = widget.initialFilter;
    if (seed == null || _seedApplied) return;
    _seedApplied = true;
    // Deferred past the frame: never mutate a provider during build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(taskFilterStateProvider.notifier).setFilter(seed);
    });
  }

  @override
  Widget build(BuildContext context) {
    _seedFilterOnce();
    return Scaffold(
      body: Row(
        children: [
          Expanded(
            flex: 5,
            child: DragTarget<Task>(
              onWillAcceptWithDetails: (details) =>
                  details.data.dueDate != null,
              onAcceptWithDetails: (details) {
                final task = details.data;
                if (task.dueDate == null) return;
                unawaited(
                  ref.read(taskRepositoryProvider).update(
                        task.copyWith(
                          dueDate: null,
                          updatedAt: DateTime.now(),
                        ),
                      ),
                );
              },
              builder: (context, candidates, _) {
                return Container(
                  color: candidates.isNotEmpty
                      ? Theme.of(context)
                          .colorScheme
                          .secondaryContainer
                          .withValues(alpha: 0.25)
                      : null,
                  child: TaskListScreen(
                    onOpenTask: widget.onOpenTask,
                  ),
                );
              },
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(
            flex: 4,
            child: CalendarPane(onOpenTask: widget.onOpenTask),
          ),
        ],
      ),
    );
  }
}