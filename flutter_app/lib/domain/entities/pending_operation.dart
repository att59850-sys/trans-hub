import '../../core/utils/id_generator.dart';

/// The kind of mutation queued for the remote backend (TH-014).
enum SyncOpType { upsert, delete }

SyncOpType syncOpTypeFromString(String s) =>
    s == 'delete' ? SyncOpType.delete : SyncOpType.upsert;

String syncOpTypeToString(SyncOpType t) =>
    t == SyncOpType.delete ? 'delete' : 'upsert';

/// A single mutation awaiting synchronization to the remote backend.
///
/// Local writes succeed immediately against Hive and enqueue one of these; the
/// [SyncEngine] later drains the queue to the server, with retries.
class PendingOperation {
  PendingOperation({
    String? id,
    required this.type,
    required this.table,
    required this.recordId,
    this.payload = const {},
    this.attempts = 0,
    this.lastError = '',
    int? createdAt,
  })  : id = id ?? newId('op'),
        createdAt = createdAt ?? DateTime.now().millisecondsSinceEpoch;

  final String id;
  final SyncOpType type;

  /// Target table, e.g. `bookings`, `companies`.
  final String table;

  /// Primary key of the affected record.
  final String recordId;

  /// Full row payload for upserts (empty for deletes).
  final Map<String, dynamic> payload;

  /// Number of failed delivery attempts (used for backoff / giving up).
  int attempts;
  String lastError;
  final int createdAt;
}
