import '../../domain/entities/pending_operation.dart';

/// JSON (de)serialization for [PendingOperation].
extension PendingOperationDto on PendingOperation {
  Map<String, dynamic> toJson() => {
        'id': id,
        'type': syncOpTypeToString(type),
        'table': table,
        'recordId': recordId,
        'payload': payload,
        'attempts': attempts,
        'lastError': lastError,
        'createdAt': createdAt,
      };
}

PendingOperation pendingOperationFromJson(Map j) => PendingOperation(
      id: j['id'] as String?,
      type: syncOpTypeFromString((j['type'] ?? 'upsert') as String),
      table: (j['table'] ?? '') as String,
      recordId: (j['recordId'] ?? '') as String,
      payload: (j['payload'] as Map?)?.cast<String, dynamic>() ??
          const <String, dynamic>{},
      attempts: (j['attempts'] ?? 0) as int,
      lastError: (j['lastError'] ?? '') as String,
      createdAt: j['createdAt'] as int?,
    );
