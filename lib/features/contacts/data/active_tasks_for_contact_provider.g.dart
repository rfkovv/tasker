// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'active_tasks_for_contact_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// ACTIVE (not done) tasks linked to [contactId], newest first.
///
/// Lives in the contacts feature (not tasks) so the two features stay acyclic:
/// it reads the shared DAOs directly and surfaces only a small [LinkedTask]
/// projection.

@ProviderFor(activeTasksForContact)
final activeTasksForContactProvider = ActiveTasksForContactFamily._();

/// ACTIVE (not done) tasks linked to [contactId], newest first.
///
/// Lives in the contacts feature (not tasks) so the two features stay acyclic:
/// it reads the shared DAOs directly and surfaces only a small [LinkedTask]
/// projection.

final class ActiveTasksForContactProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<LinkedTask>>,
          List<LinkedTask>,
          Stream<List<LinkedTask>>
        >
    with $FutureModifier<List<LinkedTask>>, $StreamProvider<List<LinkedTask>> {
  /// ACTIVE (not done) tasks linked to [contactId], newest first.
  ///
  /// Lives in the contacts feature (not tasks) so the two features stay acyclic:
  /// it reads the shared DAOs directly and surfaces only a small [LinkedTask]
  /// projection.
  ActiveTasksForContactProvider._({
    required ActiveTasksForContactFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'activeTasksForContactProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$activeTasksForContactHash();

  @override
  String toString() {
    return r'activeTasksForContactProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<List<LinkedTask>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<LinkedTask>> create(Ref ref) {
    final argument = this.argument as String;
    return activeTasksForContact(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is ActiveTasksForContactProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$activeTasksForContactHash() =>
    r'f047856e2057cf28a99130f00283722a3a7bcd20';

/// ACTIVE (not done) tasks linked to [contactId], newest first.
///
/// Lives in the contacts feature (not tasks) so the two features stay acyclic:
/// it reads the shared DAOs directly and surfaces only a small [LinkedTask]
/// projection.

final class ActiveTasksForContactFamily extends $Family
    with $FunctionalFamilyOverride<Stream<List<LinkedTask>>, String> {
  ActiveTasksForContactFamily._()
    : super(
        retry: null,
        name: r'activeTasksForContactProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// ACTIVE (not done) tasks linked to [contactId], newest first.
  ///
  /// Lives in the contacts feature (not tasks) so the two features stay acyclic:
  /// it reads the shared DAOs directly and surfaces only a small [LinkedTask]
  /// projection.

  ActiveTasksForContactProvider call(String contactId) =>
      ActiveTasksForContactProvider._(argument: contactId, from: this);

  @override
  String toString() => r'activeTasksForContactProvider';
}
