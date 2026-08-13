// QA round 14 — review submission edge cases (pure-Dart harness).
//
// Runs the review submission rules WITHOUT Flutter/Hive by re-implementing the
// facade's store-and-aggregate logic in-memory. The point is to demonstrate the
// concrete bug found while acting as a human user (a single account posting the
// same/many reviews for one company skews its displayed average and inflates
// its review count — and a company owner can review their own company), and to
// prove the hardened rule fixes it.
//
// Run: dart run tool/review_submission_edge_cases.dart
//
// This mirrors DataService.addReview / reviewsFor / ratingFor and
// ReviewRepositoryImpl.add so the harness stays honest about real behaviour.

import '../lib/core/utils/validators.dart';
import '../lib/models/models.dart';

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

/// Minimal in-memory review store that mirrors the RAW (pre-fix) facade:
/// every addReview simply appends a row keyed by its unique id.
class RawReviewStore {
  final Map<String, Review> _rows = {};

  void addReview(Review r) {
    // Raw behaviour today: text + rating are guarded, but nothing prevents the
    // same user from posting again and again for the same company.
    if (!Validators.isValidReviewText(r.text)) {
      throw Exception('Please write a short review.');
    }
    r.rating = Validators.clampRating(r.rating);
    _rows[r.id] = r;
  }

  List<Review> forCompany(String companyId) =>
      _rows.values.where((r) => r.companyId == companyId).toList();

  ({double avg, int count}) ratingFor(String companyId) {
    final rs = forCompany(companyId);
    if (rs.isEmpty) return (avg: 0, count: 0);
    final avg = rs
            .map((r) => Validators.clampRating(r.rating))
            .reduce((a, b) => a + b) /
        rs.length;
    return (avg: (avg * 10).round() / 10, count: rs.length);
  }
}

/// Hardened store mirroring the FIXED facade: one review per (userId, companyId)
/// — a repeat submission updates the existing row in place — plus a self-review
/// guard (a company owner cannot review their own company).
class FixedReviewStore {
  final Map<String, Review> _rows = {};

  /// Returns the id of the stored/updated review, or throws on rejection.
  String addReview(Review r, {String? ownerUserId}) {
    if (!Validators.isValidReviewText(r.text)) {
      throw Exception('Please write a short review.');
    }
    final err = Validators.reviewEligibilityError(
      reviewerId: r.userId,
      ownerUserId: ownerUserId,
    );
    if (err != null) throw Exception(err);
    r.rating = Validators.clampRating(r.rating);

    // One review per user per company: reuse the existing row's id so a repeat
    // submission edits the prior review instead of stacking a new one.
    final existing = _existingFor(r.userId, r.companyId);
    if (existing != null) {
      existing.rating = r.rating;
      existing.text = r.text;
      existing.name = r.name;
      existing.createdAt = r.createdAt;
      return existing.id;
    }
    _rows[r.id] = r;
    return r.id;
  }

  Review? _existingFor(String? userId, String companyId) {
    if (userId == null || userId.isEmpty) return null;
    for (final r in _rows.values) {
      if (r.userId == userId && r.companyId == companyId) return r;
    }
    return null;
  }

  List<Review> forCompany(String companyId) =>
      _rows.values.where((r) => r.companyId == companyId).toList();

  ({double avg, int count}) ratingFor(String companyId) {
    final rs = forCompany(companyId);
    if (rs.isEmpty) return (avg: 0, count: 0);
    final avg = rs
            .map((r) => Validators.clampRating(r.rating))
            .reduce((a, b) => a + b) /
        rs.length;
    return (avg: (avg * 10).round() / 10, count: rs.length);
  }
}

Review _rev({
  required String companyId,
  String? userId,
  String name = 'Sam',
  int rating = 5,
  String text = 'Great service',
  int createdAt = 0,
}) =>
    Review(
      companyId: companyId,
      userId: userId,
      name: name,
      rating: rating,
      text: text,
      createdAt: createdAt,
    );

