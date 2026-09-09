/// A kind of searchable record. Extending this enum is not required for a
/// future section to participate — each section is identified by its own
/// [SearchSectionType] — but it drives navigation in the shared overlay.
enum SearchHitType { task, contact }

/// One ranked search result within a section.
class SearchHit {
  const SearchHit({
    required this.id,
    required this.type,
    required this.title,
    this.subtitle,
  });

  final String id;
  final SearchHitType type;
  final String title;
  final String? subtitle;
}

/// The distinct sections the global search can return. This is the SEARCH
/// side of the registry: a future feature adds a new value here plus a
/// section builder, and the overlay renders it automatically.
enum SearchSectionType { tasks, contacts }

/// The ordered results for a single section: the ranked, limited hits a user
/// sees, plus the total matching count so the overlay can offer "show all".
class SearchSectionResult {
  const SearchSectionResult({
    required this.type,
    required this.hits,
    required this.total,
  });

  final SearchSectionType type;

  /// Ranked hits, already limited to the overlay's per-section cap.
  final List<SearchHit> hits;

  /// How many records matched the query before the cap was applied. When
  /// [total] > [hits].length the overlay shows a "show all" action.
  final int total;

  bool get hasMore => total > hits.length;
}

/// Aggregate of every section's search results, in display order.
class SearchResults {
  const SearchResults(this.sections);

  final List<SearchSectionResult> sections;

  bool get isEmpty => sections.every((s) => s.hits.isEmpty);
}