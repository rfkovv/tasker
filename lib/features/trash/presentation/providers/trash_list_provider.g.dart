// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'trash_list_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Which trash tab is active: false = tasks, true = contacts.

@ProviderFor(TrashTab)
final trashTabProvider = TrashTabProvider._();

/// Which trash tab is active: false = tasks, true = contacts.
final class TrashTabProvider extends $NotifierProvider<TrashTab, bool> {
  /// Which trash tab is active: false = tasks, true = contacts.
  TrashTabProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'trashTabProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$trashTabHash();

  @$internal
  @override
  TrashTab create() => TrashTab();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$trashTabHash() => r'150165716471ecddbd1ef77e4fafc37b32d41abb';

/// Which trash tab is active: false = tasks, true = contacts.

abstract class _$TrashTab extends $Notifier<bool> {
  bool build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<bool, bool>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<bool, bool>,
              bool,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// Soft-deleted tasks surfaced by Kosz.

@ProviderFor(deletedTasks)
final deletedTasksProvider = DeletedTasksProvider._();

/// Soft-deleted tasks surfaced by Kosz.

final class DeletedTasksProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Task>>,
          List<Task>,
          Stream<List<Task>>
        >
    with $FutureModifier<List<Task>>, $StreamProvider<List<Task>> {
  /// Soft-deleted tasks surfaced by Kosz.
  DeletedTasksProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'deletedTasksProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$deletedTasksHash();

  @$internal
  @override
  $StreamProviderElement<List<Task>> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<List<Task>> create(Ref ref) {
    return deletedTasks(ref);
  }
}

String _$deletedTasksHash() => r'14a1d87780ea57bab6956e8f75f9c3615d6f9d1a';

/// Soft-deleted contacts surfaced by Kosz.

@ProviderFor(deletedContacts)
final deletedContactsProvider = DeletedContactsProvider._();

/// Soft-deleted contacts surfaced by Kosz.

final class DeletedContactsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Contact>>,
          List<Contact>,
          Stream<List<Contact>>
        >
    with $FutureModifier<List<Contact>>, $StreamProvider<List<Contact>> {
  /// Soft-deleted contacts surfaced by Kosz.
  DeletedContactsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'deletedContactsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$deletedContactsHash();

  @$internal
  @override
  $StreamProviderElement<List<Contact>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<Contact>> create(Ref ref) {
    return deletedContacts(ref);
  }
}

String _$deletedContactsHash() => r'cfabe0882238cdfd5049365cda7a214aa95f7d83';
