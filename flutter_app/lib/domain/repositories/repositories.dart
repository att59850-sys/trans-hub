import '../entities/entities.dart';

/// Authentication & session (TH-006: AuthRepository).
abstract interface class AuthRepository {
  AppUser? get currentUser;
  AppUser signup({
    required String name,
    required String email,
    required String password,
    required UserRole role,
    String? companyName,
    String? defaultCity,
  });
  AppUser login({required String email, required String password});
  void logout();
}

/// Companies & their services (TH-006: CompanyRepository).
abstract interface class CompanyRepository {
  List<Company> all();
  Company? byId(String id);
  void save(Company company);
  void addService(String companyId, TransportService service);
  void updateService(String companyId, TransportService service);
  void removeService(String companyId, String serviceId);
}

/// Bookings & their lifecycle events (TH-006: BookingRepository).
abstract interface class BookingRepository {
  List<Booking> all();
  Booking create(Booking booking);
  List<Booking> forCompany(String companyId);
  List<Booking> forUser(String userId);

  /// Transitions a booking to [status], appending a [BookingEvent].
  ///
  /// Enforces the lifecycle state machine: an illegal transition (e.g. a jump
  /// from pending straight to completed, or any move out of a terminal state)
  /// is rejected and leaves the booking unchanged. Returns `true` when the
  /// transition was applied, `false` when it was rejected or the booking was
  /// not found.
  bool setStatus(String bookingId, BookingStatus status, {String note});
}

/// Reviews & aggregate ratings (TH-006: ReviewRepository).
abstract interface class ReviewRepository {
  List<Review> forCompany(String companyId);
  ({double avg, int count}) ratingFor(String companyId);
  void add(Review review);
}

/// Favorited companies (TH-006: FavoritesRepository).
abstract interface class FavoritesRepository {
  List<String> all();
  bool isFavorite(String companyId);
  bool toggle(String companyId);
}

/// Selected location (TH-006: LocationRepository).
abstract interface class LocationRepository {
  String get current;
  void set(String location);
}
