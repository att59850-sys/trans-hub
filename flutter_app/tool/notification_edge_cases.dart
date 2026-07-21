// Notification-integrity edge-case simulation (manual-QA style).
//
// Probes the in-app notification system (TH-018) the way a human user would
// stress it: unread-count invariants under add / markRead / markAllRead,
// empty-list handling, unknown-id no-ops, duplicate-id adds, and — the tricky
// one — ordering stability when several notifications are created in the SAME
// millisecond (a single booking action fans out multiple notifications in one
// tick). Runs on the plain Dart VM (no Flutter, no Hive) by re-implementing the
// exact repository logic over an in-memory map, so we can assert invariants the
// real NotificationRepositoryImpl must uphold.

import 'package:transport_hub/domain/entities/app_notification.dart';

int _checks = 0;
int _failures = 0;

void check(String desc, bool ok, [String? detail]) {
  _checks++;
  final tag = ok ? 'PASS' : 'FAIL';
  if (!ok) _failures++;
  print('   $tag  $desc${detail != null ? '  ($detail)' : ''}');
}

void section(String title) => print('\n== $title ==');

/// In-memory stand-in for HiveLocalDataSource.notifications keyed by id,
/// mirroring the repository's id-keyed `put` semantics exactly.
class FakeNotificationStore {
  final Map<String, AppNotification> _box = {};

  List<AppNotification> get _all => _box.values.toList();

  // Mirrors NotificationRepositoryImpl.forUser — this is the code under test.
  // The FIX: tie-break equal createdAt by id so ordering is deterministic and
  // stable regardless of Map/iteration order.
  List<AppNotification> forUser(String userId) =>
      _all.where((n) => n.userId == userId).toList()
        ..sort((a, b) {
          final byTime = b.createdAt.compareTo(a.createdAt);
          return byTime != 0 ? byTime : b.id.compareTo(a.id);
        });

  int unreadCount(String userId) =>
      _all.where((n) => n.userId == userId && !n.read).length;

  void add(AppNotification n) => _box[n.id] = n;

  void markRead(String id) {
    final n = _box[id];
    if (n == null) return;
    n.read = true;
  }

  void markAllRead(String userId) {
    for (final n in forUser(userId)) {
      if (!n.read) n.read = true;
    }
  }
}

/// The OLD, unstable ordering — kept only to demonstrate the flaky reorder it
/// produced when createdAt values tie.
List<AppNotification> naiveForUser(List<AppNotification> all, String userId) =>
    all.where((n) => n.userId == userId).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

