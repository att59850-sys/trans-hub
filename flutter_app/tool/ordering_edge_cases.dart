// Ordering-stability edge-case simulation (manual-QA style).
//
// QA round 7 was a *systemic* sweep: an audit of every `.sort()` in lib/ turned
// up FIVE more time-ordered lists (bookings, reviews at both the repository and
// DataService layers, and the admin verification queue) that still sorted by
// `createdAt` alone — the same unstable-on-ms-tie defect fixed for
// notifications (round 5) and the sync queue (round 6). This exercises the new
// shared `Ordering` helper that all of them now use, proving newest-first /
// oldest-first orderings are deterministic and stable regardless of insertion
// order. Runs on the plain Dart VM.

import 'package:transport_hub/core/utils/ordering.dart';

int _checks = 0;
int _failures = 0;

void check(String desc, bool ok, [String? detail]) {
  _checks++;
  final tag = ok ? 'PASS' : 'FAIL';
  if (!ok) _failures++;
  print('   $tag  $desc${detail != null ? '  ($detail)' : ''}');
}

void section(String title) => print('\n== $title ==');

/// Minimal time-ordered record: just the two fields ordering depends on.
class Rec {
  Rec(this.id, this.createdAt);
  final String id;
  final int createdAt;
  @override
  String toString() => id;
}

List<String> sortNewest(List<Rec> recs) => (recs.toList()
      ..sort(
          (a, b) => Ordering.newestFirst(a.createdAt, a.id, b.createdAt, b.id)))
    .map((r) => r.id)
    .toList();

List<String> sortOldest(List<Rec> recs) => (recs.toList()
      ..sort(
          (a, b) => Ordering.oldestFirst(a.createdAt, a.id, b.createdAt, b.id)))
    .map((r) => r.id)
    .toList();

// The OLD undefended comparators, kept only to demonstrate the instability.
List<String> naiveNewest(List<Rec> recs) =>
    (recs.toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt)))
        .map((r) => r.id)
        .toList();

void main() {
  print('Trans-Hub — ordering-stability edge-case simulation\n');

  const t = 1700000000000;

  // ---------------------------------------------------------------------------
  section('ORD 1: distinct timestamps sort correctly');
  {
    final recs = [Rec('r_b', t + 2), Rec('r_a', t + 1), Rec('r_c', t + 3)];
    check('newestFirst → c,b,a', sortNewest(recs).join(',') == 'r_c,r_b,r_a',
        sortNewest(recs).join(','));
    check('oldestFirst → a,b,c', sortOldest(recs).join(',') == 'r_a,r_b,r_c',
        sortOldest(recs).join(','));
  }

  // ---------------------------------------------------------------------------
  section('ORD 2: same-millisecond ties are deterministic & stable');
  {
    final a = Rec('r_aaa', t);
    final b = Rec('r_bbb', t);
    final c = Rec('r_ccc', t);

    // Same three records, three different insertion orders.
    final o1 = sortNewest([a, b, c]);
    final o2 = sortNewest([c, b, a]);
    final o3 = sortNewest([b, a, c]);
    check(
        'newestFirst identical across all insertion orders',
        o1.toString() == o2.toString() && o2.toString() == o3.toString(),
        'o1=$o1 o2=$o2 o3=$o3');
    check('newestFirst tie-break is descending id (ccc,bbb,aaa)',
        o1.join(',') == 'r_ccc,r_bbb,r_aaa', o1.join(','));

    final p1 = sortOldest([a, b, c]);
    final p2 = sortOldest([c, b, a]);
    check('oldestFirst identical across insertion orders',
        p1.toString() == p2.toString(), 'p1=$p1 p2=$p2');
    check('oldestFirst tie-break is ascending id (aaa,bbb,ccc)',
        p1.join(',') == 'r_aaa,r_bbb,r_ccc', p1.join(','));

    // Contrast: the OLD naive newest-first was NOT stable across insert order.
    check(
        'DEMO: naive createdAt-only sort was NOT stable across insert order',
        naiveNewest([a, b, c]).toString() != naiveNewest([c, b, a]).toString(),
        '${naiveNewest([a, b, c])} vs ${naiveNewest([c, b, a])}');
  }

  // ---------------------------------------------------------------------------
  section('ORD 3: mixed ties + distinct times keep time as the primary key');
  {
    final older = Rec('r_z_older', t - 1000); // id sorts LAST alphabetically
    final tieA = Rec('r_a', t);
    final tieB = Rec('r_b', t);
    final newest = Rec('r_a_newest', t + 5000);

    final newestOrder = sortNewest([older, tieA, tieB, newest]);
    check('newest by time is first even if its id sorts early',
        newestOrder.first == 'r_a_newest', 'order=$newestOrder');
    check('older by time is last even if its id sorts late',
        newestOrder.last == 'r_z_older', 'order=$newestOrder');
    check(
        'the two same-ms items keep descending-id order between them',
        newestOrder.indexOf('r_b') < newestOrder.indexOf('r_a'),
        'order=$newestOrder');
  }

  // ---------------------------------------------------------------------------
  section('ORD 4: single element & empty are no-ops');
  {
    check(
        'single element newestFirst', sortNewest([Rec('x', t)]).join() == 'x');
    check('empty list newestFirst', sortNewest(<Rec>[]).isEmpty);
    check('empty list oldestFirst', sortOldest(<Rec>[]).isEmpty);
  }

  // ---------------------------------------------------------------------------
  print('\n${'=' * 60}');
  print('RESULT: ${_checks - _failures}/$_checks checks passed');
  if (_failures > 0) {
    print('$_failures FAILURE(S) — see FAIL lines above.');
  } else {
    print('All ordering invariants hold.');
  }
}
