import 'package:flutter_test/flutter_test.dart';
import 'package:transport_hub/data/datasources/remote/remote_datasource.dart';
import 'package:transport_hub/domain/entities/pending_operation.dart';
import 'package:transport_hub/domain/repositories/sync_queue_repository.dart';

/// In-memory queue for testing the push flow without Hive.
class InMemoryQueue implements SyncQueueRepository {
  final Map<String, PendingOperation> _ops = {};

  @override
  void enqueue(PendingOperation op) => _ops[op.id] = op;
  @override
  List<PendingOperation> pending() =>
      _ops.values.toList()..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  @override
  void remove(String opId) => _ops.remove(opId);
  @override
  void update(PendingOperation op) => _ops[op.id] = op;
  @override
  int get length => _ops.length;
}

/// Remote that fails a configurable number of times before succeeding.
class FlakyRemote implements RemoteDataSource {
  FlakyRemote({this.failTimes = 0});
  int failTimes;
  int upserts = 0;

  @override
  bool get isConfigured => true;
  @override
  Future<List<Map<String, dynamic>>> fetchAll(String table,
          {int sinceMillis = 0}) async =>
      const [];
  @override
  Future<Map<String, dynamic>> upsert(
      String table, Map<String, dynamic> row) async {
    if (failTimes > 0) {
      failTimes--;
      throw Exception('transient');
    }
    upserts++;
    return row;
  }

  @override
  Future<void> delete(String table, String id) async {}
}

void main() {
  group('SyncQueue + RemoteDataSource semantics', () {
    test('enqueue / pending / remove', () {
      final q = InMemoryQueue();
      q.enqueue(PendingOperation(
        type: SyncOpType.upsert,
        table: 'bookings',
        recordId: 'b_1',
        payload: const {'id': 'b_1'},
      ));
      expect(q.length, 1);
      expect(q.pending().first.table, 'bookings');
      q.remove(q.pending().first.id);
      expect(q.length, 0);
    });

    test('NoopRemoteDataSource is not configured and no-ops', () async {
      const noop = NoopRemoteDataSource();
      expect(noop.isConfigured, isFalse);
      expect(await noop.fetchAll('companies'), isEmpty);
      final row = await noop.upsert('companies', {'id': 'c_1'});
      expect(row['id'], 'c_1');
    });

    test('FlakyRemote eventually succeeds (retry semantics)', () async {
      final remote = FlakyRemote(failTimes: 2);
      // Simulate the engine's retry loop on a single op.
      var attempts = 0;
      while (attempts < 5) {
        try {
          await remote.upsert('bookings', {'id': 'b_1'});
          break;
        } catch (_) {
          attempts++;
        }
      }
      expect(remote.upserts, 1);
      expect(attempts, 2);
    });
  });
}
