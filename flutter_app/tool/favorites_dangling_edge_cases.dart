// QA round 17 — favorites vs. vanished companies (pure-Dart harness).
//
// A human user saves a few providers, then one of those companies disappears
// (a provider removes their listing, or a sync `_pull` server-wins prune drops
// a company the server no longer has). The stored favorites list keeps the
// dangling id forever:
//
//   * the "Saved providers" count is inflated by unreachable ids, and
//   * any code that resolves favorite ids -> Company via firstWhere would throw
//     (a StateError) the moment it hits a vanished id.
//
// This harness reproduces both hazards against a faithful re-implementation of
// DataService.favorites (de-dupe on read) and validates a null-safe
// `favoriteCompanies` resolver that drops dangling ids while preserving order.
//
// Run: dart run tool/favorites_dangling_edge_cases.dart

int _passed = 0;
int _failed = 0;

void check(String name, bool cond) {
  if (cond) {
    _passed++;
    print('  ok   $name');
  } else {
    _failed++;
    print('  FAIL $name');
  }
}

/// Minimal company stand-in.
class Co {
  Co(this.id, this.name);
  final String id;
  final String name;
}

/// Mirrors DataService.favorites: de-dupe on read, preserve first-seen order.
List<String> favoritesOf(List<String> raw) {
  final seen = <String>{};
  final out = <String>[];
  for (final id in raw) {
    if (seen.add(id)) out.add(id);
  }
  return out;
}

/// Null-safe company lookup, mirroring DataService.company(id).
Co? companyById(List<Co> all, String id) {
  for (final c in all) {
    if (c.id == id) return c;
  }
  return null;
}

/// RAW resolver a naive caller might write: firstWhere throws on a missing id.
List<Co> rawFavoriteCompanies(List<String> favIds, List<Co> all) {
  return favIds.map((id) => all.firstWhere((c) => c.id == id)).toList();
}

/// FIXED resolver: map each id through the null-safe lookup, drop danglers,
/// preserve order.
List<Co> favoriteCompanies(List<String> favIds, List<Co> all) {
  final out = <Co>[];
  for (final id in favIds) {
    final c = companyById(all, id);
    if (c != null) out.add(c);
  }
  return out;
}

/// FIXED reachable-count for the account screen.
int reachableFavoriteCount(List<String> favIds, List<Co> all) =>
    favoriteCompanies(favIds, all).length;

void main() {
  print('== QA round 17: favorites vs. vanished companies ==\n');

  final companies = [
    Co('c1', 'Acme Freight'),
    Co('c2', 'Blue Movers'),
    // c3 has vanished (removed / pruned by sync).
  ];
  // The user favorited c1, c3 (now gone), c2 — with a stray duplicate of c1.
  final storedRaw = ['c1', 'c3', 'c2', 'c1'];

  print('-- de-dupe still works (regression) --');
  {
    final favs = favoritesOf(storedRaw);
    check('duplicate c1 collapses', favs.length == 3);
    check('order preserved (c1, c3, c2)',
        favs[0] == 'c1' && favs[1] == 'c3' && favs[2] == 'c2');
  }

  print('\n-- raw defect: count inflated + resolver throws on danglers --');
  {
    final favs = favoritesOf(storedRaw);
    // The naive "Saved providers" count includes the vanished c3.
    check('RAW BUG: raw count is 3 (includes vanished c3)', favs.length == 3);

    var threw = false;
    try {
      rawFavoriteCompanies(favs, companies);
    } catch (_) {
      threw = true;
    }
    check('RAW BUG: firstWhere resolver throws on the dangling id', threw);
  }

  print('\n-- fixed: dangling favorites are dropped on resolve --');
  {
    final favs = favoritesOf(storedRaw);
    final resolved = favoriteCompanies(favs, companies);
    check('resolves to 2 live companies', resolved.length == 2);
    check(
        'order preserved (Acme then Blue)',
        resolved[0].name == 'Acme Freight' &&
            resolved[1].name == 'Blue Movers');
    check('vanished c3 is not present', !resolved.any((c) => c.id == 'c3'));
  }

  print(
      '\n-- fixed: reachable count matches what the user can actually open --');
  {
    final favs = favoritesOf(storedRaw);
    check('reachable favorite count is 2, not 3',
        reachableFavoriteCount(favs, companies) == 2);
  }

  print('\n-- fixed: all-vanished favorites -> empty, no crash --');
  {
    final favs = favoritesOf(['x1', 'x2']);
    check('no live companies resolve',
        favoriteCompanies(favs, companies).isEmpty);
    check('reachable count is 0', reachableFavoriteCount(favs, companies) == 0);
  }

  print('\n-- fixed: empty favorites -> empty --');
  {
    check('empty stays empty', favoriteCompanies(const [], companies).isEmpty);
  }

  print('\n-- fixed: no vanished companies -> unchanged --');
  {
    final favs = favoritesOf(['c2', 'c1']);
    final resolved = favoriteCompanies(favs, companies);
    check('both resolve', resolved.length == 2);
    check('order still honours the favorites list (c2 first)',
        resolved.first.id == 'c2');
  }

  print('\n== $_passed passed, $_failed failed ==');
  if (_failed > 0) {
    throw StateError('favorites dangling edge cases failed');
  }
}
