import 'package:get_it/get_it.dart';

import '../../data/datasources/local/hive_local_datasource.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../data/repositories/booking_repository_impl.dart';
import '../../data/repositories/company_repository_impl.dart';
import '../../data/repositories/favorites_repository_impl.dart';
import '../../data/repositories/location_repository_impl.dart';
import '../../data/repositories/review_repository_impl.dart';
import '../../domain/repositories/repositories.dart';
import '../../domain/usecases/usecases.dart';

/// Service locator (TH-008). Replaces manual instantiation / singletons.
final GetIt sl = GetIt.instance;

/// Registers all dependencies. Call once after Hive is initialized.
void configureDependencies(HiveLocalDataSource ds) {
  if (sl.isRegistered<HiveLocalDataSource>()) return;

  // Datasource
  sl.registerSingleton<HiveLocalDataSource>(ds);

  // Repositories
  sl.registerLazySingleton<AuthRepository>(() => AuthRepositoryImpl(sl()));
  sl.registerLazySingleton<CompanyRepository>(
      () => CompanyRepositoryImpl(sl()));
  sl.registerLazySingleton<BookingRepository>(
      () => BookingRepositoryImpl(sl()));
  sl.registerLazySingleton<ReviewRepository>(() => ReviewRepositoryImpl(sl()));
  sl.registerLazySingleton<FavoritesRepository>(
      () => FavoritesRepositoryImpl(sl()));
  sl.registerLazySingleton<LocationRepository>(
      () => LocationRepositoryImpl(sl()));

  // Use cases
  sl.registerLazySingleton(() => LoginUser(sl()));
  sl.registerLazySingleton(() => RegisterUser(sl()));
  sl.registerLazySingleton(() => LogoutUser(sl()));
  sl.registerLazySingleton(() => CreateBooking(sl()));
  sl.registerLazySingleton(() => UpdateBookingStatus(sl()));
  sl.registerLazySingleton(() => SubmitReview(sl()));
  sl.registerLazySingleton(() => ToggleFavorite(sl()));
}
