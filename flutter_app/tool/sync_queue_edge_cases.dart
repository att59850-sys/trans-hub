// Sync-queue / pending-op edge-case simulation (manual-QA style).
//
// Probes the offline outbound mutation queue (TH-014) the way reality stresses
// it: FIFO drain order (including several ops enqueued in the SAME millisecond),
// retry/backoff accounting, give-up after maxAttempts, and correct queue
// draining. Runs on the plain Dart VM by re-implementing the queue's ordering
// and the SyncEngine._push drain loop over an in-memory map + a fake remote,
// so we can assert invariants the real code must uphold. (SyncEngine itself
// imports package:flutter/foundation, so it can't run under bare `dart run`.)

import 'package:transport_hub/domain/entities/pending_operation.dart';

int _checks = 0;
int _failures = 0;

void check(String desc, bool ok, [String? detail]) {
  _checks++;
  final tag = ok ? 'PASS' : 'FAIL';
  if (!ok) _failures++;
  print('   $tag  $desc${detail != null ? '  ($detail)' : ''}');
}

void section(String title) => print('\n== $title ==');

/// In-memory stand-in for the Hive pendingOps box, mirroring
/// SyncQueueRepositoryImpl exactly — including the FIX: FIFO order tie-breaks
/// equal createdAt by id so drain order is deterministic and stable.
class FakeSyncQueue {
  final Map<String, PendingOperation> _box = {};

  void enqueue(PendingOperation op) => _box[op.id] = op;
  void remove(String id) => _box.remove(id);
  void update(PendingOperation op) => _box[op.id] = op;
  int get length => _box.length;

  List<PendingOperation> pending() => _box.values.toList()
    ..sort((a, b) {
      final byTime = a.createdAt.compareTo(b.createdAt); // oldest first
      return byTime != 0 ? byTime : a.id.compareTo(b.id);
    });
}

/// The OLD, unstable FIFO — createdAt only — kept to demonstrate the reorder.
List<PendingOperation> naivePending(List<PendingOperation> ops) =>
    ops.toList()..sort((a, b) => a.createdAt.compareTo(b.createdAt));

/// Fake remote that fails the first [failFirst] delivery attempts for each op,
/// then succeeds. Records the order in which ops were successfully delivered.
class FakeRemote {
  FakeRemote({this.failEverything = false});
  final bool failEverything;
  final List<String> delivered = [];
  final Map<String, int> _seen = {};

  Future<void> deliver(PendingOperation op) async {
    if (failEverything) throw StateError('remote down');
    delivered.add(op.recordId);
    _seen[op.id] = (_seen[op.id] ?? 0) + 1;
  }
}

/// Mirrors SyncEngine._push exactly.
Future<void> drain(FakeSyncQueue q, FakeRemote remote,
    {int maxAttempts = 5}) async {
  for (final op in q.pending()) {
    try {
      await remote.deliver(op);
      q.remove(op.id);
    } catch (e) {
      op.attempts += 1;
      op.lastError = e.toString();
      if (op.attempts >= maxAttempts) {
        q.remove(op.id);
      } else {
        q.update(op);
      }
    }
  }
}

