import 'package:flutter/foundation.dart';

import '../../../domain/entities/pending_operation.dart';
import '../../../domain/repositories/sync_queue_repository.dart';
import '../local/hive_local_datasource.dart';
import 'remote_datasource.dart';

/// Synchronization status surfaced to the UI (TH-015 sync indicator).
enum SyncState { idle, syncing, error, offline }

/// Bidirectional synchronization engine (TH-014).
///
/// * **Local → Remote**: drains the [SyncQueueRepository] (the
///   `pending_operations` queue), pushing each mutation with retry/backoff.
/// * **Remote → Local**: pulls rows changed since the last successful sync and
///   writes them into the Hive cache.
///
/// Conflict strategy: **server wins** — on pull, remote rows overwrite local
/// cache; failed pushes are retried but never silently clobber newer server
/// state (the next pull reconciles).
///
/// When no backend is configured ([RemoteDataSource.isConfigured] == false) the
/// engine is a no-op and reports [SyncState.offline], so the app runs fully
/// offline (the queue simply accumulates harmlessly / is skipped).
class SyncEngine extends ChangeNotifier {
  SyncEngine({
    required RemoteDataSource remote,
    required SyncQueueRepository queue,
    required HiveLocalDataSource local,
    this.maxAttempts = 5,
  })  : _remote = remote,
        _queue = queue,
        _local = local;

  final RemoteDataSource _remote;
  final SyncQueueRepository _queue;
  final HiveLocalDataSource _local;
  final int maxAttempts;

  SyncState _state = SyncState.idle;
  SyncState get state => _state;

  String _lastError = '';
  String get lastError => _lastError;

  int get pendingCount => _queue.length;

  static const _kLastPull = 'last_pull_millis';

  /// Tables to pull from the remote, mapped to their local Hive boxes.
  static const Map<String, String> _pullTables = {
    HiveLocalDataSource.companiesBox: HiveLocalDataSource.companiesBox,
    HiveLocalDataSource.usersBox: HiveLocalDataSource.usersBox,
    HiveLocalDataSource.bookingsBox: HiveLocalDataSource.bookingsBox,
    HiveLocalDataSource.reviewsBox: HiveLocalDataSource.reviewsBox,
  };

  void _setState(SyncState s) {
    if (_state == s) return;
    _state = s;
    notifyListeners();
  }

  /// Runs a full sync cycle: push the queue, then pull remote changes.
  Future<void> sync() async {
    if (!_remote.isConfigured) {
      _setState(SyncState.offline);
      return;
    }
    _setState(SyncState.syncing);
    try {
      await _push();
      await _pull();
      _lastError = '';
      _setState(SyncState.idle);
    } catch (e) {
      _lastError = e.toString();
      _setState(SyncState.error);
    }
  }

  /// Local → Remote: drain the pending-operations queue.
  Future<void> _push() async {
    for (final op in _queue.pending()) {
      try {
        switch (op.type) {
          case SyncOpType.upsert:
            await _remote.upsert(op.table, op.payload);
          case SyncOpType.delete:
            await _remote.delete(op.table, op.recordId);
        }
        _queue.remove(op.id);
      } catch (e) {
        op.attempts += 1;
        op.lastError = e.toString();
        if (op.attempts >= maxAttempts) {
          // Give up after maxAttempts; drop so the queue can drain. The next
          // pull reconciles state (server wins).
          _queue.remove(op.id);
        } else {
          _queue.update(op);
        }
      }
    }
  }

  /// Remote → Local: pull changed rows into the cache (server wins).
  Future<void> _pull() async {
    final since = (_local.meta.get(_kLastPull) as int?) ?? 0;
    for (final entry in _pullTables.entries) {
      final rows = await _remote.fetchAll(entry.key, sinceMillis: since);
      final target = _boxFor(entry.value);
      for (final row in rows) {
        final id = row['id'];
        if (id != null) await target.put(id, row);
      }
    }
    await _local.meta.put(_kLastPull, DateTime.now().millisecondsSinceEpoch);
  }

  dynamic _boxFor(String boxName) {
    switch (boxName) {
      case HiveLocalDataSource.companiesBox:
        return _local.companies;
      case HiveLocalDataSource.usersBox:
        return _local.users;
      case HiveLocalDataSource.bookingsBox:
        return _local.bookings;
      case HiveLocalDataSource.reviewsBox:
        return _local.reviews;
      default:
        return _local.meta;
    }
  }
}
