/// Shared input-validation rules (single source of truth).
///
/// Both the Clean Architecture auth repository and the legacy [DataService]
/// facade validate sign-up input through these helpers so the rules cannot
/// drift apart (a real bug fixed after a QA pass found the facade accepting
/// empty emails and 1-character passwords the repository would have rejected).
class Validators {
  const Validators._();

  /// Minimum acceptable password length.
  static const int minPasswordLength = 4;

  /// A pragmatic email check: non-empty, exactly one `@`, with a non-empty
  /// local part and a dotted domain. Deliberately lenient (real verification
  /// happens via a confirmation email once a backend is wired in) but strict
  /// enough to reject obviously invalid input like "", "foo", "a@b".
  static bool isValidEmail(String email) {
    final e = email.trim();
    if (e.isEmpty) return false;
    final at = e.indexOf('@');
    if (at <= 0 || at != e.lastIndexOf('@')) return false;
    final domain = e.substring(at + 1);
    if (domain.isEmpty || !domain.contains('.')) return false;
    // No leading/trailing dot in the domain, no spaces anywhere.
    if (e.contains(' ')) return false;
    if (domain.startsWith('.') || domain.endsWith('.')) return false;
    return true;
  }

  static bool isValidPassword(String password) =>
      password.length >= minPasswordLength;

  /// Allowed inclusive range for a star rating.
  static const int minRating = 1;
  static const int maxRating = 5;

  /// Whether [rating] is a legal star value (1..5).
  static bool isValidRating(int rating) =>
      rating >= minRating && rating <= maxRating;

  /// Clamps [rating] into the legal 1..5 range so a corrupt or out-of-range
  /// stored value can never skew a displayed average.
  static int clampRating(int rating) => rating < minRating
      ? minRating
      : (rating > maxRating ? maxRating : rating);

  /// Whether review body text is acceptable (non-empty after trimming).
  static bool isValidReviewText(String text) => text.trim().isNotEmpty;

  static bool isNonEmptyName(String name) => name.trim().isNotEmpty;

  /// Upper bound for a service price. A price above this is almost certainly a
  /// data-entry slip (e.g. a stray trailing digit) and would render as an
  /// absurd figure; we clamp rather than reject so the edit still saves.
  static const double maxServicePrice = 1000000; // $1,000,000

  /// Whether [price] is a usable service price: finite (not NaN/±Infinity) and
  /// non-negative. A non-finite price crashes `priceLabel` (`(±Inf).toInt()`
  /// throws) and a negative price renders as a nonsensical `$-50`.
  static bool isValidPrice(double price) =>
      price.isFinite && price >= 0 && price <= maxServicePrice;

  /// Sanitizes a service price so it can never crash a label or show a negative
  /// figure: non-finite → 0 (treated as "On quote"), negatives → 0, and
  /// anything above [maxServicePrice] is clamped down.
  static double sanitizePrice(double price) {
    if (!price.isFinite || price < 0) return 0;
    return price > maxServicePrice ? maxServicePrice : price;
  }

  /// Returns a human-readable error for invalid sign-up input, or null if the
  /// input is acceptable. Order mirrors the fields a user fills in.
  static String? signupError({
    required String name,
    required String email,
    required String password,
  }) {
    if (!isNonEmptyName(name)) return 'Please enter your name.';
    if (!isValidEmail(email)) return 'Please enter a valid email address.';
    if (!isValidPassword(password)) {
      return 'Password must be at least $minPasswordLength characters.';
    }
    return null;
  }

  /// Returns a human-readable error for invalid booking/quote contact details,
  /// or null if acceptable. A provider can only follow up if they have a real
  /// name and a well-formed email; the booking form checked only for
  /// non-emptiness, so a garbage email like "notanemail" still got through.
  static String? bookingContactError({
    required String name,
    required String email,
  }) {
    if (!isNonEmptyName(name)) return 'Please enter your name.';
    if (!isValidEmail(email)) return 'Please enter a valid email address.';
    return null;
  }
}
