import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:transport_hub/data/datasources/local/hive_local_datasource.dart';
import 'package:transport_hub/data/models/review_dto.dart';
import 'package:transport_hub/data/repositories/review_repository_impl.dart';
import 'package:transport_hub/domain/entities/entities.dart';

/// Review-integrity enforcement (rating bounds). A QA pass showed that an
/// out-of-range rating (e.g. 999) would skew a company's displayed average;
/// the repository now clamps ratings on both write and read. Hive-backed; runs
/// in CI (may OOM on very low-memory hosts, like the other Hive suites).
void main() {
  late Directory tempDir;
  late HiveLocalDataSource ds;
  late ReviewRepositoryImpl repo;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('transhub_review_');
    Hive.init(tempDir.path);
    ds = HiveLocalDataSource.instance;
    ds.reviews = await Hive.openBox(HiveLocalDataSource.reviewsBox);
    repo = ReviewRepositoryImpl(ds);
  });

  tearDown(() async {
    await ds.reviews.clear();
    await Hive.deleteFromDisk();
    try {
      await tempDir.delete(recursive: true);
    } catch (_) {}
  });

  Review review(int rating) =>
      Review(companyId: 'c1', name: 'Tester', rating: rating, text: 'ok');

  test('clamps an out-of-range rating on write', () {
    repo.add(review(999));
    final stored = repo.forCompany('c1').single;
    expect(stored.rating, 5);
  });

  test('clamps a zero rating up to the minimum', () {
    repo.add(review(0));
    expect(repo.forCompany('c1').single.rating, 1);
  });

  test('a malicious rating cannot push the average past 5', () {
    repo.add(review(5));
    repo.add(review(5));
    repo.add(review(999));
    final r = repo.ratingFor('c1');
    expect(r.count, 3);
    expect(r.avg, lessThanOrEqualTo(5.0));
    expect(r.avg, 5.0);
  });

  test('average defends against corrupt stored data on read', () {
    // Simulate a pre-existing corrupt record written directly to Hive
    // (bypassing add), then confirm ratingFor still clamps it.
    final corrupt = review(42);
    ds.reviews.put(corrupt.id, corrupt.toJson());
    final r = repo.ratingFor('c1');
    expect(r.avg, lessThanOrEqualTo(5.0));
  });
}
