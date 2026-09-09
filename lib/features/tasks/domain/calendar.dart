/// Viewing granularity of the calendar pane. All three render the same
/// day-cell grid — only the window of days differs.
enum CalendarViewMode { month, week, quarter }

/// Returns the first day of the month containing [day] (date-only).
DateTime firstOfMonth(DateTime day) => DateTime(day.year, day.month);

/// Returns the Monday (first day of week) of the week containing [day].
/// The calendar always uses a Monday-first week.
DateTime startOfWeek(DateTime day) => DateTime(day.year, day.month, day.day - (day.weekday - 1));

/// The 42 day cells (6 weeks, Monday-first) covering the month box that
/// contains [month]. Days bleeding from the previous/next month are
/// included so the grid is always rectangular.
List<DateTime> monthGridDays(DateTime month) {
  final start = startOfWeek(firstOfMonth(month));
  return [
    for (var i = 0; i < 42; i++)
      DateTime(start.year, start.month, start.day + i),
  ];
}

/// The 7 days (Monday-first) of the week containing [day].
List<DateTime> weekGridDays(DateTime day) {
  final start = startOfWeek(day);
  return [
    for (var i = 0; i < 7; i++)
      DateTime(start.year, start.month, start.day + i),
  ];
}

/// The first days of the three months that make up the quarter containing
/// [day], e.g. Q1 -> January, February, March.
List<DateTime> quarterMonths(DateTime day) {
  final quarterStartMonth = ((day.month - 1) ~/ 3) * 3 + 1;
  final first = DateTime(day.year, quarterStartMonth);
  return [
    first,
    DateTime(first.year, first.month + 1),
    DateTime(first.year, first.month + 2),
  ];
}

/// Advances/rewinds [day] by calendar [months] (year-normalizing).
DateTime addMonths(DateTime day, int months) =>
    DateTime(day.year, day.month + months);

/// Advances/rewinds [day] by a whole number of weeks.
DateTime addWeeks(DateTime day, int weeks) =>
    DateTime(day.year, day.month, day.day + 7 * weeks);

/// Advances/rewinds [day] by a number of quarters.
DateTime addQuarters(DateTime day, int quarters) =>
    DateTime(day.year, day.month + 3 * quarters);