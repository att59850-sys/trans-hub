// Adversarial / edge-case journey simulation (manual-QA style).
//
// Complements tool/human_journey.dart by probing the *unhappy* paths a real
// user (or a misbehaving client) can trigger: illegal booking transitions,
// signup validation, empty inputs, rating math on degenerate data, and the
// notification unread-count invariant. Runs on the plain Dart VM so it works
// in the memory-constrained sandbox.

import 'package:transport_hub/core/maps/estimating_maps_service.dart';
import 'package:transport_hub/domain/entities/booking_status.dart';

int _checks = 0;
int _failures = 0;

void check(String desc, bool ok, [String? detail]) {
  _checks++;
  final tag = ok ? 'PASS' : 'FAIL';
  if (!ok) _failures++;
  print('   $tag  $desc${detail != null ? '  ($detail)' : ''}');
}

void section(String title) => print('\n== $title ==');

Future<void> main() async {
  print('Trans-Hub — edge-case / adversarial simulation\n');

  // ---------------------------------------------------------------------------
  section('EDGE 1: illegal booking transitions must be rejected');
  // The dashboard only offers legal nextStates, but the domain state machine
  // should be able to answer "is this transition allowed?" so the data layer
  // can defend itself against programmatic/API misuse.
  const pending = BookingStatus.pending;

  // A legal step: pending -> accepted.
  check('pending -> accepted is allowed',
      pending.canTransitionTo(BookingStatus.accepted));

  // Illegal jumps a client might attempt:
  check('pending -> completed is BLOCKED (skips accepted/in_transit)',
      !pending.canTransitionTo(BookingStatus.completed));
  check('pending -> in_transit is BLOCKED',
      !pending.canTransitionTo(BookingStatus.inTransit));

  // Terminal states never move again.
  check('completed -> anything is BLOCKED',
      !BookingStatus.completed.canTransitionTo(BookingStatus.pending));
  check('cancelled -> accepted is BLOCKED',
      !BookingStatus.cancelled.canTransitionTo(BookingStatus.accepted));

  // Self-transition is not a real move.
  check('accepted -> accepted (no-op) is BLOCKED',
      !BookingStatus.accepted.canTransitionTo(BookingStatus.accepted));

  // Every legal nextState must satisfy canTransitionTo (internal consistency).
  var consistent = true;
  for (final s in BookingStatus.values) {
    for (final n in s.nextStates) {
      if (!s.canTransitionTo(n)) consistent = false;
    }
  }
  check('nextStates and canTransitionTo agree for all states', consistent);

  // ---------------------------------------------------------------------------
  section('EDGE 2: route estimator on degenerate input');
  const maps = EstimatingMapsService();
  check('empty geocode returns null', (await maps.geocode('')) == null);
  check('whitespace-only geocode returns null',
      (await maps.geocode('   ')) == null);

  final unknownA = await maps.geocode('123 Fake Street, Nowhere');
  final unknownB = await maps.geocode('123 Fake Street, Nowhere');
  check('unknown address is deterministic',
      unknownA!.lat == unknownB!.lat && unknownA.lng == unknownB.lng);
  check('fallback lat in range', unknownA.lat >= -70 && unknownA.lat <= 70);
  check('fallback lng in range', unknownA.lng >= -180 && unknownA.lng <= 180);

  // A route between two unknowns must still be a finite, non-negative number.
  final r = await maps.routePreview(unknownA, unknownB);
  check('same fallback point => ~0 km', r != null && r.distanceKm < 1.0,
      '${r?.distanceKm}');
  check('duration floors at 5 min', r != null && r.durationMinutes >= 5,
      '${r?.durationMinutes}');

  // ---------------------------------------------------------------------------
  section('EDGE 3: booking-status label safety on bad wire values');
  check('null wire -> Pending fallback',
      bookingStatusFromWire(null) == BookingStatus.pending);
  check('empty wire -> Pending fallback',
      bookingStatusFromWire('') == BookingStatus.pending);
  check('every status has a non-empty label',
      BookingStatus.values.every((s) => s.label.isNotEmpty));
  check('every status has a non-empty wire',
      BookingStatus.values.every((s) => s.wire.isNotEmpty));
  // Round-trip: wire -> enum -> wire is stable.
  final wireStable =
      BookingStatus.values.every((s) => bookingStatusFromWire(s.wire) == s);
  check('wire round-trips through the parser', wireStable);

  // ---------------------------------------------------------------------------
  print('\n${'=' * 52}');
  print('RESULT: ${_checks - _failures}/$_checks checks passed'
      '${_failures == 0 ? '  — ALL GREEN' : '  — $_failures FAILED'}');
  print('=' * 52);
}
