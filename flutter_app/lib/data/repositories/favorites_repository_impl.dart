import '../../domain/repositories/repositories.dart';
import '../datasources/local/hive_local_datasource.dart';

/// Hive-backed [FavoritesRepository].
class FavoritesRepositoryImpl implements FavoritesRepository {
  FavoritesRepositoryImpl(this._ds);

  final HiveLocalDataSource _ds;

  @override
  List<String> all() {
    // De-dupe on read so a legacy/corrupt list containing the same id twice
    // can't break isFavorite/toggle (a QA pass showed a duplicate copy made
    // "unfavorite" silently fail). Preserves first-seen order.
    final raw =
        (_ds.meta.get('favorites') as List?)?.map((e) => e.toString()) ??
            const <String>[];
    final seen = <String>{};
    final out = <String>[];
    for (final id in raw) {
      if (seen.add(id)) out.add(id);
    }
    return out;
  }

  @override
  bool isFavorite(String companyId) => all().contains(companyId);

  @override
  bool toggle(String companyId) {
    final favs = all(); // already de-duped
    if (favs.contains(companyId)) {
      // removeWhere clears ALL copies, not just the first — so a duplicated
      // entry can never leave the company stuck in the favorited state.
      favs.removeWhere((e) => e == companyId);
    } else {
      favs.add(companyId);
    }
    _ds.meta.put('favorites', favs);
    return favs.contains(companyId);
  }
}
