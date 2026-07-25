import 'package:flutter_test/flutter_test.dart';
import 'package:transport_hub/core/utils/ordering.dart';

/// Stable-ordering invariants (QA round 7 sweep). Several records can share the
/// same `createdAt` millisecond; the shared [Ordering] comparators tie-break by
/// id so newest-first / oldest-first lists are deterministic and stable
/// regardless of insertion order. Pure Dart — lightweight in CI.
void main() {
  ({int t, String id}) rec(String id, int t) => (t: t, id: id);

  List<String> newest(List<({int t, String id})> recs) => (recs.toList()
        ..sort((a, b) => Ordering.newestFirst(a.t, a.id, b.t, b.id)))
      .map((r) => r.id)
      .toList();

  List<String> oldest(List<({int t, String id})> recs) => (recs.toList()
        ..sort((a, b) => Ordering.oldestFirst(a.t, a.id, b.t, b.id)))
      .map((r) => r.id)
      .toList();

  const t = 1700000000000;

  test('distinct timestamps sort by time', () {
    final recs = [rec('b', t + 2), rec('a', t + 1), rec('c', t + 3)];
    expect(newest(recs), ['c', 'b', 'a']);
    expect(oldest(recs), ['a', 'b', 'c']);
  });

  test('same-millisecond ties are stable across insertion order', () {
    final a = rec('aaa', t), b = rec('bbb', t), c = rec('ccc', t);
    expect(newest([a, b, c]), newest([c, b, a]));
    expect(newest([b, a, c]), newest([c, b, a]));
    expect(oldest([a, b, c]), oldest([c, b, a]));
  });

  test('tie-break direction matches sort direction', () {
    final a = rec('aaa', t), b = rec('bbb', t), c = rec('ccc', t);
    expect(newest([a, b, c]), ['ccc', 'bbb', 'aaa']); // descending id
    expect(oldest([a, b, c]), ['aaa', 'bbb', 'ccc']); // ascending id
  });

  test('time remains the primary key even when ids would reorder', () {
    final older = rec('z_older', t - 1000);
    final tieA = rec('a', t);
    final tieB = rec('b', t);
    final newer = rec('a_newest', t + 5000);
    final order = newest([older, tieA, tieB, newer]);
    expect(order.first, 'a_newest');
    expect(order.last, 'z_older');
    expect(order.indexOf('b'), lessThan(order.indexOf('a')));
  });

  test('empty and single-element are no-ops', () {
    expect(newest(const []), isEmpty);
    expect(newest([rec('x', t)]), ['x']);
  });
}
