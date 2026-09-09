import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/task_repository_provider.dart';
import '../../domain/task.dart';
import '../widgets/calendar_pane.dart';
import 'task_list_screen.dart';

/// Two-pane tasks screen: the existing task list (backlog) on the left and
/// the calendar grid on the right. Dragging a scheduled tile onto the list
/// clears its due date.
class TaskBoardScreen extends ConsumerWidget {
  const TaskBoardScreen({super.key, this.onOpenTask});

  final ValueChanged<String>? onOpenTask;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                    onOpenTask: onOpenTask,
                  ),
                );
              },
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(
            flex: 4,
            child: CalendarPane(onOpenTask: onOpenTask),
          ),
        ],
      ),
    );
  }
}