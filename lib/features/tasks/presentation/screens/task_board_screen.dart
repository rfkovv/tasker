import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/app_shell.dart' show isCompactMode;
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/hide_on_scroll_header.dart';
import '../../../settings/settings.dart' as settings_feature;
import '../../../search/search.dart' show FloatingSearchButton;
import '../../data/task_repository_provider.dart';
import '../../domain/scheduling.dart';
import '../../domain/task.dart';
import '../../domain/task_filter.dart';
import '../providers/task_list_provider.dart';
import '../widgets/calendar_pane.dart';
import '../widgets/task_filter_bar.dart';
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
                        task.copyWith(dueDate: null, updatedAt: DateTime.now()),
                      ),
                );
              },
              builder: (context, candidates, _) {
                return Container(
                  color: candidates.isNotEmpty
                      ? Theme.of(context).colorScheme.secondaryContainer
                            .withValues(alpha: 0.25)
                      : null,
                  child: TaskListScreen(onOpenTask: onOpenTask),
                );
              },
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(flex: 4, child: CalendarPane(onOpenTask: onOpenTask)),
        ],
      ),
    );
  }
}

/// Narrow layout: segmented control [List | Calendar] with one view at a time.
class _NarrowLayout extends StatefulWidget {
  const _NarrowLayout({
    required this.onOpenTask,
    required this.showCalendar,
    required this.onToggleView,
  });

  final ValueChanged<String>? onOpenTask;
  final bool showCalendar;
  final ValueChanged<bool> onToggleView;

  @override
  State<_NarrowLayout> createState() => _NarrowLayoutState();
}

class _NarrowLayoutState extends State<_NarrowLayout> {
  Task? _schedulingTask;

  void _onTaskTap(Task task) {
    setState(() {
      if (_schedulingTask?.id == task.id) {
        _schedulingTask = null; // toggle off
      } else {
        _schedulingTask = task;
      }
    });
  }

  void _onTapDay(DateTime day) {
    final task = _schedulingTask;
    if (task == null) return;
    final container = ProviderScope.containerOf(context);
    final zone = container.read(settings_feature.selectedTimeZoneProvider);
    final dueTime = container.read(settings_feature.defaultDueTimeProvider);
    final newDue = movedDueDate(
      task: task,
      day: day,
      zone: zone,
      defaultDueTime: DueTime(hour: dueTime.hour, minute: dueTime.minute),
    );
    if (task.dueDate == newDue) return;
    unawaited(
      container
          .read(taskRepositoryProvider)
          .update(task.copyWith(dueDate: newDue, updatedAt: DateTime.now())),
    );
    setState(() => _schedulingTask = null);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final compact = isCompactMode(context);
    return Scaffold(
      body: HideOnScrollHeader(
        // Unified mobile toolbar: Lista|Kalendarz segmented control AND
        // Filtruj (+ active badge) in ONE row. Hides on scroll down,
        // reappears on scroll up (shared HideOnScrollHeader).
        header: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                key: const Key('mobile-toolbar'),
                children: [
                  Expanded(
                    child: SegmentedButton<bool>(
                      showSelectedIcon: false,
                      segments: [
                        ButtonSegment(value: false, label: Text(l10n.tabList)),
                        ButtonSegment(
                          value: true,
                          label: Text(l10n.tabCalendar),
                        ),
                      ],
                      selected: {widget.showCalendar},
                      onSelectionChanged: (selection) =>
                          widget.onToggleView(selection.first),
                    ),
                  ),
                  const SizedBox(width: 12),
                  TaskFilterBar(padding: EdgeInsets.zero, embedded: true),
                ],
              ),
            ),
            const Divider(height: 1),
          ],
        ),
        child: Column(
          children: [
            if (_schedulingTask != null)
              Material(
                color: Theme.of(context).colorScheme.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.event,
                        size: 20,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l10n.tapToScheduleHint,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                      TextButton(
                        onPressed: () => setState(() => _schedulingTask = null),
                        child: Text(l10n.cancelSchedule),
                      ),
                    ],
                  ),
                ),
              ),
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: widget.showCalendar
                        ? CalendarPane(
                            onOpenTask: widget.onOpenTask,
                            onTaskTap: _onTaskTap,
                            onTapDay: _schedulingTask != null
                                ? _onTapDay
                                : null,
                          )
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
                                child: TaskListScreen(
                                  onOpenTask: widget.onOpenTask,
                                  // Filter controls live in the unified
                                  // mobile toolbar above, not inside the list.
                                  showFilterBar: false,
                                ),
                              );
                            },
                          ),
                  ),
                  if (compact) const FloatingSearchButton(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
