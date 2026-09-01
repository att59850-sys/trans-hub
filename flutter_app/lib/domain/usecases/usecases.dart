import '../entities/entities.dart';
import '../repositories/repositories.dart';

/// Use cases (TH-007). UI/providers interact with these rather than touching
/// repositories directly, keeping business rules in one place.

class LoginUser {
  const LoginUser(this._auth);
  final AuthRepository _auth;
  AppUser call({required String email, required String password}) =>
      _auth.login(email: email, password: password);
}

class RegisterUser {
  const RegisterUser(this._auth);
  final AuthRepository _auth;
  AppUser call({
    required String name,
    required String email,
    required String password,
    required UserRole role,
    String? companyName,
    String? defaultCity,
  }) =>
      _auth.signup(
        name: name,
        email: email,
        password: password,
        role: role,
        companyName: companyName,
        defaultCity: defaultCity,
      );
}

class LogoutUser {
  const LogoutUser(this._auth);
  final AuthRepository _auth;
  void call() => _auth.logout();
}

class CreateBooking {
  const CreateBooking(this._bookings);
  final BookingRepository _bookings;
  Booking call(Booking booking) => _bookings.create(booking);
}

class UpdateBookingStatus {
  const UpdateBookingStatus(this._bookings);
  final BookingRepository _bookings;

  /// Returns `true` when the transition was applied, `false` if it was an
  /// illegal move or the booking was not found.
  bool call(String bookingId, BookingStatus status, {String note = ''}) =>
      _bookings.setStatus(bookingId, status, note: note);
}

class SubmitReview {
  const SubmitReview(this._reviews);
  final ReviewRepository _reviews;
  void call(Review review) => _reviews.add(review);
}

class ToggleFavorite {
  const ToggleFavorite(this._favorites);
  final FavoritesRepository _favorites;
  bool call(String companyId) => _favorites.toggle(companyId);
}
