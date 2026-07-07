/// Base class for domain-level failures surfaced to the UI.
sealed class Failure implements Exception {
  const Failure(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Authentication / authorization problems (bad credentials, duplicate email).
class AuthFailure extends Failure {
  const AuthFailure(super.message);
}

/// A requested entity could not be found.
class NotFoundFailure extends Failure {
  const NotFoundFailure(super.message);
}

/// Validation of user input failed.
class ValidationFailure extends Failure {
  const ValidationFailure(super.message);
}

/// Network / remote backend failure (used once Supabase is wired in).
class NetworkFailure extends Failure {
  const NetworkFailure(super.message);
}

/// Local cache / storage failure.
class CacheFailure extends Failure {
  const CacheFailure(super.message);
}
