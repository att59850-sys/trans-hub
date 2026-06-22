/// Product analytics abstraction (TH-024).
///
/// Implement with Firebase Analytics (or similar) behind this interface. A
/// [NoopAnalyticsService] is used until a provider is configured.
///
/// [AnalyticsEvent] enumerates the key events the plan tracks: registrations,
/// bookings, provider activity and retention signals.
enum AnalyticsEvent {
  appOpened,
  signUp,
  login,
  logout,
  searchPerformed,
  companyViewed,
  bookingCreated,
  quoteRequested,
  bookingStatusChanged,
  reviewSubmitted,
  serviceCreated,
  favoriteToggled,
}

abstract interface class AnalyticsService {
  /// Logs an analytics [event] with optional [params].
  void logEvent(AnalyticsEvent event, {Map<String, Object?> params});

  /// Sets the current user id (or null to clear) for attribution.
  void setUser(String? userId);
}

class NoopAnalyticsService implements AnalyticsService {
  const NoopAnalyticsService();

  @override
  void logEvent(AnalyticsEvent event,
      {Map<String, Object?> params = const {}}) {}

  @override
  void setUser(String? userId) {}
}
