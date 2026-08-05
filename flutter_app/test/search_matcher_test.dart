import 'package:flutter_test/flutter_test.dart';
import 'package:transport_hub/core/utils/search_matcher.dart';
import 'package:transport_hub/models/models.dart';

/// Browse search/sort rules (QA round 10). The old inline filter matched with
/// the RAW query, so a trailing/leading space hid real matches and a
/// whitespace-only query blanked the list; the name sort was case-sensitive,
/// mis-ordering lowercase initials. These are now centralized in SearchMatcher.
void main() {
  Company company({
    required String name,
    String tagline = '',
    String city = '',
    String category = 'freight',
    List<String> services = const [],
  }) =>
      Company(
        ownerId: 'o',
        name: name,
        tagline: tagline,
        city: city,
        category: category,
        services: [for (final s in services) TransportService(name: s)],
      );

  group('SearchMatcher.matches', () {
    final acme = company(
      name: 'Acme Freight',
      tagline: 'Nationwide haulage',
      city: 'Boston',
      services: ['Same-day courier'],
    );

    test('trims stray whitespace so it never hides a real match', () {
      for (final q in ['acme', ' acme', 'acme ', '  acme  ']) {
        expect(SearchMatcher.matches(acme.searchHaystack, q), isTrue,
            reason: '"$q"');
      }
    });

    test('is case-insensitive', () {
      expect(SearchMatcher.matches(acme.searchHaystack, 'ACME'), isTrue);
      expect(SearchMatcher.matches(acme.searchHaystack, 'AcMe'), isTrue);
    });

    test('a blank / whitespace-only query matches everything', () {
      for (final q in ['', '   ', '\t', ' \n ']) {
        expect(SearchMatcher.matches(acme.searchHaystack, q), isTrue,
            reason: '"$q"');
      }
    });

    test('matches across name, tagline, city, services and category label', () {
      expect(SearchMatcher.matches(acme.searchHaystack, 'boston'), isTrue);
      expect(SearchMatcher.matches(acme.searchHaystack, 'haulage'), isTrue);
      expect(SearchMatcher.matches(acme.searchHaystack, 'courier'), isTrue);
      expect(SearchMatcher.matches(acme.searchHaystack, 'freight'), isTrue);
      expect(SearchMatcher.matches(acme.searchHaystack, 'zzznope'), isFalse);
    });
  });

  group('SearchMatcher.compareNames', () {
    test('sorts alphabetically ignoring case', () {
      final names = ['Zephyr Movers', 'blue Ocean', 'Acme Freight']
        ..sort(SearchMatcher.compareNames);
      expect(names, ['Acme Freight', 'blue Ocean', 'Zephyr Movers']);
    });

    test('is deterministic on case-only differences', () {
      expect(SearchMatcher.compareNames('abc', 'ABC'), isNot(0));
      // Same letters, differing case -> stable, non-zero, and symmetric sign.
      final ab = SearchMatcher.compareNames('abc', 'ABC');
      final ba = SearchMatcher.compareNames('ABC', 'abc');
      expect(ab, -ba);
    });
  });
}
