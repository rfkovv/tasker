// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_settings_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(AppSettings)
final appSettingsProvider = AppSettingsProvider._();

final class AppSettingsProvider
    extends $NotifierProvider<AppSettings, AppSettingsData> {
  AppSettingsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appSettingsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appSettingsHash();

  @$internal
  @override
  AppSettings create() => AppSettings();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AppSettingsData value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AppSettingsData>(value),
    );
  }
}

String _$appSettingsHash() => r'7528a5246d037470ab2f9812eb4a6021f700208b';

abstract class _$AppSettings extends $Notifier<AppSettingsData> {
  AppSettingsData build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AppSettingsData, AppSettingsData>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AppSettingsData, AppSettingsData>,
              AppSettingsData,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
