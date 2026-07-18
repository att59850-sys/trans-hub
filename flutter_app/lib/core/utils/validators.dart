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

  static bool isNonEmptyName(String name) => name.trim().isNotEmpty;

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
}
