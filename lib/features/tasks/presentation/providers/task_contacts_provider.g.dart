// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'task_contacts_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(taskContacts)
final taskContactsProvider = TaskContactsFamily._();

final class TaskContactsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Contact>>,
          List<Contact>,
          FutureOr<List<Contact>>
        >
    with $FutureModifier<List<Contact>>, $FutureProvider<List<Contact>> {
  TaskContactsProvider._({
    required TaskContactsFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'taskContactsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$taskContactsHash();

  @override
  String toString() {
    return r'taskContactsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<Contact>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<Contact>> create(Ref ref) {
    final argument = this.argument as String;
    return taskContacts(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is TaskContactsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$taskContactsHash() => r'896e1003e1a0a8d76023312811230f649c803b6d';

final class TaskContactsFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<Contact>>, String> {
  TaskContactsFamily._()
    : super(
        retry: null,
        name: r'taskContactsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  TaskContactsProvider call(String taskId) =>
      TaskContactsProvider._(argument: taskId, from: this);

  @override
  String toString() => r'taskContactsProvider';
}

@ProviderFor(TaskContactsManager)
final taskContactsManagerProvider = TaskContactsManagerFamily._();

final class TaskContactsManagerProvider
    extends $NotifierProvider<TaskContactsManager, AsyncValue<List<Contact>>> {
  TaskContactsManagerProvider._({
    required TaskContactsManagerFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'taskContactsManagerProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$taskContactsManagerHash();

  @override
  String toString() {
    return r'taskContactsManagerProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  TaskContactsManager create() => TaskContactsManager();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AsyncValue<List<Contact>> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AsyncValue<List<Contact>>>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is TaskContactsManagerProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$taskContactsManagerHash() =>
    r'96e850eca0fcbfb2100c2cea7a5584c76afc7137';

final class TaskContactsManagerFamily extends $Family
    with
        $ClassFamilyOverride<
          TaskContactsManager,
          AsyncValue<List<Contact>>,
          AsyncValue<List<Contact>>,
          AsyncValue<List<Contact>>,
          String
        > {
  TaskContactsManagerFamily._()
    : super(
        retry: null,
        name: r'taskContactsManagerProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  TaskContactsManagerProvider call(String taskId) =>
      TaskContactsManagerProvider._(argument: taskId, from: this);

  @override
  String toString() => r'taskContactsManagerProvider';
}

abstract class _$TaskContactsManager
    extends $Notifier<AsyncValue<List<Contact>>> {
  late final _$args = ref.$arg as String;
  String get taskId => _$args;

  AsyncValue<List<Contact>> build(String taskId);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<List<Contact>>, AsyncValue<List<Contact>>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<Contact>>, AsyncValue<List<Contact>>>,
              AsyncValue<List<Contact>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}
