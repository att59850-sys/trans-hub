/// Crash / error reporting abstraction (TH-023).
///
/// Implement with Firebase Crashlytics or Sentry behind this interface so the
/// rest of the app never depends on a specific SDK. A [NoopCrashReporter] is
/// used until a provider is configured.
abstract interface class CrashReporter {
  /// Records a non-fatal error with optional [stack] and [context].
  Future<void> recordError(
    Object error,
    StackTrace? stack, {
    Map<String, Object?> context,
  });

  /// Adds a breadcrumb-style log line.
  void log(String message);

  /// Associates subsequent reports with a user id (or null to clear).
  void setUser(String? userId);
}

class NoopCrashReporter implements CrashReporter {
  const NoopCrashReporter();

  @override
  Future<void> recordError(
    Object error,
    StackTrace? stack, {
    Map<String, Object?> context = const {},
  }) async {}

  @override
  void log(String message) {}

  @override
  void setUser(String? userId) {}
}
