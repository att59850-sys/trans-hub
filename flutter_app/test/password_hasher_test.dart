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
  });
}
