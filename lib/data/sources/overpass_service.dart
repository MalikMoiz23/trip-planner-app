import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import 'package:trip_planner/core/constants.dart';
import 'package:trip_planner/core/geo.dart';

/// One place as OpenStreetMap actually holds it: a name, a category and a
/// position. No prices, because OSM carries none.
class OsmPlace {
  const OsmPlace({
    required this.id,
    required this.name,
    required this.category,
    required this.lat,
    required this.lng,
    required this.feeExplicitlyFree,
  });

  final String id;
  final String name;
  final String category;
  final double lat;
  final double lng;

  /// OSM tagged it `fee=no`. Worth carrying through, because it is the one
  /// price fact the data does contain.
  final bool feeExplicitlyFree;

  LatLng get point => LatLng(lat, lng);
}

/// Live "what else is around here" lookup against OpenStreetMap via Overpass.
///
/// Free and key-less. This layer only fetches and parses. What a waterfall
/// typically costs to visit is a pricing assumption, and assumptions belong in
/// domain — the repository joins the two together.
class OverpassService {
  OverpassService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  final Map<String, List<OsmPlace>> _cache = {};

  Future<List<OsmPlace>> nearby(
    LatLng centre, {
    int radiusMetres = 35000,
    int limit = 30,
    Set<String> excludeNames = const {},
  }) async {
    final key = '${centre.latitude.toStringAsFixed(3)},'
        '${centre.longitude.toStringAsFixed(3)}:$radiusMetres';
    final cached = _cache[key];
    if (cached != null) return _filter(cached, excludeNames, limit);

    final lat = centre.latitude;
    final lng = centre.longitude;
    final r = radiusMetres;
    final query = '''
[out:json][timeout:25];
(
  node["tourism"~"^(attraction|viewpoint|museum|artwork|zoo|theme_park)\$"](around:$r,$lat,$lng);
  way["tourism"~"^(attraction|viewpoint|museum)\$"](around:$r,$lat,$lng);
  node["natural"~"^(peak|glacier|hot_spring|cave_entrance)\$"](around:$r,$lat,$lng);
  node["waterway"="waterfall"](around:$r,$lat,$lng);
  node["historic"~"^(fort|castle|monument|memorial|ruins|archaeological_site|tomb)\$"](around:$r,$lat,$lng);
  way["natural"="water"](around:$r,$lat,$lng);
);
out center $limit;
''';

    try {
      final res = await _client
          .post(
            Uri.parse(Endpoints.overpassBase),
            headers: const {
              'User-Agent': Endpoints.userAgent,
              'Content-Type': 'application/x-www-form-urlencoded',
            },
            body: {'data': query},
          )
          .timeout(const Duration(seconds: 30));

      if (res.statusCode != 200) return const [];

      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final elements = (body['elements'] as List?) ?? const [];
      final seen = <String>{};
      final out = <OsmPlace>[];

      for (final raw in elements) {
        final e = raw as Map<String, dynamic>;
        final tags = (e['tags'] as Map<String, dynamic>?) ?? const {};
        // Prefer a Latin-script name. Many rural nodes carry only `name` in
        // Urdu, which is unreadable next to the rest of the UI and useless for
        // matching, so those are skipped rather than shown as mojibake.
        final name = (tags['name:en'] ?? tags['int_name'] ?? tags['name']) as String?;
        if (name == null || name.trim().isEmpty) continue;
        if (!_hasLatinLetters(name)) continue;
        if (!seen.add(name.toLowerCase())) continue;

        final lat = (e['lat'] as num?)?.toDouble() ??
            ((e['center'] as Map<String, dynamic>?)?['lat'] as num?)?.toDouble();
        final lng = (e['lon'] as num?)?.toDouble() ??
            ((e['center'] as Map<String, dynamic>?)?['lon'] as num?)?.toDouble();
        if (lat == null || lng == null) continue;

        out.add(OsmPlace(
          id: 'osm_${e['type']}_${e['id']}',
          name: name.trim(),
          category: _categoryFor(tags),
          lat: lat,
          lng: lng,
          feeExplicitlyFree: tags['fee'] == 'no' || tags['fee'] == 'false',
        ));
      }

      out.sort((a, b) => haversineKm(centre, a.point).compareTo(haversineKm(centre, b.point)));
      _cache[key] = out;
      return _filter(out, excludeNames, limit);
    } on Exception {
      return const [];
    }
  }

  List<OsmPlace> _filter(List<OsmPlace> all, Set<String> excludeNames, int limit) {
    final blocked = excludeNames.map((e) => e.toLowerCase()).toSet();
    return all
        .where((a) => !blocked.any((b) => a.name.toLowerCase().contains(b) || b.contains(a.name.toLowerCase())))
        .take(limit)
        .toList(growable: false);
  }

  /// True when the string contains at least one a-z letter. Filters out nodes
  /// named only in Urdu or Arabic script.
  bool _hasLatinLetters(String value) =>
      RegExp(r'[A-Za-z]').hasMatch(value);

  String _categoryFor(Map<String, dynamic> tags) {
    if (tags['waterway'] == 'waterfall') return 'Waterfall';
    if (tags['natural'] == 'peak') return 'Viewpoint';
    if (tags['natural'] == 'water') return 'Lake';
    if (tags['natural'] == 'glacier') return 'Nature';
    if (tags['tourism'] == 'viewpoint') return 'Viewpoint';
    if (tags['tourism'] == 'museum') return 'Historical';
    if (tags['historic'] != null) return 'Historical';
    return 'Attraction';
  }
}
