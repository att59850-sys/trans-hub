import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:transport_hub/data/datasources/local/hive_local_datasource.dart';
import 'package:transport_hub/data/repositories/favorites_repository_impl.dart';

/// Favorites-toggle integrity (TH-006). A QA pass (round 8) showed that if the
/// stored favorites list ever held the same company id twice (a legacy/corrupt
/// write or a double-tap race), the old `toggle` used `List.remove` — which
/// drops only the FIRST occurrence — so "unfavorite" silently failed and the
/// heart stayed filled. The repository now de-dupes on read and removes ALL
/// copies on toggle. Hive-backed; runs in CI (may OOM on very low-memory hosts,
/// like the other Hive suites).
void main() {
  late Directory tempDir;
  late HiveLocalDataSource ds;
  late FavoritesRepositoryImpl repo;

  const c = 'c_acme';

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('transhub_fav_');
    Hive.init(tempDir.path);
    ds = HiveLocalDataSource.instance;
    ds.meta = await Hive.openBox(HiveLocalDataSource.metaBox);
    repo = FavoritesRepositoryImpl(ds);
  });

  tearDown(() async {
    await ds.meta.clear();
    await Hive.deleteFromDisk();
    try {
      await tempDir.delete(recursive: true);
    } catch (_) {}
  });

  test('happy-path toggle on/off', () {
    expect(repo.all(), isEmpty);
    expect(repo.toggle(c), true);
    expect(repo.isFavorite(c), true);
    expect(repo.toggle(c), false);
    expect(repo.isFavorite(c), false);
  });

  test('unfavorite works even when the stored list has duplicates', () {
    // Simulate a corrupt/legacy write with two copies of the same id.
    ds.meta.put('favorites', [c, c]);
    expect(repo.isFavorite(c), true);
    // One unfavorite must clear ALL copies.
    expect(repo.toggle(c), false);
    expect(repo.isFavorite(c), false);
    expect(repo.all(), isEmpty);
  });

  test('all() de-dupes corrupt data preserving first-seen order', () {
    ds.meta.put('favorites', [c, c, 'c_beta', c, 'c_beta']);
    expect(repo.all(), ['c_acme', 'c_beta']);
  });

  test('add never leaves a duplicate', () {
    repo.toggle(c);
    // Corrupt the store with a dupe, then toggle a different id.
    ds.meta.put('favorites', [c, c]);
    repo.toggle('c_other');
    expect(repo.all().where((e) => e == c).length, 1);
    expect(repo.all().toSet(), {c, 'c_other'});
  });

  test('toggling a new id keeps existing favorites', () {
    ds.meta.put('favorites', ['c_x']);
    expect(repo.toggle('c_y'), true);
    expect(repo.all().toSet(), {'c_x', 'c_y'});
  });
}
