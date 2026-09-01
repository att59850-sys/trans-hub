// QA round 19 — password hasher / legacy-login edge cases (pure-Dart harness).
//
// PasswordHasher is dependency-free (crypto only), so this harness imports the
// REAL class and exercises hash()/verify()/isLegacy() the way DataService.login
// uses them, including the transparent legacy-plaintext upgrade path.
//
// Bug found acting as a returning user: the legacy-plaintext fallback keyed off
// whether the STORED value contained a ':'. A pre-migration user whose plaintext
// password itself contained a ':' (e.g. "correct:horse") was mis-detected as an
// already-salted hash. verify() then split it into a bogus salt+digest and the
// comparison failed — so a legitimate legacy user was locked out even with the
// RIGHT password.
//
// The fix tags the salted format with a scheme prefix ("s1:salt:digest") so
// legacy detection no longer depends on the password's own characters. Existing
// untagged "salt:digest" hashes and plaintext both keep working.
//
// Run: dart run tool/auth_hasher_edge_cases.dart

import '../lib/core/utils/password_hasher.dart';

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

const _h = PasswordHasher();

void main() {
  print('== QA round 19: password hasher / legacy login edge cases ==\n');

  // ------------------------------------------------------------------
  // Sanity: normal hash/verify round-trips.
  // ------------------------------------------------------------------
  print('-- sanity: salted hash round-trips --');
  {
    final stored = _h.hash('secret123');
    check('new hash carries the s1: scheme prefix', stored.startsWith('s1:'));
    check('correct password verifies', _h.verify('secret123', stored));
    check('wrong password rejected', !_h.verify('nope', stored));
    check('a fresh hash is not flagged legacy', !_h.isLegacy(stored));
    check('unique salt per hash', _h.hash('x') != _h.hash('x'));
  }

  print('\n-- sanity: legacy plaintext still verifies + is flagged --');
  {
    const legacyPlain = 'plainpw';
    check('legacy plaintext verifies', _h.verify('plainpw', legacyPlain));
    check('legacy plaintext is flagged for upgrade', _h.isLegacy(legacyPlain));
  }

  // ------------------------------------------------------------------
  // The round-19 bug: a legacy password containing ':' must still work.
  // ------------------------------------------------------------------
  print('\n-- fixed: legacy password containing a colon now works --');
  {
    const legacyColon = 'correct:horse';
    check('isLegacy is TRUE for a non-scheme value', _h.isLegacy(legacyColon));
    check('verify accepts the correct legacy colon-password',
        _h.verify('correct:horse', legacyColon));
    check('verify rejects a wrong legacy password',
        !_h.verify('wrong', legacyColon));
  }

  print('\n-- fixed: a passphrase with several colons is plaintext --');
  {
    const pw = 'a:b:c:d';
    check('multi-colon value is legacy', _h.isLegacy(pw));
    check('multi-colon value verifies verbatim', _h.verify('a:b:c:d', pw));
    check('multi-colon value rejects the wrong password',
        !_h.verify('a:b:c', pw));
  }

  print('\n-- fixed: back-compat with the OLD untagged "salt:digest" --');
  {
    // Strip the scheme tag to simulate a hash written before s1: existed.
    final tagged = _h.hash('legacyHashed'); // s1:salt:digest
    final untagged = tagged.substring('s1:'.length); // salt:digest
    check('untagged value is NOT scheme-prefixed', !untagged.startsWith('s1:'));
    check('untagged old-format hash still verifies',
        _h.verify('legacyHashed', untagged));
    check('untagged old-format hash is not treated as plaintext-legacy',
        !_h.isLegacy(untagged));
    check('untagged old-format hash rejects the wrong password',
        !_h.verify('nope', untagged));
  }

  print('\n-- fixed: empty-ish and odd inputs do not crash --');
  {
    final t = _h.hash('');
    check('empty password hashes + verifies', _h.verify('', t));
    check('empty != nonempty', !_h.verify('x', t));
    check('plaintext empty legacy verifies', _h.verify('', ''));
  }

  print('\n== $_passed passed, $_failed failed ==');
  if (_failed > 0) {
    throw StateError('auth hasher edge cases failed');
  }
}
