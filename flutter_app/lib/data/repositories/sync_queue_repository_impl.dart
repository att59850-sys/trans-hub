import '../../core/utils/ordering.dart';
import '../../domain/entities/pending_operation.dart';
import '../../domain/repositories/sync_queue_repository.dart';
import '../datasources/local/hive_local_datasource.dart';
import '../models/pending_operation_dto.dart';

/// Hive-backed [SyncQueueRepository].
class SyncQueueRepositoryImpl implements SyncQueueRepository {
  SyncQueueRepositoryImpl(this._ds);

  final HiveLocalDataSource _ds;

  @override
  void enqueue(PendingOperation op) => _ds.pendingOps.put(op.id, op.toJson());

  @override
  List<PendingOperation> pending() => _ds.pendingOps.values
      .map((e) => pendingOperationFromJson(e as Map))
      .toList()
    // Oldest first (FIFO), stable on same-millisecond ties: several mutations
    // can be enqueued in the SAME millisecond, and a createdAt-only sort left
    // the drain order at the mercy of Hive iteration order. For a sync queue
    // that is a lost-update hazard — two upserts to the same record could
    // replay out of order, landing the STALE payload last on the server.
    // (QA round 6.)
    ..sort(
        (a, b) => Ordering.oldestFirst(a.createdAt, a.id, b.createdAt, b.id));

  @override
  void remove(String opId) => _ds.pendingOps.delete(opId);

  @override
  void update(PendingOperation op) => _ds.pendingOps.put(op.id, op.toJson());

  @override
  int get length => _ds.pendingOps.length;
}
