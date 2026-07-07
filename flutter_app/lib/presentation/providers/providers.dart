import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di/injection.dart';
import '../../core/network/connectivity_service.dart';
import '../../data/datasources/remote/sync_engine.dart';
import '../../domain/entities/entities.dart';
import '../../domain/repositories/notification_repository.dart';
import '../../domain/repositories/repositories.dart';
import '../../domain/usecases/usecases.dart';

/// Riverpod providers (TH-005). New presentation code should consume these
/// instead of referencing singletons directly. They resolve their
/// dependencies from the get_it container (TH-008), giving a single, testable
/// composition root.

// --- Repositories ---
final authRepositoryProvider =
    Provider<AuthRepository>((ref) => sl<AuthRepository>());
final companyRepositoryProvider =
    Provider<CompanyRepository>((ref) => sl<CompanyRepository>());
final bookingRepositoryProvider =
    Provider<BookingRepository>((ref) => sl<BookingRepository>());
final reviewRepositoryProvider =
    Provider<ReviewRepository>((ref) => sl<ReviewRepository>());
final favoritesRepositoryProvider =
    Provider<FavoritesRepository>((ref) => sl<FavoritesRepository>());
final locationRepositoryProvider =
    Provider<LocationRepository>((ref) => sl<LocationRepository>());
final notificationRepositoryProvider =
    Provider<NotificationRepository>((ref) => sl<NotificationRepository>());

// --- Infrastructure ---
final syncEngineProvider = Provider<SyncEngine>((ref) => sl<SyncEngine>());
final connectivityServiceProvider =
    Provider<ConnectivityService>((ref) => sl<ConnectivityService>());

// --- Use cases ---
final loginUserProvider = Provider<LoginUser>((ref) => sl<LoginUser>());
final registerUserProvider =
    Provider<RegisterUser>((ref) => sl<RegisterUser>());
final logoutUserProvider = Provider<LogoutUser>((ref) => sl<LogoutUser>());
final createBookingProvider =
    Provider<CreateBooking>((ref) => sl<CreateBooking>());
final updateBookingStatusProvider =
    Provider<UpdateBookingStatus>((ref) => sl<UpdateBookingStatus>());
final submitReviewProvider =
    Provider<SubmitReview>((ref) => sl<SubmitReview>());
final toggleFavoriteProvider =
    Provider<ToggleFavorite>((ref) => sl<ToggleFavorite>());

// --- Derived state ---
/// The currently authenticated user, or null.
final currentUserProvider = Provider<AppUser?>(
  (ref) => ref.watch(authRepositoryProvider).currentUser,
);

/// All companies in the marketplace.
final companiesProvider = Provider<List<Company>>(
  (ref) => ref.watch(companyRepositoryProvider).all(),
);
