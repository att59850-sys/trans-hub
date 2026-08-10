/// Provider verification lifecycle (TH-017).
///
/// unverified → submitted → under_review → approved / rejected
///   * a provider submits from `unverified` OR `rejected` (re-apply);
///   * an admin moves `submitted` → `under_review` → `approved`/`rejected`
///     (and may approve/reject straight from `submitted`);
///   * `approved` is effectively terminal — a verified provider must not be
///     able to knock themselves back into the queue by re-submitting.
///
/// This mirrors the booking-status state machine: a single source of truth the
/// UI uses to *offer* actions and the facade uses to *reject* illegal ones. A
/// QA pass (round 12) found the facade applied ANY status string with no
/// validation, so an approved company could be silently re-submitted (losing
/// its badge) or set to a misspelled status that stranded it out of the queue.
enum VerificationStatus {
  unverified,
  submitted,
  underReview,
  approved,
  rejected,
}

extension VerificationStatusX on VerificationStatus {
  /// Wire/storage value (snake_case), stable across versions.
  String get wire => switch (this) {
        VerificationStatus.unverified => 'unverified',
        VerificationStatus.submitted => 'submitted',
        VerificationStatus.underReview => 'under_review',
        VerificationStatus.approved => 'approved',
        VerificationStatus.rejected => 'rejected',
      };

  /// Human-readable label (matches DataService.verificationLabel).
  String get label => switch (this) {
        VerificationStatus.unverified => 'Unverified',
        VerificationStatus.submitted => 'Submitted',
        VerificationStatus.underReview => 'Under review',
        VerificationStatus.approved => 'Verified',
        VerificationStatus.rejected => 'Rejected',
      };

  /// Whether a company in this state is awaiting an admin decision.
  bool get isInReviewQueue =>
      this == VerificationStatus.submitted ||
      this == VerificationStatus.underReview;

  /// Valid next states from here.
  List<VerificationStatus> get nextStates => switch (this) {
        VerificationStatus.unverified => [VerificationStatus.submitted],
        VerificationStatus.rejected => [VerificationStatus.submitted],
        VerificationStatus.submitted => [
            VerificationStatus.underReview,
            VerificationStatus.approved,
            VerificationStatus.rejected,
          ],
        VerificationStatus.underReview => [
            VerificationStatus.approved,
            VerificationStatus.rejected,
          ],
        VerificationStatus.approved => const [],
      };

  /// Whether moving directly to [target] is a legal transition.
  bool canTransitionTo(VerificationStatus target) =>
      nextStates.contains(target);
}

/// Parses a [VerificationStatus] from its wire value; unknown/empty → unverified.
VerificationStatus verificationStatusFromWire(String? s) => switch (s) {
      'submitted' => VerificationStatus.submitted,
      'under_review' => VerificationStatus.underReview,
      'approved' => VerificationStatus.approved,
      'rejected' => VerificationStatus.rejected,
      _ => VerificationStatus.unverified,
    };
