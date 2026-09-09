import 'package:flutter_test/flutter_test.dart';
import 'package:taskmaster/features/tasks/domain/calendar.dart';

void main() {
  group('monthGridDays', () {
    test('returns 42 days (6 Monday-first weeks) containing the month', () {
      final days = monthGridDays(DateTime(2026, 7, 15));

      expect(days.length, 42);
      expect(days.first.weekday, DateTime.monday);
      expect(days.contains(DateTime(2026, 7, 1)), isTrue);
      expect(days.contains(DateTime(2026, 7, 31)), isTrue);
    });

    test('bleeds into the previous and next month', () {
      final days = monthGridDays(DateTime(2026, 7, 1));
      expect(days.first, DateTime(2026, 6, 29));
      expect(days.last, DateTime(2026, 8, 9));
    });

    test('a Sunday-led month still starts on Monday', () {
      // 2026-08-01 is a Saturday; grid must start 2026-07-27.
      final days = monthGridDays(DateTime(2026, 8, 1));
      expect(days.first, DateTime(2026, 7, 27));
      expect(days.first.weekday, DateTime.monday);
    });
  });

  group('weekGridDays', () {
    test('returns the 7 days Monday-first of the week', () {
      final days = weekGridDays(DateTime(2026, 7, 15, 14));

      expect(days.length, 7);
      expect(days.first, DateTime(2026, 7, 13));
      expect(days.last, DateTime(2026, 7, 19));
    });

    test('midweek anchor resolves to the same week', () {
      final days = weekGridDays(DateTime(2026, 7, 17));
      expect(days, weekGridDays(DateTime(2026, 7, 17, 23, 59)));
    });
  });

  group('quarterMonths', () {
    test('mid-quarter anchor resolves to its three months', () {
      final months = quarterMonths(DateTime(2026, 11, 11));
      expect(months, [
        DateTime(2026, 10, 1),
        DateTime(2026, 11, 1),
        DateTime(2026, 12, 1),
      ]);
    });

    test('January resolves to January/February/March of the same year', () {
      final months = quarterMonths(DateTime(2026, 1, 5));
      expect(months, [
        DateTime(2026, 1, 1),
        DateTime(2026, 2, 1),
        DateTime(2026, 3, 1),
      ]);
    });
  });

  group('navigation arithmetic', () {
    test('addMonths rolls into the next year', () {
      expect(addMonths(DateTime(2026, 12, 15), 1), DateTime(2027, 1, 1));
    });

    test('addWeeks steps a full week', () {
      expect(addWeeks(DateTime(2026, 7, 1), 1), DateTime(2026, 7, 8));
    });

    test('addQuarters resolves the calendar quarter', () {
      expect(addQuarters(DateTime(2026, 7, 15), 1), DateTime(2026, 10, 1));
    });
  });

  test('CalendarViewMode defaults to month', () {
    expect(CalendarViewMode.values.first, CalendarViewMode.month);
  });
}