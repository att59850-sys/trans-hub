// Auth edge-case simulation (manual-QA style).
//
// Probes the sign-up / sign-in validation a real user (or attacker) hits:
// empty and malformed emails, blank names, too-short passwords, and whitespace
// handling. Runs on the plain Dart VM (works in the memory-constrained sandbox).

import 'package:transport_hub/core/utils/password_hasher.dart';
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

void main() {
  print('Trans-Hub — auth edge-case simulation\n');

  // ---------------------------------------------------------------------------
  section('AUTH 1: email validation rejects bad input');
  const bad = <String>[
    '', // empty
    '   ', // whitespace only
    'notanemail', // no @
    'foo@', // no domain
    '@example.com', // no local part
    'a@b', // domain not dotted
    'a@@b.com', // double @
    'a b@example.com', // space in local part
    'foo@bar.', // trailing dot
    'foo@.bar', // leading dot
  ];
  for (final e in bad) {
    check(
        'rejects "${e.isEmpty ? '<empty>' : e}"', !Validators.isValidEmail(e));
  }

  section('AUTH 2: email validation accepts good input');
  const good = <String>[
    'jane@example.com',
    'JANE@EXAMPLE.COM',
    ' jane@example.com ', // trimmed
    'first.last@sub.domain.co',
    'user+tag@gmail.com',
  ];
  for (final e in good) {
    check('accepts "$e"', Validators.isValidEmail(e));
  }

  // ---------------------------------------------------------------------------
  section('AUTH 3: password strength');
  check('rejects empty password', !Validators.isValidPassword(''));
  check('rejects 1-char password', !Validators.isValidPassword('a'));
  check('rejects 3-char password', !Validators.isValidPassword('abc'));
  check('accepts 4-char password', Validators.isValidPassword('abcd'));
  check('accepts long password',
      Validators.isValidPassword('a-very-long-passphrase'));

  // ---------------------------------------------------------------------------
  section('AUTH 4: composite signupError message ordering');
  check(
      'blank name reported first',
      Validators.signupError(name: '  ', email: 'x', password: 'x') ==
          'Please enter your name.');
  check(
      'bad email reported next',
      Validators.signupError(name: 'Jane', email: 'nope', password: 'x') ==
          'Please enter a valid email address.');
  check(
      'weak password reported next',
      Validators.signupError(name: 'Jane', email: 'j@e.com', password: 'ab') ==
          'Password must be at least 4 characters.');
  check(
      'valid input returns null (no error)',
      Validators.signupError(
              name: 'Jane', email: 'jane@example.com', password: 'secret') ==
          null);

  // ---------------------------------------------------------------------------
  section('AUTH 5: password hashing invariants (security)');
  const hasher = PasswordHasher();
  final h1 = hasher.hash('secret123');
  final h2 = hasher.hash('secret123');
  check('hash is not the plaintext', h1 != 'secret123');
  check('two hashes of same password differ (per-hash salt)', h1 != h2);
  check('both verify against the original', hasher.verify('secret123', h1));
  check('second hash also verifies', hasher.verify('secret123', h2));
  check('wrong password fails', !hasher.verify('nope', h1));
  check('salted hash is not "legacy"', !hasher.isLegacy(h1));

  // ---------------------------------------------------------------------------
  print('\n${'=' * 52}');
  print('RESULT: ${_checks - _failures}/$_checks checks passed'
      '${_failures == 0 ? '  — ALL GREEN' : '  — $_failures FAILED'}');
  print('=' * 52);
}
