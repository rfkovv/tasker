import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../domain/calendar.dart';

part 'calendar_view_provider.g.dart';

class CalendarViewState {
  const CalendarViewState({
    this.mode = CalendarViewMode.month,
    required this.anchor,
  });

  /// Current view granularity (month / week / quarter).
  final CalendarViewMode mode;

  /// A date (date-only) inside the currently shown window. Which grid is
  /// rendered is derived from [mode] + [anchor].
  final DateTime anchor;

  CalendarViewState copyWith({
    CalendarViewMode? mode,
    DateTime? anchor,
  }) {
    return CalendarViewState(mode: mode ?? this.mode, anchor: anchor ?? this.anchor);
  }
}

/// Navigational state of the calendar pane: which view mode is active and
/// where its window starts.
@riverpod
class CalendarView extends _$CalendarView {
  @override
  CalendarViewState build() {
    final now = DateTime.now();
    return CalendarViewState(anchor: DateTime(now.year, now.month, now.day));
  }

  void setMode(CalendarViewMode mode) => state = state.copyWith(mode: mode);

  void next() => state = state.copyWith(anchor: _moved(state, 1));

  void previous() => state = state.copyWith(anchor: _moved(state, -1));

  void goToday() {
    final now = DateTime.now();
    state = state.copyWith(anchor: DateTime(now.year, now.month, now.day));
  }

  DateTime _moved(CalendarViewState s, int step) {
    return switch (s.mode) {
      CalendarViewMode.month => addMonths(s.anchor, step),
      CalendarViewMode.week => addWeeks(s.anchor, step),
      CalendarViewMode.quarter => addQuarters(s.anchor, step),
    };
  }
}