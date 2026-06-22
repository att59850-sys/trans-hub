import '../entities/pending_operation.dart';

/// Persistent outbound mutation queue (TH-014).
abstract interface class SyncQueueRepository {
  /// Enqueues a mutation to be delivered to the remote backend.
  void enqueue(PendingOperation op);

  /// All pending operations, oldest first.
  List<PendingOperation> pending();

  /// Removes a completed operation.
  void remove(String opId);

  /// Persists an updated operation (e.g. incremented attempts / lastError).
  void update(PendingOperation op);

  /// Number of operations waiting to sync.
  int get length;
}
