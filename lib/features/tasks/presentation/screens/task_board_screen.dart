import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../data/task_repository_provider.dart';
import '../../domain/task.dart';
import '../../domain/task_filter.dart';
import '../providers/task_list_provider.dart';
import '../widgets/calendar_pane.dart';
import 'task_list_screen.dart';

/// Two-pane tasks screen: the existing task list (backlog) on the left and
/// the calendar grid on the right. Dragging a scheduled tile onto the list
/// clears its due date.
///
/// On narrow screens (< 1000 px) a segmented control replaces the two-pane
/// layout, showing exactly one view at a time.
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
  bool _showCalendar = false;

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
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 1000) {
          return _WideLayout(onOpenTask: widget.onOpenTask);
        }
        return _NarrowLayout(
          onOpenTask: widget.onOpenTask,
          showCalendar: _showCalendar,
          onToggleView: (showCal) => setState(() => _showCalendar = showCal),
        );
      },
    );
  }
}

/// Wide layout: unchanged two-pane side-by-side.
class _WideLayout extends StatelessWidget {
  const _WideLayout({required this.onOpenTask});

  final ValueChanged<String>? onOpenTask;

  @override
  Widget build(BuildContext context) {
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
                  ProviderScope.containerOf(context)
                      .read(taskRepositoryProvider)
                      .update(
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
                  child: TaskListScreen(onOpenTask: onOpenTask),
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

/// Narrow layout: segmented control [List | Calendar] with one view at a time.
class _NarrowLayout extends StatelessWidget {
  const _NarrowLayout({
    required this.onOpenTask,
    required this.showCalendar,
    required this.onToggleView,
  });

  final ValueChanged<String>? onOpenTask;
  final bool showCalendar;
  final ValueChanged<bool> onToggleView;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SegmentedButton<bool>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(
                  value: false,
                  label: Text(l10n.tabList),
                ),
                ButtonSegment(
                  value: true,
                  label: Text(l10n.tabCalendar),
                ),
              ],
              selected: {showCalendar},
              onSelectionChanged: (selection) =>
                  onToggleView(selection.first),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: showCalendar
                ? CalendarPane(onOpenTask: onOpenTask)
                : DragTarget<Task>(
                    onWillAcceptWithDetails: (details) =>
                        details.data.dueDate != null,
                    onAcceptWithDetails: (details) {
                      final task = details.data;
                      if (task.dueDate == null) return;
                      unawaited(
                        ProviderScope.containerOf(context)
                            .read(taskRepositoryProvider)
                            .update(
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
                        child: TaskListScreen(onOpenTask: onOpenTask),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}