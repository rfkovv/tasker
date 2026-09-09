import 'search_models.dart';

/// Builds a [SearchSectionResult] from the full set of matching records of a
/// single section.
///
/// Ranking (case-insensitive) is per the spec: title prefix matches rank
/// above substring matches, then alphabetically. The returned hits are
/// truncated to [limit] while [total] reflects every match, enabling the
/// "show all" affordance.
SearchSectionResult buildSectionResult({
  required SearchSectionType type,
  required Iterable<SearchHit> hits,
  required String query,
  required int limit,
}) {
  final q = query.trim();
  final sorted = hits.toList()
    ..sort((a, b) => rankCompare(a.title, b.title, q));
  return SearchSectionResult(
    type: type,
    hits: sorted.take(limit).toList(),
    total: sorted.length,
  );
}

/// Ranks two titles against [query] (case-insensitive): a prefix match
/// outranks a substring match; ties break alphabetically.
int rankCompare(String a, String b, String query) {
  final q = query.toLowerCase().trim();
  final qa = a.toLowerCase();
  final qb = b.toLowerCase();

  final aPrefix = q.isNotEmpty && qa.startsWith(q);
  final bPrefix = q.isNotEmpty && qb.startsWith(q);
  if (aPrefix != bPrefix) return aPrefix ? -1 : 1;

  final aIndex = q.isEmpty ? 0 : qa.indexOf(q);
  final bIndex = q.isEmpty ? 0 : qb.indexOf(q);
  if (aIndex != bIndex) return aIndex.compareTo(bIndex);

  return qa.compareTo(qb);
}

/// Case-insensitive substring match used to decide whether a record belongs
/// to the result set for [query].
bool matchesQuery(String value, String query) {
  final q = query.trim();
  if (q.isEmpty) return true;
  return value.toLowerCase().contains(q.toLowerCase());
}