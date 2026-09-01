import 'package:flutter_test/flutter_test.dart';
import 'package:transport_hub/core/verification/verification_status.dart';

/// Provider verification state machine (QA round 12). The facade used to apply
/// any status string with no check, so an approved company could be re-submitted
/// (losing its badge) and a misspelled status could strand a company out of the
/// review queue. These rules are the single source of truth the facade enforces.
void main() {
  group('VerificationStatusX.canTransitionTo', () {
    test('legal happy-path transitions', () {
      expect(
          VerificationStatus.unverified
              .canTransitionTo(VerificationStatus.submitted),
          isTrue);
      expect(
          VerificationStatus.submitted
              .canTransitionTo(VerificationStatus.underReview),
          isTrue);
      expect(
          VerificationStatus.underReview
              .canTransitionTo(VerificationStatus.approved),
          isTrue);
      expect(
          VerificationStatus.submitted
              .canTransitionTo(VerificationStatus.approved),
          isTrue);
      expect(
          VerificationStatus.rejected
              .canTransitionTo(VerificationStatus.submitted),
          isTrue);
    });

    test('approved is terminal (no self-demotion)', () {
      expect(VerificationStatus.approved.nextStates, isEmpty);
      for (final t in VerificationStatus.values) {
        expect(VerificationStatus.approved.canTransitionTo(t), isFalse,
            reason: 'approved → ${t.wire}');
      }
    });

    test('illegal jumps are blocked', () {
      expect(
          VerificationStatus.unverified
              .canTransitionTo(VerificationStatus.approved),
          isFalse);
      expect(
          VerificationStatus.rejected
              .canTransitionTo(VerificationStatus.approved),
          isFalse);
      expect(
          VerificationStatus.underReview
              .canTransitionTo(VerificationStatus.submitted),
          isFalse);
    });

    test('no self-transitions', () {
      for (final s in VerificationStatus.values) {
        expect(s.canTransitionTo(s), isFalse, reason: s.wire);
      }
    });
  });

  group('verificationStatusFromWire', () {
    test('parses known values and defaults junk to unverified', () {
      expect(
          verificationStatusFromWire('approved'), VerificationStatus.approved);
      expect(verificationStatusFromWire('under_review'),
          VerificationStatus.underReview);
      expect(
          verificationStatusFromWire('aproved'), VerificationStatus.unverified);
      expect(verificationStatusFromWire(null), VerificationStatus.unverified);
      expect(verificationStatusFromWire(''), VerificationStatus.unverified);
    });
  });

  group('isInReviewQueue', () {
    test('matches the review-queue definition', () {
      expect(VerificationStatus.submitted.isInReviewQueue, isTrue);
      expect(VerificationStatus.underReview.isInReviewQueue, isTrue);
      expect(VerificationStatus.approved.isInReviewQueue, isFalse);
      expect(VerificationStatus.rejected.isInReviewQueue, isFalse);
      expect(VerificationStatus.unverified.isInReviewQueue, isFalse);
    });
  });
}
