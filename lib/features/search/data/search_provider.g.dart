// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'search_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Global search over every registered section.
///
/// Consumes tasks and contacts exclusively through their public barrels
/// ([tasks_feature], [contacts_feature]). Adding a new section means adding a
/// new [SearchSectionType] and folding its hits into [searchResults].

@ProviderFor(searchResults)
final searchResultsProvider = SearchResultsFamily._();

/// Global search over every registered section.
///
/// Consumes tasks and contacts exclusively through their public barrels
/// ([tasks_feature], [contacts_feature]). Adding a new section means adding a
/// new [SearchSectionType] and folding its hits into [searchResults].

final class SearchResultsProvider
    extends
        $FunctionalProvider<
          AsyncValue<SearchResults>,
          SearchResults,
          FutureOr<SearchResults>
        >
    with $FutureModifier<SearchResults>, $FutureProvider<SearchResults> {
  /// Global search over every registered section.
  ///
  /// Consumes tasks and contacts exclusively through their public barrels
  /// ([tasks_feature], [contacts_feature]). Adding a new section means adding a
  /// new [SearchSectionType] and folding its hits into [searchResults].
  SearchResultsProvider._({
    required SearchResultsFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'searchResultsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$searchResultsHash();

  @override
  String toString() {
    return r'searchResultsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<SearchResults> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<SearchResults> create(Ref ref) {
    final argument = this.argument as String;
    return searchResults(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is SearchResultsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$searchResultsHash() => r'72ab13cc0e530309197dcfe1bed1ee6d61582a62';

/// Global search over every registered section.
///
/// Consumes tasks and contacts exclusively through their public barrels
/// ([tasks_feature], [contacts_feature]). Adding a new section means adding a
/// new [SearchSectionType] and folding its hits into [searchResults].

final class SearchResultsFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<SearchResults>, String> {
  SearchResultsFamily._()
    : super(
        retry: null,
        name: r'searchResultsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Global search over every registered section.
  ///
  /// Consumes tasks and contacts exclusively through their public barrels
  /// ([tasks_feature], [contacts_feature]). Adding a new section means adding a
  /// new [SearchSectionType] and folding its hits into [searchResults].

  SearchResultsProvider call(String query) =>
      SearchResultsProvider._(argument: query, from: this);

  @override
  String toString() => r'searchResultsProvider';
}
