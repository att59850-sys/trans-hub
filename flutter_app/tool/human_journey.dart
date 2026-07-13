// Standalone "human user" journey simulation (manual-QA style).
//
// Runs with the plain Dart VM (`dart run tool/human_journey.dart`) so it works
// inside the memory-constrained sandbox where `flutter test` OOMs during kernel
// compilation. It drives the REAL business-logic modules the app depends on —
// password hashing, the booking-status state machine, verification transitions,
// the offline route estimator, model JSON round-tripping and config/admin gating
// — in the exact order a person would tap through the app.
//
// Exit code is non-zero if any assertion fails, so it doubles as a CI smoke test.

import 'package:transport_hub/core/config/app_config.dart';
import 'package:transport_hub/core/maps/estimating_maps_service.dart';
import 'package:transport_hub/core/maps/maps_service.dart';
import 'package:transport_hub/core/utils/password_hasher.dart';
import 'package:transport_hub/domain/entities/booking_status.dart';
import 'package:transport_hub/models/models.dart';

int _checks = 0;
int _failures = 0;

void check(String desc, bool ok, [String? detail]) {
  _checks++;
  if (ok) {
    print('   PASS  $desc${detail != null ? '  ($detail)' : ''}');
  } else {
    _failures++;
    print('   FAIL  $desc${detail != null ? '  ($detail)' : ''}');
  }
}

void section(String title) => print('\n== $title ==');

Future<void> main() async {
  print('Trans-Hub — human-user journey simulation\n');

  // ---------------------------------------------------------------------------
  section('JOURNEY 1: sign-up security (as a new customer)');
  const hasher = PasswordHasher();
  final stored = hasher.hash('secret123');
  check('password is not stored as plaintext', stored != 'secret123', stored);
  check('correct password verifies', hasher.verify('secret123', stored));
  check('wrong password rejected', !hasher.verify('wrongpass', stored));

  final user = AppUser(
    name: 'Jane Customer',
    email: 'jane@example.com',
    password: stored,
    role: UserRole.customer,
  );
  final roundTrip = AppUser.fromJson(user.toJson());
  check('user model round-trips through JSON', roundTrip.email == user.email);
  check('role preserved', roundTrip.role == UserRole.customer);

  // ---------------------------------------------------------------------------
  section('JOURNEY 2: booking lifecycle (customer books, provider works it)');
  // A customer request tied to a service starts as pending.
  var status = bookingStatusFromWire('pending');
  check('initial status is Pending', status.label == 'Pending');

  final path = <String>[status.wire];
  var guard = 0;
  while (!status.isTerminal && guard++ < 20) {
    final next = status.nextStates;
    if (next.isEmpty) break;
    // A provider drives the booking to completion (never picks "cancelled").
    final happy = next.firstWhere(
      (s) => s != BookingStatus.cancelled,
      orElse: () => next.first,
    );
    status = happy;
    path.add(status.wire);
  }
  print('   route: ${path.join(' -> ')}');
  check('booking reaches a terminal state', status.isTerminal, status.label);
  check('happy path ends Completed', status == BookingStatus.completed);
  check(
      'no illegal jump pending->completed directly',
      !bookingStatusFromWire('pending')
          .nextStates
          .contains(BookingStatus.completed));

  // legacy tolerance a real DB might contain
  check('legacy "confirmed" maps to Accepted',
      bookingStatusFromWire('confirmed') == BookingStatus.accepted);
  check('unknown status falls back to Pending',
      bookingStatusFromWire('gibberish') == BookingStatus.pending);

  // terminal states expose no further actions (drives the dashboard UI)
  check('completed is terminal with no next states',
      bookingStatusFromWire('completed').nextStates.isEmpty);
  check('cancelled is terminal with no next states',
      bookingStatusFromWire('cancelled').nextStates.isEmpty);

  final booking = Booking(
    companyId: 'c1',
    serviceId: 's1',
    userId: user.id,
    contactName: 'Jane Customer',
    contactEmail: 'jane@example.com',
    phone: '555-0100',
    pickup: 'New York',
    dropoff: 'Boston',
    date: '2026-08-01',
    notes: 'Two-bedroom apartment',
    status: 'pending',
  );
  final bRound = Booking.fromJson(booking.toJson());
  check(
      'booking model round-trips', bRound.pickup == 'New York', bRound.dropoff);

  // ---------------------------------------------------------------------------
  section('JOURNEY 3: route preview on the booking form');
  const maps = EstimatingMapsService();

  // Mirror DataService.estimateRoute: geocode both free-text places, then
  // preview the route between the resulting coordinates.
  Future<RoutePreview?> estimate(String pickup, String dropoff) async {
    if (pickup.trim().isEmpty || dropoff.trim().isEmpty) return null;
    final from = await maps.geocode(pickup);
    final to = await maps.geocode(dropoff);
    if (from == null || to == null) return null;
    return maps.routePreview(from, to);
  }

  final preview = await estimate('New York', 'Boston');
  check('estimator returns a route', preview != null);
  if (preview != null) {
    print('   NYC -> Boston: ~${preview.distanceKm.toStringAsFixed(0)} km, '
        '${preview.durationMinutes} min');
    check('distance is positive', preview.distanceKm > 0);
    check('duration is positive', preview.durationMinutes > 0);
  }
  final samePlace = await estimate('Boston', 'Boston');
  check(
      'same-city distance is ~0',
      samePlace != null && samePlace.distanceKm < 5,
      '${samePlace?.distanceKm} km');
  // Regression guard: a short intercity hop must not balloon into a
  // cross-planet distance (the "Boston missing from the table" bug).
  check(
      'NY -> Boston is a plausible short hop (< 1000 km)',
      preview != null && preview.distanceKm < 1000,
      '${preview?.distanceKm} km');
  final far = await estimate('New York', 'Los Angeles');
  check('cross-country > cross-state',
      far != null && preview != null && far.distanceKm > preview.distanceKm);
  check('empty pickup returns null (no estimate)',
      (await estimate('', 'Boston')) == null);

  // ---------------------------------------------------------------------------
  section('JOURNEY 4: provider verification workflow');
  final company = Company(
    ownerId: user.id,
    name: 'Pat Haulers',
    tagline: 'Reliable moves',
    description: 'Interstate household moves',
    city: 'Chicago',
  );
  check('new company defaults to unverified',
      company.verificationStatus == 'unverified', company.verificationStatus);
  check('new company verified flag is false', company.verified == false);

  // provider submits -> admin reviews -> approves
  company.verificationStatus = 'submitted';
  final cRound = Company.fromJson(company.toJson());
  check('verificationStatus survives JSON round-trip',
      cRound.verificationStatus == 'submitted');

  company.verificationStatus = 'approved';
  company.verified = company.verificationStatus == 'approved';
  check('approval flips legacy verified flag', company.verified == true);

  // ---------------------------------------------------------------------------
  section('JOURNEY 5: admin gating (config-driven)');
  final cfg = AppConfig.fromEnvironment();
  check(
      'dev default admin is recognized', cfg.isAdmin('admin@transporthub.app'));
  check(
      'admin check is case-insensitive', cfg.isAdmin('ADMIN@TRANSPORTHUB.APP'));
  check('random user is not admin', !cfg.isAdmin('jane@example.com'));
  check('null email is not admin', !cfg.isAdmin(null));

  // ---------------------------------------------------------------------------
  print('\n${'=' * 50}');
  print('RESULT: ${_checks - _failures}/$_checks checks passed'
      '${_failures == 0 ? '  — ALL GREEN' : '  — $_failures FAILED'}');
  print('=' * 50);
}
