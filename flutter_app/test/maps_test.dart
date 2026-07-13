import 'package:flutter_test/flutter_test.dart';
import 'package:transport_hub/core/maps/estimating_maps_service.dart';
import 'package:transport_hub/core/maps/maps_service.dart';

/// TH-019 — Offline route estimator. Verifies deterministic geocoding and
/// sensible distance/duration estimates without any external API.
void main() {
  const maps = EstimatingMapsService();

  group('geocode', () {
    test('resolves known cities to real-ish coordinates', () async {
      final ny = await maps.geocode('New York');
      expect(ny, isNotNull);
      expect(ny!.lat, closeTo(40.7, 0.5));
      expect(ny.lng, closeTo(-74.0, 0.5));
    });

    test('is case-insensitive and matches substrings', () async {
      final a = await maps.geocode('LONDON');
      final b = await maps.geocode('Greater London, UK');
      expect(a!.lat, b!.lat);
      expect(a.lng, b.lng);
    });

    test('returns null for empty input', () async {
      expect(await maps.geocode(''), isNull);
      expect(await maps.geocode('   '), isNull);
    });

    test('unknown addresses resolve deterministically and in range', () async {
      final first = await maps.geocode('123 Nowhere Lane');
      final second = await maps.geocode('123 Nowhere Lane');
      expect(first!.lat, second!.lat);
      expect(first.lng, second.lng);
      expect(first.lat, inInclusiveRange(-70, 70));
      expect(first.lng, inInclusiveRange(-180, 180));
    });

    // Regression (found via the human-journey simulation): common cities like
    // Boston were missing from the seed table and fell through to the hash
    // fallback, producing absurd route distances (e.g. NY->Boston ~8800 km).
    test('resolves Boston to real-ish coordinates (regression)', () async {
      final b = await maps.geocode('Boston');
      expect(b, isNotNull);
      expect(b!.lat, closeTo(42.36, 0.5));
      expect(b.lng, closeTo(-71.06, 0.5));
    });

    // Regression: multi-word queries must pick the longest matching city name,
    // not whichever key iterates first.
    test('prefers the most specific city match', () async {
      final ny = await maps.geocode('New York');
      final nyc = await maps.geocode('New York City, NY');
      expect(nyc!.lat, ny!.lat);
      expect(nyc.lng, ny.lng);
    });
  });

  group('routePreview', () {
    test('estimates a realistic distance + duration between cities', () async {
      final from = await maps.geocode('New York');
      final to = await maps.geocode('Chicago');
      final RoutePreview? r = await maps.routePreview(from!, to!);
      expect(r, isNotNull);
      // Great-circle NY↔Chicago is ~1150 km.
      expect(r!.distanceKm, greaterThan(1000));
      expect(r.distanceKm, lessThan(1400));
      expect(r.durationMinutes, greaterThan(60));
      expect(r.polyline, hasLength(2));
    });

    test('same point yields ~0 distance and the floor duration', () async {
      final p = await maps.geocode('Paris');
      final r = await maps.routePreview(p!, p);
      expect(r!.distanceKm, closeTo(0, 0.1));
      expect(r.durationMinutes, 5); // floor
    });
  });
}
