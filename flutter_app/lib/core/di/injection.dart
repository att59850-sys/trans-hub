import 'package:get_it/get_it.dart';

import '../../data/datasources/local/hive_local_datasource.dart';
import '../../data/datasources/remote/remote_datasource.dart';
import '../../data/datasources/remote/supabase_remote_datasource.dart';
import '../../data/datasources/remote/sync_engine.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../data/repositories/booking_repository_impl.dart';
import '../../data/repositories/company_repository_impl.dart';
import '../../data/repositories/favorites_repository_impl.dart';
import '../../data/repositories/location_repository_impl.dart';
import '../../data/repositories/notification_repository_impl.dart';
import '../../data/repositories/review_repository_impl.dart';
import '../../data/repositories/sync_queue_repository_impl.dart';
import '../../domain/repositories/notification_repository.dart';
import '../../domain/repositories/repositories.dart';
import '../../domain/repositories/sync_queue_repository.dart';
import '../../domain/usecases/usecases.dart';
import '../config/app_config.dart';
import '../maps/maps_service.dart';
import '../messaging/push_messaging.dart';
import '../network/connectivity_service.dart';
import '../telemetry/analytics.dart';
import '../telemetry/crash_reporter.dart';

/// Service locator (TH-008). Replaces manual instantiation / singletons.
final GetIt sl = GetIt.instance;

/// Registers all dependencies. Call once after Hive is initialized.
void configureDependencies(HiveLocalDataSource ds) {
  if (sl.isRegistered<HiveLocalDataSource>()) return;

  // Config (TH-009)
  final config = AppConfig.fromEnvironment();
  sl.registerSingleton<AppConfig>(config);

  // Datasources
  sl.registerSingleton<HiveLocalDataSource>(ds);
  sl.registerSingleton<RemoteDataSource>(
    config.hasRemoteBackend
        ? SupabaseRemoteDataSource(config)
        : const NoopRemoteDataSource(),
  );

  // Telemetry (TH-023/024) — no-op until a provider is wired in.
  sl.registerSingleton<CrashReporter>(const NoopCrashReporter());
  sl.registerSingleton<AnalyticsService>(const NoopAnalyticsService());

  // Messaging (TH-018) & Maps (TH-019) — no-op until configured.
  sl.registerSingleton<PushMessaging>(const NoopPushMessaging());
  sl.registerSingleton<MapsService>(const NoopMapsService());

  // Repositories (TH-006)
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
  sl.registerLazySingleton<SyncQueueRepository>(
      () => SyncQueueRepositoryImpl(sl()));
  sl.registerLazySingleton<NotificationRepository>(
      () => NotificationRepositoryImpl(sl()));

  // Sync engine (TH-014)
  sl.registerLazySingleton<SyncEngine>(
    () => SyncEngine(remote: sl(), queue: sl(), local: sl()),
  );

  // Connectivity (TH-015) — on reconnect, run a sync cycle.
  sl.registerLazySingleton<ConnectivityService>(
    () => ConnectivityService(onReconnect: () => sl<SyncEngine>().sync()),
  );

  // Use cases (TH-007)
  sl.registerLazySingleton(() => LoginUser(sl()));
  sl.registerLazySingleton(() => RegisterUser(sl()));
  sl.registerLazySingleton(() => LogoutUser(sl()));
  sl.registerLazySingleton(() => CreateBooking(sl()));
  sl.registerLazySingleton(() => UpdateBookingStatus(sl()));
  sl.registerLazySingleton(() => SubmitReview(sl()));
  sl.registerLazySingleton(() => ToggleFavorite(sl()));
}
