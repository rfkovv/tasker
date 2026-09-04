// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'task_list_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(taskList)
final taskListProvider = TaskListFamily._();

final class TaskListProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Task>>,
          List<Task>,
          Stream<List<Task>>
        >
    with $FutureModifier<List<Task>>, $StreamProvider<List<Task>> {
  TaskListProvider._({
    required TaskListFamily super.from,
    required TaskFilter super.argument,
  }) : super(
         retry: null,
         name: r'taskListProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$taskListHash();

  @override
  String toString() {
    return r'taskListProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<List<Task>> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<List<Task>> create(Ref ref) {
    final argument = this.argument as TaskFilter;
    return taskList(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is TaskListProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$taskListHash() => r'fdcaa73a8f4c9003835549e0e60498cfde91c0d8';

final class TaskListFamily extends $Family
    with $FunctionalFamilyOverride<Stream<List<Task>>, TaskFilter> {
  TaskListFamily._()
    : super(
        retry: null,
        name: r'taskListProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  TaskListProvider call(TaskFilter filter) =>
      TaskListProvider._(argument: filter, from: this);

  @override
  String toString() => r'taskListProvider';
}

@ProviderFor(watchTaskById)
final watchTaskByIdProvider = WatchTaskByIdFamily._();

final class WatchTaskByIdProvider
    extends $FunctionalProvider<AsyncValue<Task?>, Task?, Stream<Task?>>
    with $FutureModifier<Task?>, $StreamProvider<Task?> {
  WatchTaskByIdProvider._({
    required WatchTaskByIdFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'watchTaskByIdProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$watchTaskByIdHash();

  @override
  String toString() {
    return r'watchTaskByIdProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<Task?> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<Task?> create(Ref ref) {
    final argument = this.argument as String;
    return watchTaskById(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is WatchTaskByIdProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$watchTaskByIdHash() => r'674f612dfb3de44be83fd7e52ada43aac89e3b30';

final class WatchTaskByIdFamily extends $Family
    with $FunctionalFamilyOverride<Stream<Task?>, String> {
  WatchTaskByIdFamily._()
    : super(
        retry: null,
        name: r'watchTaskByIdProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  WatchTaskByIdProvider call(String id) =>
      WatchTaskByIdProvider._(argument: id, from: this);

  @override
  String toString() => r'watchTaskByIdProvider';
}

@ProviderFor(TaskFilterState)
final taskFilterStateProvider = TaskFilterStateProvider._();

final class TaskFilterStateProvider
    extends $NotifierProvider<TaskFilterState, TaskFilter> {
  TaskFilterStateProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'taskFilterStateProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$taskFilterStateHash();

  @$internal
  @override
  TaskFilterState create() => TaskFilterState();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TaskFilter value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TaskFilter>(value),
    );
  }
}

String _$taskFilterStateHash() => r'01f1fcd59163eb008c9df3bdeb30ae4cd76f58c2';

abstract class _$TaskFilterState extends $Notifier<TaskFilter> {
  TaskFilter build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<TaskFilter, TaskFilter>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<TaskFilter, TaskFilter>,
              TaskFilter,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
