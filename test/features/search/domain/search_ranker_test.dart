import 'package:flutter_test/flutter_test.dart';
import 'package:taskmaster/features/search/domain/search_models.dart';
import 'package:taskmaster/features/search/domain/search_ranker.dart';

void main() {
  group('rankCompare', () {
    test('prefix match outranks substring match', () {
      expect(rankCompare('Calendar', 'Memo Calendar', 'cal'), lessThan(0));
      expect(rankCompare('Memo Calendar', 'Calendar', 'cal'), greaterThan(0));
    });

    test('empty or spaced query falls back to alphabetical', () {
      expect(rankCompare('apple', 'banana', ''), lessThan(0));
      expect(rankCompare('banana', 'apple', '   '), greaterThan(0));
    });

    test('ties break alphabetically', () {
      expect(rankCompare('beta', 'alpha', 'et'), greaterThan(0));
      expect(rankCompare('alpha', 'beta', 'al'), lessThan(0));
    });

    test('is case-insensitive on both sides', () {
      expect(rankCompare('sprint', 'SPRINT', 'SPR'), 0);
      expect(rankCompare('Design', 'design system', 'design'), lessThan(0));
    });
  });

  group('buildSectionResult', () {
    SearchHit hit(String id, String title) => SearchHit(
          id: id,
          type: SearchHitType.task,
          title: title,
        );

    test('groups, ranks and limits hits while tracking total', () {
      final matches = [
        hit('2', 'Review calendar'),
        hit('1', 'Calendar cleanup'),
      ];
      final result = buildSectionResult(
        type: SearchSectionType.tasks,
        hits: matches,
        query: 'cal',
        limit: 2,
      );

      expect(result.type, SearchSectionType.tasks);
      expect(result.total, 2);
      expect(result.hits.length, 2);
      expect(result.hasMore, isFalse);
      expect(result.hits.map((h) => h.id), ['1', '2']);
    });

    test('exposes hasMore when matches exceed the limit', () {
      final result = buildSectionResult(
        type: SearchSectionType.contacts,
        hits: [
          for (var i = 0; i < 12; i++) hit('$i', 'cal-$i'),
        ],
        query: 'cal',
        limit: 10,
      );

      expect(result.hits.length, 10);
      expect(result.total, 12);
      expect(result.hasMore, isTrue);
    });

    test('keeps repository order stable for empty query', () {
      final result = buildSectionResult(
        type: SearchSectionType.tasks,
        hits: [hit('a', 'Beta'), hit('b', 'Alpha')],
        query: '',
        limit: 10,
      );
      expect(result.hits.map((h) => h.id), ['b', 'a']);
    });
  });

  group('matchesQuery', () {
    test('matches substrings case-insensitively', () {
      expect(matchesQuery('Buy MILK', 'milk'), isTrue);
      expect(matchesQuery('Shopping', 'milk'), isFalse);
    });

    test('empty query matches everything', () {
      expect(matchesQuery('anything', ''), isTrue);
      expect(matchesQuery('anything', '   '), isTrue);
    });
  });
}