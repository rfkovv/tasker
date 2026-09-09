// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'task_form_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(TaskForm)
final taskFormProvider = TaskFormFamily._();

final class TaskFormProvider
    extends $NotifierProvider<TaskForm, TaskFormState> {
  TaskFormProvider._({
    required TaskFormFamily super.from,
    required Task? super.argument,
  }) : super(
         retry: null,
         name: r'taskFormProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$taskFormHash();

  @override
  String toString() {
    return r'taskFormProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  TaskForm create() => TaskForm();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TaskFormState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TaskFormState>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is TaskFormProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$taskFormHash() => r'cf14fd9443165d0946957171f6ec485a1e888639';

final class TaskFormFamily extends $Family
    with
        $ClassFamilyOverride<
          TaskForm,
          TaskFormState,
          TaskFormState,
          TaskFormState,
          Task?
        > {
  TaskFormFamily._()
    : super(
        retry: null,
        name: r'taskFormProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  TaskFormProvider call(Task? task) =>
      TaskFormProvider._(argument: task, from: this);

  @override
  String toString() => r'taskFormProvider';
}

abstract class _$TaskForm extends $Notifier<TaskFormState> {
  late final _$args = ref.$arg as Task?;
  Task? get task => _$args;

  TaskFormState build(Task? task);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<TaskFormState, TaskFormState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<TaskFormState, TaskFormState>,
              TaskFormState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}
