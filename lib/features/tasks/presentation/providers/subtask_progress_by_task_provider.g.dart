// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'subtask_progress_by_task_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Maps each visible task id to its subtask completion progress ("x/y").
///
/// Only tasks that actually have subtasks are present in the map.

@ProviderFor(subtaskProgressByTask)
final subtaskProgressByTaskProvider = SubtaskProgressByTaskFamily._();

/// Maps each visible task id to its subtask completion progress ("x/y").
///
/// Only tasks that actually have subtasks are present in the map.

final class SubtaskProgressByTaskProvider
    extends
        $FunctionalProvider<
          AsyncValue<Map<String, SubtaskProgress>>,
          Map<String, SubtaskProgress>,
          FutureOr<Map<String, SubtaskProgress>>
        >
    with
        $FutureModifier<Map<String, SubtaskProgress>>,
        $FutureProvider<Map<String, SubtaskProgress>> {
  /// Maps each visible task id to its subtask completion progress ("x/y").
  ///
  /// Only tasks that actually have subtasks are present in the map.
  SubtaskProgressByTaskProvider._({
    required SubtaskProgressByTaskFamily super.from,
    required TaskFilter super.argument,
  }) : super(
         retry: null,
         name: r'subtaskProgressByTaskProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$subtaskProgressByTaskHash();

  @override
  String toString() {
    return r'subtaskProgressByTaskProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<Map<String, SubtaskProgress>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<Map<String, SubtaskProgress>> create(Ref ref) {
    final argument = this.argument as TaskFilter;
    return subtaskProgressByTask(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is SubtaskProgressByTaskProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$subtaskProgressByTaskHash() =>
    r'cec19898d172ad0664df183d33ea5f1ed97b174b';

/// Maps each visible task id to its subtask completion progress ("x/y").
///
/// Only tasks that actually have subtasks are present in the map.

final class SubtaskProgressByTaskFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<Map<String, SubtaskProgress>>,
          TaskFilter
        > {
  SubtaskProgressByTaskFamily._()
    : super(
        retry: null,
        name: r'subtaskProgressByTaskProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Maps each visible task id to its subtask completion progress ("x/y").
  ///
  /// Only tasks that actually have subtasks are present in the map.

  SubtaskProgressByTaskProvider call(TaskFilter filter) =>
      SubtaskProgressByTaskProvider._(argument: filter, from: this);

  @override
  String toString() => r'subtaskProgressByTaskProvider';
}
