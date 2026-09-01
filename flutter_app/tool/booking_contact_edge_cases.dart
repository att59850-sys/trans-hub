// Booking/quote contact-detail edge-case simulation (manual-QA style).
//
// QA round 11 acts as a customer filling in the "Confirm booking request" /
// "Send quote request" form on a company page. The form's only guard was:
//
//   if (name.text.trim().isEmpty || email.text.trim().isEmpty) { ...reject... }
//
// i.e. it checked that name/email are NON-EMPTY but never that the email is
// well-formed. So "notanemail" (or "j@", "@x.com", "a b@c.com") sailed through
// and the booking was created with a contact address the provider can never
// reach — a silent dead-end for the customer.
//
// The facade (createBooking) had no contact validation at all, so any other
// code path could create a booking with empty/garbage contact details.
//
// This runs on the plain Dart VM: the rule now lives in Validators
// (single source of truth) and is exercised here the way both the form and the
// facade will call it.

import 'package:transport_hub/core/utils/validators.dart';

int _checks = 0;
int _failures = 0;

void check(String desc, bool ok, [String? detail]) {
  _checks++;
  final tag = ok ? 'PASS' : 'FAIL';
  if (!ok) _failures++;
  print('   $tag  $desc${detail != null ? '  ($detail)' : ''}');
}

void section(String title) => print('\n== $title ==');

/// The OLD form guard — non-emptiness only. Kept to demonstrate the gap.
bool oldFormAccepts(String name, String email) =>
    name.trim().isNotEmpty && email.trim().isNotEmpty;

void main() {
  print('Trans-Hub — booking contact edge-case simulation\n');

  // ---------------------------------------------------------------------------
  section('BOOKING 1: the raw (undefended) gap');
  for (final bad in [
    'notanemail',
    'j@',
    '@example.com',
    'a b@c.com',
    'foo@bar'
  ]) {
    check('DEMO: old form accepted garbage email "$bad"',
        oldFormAccepts('Jane', bad), 'accepted=${oldFormAccepts('Jane', bad)}');
  }

  // ---------------------------------------------------------------------------
  section('BOOKING 2: new rule rejects empty / malformed contact');
  check(
      'empty name rejected',
      Validators.bookingContactError(name: '  ', email: 'j@example.com') ==
          'Please enter your name.');
  check(
      'empty email rejected',
      Validators.bookingContactError(name: 'Jane', email: '  ') ==
          'Please enter a valid email address.');
  for (final bad in [
    'notanemail',
    'j@',
    '@example.com',
    'a b@c.com',
    'foo@bar'
  ]) {
    check(
        'malformed email "$bad" rejected',
        Validators.bookingContactError(name: 'Jane', email: bad) != null,
        Validators.bookingContactError(name: 'Jane', email: bad));
  }

  // ---------------------------------------------------------------------------
  section('BOOKING 3: new rule accepts valid contact');
  for (final good in [
    'jane@example.com',
    ' JANE@EXAMPLE.COM ',
    'first.last@sub.domain.co',
    'user+tag@gmail.com',
  ]) {
    check('valid email "$good" accepted',
        Validators.bookingContactError(name: 'Jane', email: good) == null);
  }

  // ---------------------------------------------------------------------------
  section('BOOKING 4: name-before-email ordering (matches form field order)');
  check(
      'reports name error first when both are bad',
      Validators.bookingContactError(name: '', email: 'nope') ==
          'Please enter your name.');

  // ---------------------------------------------------------------------------
  print('\n${'=' * 60}');
  print('RESULT: ${_checks - _failures}/$_checks checks passed');
  if (_failures > 0) {
    print('$_failures FAILURE(S) — see FAIL lines above.');
  } else {
    print('All booking-contact invariants hold.');
  }
}
