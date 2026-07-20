import '../../core/utils/validators.dart';
import '../../domain/entities/entities.dart';
import '../../domain/repositories/repositories.dart';
import '../datasources/local/hive_local_datasource.dart';
import '../models/review_dto.dart';

/// Hive-backed [ReviewRepository].
class ReviewRepositoryImpl implements ReviewRepository {
  ReviewRepositoryImpl(this._ds);

  final HiveLocalDataSource _ds;

  @override
  List<Review> forCompany(String companyId) => _ds.reviews.values
      .map((e) => reviewFromJson(e as Map))
      .where((r) => r.companyId == companyId)
      .toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  @override
  ({double avg, int count}) ratingFor(String companyId) {
    final rs = forCompany(companyId);
    if (rs.isEmpty) return (avg: 0, count: 0);
    // Clamp each rating on read so a corrupt/out-of-range value cannot skew
    // the average outside the legal 1..5 range.
    final avg = rs
            .map((r) => Validators.clampRating(r.rating))
            .reduce((a, b) => a + b) /
        rs.length;
    return (avg: (avg * 10).round() / 10, count: rs.length);
  }

  @override
  void add(Review review) {
    // Clamp the rating into range before persisting (defense-in-depth).
    review.rating = Validators.clampRating(review.rating);
    _ds.reviews.put(review.id, review.toJson());
  }
}
