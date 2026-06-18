import '../../domain/repositories/repositories.dart';
import '../datasources/local/hive_local_datasource.dart';

/// Hive-backed [LocationRepository].
class LocationRepositoryImpl implements LocationRepository {
  LocationRepositoryImpl(this._ds);

  final HiveLocalDataSource _ds;

  @override
  String get current => (_ds.meta.get('location') as String?) ?? '';

  @override
  void set(String location) => _ds.meta.put('location', location);
}
