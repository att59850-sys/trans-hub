// QA round 16 — booking status transition integrity (pure-Dart harness).
//
// Probes DataService.setBookingStatus / BookingRepositoryImpl.setStatus from
// the provider's side WITHOUT Flutter/Hive by re-implementing the transition
// decision. Two things a human/QA tester can trigger:
//
//   1. A misspelled/unknown status wire ("complete", "in-transit",
//      "confirmedd") parses via bookingStatusFromWire's fallback to `pending`.
//      From a `draft` booking, `pending` is a LEGAL target — so a typo would
//      SILENTLY move the booking to Pending instead of being rejected. That is
//      a real data-integrity hazard on any non-UI path (sync engine / API).
//
//   2. A self-loop (setting a booking to the status it already has) is not a
//      legal transition (a status is never in its own nextStates), so it must
//      be a rejected no-op — the provider dashboard relies on the returned
//      bool to avoid a misleading "updated" toast.
//
// The fix hardens the transition entry point to require a RECOGNISED status
// wire (reject the silent fallback) before consulting the state machine.
//
// Run: dart run tool/booking_status_transition_edge_cases.dart

import '../lib/domain/entities/booking_status.dart';

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

/// Recognised wire values (the enum's own wire strings). Anything else is a
/// typo/unknown and must NOT be coerced into a real status.
final Set<String> _knownWires = BookingStatus.values.map((s) => s.wire).toSet();

bool isKnownStatusWire(String? wire) =>
    wire != null && _knownWires.contains(wire);

/// A booking stand-in (only the status matters for transitions).
class Bk {
  Bk(this.status);
  String status; // wire value
}

/// RAW facade behaviour: parse (with the pending fallback), then apply if the
/// state machine allows it. Returns whether it was applied.
bool rawSetStatus(Bk b, String wire) {
  final current = bookingStatusFromWire(b.status);
  final target = bookingStatusFromWire(wire); // unknown -> pending (the hazard)
  if (!current.canTransitionTo(target)) return false;
  b.status = target.wire;
  return true;
}

/// FIXED facade behaviour: reject an unrecognised wire BEFORE parsing, so a typo
/// can never be coerced into `pending`. Otherwise identical.
bool fixedSetStatus(Bk b, String wire) {
  if (!isKnownStatusWire(wire)) return false;
  final current = bookingStatusFromWire(b.status);
  final target = bookingStatusFromWire(wire);
  if (!current.canTransitionTo(target)) return false;
  b.status = target.wire;
  return true;
}

void main() {
  print('== QA round 16: booking status transition edge cases ==\n');

  // ------------------------------------------------------------------
  // DEMO: raw defect — a typo silently moves a draft booking to pending.
  // ------------------------------------------------------------------
  print('-- raw defect: misspelled status coerced to pending --');
  {
    final b = Bk('draft');
    // "complete" is a typo for "completed"; it parses to pending, and
    // draft -> pending is legal, so it is applied.
    final applied = rawSetStatus(b, 'complete');
    check('RAW BUG: typo "complete" is accepted', applied);
    check(
        'RAW BUG: draft was silently moved to pending', b.status == 'pending');
  }
  {
    final b = Bk('draft');
    final applied = rawSetStatus(b, 'in-transit'); // hyphen typo
    check('RAW BUG: "in-transit" typo accepted from draft', applied);
    check('RAW BUG: ended up pending, not in_transit', b.status == 'pending');
  }

  // ------------------------------------------------------------------
  // FIX: an unrecognised wire is rejected outright.
  // ------------------------------------------------------------------
  print('\n-- fixed: unrecognised status is rejected --');
  {
    for (final typo in [
      'complete',
      'in-transit',
      'confirmedd',
      '',
      'PENDING'
    ]) {
      final b = Bk('draft');
      final applied = fixedSetStatus(b, typo);
      check('typo "$typo" rejected', !applied);
      check('booking stays draft after "$typo"', b.status == 'draft');
    }
  }

  print('\n-- fixed: a self-loop is a rejected no-op --');
  {
    for (final s in ['pending', 'accepted', 'in_transit', 'draft']) {
      final b = Bk(s);
      final applied = fixedSetStatus(b, s); // same status
      check('$s -> $s is a no-op', !applied);
      check('$s unchanged after self-loop', b.status == s);
    }
  }

  print('\n-- fixed: legal provider transitions still work --');
  {
    final b = Bk('pending');
    check('pending -> accepted',
        fixedSetStatus(b, 'accepted') && b.status == 'accepted');
    check('accepted -> in_transit',
        fixedSetStatus(b, 'in_transit') && b.status == 'in_transit');
    check('in_transit -> completed',
        fixedSetStatus(b, 'completed') && b.status == 'completed');
    // completed is terminal.
    check('completed -> cancelled rejected', !fixedSetStatus(b, 'cancelled'));
    check('booking stays completed', b.status == 'completed');
  }

  print('\n-- fixed: legacy "confirmed" alias still resolves to accepted --');
  {
    // The wire "confirmed" is a recognised LEGACY alias for accepted, so it is
    // NOT treated as a typo. From pending, moving to accepted is legal.
    final b = Bk('pending');
    // "confirmed" is not in the enum's wire set, so our strict guard rejects it
    // as a transition TARGET (callers should use canonical wires). Confirm the
    // parser still maps a STORED legacy value correctly, independent of writes.
    check('bookingStatusFromWire("confirmed") == accepted',
        bookingStatusFromWire('confirmed') == BookingStatus.accepted);
    check('strict guard rejects non-canonical "confirmed" as a write target',
        !fixedSetStatus(b, 'confirmed'));
    check('canonical "accepted" is accepted from pending',
        fixedSetStatus(b, 'accepted') && b.status == 'accepted');
  }

  print('\n-- isKnownStatusWire direct checks --');
  {
    for (final w in [
      'draft',
      'quote_requested',
      'quote_sent',
      'pending',
      'accepted',
      'in_transit',
      'completed',
      'cancelled'
    ]) {
      check('"$w" is a known wire', isKnownStatusWire(w));
    }
    check('null is not known', !isKnownStatusWire(null));
    check('"confirmed" (legacy alias) is not a canonical wire',
        !isKnownStatusWire('confirmed'));
    check('"" is not known', !isKnownStatusWire(''));
  }

  print('\n== $_passed passed, $_failed failed ==');
  if (_failed > 0) {
    throw StateError('booking status transition edge cases failed');
  }
}