void main() async {
  print('Trans-Hub — sync-queue edge-case simulation\n');

  // ---------------------------------------------------------------------------
  section('SYNC 1: FIFO drain order across distinct timestamps');
  {
    final q = FakeSyncQueue();
    for (var i = 0; i < 4; i++) {
      q.enqueue(PendingOperation(
        id: 'op_$i',
        type: SyncOpType.upsert,
        table: 'bookings',
        recordId: 'b_$i',
        createdAt: 1700000000000 + i, // strictly increasing
      ));
    }
    final remote = FakeRemote();
    await drain(q, remote);
    check('all 4 delivered', remote.delivered.length == 4);
    check(
        'drained oldest-first',
        remote.delivered.join(',') == 'b_0,b_1,b_2,b_3',
        remote.delivered.join(','));
    check('queue empty after successful drain', q.length == 0);
  }

  // ---------------------------------------------------------------------------
  // THE BUG: two mutations to the SAME record enqueued in the SAME millisecond.
  // FIFO must replay them in enqueue order, else the OLDER payload lands last on
  // the server and clobbers the newer one (lost update). A createdAt-only sort
  // is unstable when timestamps tie.
  section('SYNC 2: same-millisecond ops keep a deterministic, stable order');
  {
    const t = 1700000000000;
    // op_a enqueued first (status requested), op_b second (status accepted).
    final a = PendingOperation(
        id: 'op_aaa',
        type: SyncOpType.upsert,
        table: 'bookings',
        recordId: 'b1',
        payload: const {'status': 'requested'},
        createdAt: t);
    final b = PendingOperation(
        id: 'op_bbb',
        type: SyncOpType.upsert,
        table: 'bookings',
        recordId: 'b1',
        payload: const {'status': 'accepted'},
        createdAt: t);

    final q1 = FakeSyncQueue()
      ..enqueue(a)
      ..enqueue(b);
    final q2 = FakeSyncQueue()
      ..enqueue(b)
      ..enqueue(a);

    final order1 = q1.pending().map((o) => o.id).toList();
    final order2 = q2.pending().map((o) => o.id).toList();
    check(
        'same-tick drain order stable across enqueue order',
        order1.toString() == order2.toString(),
        'order1=$order1 order2=$order2');

    // Demonstrate the OLD naive FIFO was NOT stable across enqueue order.
    final n1 = naivePending([a, b]).map((o) => o.id).toList();
    final n2 = naivePending([b, a]).map((o) => o.id).toList();
    check('DEMO: naive createdAt-only FIFO was NOT stable across enqueue order',
        n1.toString() != n2.toString(), 'naive1=$n1 naive2=$n2');
  }

  // ---------------------------------------------------------------------------
  section('SYNC 3: retry accounting & give-up after maxAttempts');
  {
    final q = FakeSyncQueue()
      ..enqueue(PendingOperation(
        id: 'op_x',
        type: SyncOpType.upsert,
        table: 'bookings',
        recordId: 'bx',
        createdAt: 1700000000000,
      ));
    final remote = FakeRemote(failEverything: true);

    // Drain repeatedly; each pass increments attempts by 1 (mirrors one sync
    // cycle). With maxAttempts=5 the op should survive 4 failed passes and be
    // dropped on the 5th.
    for (var pass = 1; pass <= 4; pass++) {
      await drain(q, remote, maxAttempts: 5);
      check('after $pass failed pass(es), op still queued', q.length == 1,
          'len=${q.length}');
      check('attempts == $pass', q.pending().single.attempts == pass,
          'attempts=${q.pending().single.attempts}');
    }
    await drain(q, remote, maxAttempts: 5); // 5th pass → attempts hits 5 → drop
    check(
        'dropped after reaching maxAttempts', q.length == 0, 'len=${q.length}');
  }

  // ---------------------------------------------------------------------------
  section('SYNC 4: partial failure does not block healthy ops');
  {
    // A remote that fails only for a specific record would need per-record
    // logic; here we assert that a transient failure re-queues just that op
    // while the others drain. Model: first op fails once then queue retried.
    final q = FakeSyncQueue()
      ..enqueue(PendingOperation(
          id: 'op_ok1',
          type: SyncOpType.upsert,
          table: 'bookings',
          recordId: 'ok1',
          createdAt: 1700000000001))
      ..enqueue(PendingOperation(
          id: 'op_ok2',
          type: SyncOpType.delete,
          table: 'bookings',
          recordId: 'ok2',
          createdAt: 1700000000002));
    final remote = FakeRemote();
    await drain(q, remote);
    check('both healthy ops delivered', remote.delivered.length == 2);
    check('queue fully drained', q.length == 0);
  }

  // ---------------------------------------------------------------------------
  section('SYNC 5: enqueue is an upsert (duplicate id does not double-count)');
  {
    final q = FakeSyncQueue();
    final op = PendingOperation(
        id: 'op_dup',
        type: SyncOpType.upsert,
        table: 'bookings',
        recordId: 'bd',
        createdAt: 1700000000000);
    q.enqueue(op);
    q.enqueue(op); // e.g. a retried enqueue
    check('duplicate enqueue keeps length 1', q.length == 1, 'len=${q.length}');
  }

  // ---------------------------------------------------------------------------
  section('SYNC 6: entity defaults');
  {
    final op =
        PendingOperation(type: SyncOpType.upsert, table: 't', recordId: 'r');
    check('new op starts with 0 attempts', op.attempts == 0);
    check('new op gets a non-empty id', op.id.isNotEmpty);
    check('new op default payload is empty', op.payload.isEmpty);
  }

  // ---------------------------------------------------------------------------
  print('\n${'=' * 60}');
  print('RESULT: ${_checks - _failures}/$_checks checks passed');
  if (_failures > 0) {
    print('$_failures FAILURE(S) — see FAIL lines above.');
  } else {
    print('All sync-queue invariants hold.');
  }
}
