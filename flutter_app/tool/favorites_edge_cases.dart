// Favorites edge-case simulation (manual-QA style).
//
// Probes the favorites toggle (TH-006) the way corrupt data / a double-tap race
// can stress it. The suspect: both DataService.toggleFav and
// FavoritesRepositoryImpl.toggle store a plain List and unfavorite via
// List.remove(), which removes only the FIRST occurrence. If the stored list
// ever holds a company id twice (a legacy/corrupt write, or add() running twice
// before a read), then "unfavorite" removes only one copy — the heart stays
// filled and the user can't un-favorite. There is also no dedup on add.
//
// This models BOTH the old (buggy) behavior and the fixed behavior over an
// in-memory "meta box" so we can assert the invariant a favorites set must
// uphold: after unfavoriting, isFavorite must be false regardless of how many
// duplicate copies were stored. Runs on the plain Dart VM.

int _checks = 0;
int _failures = 0;

void check(String desc, bool ok, [String? detail]) {
  _checks++;
  final tag = ok ? 'PASS' : 'FAIL';
  if (!ok) _failures++;
  print('   $tag  $desc${detail != null ? '  ($detail)' : ''}');
}

void section(String title) => print('\n== $title ==');

/// In-memory stand-in for the Hive `meta` box holding the 'favorites' List.
class FakeMeta {
  Object? _favorites;
  List? get(String _) => _favorites as List?;
  void put(String _, List v) => _favorites = v;
  // Simulate a corrupt/legacy write with duplicates.
  void seed(List<String> raw) => _favorites = List<String>.from(raw);
}

// ------------------------- OLD (buggy) implementation -------------------------
List<String> oldAll(FakeMeta m) =>
    (m.get('favorites'))?.map((e) => e.toString()).toList() ?? <String>[];

bool oldIsFavorite(FakeMeta m, String id) => oldAll(m).contains(id);

bool oldToggle(FakeMeta m, String id) {
  final favs = oldAll(m);
  if (favs.contains(id)) {
    favs.remove(id); // removes only the FIRST occurrence
  } else {
    favs.add(id); // no dedup
  }
  m.put('favorites', favs);
  return favs.contains(id);
}

// ------------------------- NEW (fixed) implementation -------------------------
List<String> newAll(FakeMeta m) {
  final raw = (m.get('favorites'))?.map((e) => e.toString()) ?? const [];
  // De-dupe on read, preserving first-seen order.
  final seen = <String>{};
  final out = <String>[];
  for (final id in raw) {
    if (seen.add(id)) out.add(id);
  }
  return out;
}

bool newIsFavorite(FakeMeta m, String id) => newAll(m).contains(id);

bool newToggle(FakeMeta m, String id) {
  final favs = newAll(m); // already de-duped
  if (favs.contains(id)) {
    favs.removeWhere((e) => e == id); // remove ALL occurrences
  } else {
    favs.add(id);
  }
  m.put('favorites', favs);
  return favs.contains(id);
}

void main() {
  print('Trans-Hub — favorites edge-case simulation\n');

  const c = 'c_acme';

  // ---------------------------------------------------------------------------
  section('FAV 1: happy-path toggle');
  {
    final m = FakeMeta();
    check('starts empty', newAll(m).isEmpty);
    check('toggle on → favorited', newToggle(m, c) == true);
    check('isFavorite true after add', newIsFavorite(m, c));
    check('toggle off → not favorited', newToggle(m, c) == false);
    check('isFavorite false after remove', !newIsFavorite(m, c));
  }

  // ---------------------------------------------------------------------------
  // THE BUG: stored list already contains a duplicate (corrupt/legacy/race).
  section('FAV 2: duplicate in stored list — unfavorite must still work');
  {
    // Demonstrate the OLD behavior is broken.
    final bad = FakeMeta()..seed([c, c]); // two copies
    check('DEMO(old): isFavorite true with dupes', oldIsFavorite(bad, c));
    oldToggle(bad, c); // user taps unfavorite
    check('DEMO(old): STILL favorited after one unfavorite (BUG)',
        oldIsFavorite(bad, c), 'remaining=${oldAll(bad)}');

    // The FIX handles it correctly.
    final good = FakeMeta()..seed([c, c]);
    check('new: isFavorite true with dupes', newIsFavorite(good, c));
    final now = newToggle(good, c);
    check('new: unfavorite clears ALL copies', now == false,
        'remaining=${newAll(good)}');
    check('new: isFavorite false afterwards', !newIsFavorite(good, c));
    check('new: stored list is empty (no orphan copy)', newAll(good).isEmpty,
        'stored=${newAll(good)}');
  }

  // ---------------------------------------------------------------------------
  section('FAV 3: read de-dupes corrupt data');
  {
    final m = FakeMeta()..seed([c, c, 'c_beta', c, 'c_beta']);
    final favs = newAll(m);
    check('duplicates collapsed on read', favs.length == 2, 'got=$favs');
    check('first-seen order preserved', favs.join(',') == 'c_acme,c_beta',
        favs.join(','));
  }

  // ---------------------------------------------------------------------------
  section('FAV 4: add never introduces a duplicate');
  {
    final m = FakeMeta();
    newToggle(m, c); // add
    // Simulate an accidental second add of the same id (double-tap / retry) by
    // seeding a dupe then toggling a DIFFERENT id; the read-dedup keeps it sane.
    m.seed([c, c]);
    newToggle(m, 'c_other'); // add another
    final favs = newAll(m);
    check('no duplicate of c after mixed ops',
        favs.where((e) => e == c).length == 1, 'favs=$favs');
    check('both distinct favorites present',
        favs.contains(c) && favs.contains('c_other'));
  }

  // ---------------------------------------------------------------------------
  section('FAV 5: toggling an unknown id just removes/keeps cleanly');
  {
    final m = FakeMeta()..seed(['c_x']);
    check('toggle new id → favorited', newToggle(m, 'c_y') == true);
    check('both present', newAll(m).toSet().containsAll({'c_x', 'c_y'}));
  }

  // ---------------------------------------------------------------------------
  print('\n${'=' * 60}');
  print('RESULT: ${_checks - _failures}/$_checks checks passed');
  if (_failures > 0) {
    print('$_failures FAILURE(S) — see FAIL lines above.');
  } else {
    print('All favorites invariants hold.');
  }
}
