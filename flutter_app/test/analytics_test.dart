import 'package:flutter_test/flutter_test.dart';
import 'package:transport_hub/core/telemetry/analytics.dart';

/// Recording fake used to assert that instrumentation fires the right events
/// with the expected params (TH-024).
class _RecordingAnalytics implements AnalyticsService {
  final List<(AnalyticsEvent, Map<String, Object?>)> events = [];
  String? user;

  @override
  void logEvent(AnalyticsEvent event,
      {Map<String, Object?> params = const {}}) {
    events.add((event, params));
  }

  @override
  void setUser(String? userId) => user = userId;
}

void main() {
  group('AnalyticsEvent surface (TH-024)', () {
    test('enumerates all tracked product events', () {
      // Guards against accidental removal of an event the app instruments.
      const expected = {
        AnalyticsEvent.appOpened,
        AnalyticsEvent.signUp,
        AnalyticsEvent.login,
        AnalyticsEvent.logout,
        AnalyticsEvent.searchPerformed,
        AnalyticsEvent.companyViewed,
        AnalyticsEvent.bookingCreated,
        AnalyticsEvent.quoteRequested,
        AnalyticsEvent.bookingStatusChanged,
        AnalyticsEvent.reviewSubmitted,
        AnalyticsEvent.serviceCreated,
        AnalyticsEvent.favoriteToggled,
      };
      expect(AnalyticsEvent.values.toSet(), expected);
    });
  });

  group('NoopAnalyticsService', () {
    test('is a safe no-op', () {
      const svc = NoopAnalyticsService();
      expect(() => svc.logEvent(AnalyticsEvent.appOpened), returnsNormally);
      expect(() => svc.setUser('u1'), returnsNormally);
      expect(() => svc.setUser(null), returnsNormally);
    });
  });

  group('recording fake', () {
    test('captures events, params and user id', () {
      final a = _RecordingAnalytics();
      a.setUser('user-1');
      a.logEvent(AnalyticsEvent.searchPerformed,
          params: {'q': 'movers', 'category': 'moving'});
      a.logEvent(AnalyticsEvent.bookingCreated, params: {'company_id': 'c1'});

      expect(a.user, 'user-1');
      expect(a.events, hasLength(2));
      expect(a.events.first.$1, AnalyticsEvent.searchPerformed);
      expect(a.events.first.$2['q'], 'movers');
      expect(a.events[1].$1, AnalyticsEvent.bookingCreated);
      expect(a.events[1].$2['company_id'], 'c1');
    });
  });
}
