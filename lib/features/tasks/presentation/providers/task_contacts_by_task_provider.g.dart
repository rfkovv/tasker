// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'task_contacts_by_task_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Maps each visible task id to its linked contacts (from the contacts feature).
///
/// Uses only the public contacts API exposed through the contacts barrel.

@ProviderFor(taskContactsByTask)
final taskContactsByTaskProvider = TaskContactsByTaskFamily._();

/// Maps each visible task id to its linked contacts (from the contacts feature).
///
/// Uses only the public contacts API exposed through the contacts barrel.

final class TaskContactsByTaskProvider
    extends
        $FunctionalProvider<
          AsyncValue<Map<String, List<contacts_feature.Contact>>>,
          Map<String, List<contacts_feature.Contact>>,
          FutureOr<Map<String, List<contacts_feature.Contact>>>
        >
    with
        $FutureModifier<Map<String, List<contacts_feature.Contact>>>,
        $FutureProvider<Map<String, List<contacts_feature.Contact>>> {
  /// Maps each visible task id to its linked contacts (from the contacts feature).
  ///
  /// Uses only the public contacts API exposed through the contacts barrel.
  TaskContactsByTaskProvider._({
    required TaskContactsByTaskFamily super.from,
    required TaskFilter super.argument,
  }) : super(
         retry: null,
         name: r'taskContactsByTaskProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$taskContactsByTaskHash();

  @override
  String toString() {
    return r'taskContactsByTaskProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<Map<String, List<contacts_feature.Contact>>>
  $createElement($ProviderPointer pointer) => $FutureProviderElement(pointer);

  @override
  FutureOr<Map<String, List<contacts_feature.Contact>>> create(Ref ref) {
    final argument = this.argument as TaskFilter;
    return taskContactsByTask(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is TaskContactsByTaskProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$taskContactsByTaskHash() =>
    r'd4b3efe00eb9d6a0c48f4c65e21811bd82725050';

/// Maps each visible task id to its linked contacts (from the contacts feature).
///
/// Uses only the public contacts API exposed through the contacts barrel.

final class TaskContactsByTaskFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<Map<String, List<contacts_feature.Contact>>>,
          TaskFilter
        > {
  TaskContactsByTaskFamily._()
    : super(
        retry: null,
        name: r'taskContactsByTaskProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Maps each visible task id to its linked contacts (from the contacts feature).
  ///
  /// Uses only the public contacts API exposed through the contacts barrel.

  TaskContactsByTaskProvider call(TaskFilter filter) =>
      TaskContactsByTaskProvider._(argument: filter, from: this);

  @override
  String toString() => r'taskContactsByTaskProvider';
}
