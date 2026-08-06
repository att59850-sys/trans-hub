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

  group('Validators rating rules', () {
    test('isValidRating enforces the 1..5 range', () {
      expect(Validators.isValidRating(0), isFalse);
      expect(Validators.isValidRating(6), isFalse);
      expect(Validators.isValidRating(999), isFalse);
      expect(Validators.isValidRating(-3), isFalse);
      for (var r = 1; r <= 5; r++) {
        expect(Validators.isValidRating(r), isTrue);
      }
    });

    test('clampRating pins out-of-range values into 1..5', () {
      expect(Validators.clampRating(0), 1);
      expect(Validators.clampRating(-5), 1);
      expect(Validators.clampRating(6), 5);
      expect(Validators.clampRating(999), 5);
      expect(Validators.clampRating(3), 3);
    });

    test('isValidReviewText requires non-empty body', () {
      expect(Validators.isValidReviewText(''), isFalse);
      expect(Validators.isValidReviewText('   '), isFalse);
      expect(Validators.isValidReviewText('ok'), isTrue);
    });
  });

  group('Validators price rules', () {
    test('isValidPrice rejects non-finite, negative and absurd values', () {
      expect(Validators.isValidPrice(double.infinity), isFalse);
      expect(Validators.isValidPrice(double.negativeInfinity), isFalse);
      expect(Validators.isValidPrice(double.nan), isFalse);
      expect(Validators.isValidPrice(-0.01), isFalse);
      expect(Validators.isValidPrice(-50), isFalse);
      expect(Validators.isValidPrice(1e12), isFalse);
    });

    test('isValidPrice accepts 0..max', () {
      expect(Validators.isValidPrice(0), isTrue);
      expect(Validators.isValidPrice(120.50), isTrue);
      expect(Validators.isValidPrice(Validators.maxServicePrice), isTrue);
    });

    test('sanitizePrice maps every hazard to a safe value', () {
      expect(Validators.sanitizePrice(double.infinity), 0);
      expect(Validators.sanitizePrice(double.negativeInfinity), 0);
      expect(Validators.sanitizePrice(double.nan), 0);
      expect(Validators.sanitizePrice(-50), 0);
      expect(Validators.sanitizePrice(1e12), Validators.maxServicePrice);
      expect(Validators.sanitizePrice(120.50), 120.50);
    });
  });

  group('Validators.bookingContactError', () {
    test('rejects empty name first, then malformed email', () {
      expect(Validators.bookingContactError(name: ' ', email: 'j@e.com'),
          'Please enter your name.');
      for (final bad in [
        '',
        '   ',
        'notanemail',
        'j@',
        '@example.com',
        'a b@c.com',
        'foo@bar',
      ]) {
        expect(Validators.bookingContactError(name: 'Jane', email: bad),
            'Please enter a valid email address.',
            reason: '"$bad"');
      }
    });

    test('accepts a real name + well-formed email (trimmed, any case)', () {
      for (final good in [
        'jane@example.com',
        ' JANE@EXAMPLE.COM ',
        'first.last@sub.domain.co',
        'user+tag@gmail.com',
      ]) {
        expect(
            Validators.bookingContactError(name: 'Jane', email: good), isNull,
            reason: '"$good"');
      }
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
