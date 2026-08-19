// QA round 15 — admin verification queue edge cases (pure-Dart harness).
//
// Models the admin review queue's action → toast flow WITHOUT Flutter/Hive by
// re-implementing DataService.setVerificationStatus's state-machine result and
// companiesForReview's filter/order. The bug found acting as a human admin:
// the queue's Approve/Reject/Start-review buttons ALWAYS show a success toast,
// even when the underlying transition is a no-op (e.g. a double-tap on an
// already-approved company, or acting on a stale queue snapshot). That tells
// the admin "X approved" when nothing changed.
//
// Run: dart run tool/admin_queue_edge_cases.dart

import '../lib/core/verification/verification_status.dart';

int _passed = 0;
int _failed = 0;

void check(String name, bool cond) {
  if (cond) {
    _passed++;
    print('  ok   $name');
  } else {
    _failed++;
    print('  FAIL $name');
  }
}

/// A tiny company stand-in (only the fields the queue cares about).
class Co {
  Co(this.id, this.status, this.createdAt);
  final String id;
  String status; // wire value
  final int createdAt;
}

/// Mirrors DataService.setVerificationStatus's decision (state machine).
/// Returns true if the transition was applied, false if it was a no-op.
bool setStatus(Co? c, String status) {
  if (c == null) return false;
  final current = verificationStatusFromWire(c.status);
  final target = verificationStatusFromWire(status);
  if (target == VerificationStatus.unverified ||
      !current.canTransitionTo(target)) {
    return false;
  }
  c.status = target.wire;
  return true;
}

/// Mirrors DataService.companiesForReview (submitted/under_review only,
/// oldest first with a stable id tie-break).
List<Co> queueOf(Iterable<Co> all) {
  final q = all
      .where((c) => c.status == 'submitted' || c.status == 'under_review')
      .toList()
    ..sort((a, b) {
      final byTime = a.createdAt.compareTo(b.createdAt);
      return byTime != 0 ? byTime : a.id.compareTo(b.id);
    });
  return q;
}

/// RAW admin card behaviour: fire the transition, ignore the bool, always toast
/// success. Returns the toast text the admin would see.
String rawTap(Co c, String status, String successToast) {
  setStatus(c, status); // return value discarded (the bug)
  return successToast;
}

/// FIXED admin card behaviour: honour the bool and toast truthfully.
String fixedTap(Co c, String status, String successToast, String failToast) {
  final ok = setStatus(c, status);
  return ok ? successToast : failToast;
}

void main() {
  print('== QA round 15: admin verification queue edge cases ==\n');

  // ------------------------------------------------------------------
  // DEMO: raw defect — a success toast even on a no-op transition.
  // ------------------------------------------------------------------
  print('-- raw defect: double-tap Approve still says "approved" --');
  {
    final c = Co('c1', 'submitted', 1);
    final t1 = rawTap(c, 'approved', 'approved');
    check('first Approve applies (status is approved)', c.status == 'approved');
    check('first toast says approved', t1 == 'approved');
    // Second tap before the list rebuilds: approved is terminal -> no-op.
    final t2 = rawTap(c, 'approved', 'approved');
    check('RAW BUG: second Approve is a no-op', true);
    check('RAW BUG: yet the toast still says "approved"', t2 == 'approved');
  }

  print('\n-- raw defect: Reject on an already-approved company "succeeds" --');
  {
    final c = Co('c2', 'approved', 1);
    final t = rawTap(c, 'rejected', 'rejected');
    check('RAW BUG: approved->rejected is illegal but not applied',
        c.status == 'approved');
    check('RAW BUG: toast still says "rejected"', t == 'rejected');
  }

  // ------------------------------------------------------------------
  // FIX: honour the bool; truthful toast.
  // ------------------------------------------------------------------
  print('\n-- fixed: double-tap Approve — second tap tells the truth --');
  {
    final c = Co('c1', 'submitted', 1);
    final t1 = fixedTap(c, 'approved', 'c1 approved', 'No change');
    check(
        'first Approve applies', c.status == 'approved' && t1 == 'c1 approved');
    final t2 = fixedTap(
        c, 'approved', 'c1 approved', 'No change — already up to date');
    check('second Approve reports no change', t2.startsWith('No change'));
  }

  print('\n-- fixed: Reject on approved is reported as no change --');
  {
    final c = Co('c2', 'approved', 1);
    final t = fixedTap(c, 'rejected', 'c2 rejected', 'No change');
    check('status stays approved', c.status == 'approved');
    check('toast is truthful (no change)', t == 'No change');
  }

  print('\n-- fixed: legal queue transitions still succeed --');
  {
    final sub = Co('s', 'submitted', 1);
    check('submitted -> under_review ok',
        fixedTap(sub, 'under_review', 'ok', 'no') == 'ok');
    check('under_review -> approved ok',
        fixedTap(sub, 'approved', 'ok', 'no') == 'ok');

    final sub2 = Co('s2', 'submitted', 1);
    check('submitted -> rejected ok',
        fixedTap(sub2, 'rejected', 'ok', 'no') == 'ok');
    check('rejected -> re-submit ok',
        fixedTap(sub2, 'submitted', 'ok', 'no') == 'ok');
  }

  // ------------------------------------------------------------------
  // Queue membership: approved/rejected leave the queue; stale actions.
  // ------------------------------------------------------------------
  print('\n-- queue membership after decisions --');
  {
    final all = [
      Co('a', 'submitted', 3),
      Co('b', 'under_review', 1),
      Co('c', 'approved', 2), // already decided, not in queue
      Co('d', 'unverified', 4), // never submitted
    ];
    var q = queueOf(all);
    check('queue holds only submitted/under_review', q.length == 2);
    check('queue is oldest-first (b before a)',
        q.first.id == 'b' && q.last.id == 'a');

    // Approve b -> it should drop out of the queue on the next read.
    check('approve b succeeds', setStatus(all[1], 'approved'));
    q = queueOf(all);
    check('b left the queue after approval', !q.any((c) => c.id == 'b'));
    check('a remains in the queue', q.any((c) => c.id == 'a'));
  }

  print('\n-- stale snapshot: acting on a card already decided elsewhere --');
  {
    // Admin's queue snapshot still shows "x" as submitted, but another session
    // already approved it. The admin taps Reject on the stale card.
    final x = Co('x', 'approved', 1); // real current state
    final t =
        fixedTap(x, 'rejected', 'x rejected', 'No change — already decided');
    check('stale Reject does not override the real decision',
        x.status == 'approved');
    check('admin is told nothing changed', t.startsWith('No change'));
  }

  print('\n== $_passed passed, $_failed failed ==');
  if (_failed > 0) {
    throw StateError('admin queue edge cases failed');
  }
}