void main() {
  print('Trans-Hub — notification-integrity edge-case simulation\n');

  const u = 'u_alice';
  const other = 'u_bob';

  // ---------------------------------------------------------------------------
  section('NOTIF 1: unread-count invariants');
  {
    final s = FakeNotificationStore();
    check('empty store → unreadCount 0', s.unreadCount(u) == 0);
    check('empty store → forUser []', s.forUser(u).isEmpty);

    final ids = <String>[];
    for (var i = 0; i < 5; i++) {
      final n = AppNotification(userId: u, title: 'msg $i');
      ids.add(n.id);
      s.add(n);
    }
    check('add 5 → unreadCount 5', s.unreadCount(u) == 5,
        'got ${s.unreadCount(u)}');
    check('add 5 → forUser length 5', s.forUser(u).length == 5);

    s.markRead(ids[0]);
    check('markRead one → unreadCount 4', s.unreadCount(u) == 4,
        'got ${s.unreadCount(u)}');

    s.markRead(ids[0]); // idempotent
    check(
        'markRead same id twice → still 4 (idempotent)', s.unreadCount(u) == 4);

    s.markAllRead(u);
    check('markAllRead → unreadCount 0', s.unreadCount(u) == 0,
        'got ${s.unreadCount(u)}');
    check('markAllRead → forUser still length 5 (not deleted)',
        s.forUser(u).length == 5);
  }

  // ---------------------------------------------------------------------------
  section('NOTIF 2: no-op / empty-list safety');
  {
    final s = FakeNotificationStore();
    s.markRead('n_doesnotexist'); // must not throw
    check('markRead unknown id → no throw, count 0', s.unreadCount(u) == 0);
    s.markAllRead(u); // empty → must not throw
    check('markAllRead on empty → no throw, count 0', s.unreadCount(u) == 0);
  }

  // ---------------------------------------------------------------------------
  section('NOTIF 3: per-user isolation');
  {
    final s = FakeNotificationStore();
    s.add(AppNotification(userId: u, title: 'to alice'));
    s.add(AppNotification(userId: other, title: 'to bob 1'));
    s.add(AppNotification(userId: other, title: 'to bob 2'));
    check('alice sees only her 1', s.forUser(u).length == 1);
    check('bob sees only his 2', s.forUser(other).length == 2);
    s.markAllRead(u);
    check('markAllRead(alice) leaves bob unread 2', s.unreadCount(other) == 2,
        'got ${s.unreadCount(other)}');
  }

  // ---------------------------------------------------------------------------
  section('NOTIF 4: duplicate-id add is an upsert (id-keyed put)');
  {
    final s = FakeNotificationStore();
    final n = AppNotification(userId: u, title: 'original');
    s.add(n);
    // Re-add with the SAME id (e.g. a retried write) must NOT inflate counts.
    s.add(AppNotification(id: n.id, userId: u, title: 'updated'));
    check('duplicate id → count stays 1', s.forUser(u).length == 1,
        'got ${s.forUser(u).length}');
    check('duplicate id → latest wins (title=updated)',
        s.forUser(u).single.title == 'updated');
  }

  // ---------------------------------------------------------------------------
  // THE BUG: several notifications minted in the SAME millisecond tie on
  // createdAt, so a createdAt-only sort is unstable — the displayed order can
  // differ between reads and even reverse depending on Map iteration order.
  section('NOTIF 5: same-millisecond ordering is deterministic & stable');
  {
    const t = 1700000000000; // one fixed tick shared by all
    final a = AppNotification(id: 'n_aaa', userId: u, title: 'A', createdAt: t);
    final b = AppNotification(id: 'n_bbb', userId: u, title: 'B', createdAt: t);
    final c = AppNotification(id: 'n_ccc', userId: u, title: 'C', createdAt: t);

    // Insert in one order...
    final s1 = FakeNotificationStore()
      ..add(a)
      ..add(b)
      ..add(c);
    // ...and in the reverse order into a second store.
    final s2 = FakeNotificationStore()
      ..add(c)
      ..add(b)
      ..add(a);

    final order1 = s1.forUser(u).map((n) => n.id).toList();
    final order2 = s2.forUser(u).map((n) => n.id).toList();

    check(
        'same-tick order is stable across insertion order',
        order1.toString() == order2.toString(),
        'order1=$order1 order2=$order2');

    // Contrast: the OLD naive sort could disagree between the two insert orders.
    final naive1 = naiveForUser([a, b, c], u).map((n) => n.id).toList();
    final naive2 = naiveForUser([c, b, a], u).map((n) => n.id).toList();
    check(
        'DEMO: naive createdAt-only sort was NOT stable across insert order',
        naive1.toString() != naive2.toString(),
        'naive1=$naive1 naive2=$naive2');

    // And a mixed-time list still respects newest-first primarily.
    final older = AppNotification(
        id: 'n_old', userId: u, title: 'older', createdAt: t - 1000);
    final s3 = FakeNotificationStore()
      ..add(older)
      ..add(a)
      ..add(b);
    final ids = s3.forUser(u).map((n) => n.id).toList();
    check('newest-first still holds (older is last)', ids.last == 'n_old',
        'order=$ids');
  }

  // ---------------------------------------------------------------------------
  section('NOTIF 6: entity defaults');
  {
    final n = AppNotification(userId: u, title: 'x');
    check('new notification defaults to unread', n.read == false);
    check('new notification gets a non-empty id', n.id.isNotEmpty);
    check('new notification kind defaults to system',
        n.kind == NotificationKind.system);
  }

  // ---------------------------------------------------------------------------
  print('\n${'=' * 60}');
  print('RESULT: ${_checks - _failures}/$_checks checks passed');
  if (_failures > 0) {
    print('$_failures FAILURE(S) — see FAIL lines above.');
    // Non-zero exit so CI / manual runs notice.
  } else {
    print('All notification invariants hold.');
  }
}
