import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../../../l10n/app_localizations.dart';
import '../../../settings/settings.dart' as settings_feature;

import '../../data/task_repository_provider.dart';
import '../../domain/calendar.dart';
import '../../domain/scheduling.dart';
import '../../domain/task.dart';
import '../../domain/task_filter.dart';
import '../providers/calendar_view_provider.dart';
import '../providers/task_list_provider.dart';
import 'day_cell.dart';

/// Right-hand pane of the tasks screen: a month/week/quarter calendar grid
/// with drag & drop scheduling. Shares the task list's providers and state.
class CalendarPane extends ConsumerWidget {
  const CalendarPane({super.key, this.onOpenTask});

  final ValueChanged<String>? onOpenTask;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(calendarViewProvider);
    final zone = ref.watch(settings_feature.selectedTimeZoneProvider);
    // The calendar always shows ALL scheduled tasks, independent of the
    // list pane's filter/sort selection. Filters only affect the list.
    final tasks =
        ref.watch(taskListProvider(TaskFilter.none)).value ?? const <Task>[];
    final byDay = tasksByLocalDay(tasks, zone);
    final today = localDay(DateTime.now(), zone);

    return Column(
      children: [
        _CalendarHeader(
          view: view,
          onPrevious: () =>
              ref.read(calendarViewProvider.notifier).previous(),
          onNext: () => ref.read(calendarViewProvider.notifier).next(),
          onToday: () => ref.read(calendarViewProvider.notifier).goToday(),
          onModeChanged: (mode) =>
              ref.read(calendarViewProvider.notifier).setMode(mode),
        ),
        const Divider(height: 1),
        Expanded(
          child: byDay.isEmpty
              ? _EmptyCalendarHint()
              : switch (view.mode) {
                  CalendarViewMode.month => _MonthGrid(
                      month: view.anchor,
                      byDay: byDay,
                      zone: zone,
                      today: today,
                      onDropTask: (day, task) =>
                          _dropOnDay(ref, day, task),
                      onOpenTask: (id) => onOpenTask?.call(id),
                    ),
                  CalendarViewMode.week => _WeekGrid(
                      day: view.anchor,
                      byDay: byDay,
                      zone: zone,
                      today: today,
                      onDropTask: (day, task) =>
                          _dropOnDay(ref, day, task),
                      onOpenTask: (id) => onOpenTask?.call(id),
                    ),
                  CalendarViewMode.quarter => _QuarterGrid(
                      anchor: view.anchor,
                      byDay: byDay,
                      zone: zone,
                      today: today,
                      onDropTask: (day, task) =>
                          _dropOnDay(ref, day, task),
                      onOpenTask: (id) => onOpenTask?.call(id),
                    ),
                },
        ),
      ],
    );
  }

  /// Persists a dropped task's new due date through the same repository
  /// update path the edit form uses.
  void _dropOnDay(WidgetRef ref, DateTime day, Task task) {
    final zone = ref.read(settings_feature.selectedTimeZoneProvider);
    final dueTime = ref.read(settings_feature.defaultDueTimeProvider);
    final currentDay =
        task.dueDate == null ? null : localDay(task.dueDate!, zone);
    if (currentDay == day) return;
    final newDue = movedDueDate(
      task: task,
      day: day,
      zone: zone,
      defaultDueTime: DueTime(hour: dueTime.hour, minute: dueTime.minute),
    );
    if (task.dueDate == newDue) return;
    ref.read(taskRepositoryProvider).update(
          task.copyWith(dueDate: newDue, updatedAt: DateTime.now()),
        );
  }
}

String _shortMonth(BuildContext context, int month) {
  final l10n = AppLocalizations.of(context);
  return [
    l10n.monthJan,
    l10n.monthFeb,
    l10n.monthMar,
    l10n.monthApr,
    l10n.monthMay,
    l10n.monthJun,
    l10n.monthJul,
    l10n.monthAug,
    l10n.monthSep,
    l10n.monthOct,
    l10n.monthNov,
    l10n.monthDec,
  ][month - 1];
}

class _CalendarHeader extends StatelessWidget {
  const _CalendarHeader({
    required this.view,
    required this.onPrevious,
    required this.onNext,
    required this.onToday,
    required this.onModeChanged,
  });

  final CalendarViewState view;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onToday;
  final ValueChanged<CalendarViewMode> onModeChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final label = switch (view.mode) {
      CalendarViewMode.month =>
        '${_shortMonth(context, view.anchor.month)} ${view.anchor.year}',
      CalendarViewMode.week => _weekLabel(context, view.anchor),
      CalendarViewMode.quarter => _quarterLabel(context, view.anchor),
    };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            tooltip: l10n.back,
            onPressed: onPrevious,
          ),
          Text(label, style: Theme.of(context).textTheme.titleMedium),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: onNext,
          ),
          const SizedBox(width: 8),
          TextButton(onPressed: onToday, child: Text(l10n.today)),
          const Spacer(),
          SegmentedButton<CalendarViewMode>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(
                value: CalendarViewMode.month,
                label: Text(l10n.calendarMonth),
              ),
              ButtonSegment(
                value: CalendarViewMode.week,
                label: Text(l10n.calendarWeek),
              ),
              ButtonSegment(
                value: CalendarViewMode.quarter,
                label: Text(l10n.calendarQuarter),
              ),
            ],
            selected: {view.mode},
            onSelectionChanged: (selection) => onModeChanged(selection.first),
          ),
        ],
      ),
    );
  }

  String _weekLabel(BuildContext context, DateTime anchor) {
    final days = weekGridDays(anchor);
    final start = days.first;
    final end = days.last;
    if (start.month == end.month) {
      return '${_shortMonth(context, start.month)} ${start.day} – ${end.day}';
    }
    return '${_shortMonth(context, start.month)} ${start.day} – '
        '${_shortMonth(context, end.month)} ${end.day}';
  }

  String _quarterLabel(BuildContext context, DateTime anchor) {
    final months = quarterMonths(anchor);
    final first = months.first;
    final last = months.last;
    return '${_shortMonth(context, first.month)} – '
        '${_shortMonth(context, last.month)} ${last.year}';
  }
}

