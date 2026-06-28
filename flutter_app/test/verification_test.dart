import 'package:flutter_test/flutter_test.dart';
import 'package:transport_hub/models/models.dart';

/// TH-017 — Verification status on the UI-facing Company model.
///
/// Ensures the new `verificationStatus` field round-trips through JSON and
/// stays backward-compatible with records that only carry the legacy
/// `verified` boolean.
void main() {
  group('Company verification status', () {
    test('defaults to unverified for a new company', () {
      final c = Company(ownerId: 'u1', name: 'Acme');
      expect(c.verificationStatus, 'unverified');
      expect(c.verified, isFalse);
    });

    test('derives "approved" from a legacy verified=true flag', () {
      final c = Company(ownerId: 'u1', name: 'Acme', verified: true);
      expect(c.verificationStatus, 'approved');
    });

    test('round-trips an explicit status through JSON', () {
      final c = Company(
        ownerId: 'u1',
        name: 'Acme',
        verificationStatus: 'under_review',
      );
      final back = Company.fromJson(c.toJson());
      expect(back.verificationStatus, 'under_review');
    });

    test('legacy JSON without verificationStatus falls back to verified', () {
      final legacy = {
        'id': 'c1',
        'ownerId': 'u1',
        'name': 'Acme',
        'verified': true,
        // no verificationStatus key (older record)
      };
      final c = Company.fromJson(legacy);
      expect(c.verificationStatus, 'approved');
    });

    test('legacy unverified JSON falls back to unverified', () {
      final legacy = {
        'id': 'c1',
        'ownerId': 'u1',
        'name': 'Acme',
        'verified': false,
      };
      final c = Company.fromJson(legacy);
      expect(c.verificationStatus, 'unverified');
    });
  });
}
