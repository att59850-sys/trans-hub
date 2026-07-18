import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:transport_hub/data/datasources/local/hive_local_datasource.dart';
import 'package:transport_hub/data/repositories/booking_repository_impl.dart';
import 'package:transport_hub/domain/entities/entities.dart';

/// Data-layer enforcement of the booking lifecycle state machine (TH-016).
///
/// The dashboard only *offers* legal moves, but the repository must also
/// *reject* illegal ones so the invariant holds for any caller (sync engine,
/// a future API, tests). Uses an in-memory Hive box against a temp dir; runs in
/// CI (may OOM on very low-memory hosts, like the other Hive-backed suites).
void main() {
  late Directory tempDir;
  late HiveLocalDataSource ds;
  late BookingRepositoryImpl repo;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('transhub_booking_');
    Hive.init(tempDir.path);
    ds = HiveLocalDataSource.instance;
    ds.bookings = await Hive.openBox(HiveLocalDataSource.bookingsBox);
    repo = BookingRepositoryImpl(ds);
  });

  tearDown(() async {
    await ds.bookings.clear();
    await Hive.deleteFromDisk();
    try {
      await tempDir.delete(recursive: true);
    } catch (_) {}
  });

  Booking seed({BookingStatus status = BookingStatus.pending}) {
    final b = Booking(companyId: 'c1', userId: 'u1', status: status);
    return repo.create(b);
  }

  test('applies a legal transition and records an event', () {
    final b = seed();
    final ok = repo.setStatus(b.id, BookingStatus.accepted, note: 'go');
    expect(ok, isTrue);

    final updated = repo.all().firstWhere((x) => x.id == b.id);
    expect(updated.status, BookingStatus.accepted);
    // create() seeds one event; the transition adds a second.
    expect(updated.events.length, 2);
    expect(updated.events.last.status, BookingStatus.accepted);
    expect(updated.events.last.note, 'go');
  });

  test('rejects an illegal jump and leaves the booking unchanged', () {
    final b = seed();
    final ok = repo.setStatus(b.id, BookingStatus.completed);
    expect(ok, isFalse, reason: 'pending -> completed is illegal');

    final unchanged = repo.all().firstWhere((x) => x.id == b.id);
    expect(unchanged.status, BookingStatus.pending);
    expect(unchanged.events.length, 1, reason: 'no event should be appended');
  });

  test('rejects any move out of a terminal state', () {
    // Walk to completed legally first.
    final b = seed();
    expect(repo.setStatus(b.id, BookingStatus.accepted), isTrue);
    expect(repo.setStatus(b.id, BookingStatus.inTransit), isTrue);
    expect(repo.setStatus(b.id, BookingStatus.completed), isTrue);

    // Now nothing further is allowed.
    expect(repo.setStatus(b.id, BookingStatus.pending), isFalse);
    expect(repo.setStatus(b.id, BookingStatus.inTransit), isFalse);
    final done = repo.all().firstWhere((x) => x.id == b.id);
    expect(done.status, BookingStatus.completed);
  });

  test('returns false for an unknown booking id', () {
    expect(repo.setStatus('does-not-exist', BookingStatus.accepted), isFalse);
  });
}
