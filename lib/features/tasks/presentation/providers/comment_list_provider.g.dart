// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'comment_list_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(commentList)
final commentListProvider = CommentListFamily._();

final class CommentListProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Comment>>,
          List<Comment>,
          Stream<List<Comment>>
        >
    with $FutureModifier<List<Comment>>, $StreamProvider<List<Comment>> {
  CommentListProvider._({
    required CommentListFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'commentListProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$commentListHash();

  @override
  String toString() {
    return r'commentListProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<List<Comment>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<Comment>> create(Ref ref) {
    final argument = this.argument as String;
    return commentList(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is CommentListProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$commentListHash() => r'f1ae123e3b72e9f578e4706b8a4f67d80a9aed77';

final class CommentListFamily extends $Family
    with $FunctionalFamilyOverride<Stream<List<Comment>>, String> {
  CommentListFamily._()
    : super(
        retry: null,
        name: r'commentListProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  CommentListProvider call(String taskId) =>
      CommentListProvider._(argument: taskId, from: this);

  @override
  String toString() => r'commentListProvider';
}
