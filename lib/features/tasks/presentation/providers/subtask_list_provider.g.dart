// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'subtask_list_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(subtaskList)
final subtaskListProvider = SubtaskListFamily._();

final class SubtaskListProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Subtask>>,
          List<Subtask>,
          Stream<List<Subtask>>
        >
    with $FutureModifier<List<Subtask>>, $StreamProvider<List<Subtask>> {
  SubtaskListProvider._({
    required SubtaskListFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'subtaskListProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$subtaskListHash();

  @override
  String toString() {
    return r'subtaskListProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<List<Subtask>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<Subtask>> create(Ref ref) {
    final argument = this.argument as String;
    return subtaskList(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is SubtaskListProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$subtaskListHash() => r'649b91bd694404a60d01a616f30d2e843993906a';

final class SubtaskListFamily extends $Family
    with $FunctionalFamilyOverride<Stream<List<Subtask>>, String> {
  SubtaskListFamily._()
    : super(
        retry: null,
        name: r'subtaskListProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  SubtaskListProvider call(String taskId) =>
      SubtaskListProvider._(argument: taskId, from: this);

  @override
  String toString() => r'subtaskListProvider';
}
