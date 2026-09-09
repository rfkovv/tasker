import 'package:timezone/timezone.dart' as tz;

import 'task.dart';

/// Time-of-day (24h) used as the default when a task without a due date is
/// dropped on a calendar day.
class DueTime {
  const DueTime({required this.hour, required this.minute});

  factory DueTime.parse(String value) {
    final parts = value.split(':');
    final hour = int.tryParse(parts.first) ?? 7;
    final minute = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
    return DueTime(hour: hour.clamp(0, 23), minute: minute.clamp(0, 59));
  }

  final int hour;
  final int minute;

  /// "HH:mm" (24h), the canonical serialized form.
  String toDbString() =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}

/// The local calendar date (date-only `DateTime`) of the absolute instant
/// [instant] in [zone]. Used both for grouping tasks on the grid and for
/// identifying day cells.
DateTime localDay(DateTime instant, tz.Location zone) {
  final local = tz.TZDateTime.from(instant, zone);
  return DateTime(local.year, local.month, local.day);
}

/// Tasks having a due date, grouped by their local day in [zone].
/// Tasks without a due date are omitted (they belong to the backlog).
Map<DateTime, List<Task>> tasksByLocalDay(
  Iterable<Task> tasks,
  tz.Location zone,
) {
  final byDay = <DateTime, List<Task>>{};
  for (final task in tasks) {
    final due = task.dueDate;
    if (due == null) continue;
    byDay.putIfAbsent(localDay(due, zone), () => []).add(task);
  }
  return byDay;
}

/// Computes the new UTC due date when [task] is dropped on the local date
/// [day] (a date-only `DateTime` in [zone]).
///
/// A task that already has a due date keeps its existing local time-of-day
/// in [zone] — only the day moves. A task without a due date receives the
/// [defaultDueTime]. The result is always UTC (what gets persisted).
DateTime movedDueDate({
  required Task task,
  required DateTime day,
  required tz.Location zone,
  required DueTime defaultDueTime,
}) {
  final existing = task.dueDate;
  int hour;
  int minute;
  if (existing != null) {
    final local = tz.TZDateTime.from(existing, zone);
    hour = local.hour;
    minute = local.minute;
  } else {
    hour = defaultDueTime.hour;
    minute = defaultDueTime.minute;
  }
  final target =
      tz.TZDateTime(zone, day.year, day.month, day.day, hour, minute);
  return target.toUtc();
}