import 'package:flutter_test/flutter_test.dart';
import 'package:transport_hub/core/utils/validators.dart';

/// Shared sign-up validation rules. Regression coverage for a QA finding where
/// the DataService facade accepted empty emails and 1-character passwords that
/// the auth repository would have rejected; both now use these rules.
void main() {
  group('Validators.isValidEmail', () {
    test('rejects malformed / empty input', () {
      for (final e in [
        '',
        '   ',
        'notanemail',
        'foo@',
        '@example.com',
        'a@b', // domain not dotted
        'a@@b.com',
        'a b@example.com',
        'foo@bar.',
        'foo@.bar',
      ]) {
        expect(Validators.isValidEmail(e), isFalse, reason: '"$e"');
      }
    });

    test('accepts valid addresses (case-insensitive, trimmed)', () {
      for (final e in [
        'jane@example.com',
        'JANE@EXAMPLE.COM',
        ' jane@example.com ',
        'first.last@sub.domain.co',
        'user+tag@gmail.com',
      ]) {
        expect(Validators.isValidEmail(e), isTrue, reason: '"$e"');
      }
    });
  });

  group('Validators.isValidPassword', () {
    test('enforces the minimum length', () {
      expect(Validators.isValidPassword(''), isFalse);
      expect(Validators.isValidPassword('abc'), isFalse);
      expect(Validators.isValidPassword('abcd'), isTrue);
      expect(Validators.minPasswordLength, 4);
    });
  });

  group('Validators.signupError', () {
    test('reports the first failing field, in field order', () {
      expect(Validators.signupError(name: '  ', email: 'x', password: 'x'),
          'Please enter your name.');
      expect(Validators.signupError(name: 'J', email: 'nope', password: 'x'),
          'Please enter a valid email address.');
      expect(
          Validators.signupError(name: 'J', email: 'j@e.com', password: 'ab'),
          'Password must be at least 4 characters.');
    });

    test('returns null for valid input', () {
      expect(
        Validators.signupError(
            name: 'Jane', email: 'jane@example.com', password: 'secret'),
        isNull,
      );
    });
  });
}
