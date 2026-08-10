// Provider-verification lifecycle edge-case simulation (manual-QA style).
//
// QA round 12 acts as (a) a provider on their dashboard and (b) an admin in the
// review queue. Before this fix the facade applied ANY status string with no
// state-machine check:
//
//   void submitForVerification(id)      { c.verificationStatus = 'submitted'; }
//   void setVerificationStatus(id, s)   { c.verificationStatus = s; ... }
//
// So two real defects existed:
//   1. An APPROVED company could be re-submitted, silently dropping its verified
//      badge and re-entering the review queue (the dashboard hides the Submit
//      button once approved, but the facade had no guard, so any other path —
//      or a stale screen — could do it).
//   2. setVerificationStatus accepted illegal jumps (unverified → approved with
//      no submission) and even MISSPELLED statuses ("aproved"), which left the
//      company neither in the queue nor verified — stranded in limbo.
//
// This runs on the plain Dart VM against the new VerificationStatus state
// machine (single source of truth the facade now enforces).

import 'package:transport_hub/core/verification/verification_status.dart';

int _checks = 0;
int _failures = 0;

void check(String desc, bool ok, [String? detail]) {
  _checks++;
  final tag = ok ? 'PASS' : 'FAIL';
  if (!ok) _failures++;
  print('   $tag  $desc${detail != null ? '  ($detail)' : ''}');
}

void section(String title) => print('\n== $title ==');

const _all = VerificationStatus.values;

void main() {
  print('Trans-Hub — provider verification edge-case simulation\n');

  // ---------------------------------------------------------------------------
  section('VERIF 1: legal happy-path transitions');
  check(
      'unverified → submitted',
      VerificationStatus.unverified
          .canTransitionTo(VerificationStatus.submitted));
  check(
      'submitted → under_review',
      VerificationStatus.submitted
          .canTransitionTo(VerificationStatus.underReview));
  check(
      'under_review → approved',
      VerificationStatus.underReview
          .canTransitionTo(VerificationStatus.approved));
  check(
      'submitted → approved (fast-track)',
      VerificationStatus.submitted
          .canTransitionTo(VerificationStatus.approved));
  check(
      'submitted → rejected',
      VerificationStatus.submitted
          .canTransitionTo(VerificationStatus.rejected));
  check(
      'rejected → submitted (re-apply)',
      VerificationStatus.rejected
          .canTransitionTo(VerificationStatus.submitted));

  // ---------------------------------------------------------------------------
  section('VERIF 2: approved is terminal — no self-demotion');
  check(
      'approved → submitted rejected (the round-12 bug)',
      !VerificationStatus.approved
          .canTransitionTo(VerificationStatus.submitted));
  check(
      'approved → under_review rejected',
      !VerificationStatus.approved
          .canTransitionTo(VerificationStatus.underReview));
  check(
      'approved → rejected rejected',
      !VerificationStatus.approved
          .canTransitionTo(VerificationStatus.rejected));
  check('approved has no next states',
      VerificationStatus.approved.nextStates.isEmpty);

  // ---------------------------------------------------------------------------
  section('VERIF 3: illegal jumps are blocked');
  check(
      'unverified → approved blocked (never submitted)',
      !VerificationStatus.unverified
          .canTransitionTo(VerificationStatus.approved));
  check(
      'unverified → under_review blocked',
      !VerificationStatus.unverified
          .canTransitionTo(VerificationStatus.underReview));
  check(
      'rejected → approved blocked (must re-submit first)',
      !VerificationStatus.rejected
          .canTransitionTo(VerificationStatus.approved));
  check(
      'under_review → submitted blocked (no going back)',
      !VerificationStatus.underReview
          .canTransitionTo(VerificationStatus.submitted));

  // ---------------------------------------------------------------------------
  section('VERIF 4: no self-transitions');
  for (final s in _all) {
    check('${s.wire} → ${s.wire} blocked', !s.canTransitionTo(s));
  }

  // ---------------------------------------------------------------------------
  section('VERIF 5: wire parsing tolerates junk (→ unverified)');
  check('"approved" parses',
      verificationStatusFromWire('approved') == VerificationStatus.approved);
  check('misspelled "aproved" → unverified',
      verificationStatusFromWire('aproved') == VerificationStatus.unverified);
  check('null → unverified',
      verificationStatusFromWire(null) == VerificationStatus.unverified);
  check('empty → unverified',
      verificationStatusFromWire('') == VerificationStatus.unverified);

  // ---------------------------------------------------------------------------
  section('VERIF 6: review-queue membership matches the facade getter');
  check('submitted is in queue', VerificationStatus.submitted.isInReviewQueue);
  check('under_review is in queue',
      VerificationStatus.underReview.isInReviewQueue);
  check('approved NOT in queue', !VerificationStatus.approved.isInReviewQueue);
  check('rejected NOT in queue', !VerificationStatus.rejected.isInReviewQueue);
  check('unverified NOT in queue',
      !VerificationStatus.unverified.isInReviewQueue);

  // ---------------------------------------------------------------------------
  print('\n${'=' * 60}');
  print('RESULT: ${_checks - _failures}/$_checks checks passed');
  if (_failures > 0) {
    print('$_failures FAILURE(S) — see FAIL lines above.');
  } else {
    print('All provider-verification invariants hold.');
  }
}
