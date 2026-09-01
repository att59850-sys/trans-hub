// Review-integrity edge-case simulation (manual-QA style).
//
// Probes rating-abuse vectors a user or corrupt data can introduce: out-of-range
// star values (0, 6, 999, negative), and how they would skew a displayed
// average if not defended. Runs on the plain Dart VM.

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

/// Mirrors the (fixed) aggregate used by DataService/ReviewRepository: clamp
/// every stored rating into range before averaging.
({double avg, int count}) safeAverage(List<int> ratings) {
  if (ratings.isEmpty) return (avg: 0, count: 0);
  final clamped = ratings.map(Validators.clampRating);
  final avg = clamped.reduce((a, b) => a + b) / ratings.length;
  return (avg: (avg * 10).round() / 10, count: ratings.length);
}

/// The OLD, undefended aggregate — kept only to show the skew it produced.
double naiveAverage(List<int> ratings) =>
    ratings.reduce((a, b) => a + b) / ratings.length;

void main() {
  print('Trans-Hub — review-integrity edge-case simulation\n');

  // ---------------------------------------------------------------------------
  section('REVIEW 1: rating bounds validation');
  check('rejects 0 stars', !Validators.isValidRating(0));
  check('rejects 6 stars', !Validators.isValidRating(6));
  check('rejects 999 stars', !Validators.isValidRating(999));
  check('rejects negative stars', !Validators.isValidRating(-3));
  for (var r = 1; r <= 5; r++) {
    check('accepts $r stars', Validators.isValidRating(r));
  }

  // ---------------------------------------------------------------------------
  section('REVIEW 2: clamping keeps averages sane');
  check('clamp(0) -> 1', Validators.clampRating(0) == 1);
  check('clamp(6) -> 5', Validators.clampRating(6) == 5);
  check('clamp(999) -> 5', Validators.clampRating(999) == 5);
  check('clamp(-5) -> 1', Validators.clampRating(-5) == 1);
  check('clamp(3) -> 3 (unchanged)', Validators.clampRating(3) == 3);

  // ---------------------------------------------------------------------------
  section('REVIEW 3: a malicious rating can no longer skew the average');
  // Two honest 5-star reviews + one abusive 999-star.
  final ratings = [5, 5, 999];
  final naive = naiveAverage(ratings);
  final safe = safeAverage(ratings);
  print('   naive (buggy) avg = ${naive.toStringAsFixed(1)}');
  print('   safe  (fixed) avg = ${safe.avg}');
  check('buggy path WOULD have exceeded 5 stars', naive > 5.0);
  check('fixed average stays within 1..5', safe.avg >= 1 && safe.avg <= 5.0);
  check('fixed average is a sensible 5.0', safe.avg == 5.0);
  check('count is unaffected', safe.count == 3);

  // A single 0-star troll among 5-stars drags the average but stays >= 1.
  final mixed = safeAverage([5, 5, 5, 0]);
  check('0-star clamps to 1 and average stays >= 1', mixed.avg >= 1.0,
      '${mixed.avg}');

  // ---------------------------------------------------------------------------
  section('REVIEW 4: review text validation');
  check('rejects empty text', !Validators.isValidReviewText(''));
  check('rejects whitespace-only text', !Validators.isValidReviewText('   '));
  check('accepts real text', Validators.isValidReviewText('Great service!'));

  // ---------------------------------------------------------------------------
  print('\n${'=' * 54}');
  print('RESULT: ${_checks - _failures}/$_checks checks passed'
      '${_failures == 0 ? '  — ALL GREEN' : '  — $_failures FAILED'}');
  print('=' * 54);
}
