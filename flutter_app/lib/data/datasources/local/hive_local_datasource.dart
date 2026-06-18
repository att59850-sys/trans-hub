import 'package:hive_flutter/hive_flutter.dart';

/// Thin wrapper over the app's Hive boxes (TH-013: Hive is the offline cache /
/// local datasource; once Supabase is wired in it becomes a cache rather than
/// the source of truth).
///
/// Box names are centralized here so repositories never touch Hive directly.
class HiveLocalDataSource {
  HiveLocalDataSource._();

  static final HiveLocalDataSource instance = HiveLocalDataSource._();

  static const metaBox = 'meta';
  static const companiesBox = 'companies';
  static const usersBox = 'users';
  static const bookingsBox = 'bookings';
  static const reviewsBox = 'reviews';

  late Box meta;
  late Box companies;
  late Box users;
  late Box bookings;
  late Box reviews;

  bool _ready = false;
  bool get isReady => _ready;

  Future<void> init() async {
    if (_ready) return;
    await Hive.initFlutter();
    meta = await Hive.openBox(metaBox);
    companies = await Hive.openBox(companiesBox);
    users = await Hive.openBox(usersBox);
    bookings = await Hive.openBox(bookingsBox);
    reviews = await Hive.openBox(reviewsBox);
    _ready = true;
  }

  Future<void> clearAll() async {
    await companies.clear();
    await users.clear();
    await bookings.clear();
    await reviews.clear();
    await meta.clear();
  }
}
