import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:transport_hub/data/datasources/local/hive_local_datasource.dart';
import 'package:transport_hub/data/repositories/notification_repository_impl.dart';
import 'package:transport_hub/domain/entities/app_notification.dart';

/// Notification-integrity enforcement (TH-018). A QA pass (round 5) showed that
/// notifications minted in the SAME millisecond — a single action can fan out
/// several at once — sorted only by `createdAt` had a non-deterministic order
/// at the mercy of Hive iteration order, so the list could reorder/flicker
/// between reads. `forUser` now tie-breaks equal timestamps by id so ordering
/// is deterministic and stable. Hive-backed; runs in CI (may OOM on very
/// low-memory hosts, like the other Hive suites).
void main() {
  late Directory tempDir;
  late HiveLocalDataSource ds;
  late NotificationRepositoryImpl repo;

  const u = 'u_alice';
  const other = 'u_bob';

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('transhub_notif_');
    Hive.init(tempDir.path);
    ds = HiveLocalDataSource.instance;
    ds.notifications = await Hive.openBox(HiveLocalDataSource.notificationsBox);
    repo = NotificationRepositoryImpl(ds);
  });

  tearDown(() async {
    await ds.notifications.clear();
    await Hive.deleteFromDisk();
    try {
      await tempDir.delete(recursive: true);
    } catch (_) {}
  });

  test('unread count tracks add / markRead / markAllRead', () {
    final ids = <String>[];
    for (var i = 0; i < 5; i++) {
      final n = AppNotification(userId: u, title: 'msg $i');
      ids.add(n.id);
      repo.add(n);
    }
    expect(repo.unreadCount(u), 5);

    repo.markRead(ids.first);
    expect(repo.unreadCount(u), 4);

    repo.markRead(ids.first); // idempotent
    expect(repo.unreadCount(u), 4);

    repo.markAllRead(u);
    expect(repo.unreadCount(u), 0);
    // Marking read must not delete: the history is still visible.
    expect(repo.forUser(u).length, 5);
  });

  test('no-op safety: unknown id and empty user do not throw', () {
    repo.markRead('n_doesnotexist');
    repo.markAllRead(u);
    expect(repo.unreadCount(u), 0);
    expect(repo.forUser(u), isEmpty);
  });

  test('per-user isolation', () {
    repo.add(AppNotification(userId: u, title: 'to alice'));
    repo.add(AppNotification(userId: other, title: 'to bob 1'));
    repo.add(AppNotification(userId: other, title: 'to bob 2'));
    expect(repo.forUser(u).length, 1);
    expect(repo.forUser(other).length, 2);
    repo.markAllRead(u);
    expect(repo.unreadCount(other), 2);
  });

  test('duplicate-id add is an upsert (count stays, latest wins)', () {
    final n = AppNotification(userId: u, title: 'original');
    repo.add(n);
    repo.add(AppNotification(id: n.id, userId: u, title: 'updated'));
    expect(repo.forUser(u).length, 1);
    expect(repo.forUser(u).single.title, 'updated');
  });

  test('same-millisecond ordering is deterministic & stable', () {
    const t = 1700000000000; // one fixed tick shared by all
    final a = AppNotification(id: 'n_aaa', userId: u, title: 'A', createdAt: t);
    final b = AppNotification(id: 'n_bbb', userId: u, title: 'B', createdAt: t);
    final c = AppNotification(id: 'n_ccc', userId: u, title: 'C', createdAt: t);

    // Insert in one order, read the order back.
    repo.add(a);
    repo.add(b);
    repo.add(c);
    final order1 = repo.forUser(u).map((n) => n.id).toList();

    // Wipe and insert in the REVERSE order; order must be identical.
    ds.notifications.clear();
    repo.add(c);
    repo.add(b);
    repo.add(a);
    final order2 = repo.forUser(u).map((n) => n.id).toList();

    expect(order1, order2);
    // Deterministic tie-break: descending id.
    expect(order1, ['n_ccc', 'n_bbb', 'n_aaa']);
  });

  test('newest-first still holds across differing timestamps', () {
    const t = 1700000000000;
    repo.add(AppNotification(
        id: 'n_old', userId: u, title: 'old', createdAt: t - 1000));
    repo.add(
        AppNotification(id: 'n_new', userId: u, title: 'new', createdAt: t));
    expect(repo.forUser(u).first.id, 'n_new');
    expect(repo.forUser(u).last.id, 'n_old');
  });
}