class _EmptyCalendarHint extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.event_note,
              size: 40,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 12),
            Text(
              AppLocalizations.of(context).dragToScheduleHint,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeekdayHeaderRow extends StatelessWidget {
  const _WeekdayHeaderRow();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final labels = [
      l10n.dayMon,
      l10n.dayTue,
      l10n.dayWed,
      l10n.dayThu,
      l10n.dayFri,
      l10n.daySat,
      l10n.daySun,
    ];
    return Row(
      children: [
        for (final label in labels)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
              ),
            ),
          ),
      ],
    );
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.month,
    required this.byDay,
    required this.zone,
    required this.today,
    required this.onDropTask,
    required this.onOpenTask,
  });

  final DateTime month;
  final Map<DateTime, List<Task>> byDay;
  final tz.Location zone;
  final DateTime today;
  final void Function(DateTime day, Task task) onDropTask;
  final ValueChanged<String>? onOpenTask;

  @override
  Widget build(BuildContext context) {
    final days = monthGridDays(month);
    final rows = <Widget>[];
    for (var i = 0; i < days.length; i += 7) {
      rows.add(
        Expanded(
          child: Row(
            children: [
              for (final day in days.sublist(i, i + 7))
                Expanded(
                  child: _cell(day, isCurrentMonth: day.month == month.month),
                ),
            ],
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        children: [
          const _WeekdayHeaderRow(),
          ...rows,
        ],
      ),
    );
  }

  Widget _cell(DateTime day, {required bool isCurrentMonth}) {
    return DayCell(
      key: ValueKey('day-cell-${day.year}-${day.month}-${day.day}'),
      day: day,
      tasks: byDay[day] ?? const [],
      zone: zone,
      isCurrentMonth: isCurrentMonth,
      isToday: isCurrentMonth && day == today,
      onDropTask: (task) => onDropTask(day, task),
      onTapTask: onOpenTask,
    );
  }
}

class _WeekGrid extends StatelessWidget {
  const _WeekGrid({
    required this.day,
    required this.byDay,
    required this.zone,
    required this.today,
    required this.onDropTask,
    required this.onOpenTask,
  });

  final DateTime day;
  final Map<DateTime, List<Task>> byDay;
  final tz.Location zone;
  final DateTime today;
  final void Function(DateTime day, Task task) onDropTask;
  final ValueChanged<String>? onOpenTask;

  @override
  Widget build(BuildContext context) {
    final days = weekGridDays(day);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        children: [
          const _WeekdayHeaderRow(),
          Expanded(
            child: Row(
              children: [
                for (final day in days)
                  Expanded(
                    child: DayCell(
                      key: ValueKey(
                        'day-cell-${day.year}-${day.month}-${day.day}',
                      ),
                      day: day,
                      tasks: byDay[day] ?? const [],
                      zone: zone,
                      isCurrentMonth: true,
                      isToday: day == today,
                      onDropTask: (task) => onDropTask(day, task),
                      onTapTask: onOpenTask,
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

class _QuarterGrid extends StatelessWidget {
  const _QuarterGrid({
    required this.anchor,
    required this.byDay,
    required this.zone,
    required this.today,
    required this.onDropTask,
    required this.onOpenTask,
  });

  final DateTime anchor;
  final Map<DateTime, List<Task>> byDay;
  final tz.Location zone;
  final DateTime today;
  final void Function(DateTime day, Task task) onDropTask;
  final ValueChanged<String>? onOpenTask;

  @override
  Widget build(BuildContext context) {
    final months = quarterMonths(anchor);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final month in months)
            Expanded(
              child: Column(
                children: [
                  Text(
                    _shortMonth(context, month.month),
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const _WeekdayHeaderRow(),
                  ..._rows(month),
                ],
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _rows(DateTime month) {
    final days = monthGridDays(month);
    return [
      for (var i = 0; i < days.length; i += 7)
        Expanded(
          child: Row(
            children: [
              for (final day in days.sublist(i, i + 7))
                Expanded(
                  child: DayCell(
                    key: ValueKey(
                      'day-cell-${day.year}-${day.month}-${day.day}',
                    ),
                    day: day,
                    tasks: byDay[day] ?? const [],
                    zone: zone,
                    isCurrentMonth: day.month == month.month,
                    isToday: day.month == month.month && day == today,
                    onDropTask: (task) => onDropTask(day, task),
                    onTapTask: onOpenTask,
                  ),
                ),
            ],
          ),
        ),
    ];
  }
}