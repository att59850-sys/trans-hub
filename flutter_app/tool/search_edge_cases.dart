// Browse/search edge-case simulation (manual-QA style).
//
// QA round 10 acts as a user typing into the Browse search box. The filter in
// browse_screen.dart matched with the RAW query text:
//
//   if (_query.isNotEmpty) {
//     final hay = (...).toLowerCase();
//     if (!hay.contains(_query.toLowerCase())) return false;
//   }
//
// Two real, user-facing defects fall out of that:
//   1. The query is never trimmed. A trailing/leading space — extremely common
//      from mobile autocomplete/keyboards — makes `hay.contains(" acme ")` fail
//      even though "Acme" exists, so the user sees "No providers found".
//   2. A whitespace-only query ("   ") is `isNotEmpty`, so it runs a
//      `contains("   ")` that matches nothing → an all-empty result for what is
//      effectively an empty search.
//
// This runs on the plain Dart VM (models.dart is pure Dart) by comparing the
// OLD inline matcher against the new SearchMatcher helper the widget now uses.

import 'package:transport_hub/core/utils/search_matcher.dart';
import 'package:transport_hub/models/models.dart';

int _checks = 0;
int _failures = 0;

void check(String desc, bool ok, [String? detail]) {
  _checks++;
  final tag = ok ? 'PASS' : 'FAIL';
  if (!ok) _failures++;
  print('   $tag  $desc${detail != null ? '  ($detail)' : ''}');
}

void section(String title) => print('\n== $title ==');

/// The OLD, undefended inline matcher — kept only to demonstrate the defect.
bool oldMatches(Company c, String query) {
  if (query.isEmpty) return true;
  final hay =
      ('${c.name} ${c.tagline} ${c.city} ${c.services.map((s) => s.name).join(' ')} ${categoryById(c.category).name}')
          .toLowerCase();
  return hay.contains(query.toLowerCase());
}

List<Company> sampleCompanies() => [
      Company(
        ownerId: 'o1',
        name: 'Acme Freight',
        tagline: 'Nationwide haulage',
        city: 'Boston',
        category: 'freight',
        services: [TransportService(name: 'Same-day courier')],
      ),
      Company(
        ownerId: 'o2',
        name: 'Zephyr Movers',
        tagline: 'Home & office relocation',
        city: 'Seattle',
        category: 'movers',
        services: [TransportService(name: 'Packing')],
      ),
      Company(
        ownerId: 'o3',
        name: 'blue Ocean Logistics',
        tagline: 'Ocean & air freight',
        city: 'Miami',
        category: 'freight',
        services: [TransportService(name: 'Customs clearance')],
      ),
    ];

List<Company> filter(List<Company> all, String query,
        {required bool useNew}) =>
    all
        .where((c) => useNew
            ? SearchMatcher.matches(c.searchHaystack, query)
            : oldMatches(c, query))
        .toList();

void main() {
  print('Trans-Hub — browse/search edge-case simulation\n');

  final companies = sampleCompanies();

  // ---------------------------------------------------------------------------
  section('SEARCH 1: the raw (undefended) defect');
  {
    final oldHit = filter(companies, ' acme ', useNew: false);
    check('DEMO: old matcher misses "Acme" for query " acme " (trailing space)',
        oldHit.isEmpty, 'old matched ${oldHit.length}');

    final oldWs = filter(companies, '   ', useNew: false);
    check('DEMO: old matcher returns NOTHING for whitespace-only query',
        oldWs.isEmpty, 'old matched ${oldWs.length}');
  }

  // ---------------------------------------------------------------------------
  section('SEARCH 2: trimmed query matches regardless of stray spaces');
  {
    for (final q in ['acme', ' acme', 'acme ', '  acme  ', 'ACME', 'AcMe']) {
      final hit = filter(companies, q, useNew: true);
      check('query "$q" finds Acme Freight',
          hit.any((c) => c.name == 'Acme Freight'), '${hit.length} hit(s)');
    }
  }

  // ---------------------------------------------------------------------------
  section('SEARCH 3: whitespace-only query is treated as empty (matches all)');
  {
    for (final q in ['', '   ', '\t', ' \n ']) {
      final hit = filter(companies, q, useNew: true);
      check('blank query ${q.isEmpty ? '""' : '(whitespace)'} matches all',
          hit.length == companies.length, '${hit.length}/${companies.length}');
    }
  }

  // ---------------------------------------------------------------------------
  section('SEARCH 4: matches across all indexed fields, case-insensitively');
  {
    check(
        'by city "seattle"',
        filter(companies, 'SEATTLE', useNew: true).single.name ==
            'Zephyr Movers');
    check(
        'by tagline "relocation"',
        filter(companies, 'relocation', useNew: true).single.name ==
            'Zephyr Movers');
    check(
        'by service "customs"',
        filter(companies, 'customs', useNew: true).single.name ==
            'blue Ocean Logistics');
    check('by category "freight" (2 companies)',
        filter(companies, 'freight', useNew: true).length == 2);
    check('no match for gibberish',
        filter(companies, 'zzznope', useNew: true).isEmpty);
  }

  // ---------------------------------------------------------------------------
  section('SEARCH 5: alphabetical name sort is case-insensitive');
  {
    final byNameOld = [...companies]..sort((a, b) => a.name.compareTo(b.name));
    // ASCII: "Acme" < "Zephyr" < "blue" (lowercase 'b' > uppercase 'Z'),
    // so the old case-sensitive sort mis-places "blue Ocean" AFTER "Zephyr".
    check(
        'DEMO: case-sensitive sort mis-orders "blue Ocean" after "Zephyr"',
        byNameOld.last.name == 'blue Ocean Logistics',
        byNameOld.map((c) => c.name).toList().toString());

    final byNameNew = [...companies]
      ..sort((a, b) => SearchMatcher.compareNames(a.name, b.name));
    check(
        'case-insensitive sort: Acme, blue Ocean, Zephyr',
        byNameNew.map((c) => c.name).toList().toString() ==
            ['Acme Freight', 'blue Ocean Logistics', 'Zephyr Movers']
                .toString(),
        byNameNew.map((c) => c.name).toList().toString());
  }

  // ---------------------------------------------------------------------------
  print('\n${'=' * 60}');
  print('RESULT: ${_checks - _failures}/$_checks checks passed');
  if (_failures > 0) {
    print('$_failures FAILURE(S) — see FAIL lines above.');
  } else {
    print('All browse/search invariants hold.');
  }
}
