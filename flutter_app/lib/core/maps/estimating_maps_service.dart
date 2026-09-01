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

  /// A seed table of well-known cities (lat, lng). Longer, more specific names
  /// are matched before shorter ones (see [geocode]) so e.g. "new york" is not
  /// shadowed by a shorter substring.
  static const Map<String, GeoPoint> _cities = {
    // North America
    'new york': GeoPoint(40.7128, -74.0060),
    'los angeles': GeoPoint(34.0522, -118.2437),
    'san francisco': GeoPoint(37.7749, -122.4194),
    'chicago': GeoPoint(41.8781, -87.6298),
    'houston': GeoPoint(29.7604, -95.3698),
    'phoenix': GeoPoint(33.4484, -112.0740),
    'boston': GeoPoint(42.3601, -71.0589),
    'philadelphia': GeoPoint(39.9526, -75.1652),
    'washington': GeoPoint(38.9072, -77.0369),
    'miami': GeoPoint(25.7617, -80.1918),
    'atlanta': GeoPoint(33.7490, -84.3880),
    'dallas': GeoPoint(32.7767, -96.7970),
    'denver': GeoPoint(39.7392, -104.9903),
    'seattle': GeoPoint(47.6062, -122.3321),
    'las vegas': GeoPoint(36.1699, -115.1398),
    'toronto': GeoPoint(43.6532, -79.3832),
    'vancouver': GeoPoint(49.2827, -123.1207),
    'montreal': GeoPoint(45.5019, -73.5674),
    'mexico city': GeoPoint(19.4326, -99.1332),
    // Europe
    'london': GeoPoint(51.5074, -0.1278),
    'paris': GeoPoint(48.8566, 2.3522),
    'berlin': GeoPoint(52.5200, 13.4050),
    'madrid': GeoPoint(40.4168, -3.7038),
    'rome': GeoPoint(41.9028, 12.4964),
    'amsterdam': GeoPoint(52.3676, 4.9041),
    // Africa / Middle East
    'lagos': GeoPoint(6.5244, 3.3792),
    'nairobi': GeoPoint(-1.2921, 36.8219),
    'cairo': GeoPoint(30.0444, 31.2357),
    'johannesburg': GeoPoint(-26.2041, 28.0473),
    'dubai': GeoPoint(25.2048, 55.2708),
    // Asia / Pacific
    'singapore': GeoPoint(1.3521, 103.8198),
    'tokyo': GeoPoint(35.6762, 139.6503),
    'mumbai': GeoPoint(19.0760, 72.8777),
    'delhi': GeoPoint(28.7041, 77.1025),
    'sydney': GeoPoint(-33.8688, 151.2093),
    'melbourne': GeoPoint(-37.8136, 144.9631),
  };

  @override
  Future<GeoPoint?> geocode(String address) async {
    final key = address.trim().toLowerCase();
    if (key.isEmpty) return null;

    // Exact match wins outright.
    final exact = _cities[key];
    if (exact != null) return exact;

    // Otherwise, prefer the LONGEST known city name contained in the query so
    // that specific names ("new york") are not shadowed by shorter, more
    // generic ones. Iterating the map directly is order-dependent and picks
    // whichever key happens to come first, which is a bug for multi-word input.
    GeoPoint? best;
    var bestLen = 0;
    for (final entry in _cities.entries) {
      if (key.contains(entry.key) && entry.key.length > bestLen) {
        best = entry.value;
        bestLen = entry.key.length;
      }
    }
    if (best != null) return best;

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
