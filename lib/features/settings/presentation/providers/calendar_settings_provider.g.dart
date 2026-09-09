// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'calendar_settings_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The timezone the calendar displays and schedules in. Falls back to the
/// device-local zone when the user has not picked one explicitly.

@ProviderFor(selectedTimeZone)
final selectedTimeZoneProvider = SelectedTimeZoneProvider._();

/// The timezone the calendar displays and schedules in. Falls back to the
/// device-local zone when the user has not picked one explicitly.

final class SelectedTimeZoneProvider
    extends $FunctionalProvider<tz.Location, tz.Location, tz.Location>
    with $Provider<tz.Location> {
  /// The timezone the calendar displays and schedules in. Falls back to the
  /// device-local zone when the user has not picked one explicitly.
  SelectedTimeZoneProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'selectedTimeZoneProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$selectedTimeZoneHash();

  @$internal
  @override
  $ProviderElement<tz.Location> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  tz.Location create(Ref ref) {
    return selectedTimeZone(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(tz.Location value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<tz.Location>(value),
    );
  }
}

String _$selectedTimeZoneHash() => r'b6500a1d5197f11ae87a9c5862310bd69d1714d4';

/// The time-of-day applied to tasks dropped on a calendar day without an
/// existing due time. Ships as "HH:mm" 24h, defaults to 07:00.

@ProviderFor(defaultDueTime)
final defaultDueTimeProvider = DefaultDueTimeProvider._();

/// The time-of-day applied to tasks dropped on a calendar day without an
/// existing due time. Ships as "HH:mm" 24h, defaults to 07:00.

final class DefaultDueTimeProvider
    extends
        $FunctionalProvider<
          ({int hour, int minute}),
          ({int hour, int minute}),
          ({int hour, int minute})
        >
    with $Provider<({int hour, int minute})> {
  /// The time-of-day applied to tasks dropped on a calendar day without an
  /// existing due time. Ships as "HH:mm" 24h, defaults to 07:00.
  DefaultDueTimeProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'defaultDueTimeProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$defaultDueTimeHash();

  @$internal
  @override
  $ProviderElement<({int hour, int minute})> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ({int hour, int minute}) create(Ref ref) {
    return defaultDueTime(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(({int hour, int minute}) value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<({int hour, int minute})>(value),
    );
  }
}

String _$defaultDueTimeHash() => r'cda19e36cf5582fc0ef12ebbf9b4a2c70fef8492';
