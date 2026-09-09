import 'package:flutter_test/flutter_test.dart';
import 'package:taskmaster/features/tasks/domain/scheduling.dart';
import 'package:taskmaster/features/tasks/domain/task.dart';
import 'package:taskmaster/features/tasks/domain/task_status.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

void main() {
  tzdata.initializeTimeZones();

  final warsaw = tz.getLocation('Europe/Warsaw');
  final newYork = tz.getLocation('America/New_York');

  final now = DateTime.utc(2026, 7, 1);
  const defaultTime = DueTime(hour: 7, minute: 0);

  Task task({String id = 't1', DateTime? dueDate}) => Task(
        id: id,
        title: 'Task',
        dueDate: dueDate,
        createdAt: now,
        updatedAt: now,
        status: TaskStatus.todo,
      );

  group('DueTime', () {
    test('parse "07:00"', () {
      final t = DueTime.parse('07:00');
      expect(t.hour, 7);
      expect(t.minute, 0);
    });

    test('parse "09:30" and round-trips toDbString', () {
      final t = DueTime.parse('09:30');
      expect(t.hour, 9);
      expect(t.minute, 30);
      expect(t.toDbString(), '09:30');
    });

    test('malformed input falls back to 07:00', () {
      final t = DueTime.parse('nope');
      expect(t.hour, 7);
      expect(t.minute, 0);
    });

    test('out-of-range components are clamped', () {
      expect(DueTime.parse('25:99').hour, 23);
      expect(DueTime.parse('25:99').minute, 59);
    });
  });

  group('movedDueDate', () {
    test('unsigned task gets the default due time in the display zone',
        () {
      final result = movedDueDate(
        task: task(),
        day: DateTime(2026, 7, 15),
        zone: warsaw,
        defaultDueTime: defaultTime,
      );

      // 07:00 in Warsaw (UTC+2 in July) == 05:00 UTC.
      expect(result, DateTime.utc(2026, 7, 15, 5, 0));
    });

    test('same drop in a different timezone yields a different instant',
        () {
      final result = movedDueDate(
        task: task(),
        day: DateTime(2026, 7, 15),
        zone: newYork,
        defaultDueTime: defaultTime,
      );

      // 07:00 in New York (UTC-4 in July) == 11:00 UTC.
      expect(result, DateTime.utc(2026, 7, 15, 11, 0));
    });

    test('scheduled task keeps its local time when moved between days', () {
      final scheduledAt = tz.TZDateTime(warsaw, 2026, 7, 10, 9, 30).toUtc();
      final result = movedDueDate(
        task: task(dueDate: scheduledAt),
        day: DateTime(2026, 7, 20),
        zone: warsaw,
        defaultDueTime: defaultTime,
      );

      // 09:30 local on the 20th == 07:30 UTC.
      expect(result, DateTime.utc(2026, 7, 20, 7, 30));
    });

    test('moving a task onto its own day is a no-op', () {
      final scheduledAt = tz.TZDateTime(warsaw, 2026, 7, 15, 7, 0).toUtc();
      final original = task(dueDate: scheduledAt);
      final result = movedDueDate(
        task: original,
        day: localDay(scheduledAt, warsaw),
        zone: warsaw,
        defaultDueTime: defaultTime,
      );

      expect(result, scheduledAt);
    });

    test('spring-forward gap is handled without throwing (Warsaw DST 2026)',
        () {
      // 2026-03-29: clocks jump 02:00 -> 03:00, so 02:30 does not exist.
      final result = movedDueDate(
        task: task(),
        day: DateTime(2026, 3, 29),
        zone: warsaw,
        defaultDueTime: const DueTime(hour: 2, minute: 30),
      );
      result; // must not throw
      expect(localDay(result, warsaw), DateTime(2026, 3, 29));
      final hour = tz.TZDateTime.from(result, warsaw).hour;
      expect(hour, anyOf(2, 3));
    });

    test('autumn fold-back (02:30 twice) is handled without throwing', () {
      // 2026-10-25: clocks roll back 03:00 -> 02:00, 02:30 occurs twice.
      final result = movedDueDate(
        task: task(),
        day: DateTime(2026, 10, 25),
        zone: warsaw,
        defaultDueTime: const DueTime(hour: 2, minute: 30),
      );
      expect(localDay(result, warsaw), DateTime(2026, 10, 25));
    });
  });

  group('localDay', () {
    test('late UTC evening lands on the next day in Warsaw but same day in NY',
        () {
      final instant = DateTime.utc(2026, 7, 15, 22, 30);

      expect(localDay(instant, warsaw), DateTime(2026, 7, 16));
      expect(localDay(instant, newYork), DateTime(2026, 7, 15));
    });

    test('early UTC morning stays on the same day in both zones', () {
      final instant = DateTime.utc(2026, 7, 15, 0, 30);
      expect(localDay(instant, warsaw), DateTime(2026, 7, 15));
      expect(localDay(instant, newYork), DateTime(2026, 7, 14));
    });
  });

  group('tasksByLocalDay', () {
    test('groups and drops unsigned tasks', () {
      final signedAt = DateTime.utc(2026, 7, 15, 22, 30);
      final result = tasksByLocalDay(
        [
          task(id: 'a', dueDate: signedAt),
          task(id: 'b'),
        ],
        warsaw,
      );

      expect(result.keys, [DateTime(2026, 7, 16)]);
      expect(result[DateTime(2026, 7, 16)]!.single.id, 'a');
    });
  });
}