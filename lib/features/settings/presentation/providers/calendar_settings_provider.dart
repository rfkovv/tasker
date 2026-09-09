import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:timezone/timezone.dart' as tz;

import 'app_settings_provider.dart';

part 'calendar_settings_provider.g.dart';

int _clampInt(int value, int lo, int hi) =>
    value < lo ? lo : (value > hi ? hi : value);

/// The timezone the calendar displays and schedules in. Falls back to the
/// device-local zone when the user has not picked one explicitly.
@riverpod
tz.Location selectedTimeZone(Ref ref) {
  final name = ref.watch(appSettingsProvider).timezoneName;
  if (name.isEmpty) return tz.local;
  return tz.getLocation(name);
}

/// The time-of-day applied to tasks dropped on a calendar day without an
/// existing due time. Ships as "HH:mm" 24h, defaults to 07:00.
@riverpod
({int hour, int minute}) defaultDueTime(Ref ref) {
  final value = ref.watch(appSettingsProvider).defaultDueTime;
  final parts = value.split(':');
  final hour = _clampInt(int.tryParse(parts.first) ?? 7, 0, 23);
  final minute = parts.length > 1
      ? _clampInt(int.tryParse(parts[1]) ?? 0, 0, 59)
      : 0;
  return (hour: hour, minute: minute);
}