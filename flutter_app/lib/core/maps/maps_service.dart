/// A geographic coordinate.
class GeoPoint {
  const GeoPoint(this.lat, this.lng);
  final double lat;
  final double lng;
}

/// A summarized route between two points.
class RoutePreview {
  const RoutePreview({
    required this.distanceKm,
    required this.durationMinutes,
    this.polyline = const [],
  });

  final double distanceKm;
  final int durationMinutes;
  final List<GeoPoint> polyline;
}

/// Maps & geo abstraction (TH-019).
///
/// Implement with Google Maps or Mapbox behind this interface. Used for service
/// areas, pickup locations and route previews. A [NoopMapsService] is used
/// until a provider is configured.
abstract interface class MapsService {
  /// Geocodes a free-text [address] to coordinates, or null if not found.
  Future<GeoPoint?> geocode(String address);

  /// Previews a route between [from] and [to], or null when unavailable.
  Future<RoutePreview?> routePreview(GeoPoint from, GeoPoint to);
}

class NoopMapsService implements MapsService {
  const NoopMapsService();

  @override
  Future<GeoPoint?> geocode(String address) async => null;

  @override
  Future<RoutePreview?> routePreview(GeoPoint from, GeoPoint to) async => null;
}
