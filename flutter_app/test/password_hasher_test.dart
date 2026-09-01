import 'package:flutter_test/flutter_test.dart';
import 'package:transport_hub/core/utils/password_hasher.dart';

void main() {
  const hasher = PasswordHasher();

  group('PasswordHasher', () {
    test('hash is salted (not plaintext) and verifies', () {
      final h = hasher.hash('secret123');
      expect(h, isNot('secret123'));
      expect(h.contains(':'), isTrue);
      expect(hasher.verify('secret123', h), isTrue);
      expect(hasher.verify('wrong', h), isFalse);
    });

    test('two hashes of same password differ (random salt)', () {
      expect(hasher.hash('abc'), isNot(hasher.hash('abc')));
    });

    test('legacy plaintext is detected and still verifies', () {
      expect(hasher.isLegacy('plaintextpw'), isTrue);
      expect(hasher.verify('plaintextpw', 'plaintextpw'), isTrue);
      expect(hasher.isLegacy(hasher.hash('x')), isFalse);
    });

    group('scheme-tagged format + colon-safe legacy (QA round 19)', () {
      test('new hashes carry the s1: scheme prefix', () {
        expect(hasher.hash('secret123').startsWith('s1:'), isTrue);
      });

      test('a legacy plaintext password containing a colon still verifies', () {
        // Before the fix, "correct:horse" stored as plaintext was mis-parsed
        // as a salt:digest hash, locking the user out with the RIGHT password.
        const legacyColon = 'correct:horse';
        expect(hasher.isLegacy(legacyColon), isTrue,
            reason: 'a colon in the password does not make it a hash');
        expect(hasher.verify('correct:horse', legacyColon), isTrue);
        expect(hasher.verify('wrong', legacyColon), isFalse);
      });

      test('a passphrase with multiple colons is treated as plaintext', () {
        const pw = 'a:b:c:d';
        expect(hasher.isLegacy(pw), isTrue);
        expect(hasher.verify('a:b:c:d', pw), isTrue);
      });

      test('back-compat: an untagged salt:digest hash still verifies', () {
        // Simulate a hash written before the scheme tag existed.
        final tagged = hasher.hash('legacyHashed'); // s1:salt:digest
        final untagged = tagged.substring('s1:'.length); // salt:digest
        expect(untagged.startsWith('s1:'), isFalse);
        expect(hasher.verify('legacyHashed', untagged), isTrue);
        expect(hasher.isLegacy(untagged), isFalse,
            reason: 'a real salt:digest is not plaintext-legacy');
      });

      test('empty password hashes and verifies', () {
        final h = hasher.hash('');
        expect(hasher.verify('', h), isTrue);
        expect(hasher.verify('x', h), isFalse);
      });
    });
  });
}
