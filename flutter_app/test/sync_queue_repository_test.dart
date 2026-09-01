import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:transport_hub/data/datasources/local/hive_local_datasource.dart';
import 'package:transport_hub/data/repositories/sync_queue_repository_impl.dart';
import 'package:transport_hub/domain/entities/pending_operation.dart';

/// Sync-queue FIFO integrity (TH-014). A QA pass (round 6) showed that
/// pending operations enqueued in the SAME millisecond — several mutations can
/// be queued in one tick — sorted only by `createdAt` had a non-deterministic
/// drain order at the mercy of Hive iteration order. For an outbound mutation
/// queue that is a lost-update hazard: two upserts to the same record could
/// replay out of order and land the STALE payload last on the server.
/// `pending()` now tie-breaks equal timestamps by id, so drain order is
/// deterministic and stable. Hive-backed; runs in CI (may OOM on very
/// low-memory hosts, like the other Hive suites).
void main() {
  late Directory tempDir;
  late HiveLocalDataSource ds;
  late SyncQueueRepositoryImpl repo;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('transhub_syncq_');
    Hive.init(tempDir.path);
    ds = HiveLocalDataSource.instance;
    ds.pendingOps = await Hive.openBox(HiveLocalDataSource.pendingOpsBox);
    repo = SyncQueueRepositoryImpl(ds);
  });

  tearDown(() async {
    await ds.pendingOps.clear();
    await Hive.deleteFromDisk();
    try {
      await tempDir.delete(recursive: true);
    } catch (_) {}
  });

  PendingOperation op(String id, int createdAt, {String recordId = 'r'}) =>
      PendingOperation(
        id: id,
        type: SyncOpType.upsert,
        table: 'bookings',
        recordId: recordId,
        createdAt: createdAt,
      );

  test('drains oldest-first across distinct timestamps', () {
    repo.enqueue(op('op_c', 1700000000003));
    repo.enqueue(op('op_a', 1700000000001));
    repo.enqueue(op('op_b', 1700000000002));
    expect(repo.pending().map((o) => o.id).toList(), ['op_a', 'op_b', 'op_c']);
  });

  test('same-millisecond order is deterministic & stable across enqueue order',
      () {
    const t = 1700000000000;
    // Enqueue in one order.
    repo.enqueue(op('op_aaa', t));
    repo.enqueue(op('op_bbb', t));
    repo.enqueue(op('op_ccc', t));
    final order1 = repo.pending().map((o) => o.id).toList();

    // Wipe and enqueue in the REVERSE order; order must be identical.
    ds.pendingOps.clear();
    repo.enqueue(op('op_ccc', t));
    repo.enqueue(op('op_bbb', t));
    repo.enqueue(op('op_aaa', t));
    final order2 = repo.pending().map((o) => o.id).toList();

    expect(order1, order2);
    // Deterministic tie-break: ascending id (oldest-first FIFO).
    expect(order1, ['op_aaa', 'op_bbb', 'op_ccc']);
  });

  test('enqueue is an upsert: duplicate id does not double-count', () {
    final o = op('op_dup', 1700000000000);
    repo.enqueue(o);
    repo.enqueue(o);
    expect(repo.length, 1);
  });

  test('remove and update keep the queue consistent', () {
    repo.enqueue(op('op_1', 1700000000001));
    repo.enqueue(op('op_2', 1700000000002));
    expect(repo.length, 2);

    final first = repo.pending().first;
    first.attempts += 1;
    repo.update(first);
    expect(repo.pending().first.attempts, 1);
    expect(repo.length, 2); // update does not add

    repo.remove('op_1');
    expect(repo.length, 1);
    expect(repo.pending().single.id, 'op_2');
  });
}
