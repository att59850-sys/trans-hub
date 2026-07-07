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
    ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

  @override
  void remove(String opId) => _ds.pendingOps.delete(opId);

  @override
  void update(PendingOperation op) => _ds.pendingOps.put(op.id, op.toJson());

  @override
  int get length => _ds.pendingOps.length;
}
