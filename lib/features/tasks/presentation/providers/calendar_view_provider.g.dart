// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'calendar_view_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Navigational state of the calendar pane: which view mode is active and
/// where its window starts.

@ProviderFor(CalendarView)
final calendarViewProvider = CalendarViewProvider._();

/// Navigational state of the calendar pane: which view mode is active and
/// where its window starts.
final class CalendarViewProvider
    extends $NotifierProvider<CalendarView, CalendarViewState> {
  /// Navigational state of the calendar pane: which view mode is active and
  /// where its window starts.
  CalendarViewProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'calendarViewProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$calendarViewHash();

  @$internal
  @override
  CalendarView create() => CalendarView();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CalendarViewState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CalendarViewState>(value),
    );
  }
}

String _$calendarViewHash() => r'ed8ec60196b6442ff10ca0a819ab10f26cc7122c';

/// Navigational state of the calendar pane: which view mode is active and
/// where its window starts.

abstract class _$CalendarView extends $Notifier<CalendarViewState> {
  CalendarViewState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<CalendarViewState, CalendarViewState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<CalendarViewState, CalendarViewState>,
              CalendarViewState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
