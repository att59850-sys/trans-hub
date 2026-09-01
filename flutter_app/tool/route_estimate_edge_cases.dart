// QA round 18 — route estimate / maps edge cases (pure-Dart harness).
//
// EstimatingMapsService is dependency-free, so this harness imports it directly
// and exercises the real geocode()/routePreview() plus a faithful
// re-implementation of DataService.estimateRoute's guard logic.
//
// Bug found acting as a human user on the booking form: entering the SAME
// pickup and dropoff (or two strings that resolve to the same point) yields a
// phantom "~0 km / ~5m" estimate that looks like a real quote for a trip from
// a place to itself. estimateRoute happily returned a preview instead of
// treating it as "no meaningful route".
//
// Run: dart run tool/route_estimate_edge_cases.dart

import '../lib/core/maps/estimating_maps_service.dart';
import '../lib/core/maps/maps_service.dart';

int _passed = 0;
int _failed = 0;

void check(String name, bool cond) {
  if (cond) {
    _passed++;
    print('  ok   $name');
  } else {
    _failed++;
    print('  FAIL $name');
  }
}

const _maps = EstimatingMapsService();

/// RAW estimateRoute: only rejects blank endpoints (the pre-fix behaviour).
Future<RoutePreview?> rawEstimate(String pickup, String dropoff) async {
  if (pickup.trim().isEmpty || dropoff.trim().isEmpty) return null;
  final from = await _maps.geocode(pickup);
  final to = await _maps.geocode(dropoff);
  if (from == null || to == null) return null;
  return _maps.routePreview(from, to);
}

/// Whether two free-text endpoints denote the same place (case/space folded)
/// or geocode to effectively the same coordinate. This is the guard the fix
/// centralises in DataService.estimateRoute.
bool sameEndpoint(String pickup, String dropoff, GeoPoint from, GeoPoint to) {
  if (pickup.trim().toLowerCase() == dropoff.trim().toLowerCase()) return true;
  // Same resolved point (within ~11 m) — no meaningful route.
  const eps = 1e-4;
  return (from.lat - to.lat).abs() < eps && (from.lng - to.lng).abs() < eps;
}

/// FIXED estimateRoute: also returns null when the endpoints are the same.
Future<RoutePreview?> fixedEstimate(String pickup, String dropoff) async {
  if (pickup.trim().isEmpty || dropoff.trim().isEmpty) return null;
  final from = await _maps.geocode(pickup);
  final to = await _maps.geocode(dropoff);
  if (from == null || to == null) return null;
  if (sameEndpoint(pickup, dropoff, from, to)) return null;
  return _maps.routePreview(from, to);
}

Future<void> main() async {
  print('== QA round 18: route estimate / maps edge cases ==\n');

  // ------------------------------------------------------------------
  // Sanity: a real route still works and is sane.
  // ------------------------------------------------------------------
  print('-- sanity: a normal route produces a sane estimate --');
  {
    final r = await fixedEstimate('New York', 'Boston');
    check('NYC -> Boston returns a preview', r != null);
    check('distance is positive', r!.distanceKm > 0);
    check('distance is roughly right (~300 km)',
        r.distanceKm > 250 && r.distanceKm < 400);
    check('duration is at least the 5-min floor', r.durationMinutes >= 5);
    check('duration is finite/positive', r.durationMinutes > 0);
  }

  // ------------------------------------------------------------------
  // DEMO: raw defect — same pickup & dropoff yields a phantom estimate.
  // ------------------------------------------------------------------
  print('\n-- raw defect: identical endpoints -> phantom 0 km / 5m --');
  {
    final r = await rawEstimate('Boston', 'Boston');
    check('RAW BUG: identical text still returns a preview', r != null);
    check('RAW BUG: distance is 0 km', r!.distanceKm == 0.0);
    check('RAW BUG: duration floored to 5 min (looks like a real ETA)',
        r.durationMinutes == 5);
  }
  {
    // Case/space variations of the same place also collapse to a point.
    final r = await rawEstimate('  new york ', 'NEW YORK');
    check('RAW BUG: case/space variants of one city -> 0 km preview',
        r != null && r.distanceKm == 0.0);
  }

  // ------------------------------------------------------------------
  // FIX: identical / same-point endpoints -> no preview.
  // ------------------------------------------------------------------
  print('\n-- fixed: identical endpoints return null (strip hides) --');
  {
    check('exact same text -> null',
        await fixedEstimate('Boston', 'Boston') == null);
    check('case/space variant -> null',
        await fixedEstimate('  new york ', 'NEW YORK') == null);
    check('same unknown text -> null',
        await fixedEstimate('Nowheresville', 'nowheresville') == null);
  }

  print('\n-- fixed: blank / whitespace endpoints return null --');
  {
    check('empty pickup -> null', await fixedEstimate('', 'Boston') == null);
    check('whitespace dropoff -> null',
        await fixedEstimate('Boston', '   ') == null);
    check('both blank -> null', await fixedEstimate('', '') == null);
  }

  print('\n-- fixed: distinct cities still preview normally --');
  {
    final r = await fixedEstimate('London', 'Paris');
    check('London -> Paris returns a preview', r != null);
    check('distance positive', r!.distanceKm > 0);
    check('duration > 5 (not floored)', r.durationMinutes > 5);
  }

  print('\n-- geocode direct checks --');
  {
    check('known city resolves', await _maps.geocode('Tokyo') != null);
    check('blank resolves to null', await _maps.geocode('   ') == null);
    // Deterministic fallback: same unknown text -> same point.
    final a = await _maps.geocode('Zzyzx Junction');
    final b = await _maps.geocode('Zzyzx Junction');
    check('unknown text is deterministic',
        a != null && b != null && a.lat == b.lat && a.lng == b.lng);
    // Fallback coordinates stay within valid geographic bounds.
    check('fallback lat within [-90, 90]', a!.lat >= -90 && a.lat <= 90);
    check('fallback lng within [-180, 180]', a.lng >= -180 && a.lng <= 180);
  }

  print('\n-- routePreview never emits a negative/NaN figure --');
  {
    // Antipodal-ish points: distance large but finite; duration positive.
    final r =
        await _maps.routePreview(const GeoPoint(90, 0), const GeoPoint(-90, 0));
    check('polar distance is finite', r!.distanceKm.isFinite);
    check('polar distance positive', r.distanceKm > 0);
    check('polar duration positive', r.durationMinutes > 0);
  }

  print('\n== $_passed passed, $_failed failed ==');
  if (_failed > 0) {
    throw StateError('route estimate edge cases failed');
  }
}