void main() {
  print('== QA round 14: review submission edge cases ==\n');

  // ------------------------------------------------------------------
  // DEMO: reproduce the RAW defect a human user can trigger.
  // ------------------------------------------------------------------
  print('-- raw defect: one user skews a company average with repeats --');
  {
    final raw = RawReviewStore();
    // One honest 5-star customer.
    raw.addReview(_rev(companyId: 'c1', userId: 'honest', rating: 5));
    check(
        'after one honest review, avg is 5.0', raw.ratingFor('c1').avg == 5.0);
    check('count is 1', raw.ratingFor('c1').count == 1);

    // A single malicious account tanks the rating with ten 1-star reviews.
    for (var i = 0; i < 10; i++) {
      raw.addReview(_rev(companyId: 'c1', userId: 'troll', rating: 1));
    }
    // RAW BUG: eleven rows now exist from just two people; average collapses.
    check('RAW BUG: one troll inflates count to 11',
        raw.ratingFor('c1').count == 11);
    check('RAW BUG: avg collapses well below the single honest 5-star',
        raw.ratingFor('c1').avg < 2.0);
  }

  {
    // RAW BUG: a company owner can review their own company (no self guard).
    final raw = RawReviewStore();
    raw.addReview(_rev(companyId: 'cOwn', userId: 'ownerU', rating: 5));
    check('RAW BUG: owner self-review is accepted',
        raw.ratingFor('cOwn').count == 1);
  }

  // ------------------------------------------------------------------
  // FIX: one review per user per company + self-review guard.
  // ------------------------------------------------------------------
  print('\n-- fixed: one review per user per company --');
  {
    final fx = FixedReviewStore();
    fx.addReview(_rev(companyId: 'c1', userId: 'honest', rating: 5));

    // The troll posts ten 1-star reviews — but they collapse into ONE row.
    for (var i = 0; i < 10; i++) {
      fx.addReview(
          _rev(companyId: 'c1', userId: 'troll', rating: 1, text: 'bad #$i'));
    }
    check('count is 2 (one per distinct user), not 11',
        fx.ratingFor('c1').count == 2);
    check('avg reflects two people: (5 + 1) / 2 = 3.0',
        fx.ratingFor('c1').avg == 3.0);

    // The repeat submission edits the troll\'s single review (last text wins).
    final trollRows =
        fx.forCompany('c1').where((r) => r.userId == 'troll').toList();
    check('troll still has exactly one row', trollRows.length == 1);
    check('troll row holds the latest text', trollRows.single.text == 'bad #9');
  }

  print('\n-- fixed: same user can update their rating, not stack --');
  {
    final fx = FixedReviewStore();
    fx.addReview(_rev(
        companyId: 'c2', userId: 'u1', rating: 2, text: 'meh', createdAt: 1));
    fx.addReview(_rev(
        companyId: 'c2',
        userId: 'u1',
        rating: 5,
        text: 'they fixed it',
        createdAt: 2));
    check('still one row after an update', fx.ratingFor('c2').count == 1);
    check('rating reflects the latest submission (5)',
        fx.ratingFor('c2').avg == 5.0);
    final row = fx.forCompany('c2').single;
    check('createdAt moved to the newer submission', row.createdAt == 2);
  }

  print('\n-- fixed: self-review by the company owner is rejected --');
  {
    final fx = FixedReviewStore();
    var rejected = false;
    try {
      fx.addReview(_rev(companyId: 'cOwn', userId: 'ownerU', rating: 5),
          ownerUserId: 'ownerU');
    } catch (_) {
      rejected = true;
    }
    check('owner self-review throws', rejected);
    check('no self-review row was stored', fx.ratingFor('cOwn').count == 0);
  }

  print('\n-- fixed: distinct users are unaffected --');
  {
    final fx = FixedReviewStore();
    fx.addReview(_rev(companyId: 'c3', userId: 'a', rating: 5));
    fx.addReview(_rev(companyId: 'c3', userId: 'b', rating: 3));
    fx.addReview(_rev(companyId: 'c3', userId: 'c', rating: 4));
    check('three distinct users -> three rows', fx.ratingFor('c3').count == 3);
    check('avg is (5 + 3 + 4) / 3 = 4.0', fx.ratingFor('c3').avg == 4.0);
  }

  print('\n-- fixed: anonymous (null userId) reviews are not merged --');
  {
    // A signed-out visitor has no userId; we cannot dedupe those, so each is
    // its own row (matches raw behaviour, no regression for anonymous flow).
    final fx = FixedReviewStore();
    fx.addReview(_rev(companyId: 'c4', userId: null, name: 'Anon', rating: 5));
    fx.addReview(_rev(companyId: 'c4', userId: null, name: 'Anon', rating: 1));
    check(
        'two anonymous reviews remain two rows', fx.ratingFor('c4').count == 2);
  }

  print('\n-- Validators.reviewEligibilityError direct unit checks --');
  {
    check(
        'null reviewer (anonymous) is allowed',
        Validators.reviewEligibilityError(reviewerId: null, ownerUserId: 'x') ==
            null);
    check(
        'customer reviewing someone else is allowed',
        Validators.reviewEligibilityError(
                reviewerId: 'cust', ownerUserId: 'owner') ==
            null);
    check(
        'owner reviewing own company is rejected',
        Validators.reviewEligibilityError(
                reviewerId: 'owner', ownerUserId: 'owner') !=
            null);
    check(
        'no owner known -> allowed',
        Validators.reviewEligibilityError(
                reviewerId: 'cust', ownerUserId: null) ==
            null);
  }

  print('\n== $_passed passed, $_failed failed ==');
  if (_failed > 0) {
    throw StateError('review submission edge cases failed');
  }
}
