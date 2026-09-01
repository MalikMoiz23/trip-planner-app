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

  /// Results of [pairRoute], keyed without regard to direction. The start point
  /// is kept alongside so the polyline can be handed back the right way round.
  final Map<String, ({RouteInfo info, LatLng start})> _pairCache = {};

  /// One direction only. Prefer [pairRoute] for any figure a person will read,
  /// because this one is not symmetric — see the note there.
  Future<RouteInfo> route(
    LatLng from,
    LatLng to, {
    double roadFactor = AppDefaults.fallbackRoadFactor,
    bool withGeometry = true,
  }) async {
    if (samePoint(from, to)) return RouteInfo.zero;

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
      final usable = routes
          .whereType<Map<String, dynamic>>()
          .where((e) => e['distance'] is num && e['duration'] is num)
          .toList(growable: false);
      if (usable.isEmpty) return _fallback(from, to, roadFactor);

      final r = usable
          .reduce((a, b) => (a['distance'] as num) <= (b['distance'] as num) ? a : b);
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

  /// Road distance for a pair of points, the same in both directions.
  ///
  /// OSRM's alternative routes are a heuristic sample and the sample is not
  /// symmetric. For Wah to Panjpeer Rocks the server offered one road, 132.7 km;
  /// for Panjpeer Rocks to Wah it offered that road and also the 114.1 km one a
  /// driver would actually take. Picking the shortest of whatever each direction
  /// happened to return therefore printed "out 133 km, back 114 km" for a single
  /// road, and the figure nobody recognised was the one shown first.
  ///
  /// So both directions are asked and the shorter road is used for both legs.
  /// That is two requests, but an out-and-back trip already made both, and the
  /// answer is cached without regard to direction so the second leg is free.
  ///
  /// One-way streets do make some pairs genuinely asymmetric. Between towns that
  /// is a few hundred metres — far less than the contradiction it removes.
  Future<RouteInfo> pairRoute(
    LatLng a,
    LatLng b, {
    double roadFactor = AppDefaults.fallbackRoadFactor,
    bool withGeometry = true,
  }) async {
    if (samePoint(a, b)) return RouteInfo.zero;

    final key = _pairKey(a, b, withGeometry);
    final cached = _pairCache[key];
    if (cached != null) return _oriented(cached, a);

    final forward = await route(a, b, roadFactor: roadFactor, withGeometry: withGeometry);
    final backward = await route(b, a, roadFactor: roadFactor, withGeometry: withGeometry);

    // A straight line never wins on distance, however small it is: it is short
    // because it ignores the mountain, not because the road does.
    final RouteInfo best;
    final LatLng start;
    if (forward.estimated != backward.estimated) {
      best = forward.estimated ? backward : forward;
      start = forward.estimated ? b : a;
    } else if (forward.distanceKm <= backward.distanceKm) {
      best = forward;
      start = a;
    } else {
      best = backward;
      start = b;
    }

    final entry = (info: best, start: start);
    _pairCache[key] = entry;
    return _oriented(entry, a);
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

  /// The winning route pointed the way the caller asked for. Only the polyline
  /// has a direction; the distance and the drive time belong to the road.
  RouteInfo _oriented(({RouteInfo info, LatLng start}) e, LatLng from) {
    if (e.info.geometry.length < 2 || samePoint(e.start, from)) return e.info;
    return RouteInfo(
      distanceKm: e.info.distanceKm,
      duration: e.info.duration,
      geometry: e.info.geometry.reversed.toList(growable: false),
      estimated: e.info.estimated,
    );
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

  String _key(LatLng a, LatLng b, bool geometry) => '${_point(a)}>${_point(b)}:$geometry';

  /// Endpoints in a fixed order, so A to B and B to A land on one entry.
  String _pairKey(LatLng a, LatLng b, bool geometry) {
    final x = _point(a);
    final y = _point(b);
    return '${x.compareTo(y) <= 0 ? '$x|$y' : '$y|$x'}:$geometry';
  }

  /// Four decimal places is about eleven metres, finer than any origin this app
  /// is given and coarse enough that the cache actually hits.
  String _point(LatLng p) =>
      '${p.latitude.toStringAsFixed(4)},${p.longitude.toStringAsFixed(4)}';
}
