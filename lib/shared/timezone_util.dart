import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Initializes the tz database and sets the local zone to the best match
/// for the device. Idempotent; safe to call from `main()` and test setups.
void initAppTimeZones() {
  tzdata.initializeTimeZones();

  final now = DateTime.now();
  final zoneName = now.timeZoneName;
  for (final name in tz.timeZoneDatabase.locations.keys) {
    final location = tz.getLocation(name);
    final local = tz.TZDateTime.from(now, location);
    if (local.timeZoneName == zoneName) {
      tz.setLocalLocation(location);
      return;
    }
  }

  final offsetMinutes = now.timeZoneOffset.inMinutes;
  for (final name in tz.timeZoneDatabase.locations.keys) {
    final location = tz.getLocation(name);
    final local = tz.TZDateTime.from(now, location);
    if (local.timeZoneOffset.inMinutes == offsetMinutes) {
      tz.setLocalLocation(location);
      return;
    }
  }

  tz.setLocalLocation(tz.getLocation('UTC'));
}