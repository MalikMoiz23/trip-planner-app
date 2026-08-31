import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import 'package:trip_planner/core/constants.dart';
import 'package:trip_planner/core/geo.dart';
import 'package:trip_planner/data/models/route_info.dart';

/// Road distance and drive time from the public OSRM demo server.
///
/// The demo server is free and key-less but carries no uptime guarantee, so
/// every call falls back to great-circle distance times a terrain road factor
/// and flags the result as estimated.
class OsrmService {
  OsrmService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  final Map<String, RouteInfo> _cache = {};

  Future<RouteInfo> route(
    LatLng from,
    LatLng to, {
    double roadFactor = AppDefaults.fallbackRoadFactor,
    bool withGeometry = true,
  }) async {
    if (from.latitude == to.latitude && from.longitude == to.longitude) {
      return RouteInfo.zero;
    }

    final key = _key(from, to, withGeometry);
    final cached = _cache[key];
    if (cached != null) return cached;

    final coords = '${from.longitude},${from.latitude};${to.longitude},${to.latitude}';
    final uri = Uri.parse('${Endpoints.osrmBase}/$coords').replace(queryParameters: {
      'overview': withGeometry ? 'full' : 'false',
      'geometries': 'polyline',
      // OSRM returns its fastest route first, which is not always its shortest.
      // The figure people check against is the distance, so alternatives are
      // requested and the shortest of them is taken below. Costs nothing extra:
      // one request either way.
      'alternatives': '3',
      'steps': 'false',
    });

    try {
      final res = await _client.get(
        uri,
        headers: const {'User-Agent': Endpoints.userAgent},
      ).timeout(const Duration(seconds: 15));

      if (res.statusCode != 200) return _fallback(from, to, roadFactor);

      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (body['code'] != 'Ok') return _fallback(from, to, roadFactor);

      final routes = body['routes'] as List<dynamic>;
      if (routes.isEmpty) return _fallback(from, to, roadFactor);

      // The shortest by distance, not the first by time. A detour onto a
      // motorway can be quicker and twenty kilometres longer, and a plan costed
      // on fuel should follow the road actually taken.
      final r = routes
          .whereType<Map<String, dynamic>>()
          .where((e) => e['distance'] is num)
          .reduce((a, b) =>
              (a['distance'] as num) <= (b['distance'] as num) ? a : b);
      final geometry = withGeometry && r['geometry'] is String
          ? simplify(decodePolyline(r['geometry'] as String))
          : const <LatLng>[];

      final info = RouteInfo(
        distanceKm: (r['distance'] as num).toDouble() / 1000.0,
        duration: Duration(seconds: (r['duration'] as num).round()),
        geometry: geometry,
        estimated: false,
      );
      _cache[key] = info;
      return info;
    } on Exception {
      return _fallback(from, to, roadFactor);
    }
  }

  /// Routes many destinations from one origin, sequentially with a short gap so
  /// the shared demo server is not hammered.
  Future<Map<String, RouteInfo>> routeMany(
    LatLng from,
    Map<String, LatLng> targets, {
    double roadFactor = AppDefaults.fallbackRoadFactor,
  }) async {
    final out = <String, RouteInfo>{};
    for (final entry in targets.entries) {
      out[entry.key] = await route(
        from,
        entry.value,
        roadFactor: roadFactor,
        withGeometry: false,
      );
    }
    return out;
  }

  RouteInfo _fallback(LatLng from, LatLng to, double roadFactor) {
    final straight = haversineKm(from, to);
    final distance = straight * roadFactor;
    final hours = distance / AppDefaults.fallbackAverageSpeedKmh;
    return RouteInfo(
      distanceKm: distance,
      duration: Duration(minutes: (hours * 60).round()),
      geometry: [from, to],
      estimated: true,
    );
  }

  String _key(LatLng a, LatLng b, bool geometry) =>
      '${a.latitude.toStringAsFixed(4)},${a.longitude.toStringAsFixed(4)}'
      '>${b.latitude.toStringAsFixed(4)},${b.longitude.toStringAsFixed(4)}:$geometry';
}
