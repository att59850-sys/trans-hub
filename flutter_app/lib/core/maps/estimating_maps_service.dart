import 'dart:math' as math;

import 'maps_service.dart';

/// A dependency-free [MapsService] that produces plausible geocodes and route
/// estimates **without any external API or credentials** (TH-019).
///
/// It is used as the default so route previews work fully offline. Known city
/// names resolve to their real-ish coordinates; anything else is mapped
/// deterministically from a hash so the same text always yields the same
/// point (stable previews). Distance uses the haversine formula and duration
/// assumes an average road speed. Swap in a Google/Mapbox-backed
/// implementation in production for real geometry.
class EstimatingMapsService implements MapsService {
  const EstimatingMapsService();

  /// A small seed table of well-known cities (lat, lng).
  static const Map<String, GeoPoint> _cities = {
    'new york': GeoPoint(40.7128, -74.0060),
    'los angeles': GeoPoint(34.0522, -118.2437),
    'chicago': GeoPoint(41.8781, -87.6298),
    'houston': GeoPoint(29.7604, -95.3698),
    'phoenix': GeoPoint(33.4484, -112.0740),
    'london': GeoPoint(51.5074, -0.1278),
    'paris': GeoPoint(48.8566, 2.3522),
    'lagos': GeoPoint(6.5244, 3.3792),
    'nairobi': GeoPoint(-1.2921, 36.8219),
    'dubai': GeoPoint(25.2048, 55.2708),
    'toronto': GeoPoint(43.6532, -79.3832),
    'sydney': GeoPoint(-33.8688, 151.2093),
  };

  @override
  Future<GeoPoint?> geocode(String address) async {
    final key = address.trim().toLowerCase();
    if (key.isEmpty) return null;

    // Exact / substring match against the seed table first.
    for (final entry in _cities.entries) {
      if (key == entry.key || key.contains(entry.key)) return entry.value;
    }

    // Deterministic fallback: hash the string into a stable lat/lng so the
    // same address always previews identically.
    final h = key.codeUnits.fold<int>(7, (a, b) => (a * 31 + b) & 0x7fffffff);
    final lat = ((h % 1400) / 10.0) - 70.0; // -70..70
    final lng = (((h ~/ 1400) % 3600) / 10.0) - 180.0; // -180..180
    return GeoPoint(lat, lng);
  }

  @override
  Future<RoutePreview?> routePreview(GeoPoint from, GeoPoint to) async {
    final km = _haversineKm(from, to);
    // Assume ~55 km/h average incl. stops; floor at a few minutes for very
    // short hops. Round to a tidy number.
    final minutes = math.max(5, (km / 55.0 * 60).round());
    return RoutePreview(
      distanceKm: (km * 10).round() / 10,
      durationMinutes: minutes,
      polyline: [from, to],
    );
  }

  double _haversineKm(GeoPoint a, GeoPoint b) {
    const earthKm = 6371.0;
    double toRad(double d) => d * math.pi / 180.0;
    final dLat = toRad(b.lat - a.lat);
    final dLng = toRad(b.lng - a.lng);
    final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(toRad(a.lat)) *
            math.cos(toRad(b.lat)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return earthKm * 2 * math.atan2(math.sqrt(h), math.sqrt(1 - h));
  }
}
