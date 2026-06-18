import '../../domain/repositories/repositories.dart';
import '../datasources/local/hive_local_datasource.dart';

/// Hive-backed [FavoritesRepository].
class FavoritesRepositoryImpl implements FavoritesRepository {
  FavoritesRepositoryImpl(this._ds);

  final HiveLocalDataSource _ds;

  @override
  List<String> all() =>
      (_ds.meta.get('favorites') as List?)?.map((e) => e.toString()).toList() ??
      <String>[];

  @override
  bool isFavorite(String companyId) => all().contains(companyId);

  @override
  bool toggle(String companyId) {
    final favs = all();
    if (favs.contains(companyId)) {
      favs.remove(companyId);
    } else {
      favs.add(companyId);
    }
    _ds.meta.put('favorites', favs);
    return favs.contains(companyId);
  }
}
