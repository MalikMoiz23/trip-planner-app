import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../core/app_constants.dart';
import '../core/geo.dart';
import '../models/attraction.dart';

/// Live "what else is around here" lookup against OpenStreetMap via Overpass.
///
/// Free and key-less. It returns names and coordinates only — OSM carries no
/// pricing — so every result comes back with zero cost fields, marked
/// `isLive: true` so the UI can tell the user to fill the numbers in.
class OverpassService {
  OverpassService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  final Map<String, List<Attraction>> _cache = {};

  Future<List<Attraction>> nearby(
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
      final out = <Attraction>[];

      for (final raw in elements) {
        final e = raw as Map<String, dynamic>;
        final tags = (e['tags'] as Map<String, dynamic>?) ?? const {};
        final name = (tags['name:en'] ?? tags['name']) as String?;
        if (name == null || name.trim().isEmpty) continue;
        if (!seen.add(name.toLowerCase())) continue;

        final lat = (e['lat'] as num?)?.toDouble() ??
            ((e['center'] as Map<String, dynamic>?)?['lat'] as num?)?.toDouble();
        final lng = (e['lon'] as num?)?.toDouble() ??
            ((e['center'] as Map<String, dynamic>?)?['lon'] as num?)?.toDouble();
        if (lat == null || lng == null) continue;

        out.add(Attraction(
          id: 'osm_${e['type']}_${e['id']}',
          name: name.trim(),
          category: _categoryFor(tags),
          description: 'From OpenStreetMap. Costs are not published for this entry — '
              'set the fee and local fare yourself.',
          lat: lat,
          lng: lng,
          entryFee: 0,
          localTransport: 0,
          visitHours: 2,
          isLive: true,
        ));
      }

      out.sort((a, b) => haversineKm(centre, a.point).compareTo(haversineKm(centre, b.point)));
      _cache[key] = out;
      return _filter(out, excludeNames, limit);
    } on Exception {
      return const [];
    }
  }

  List<Attraction> _filter(List<Attraction> all, Set<String> excludeNames, int limit) {
    final blocked = excludeNames.map((e) => e.toLowerCase()).toSet();
    return all
        .where((a) => !blocked.any((b) => a.name.toLowerCase().contains(b) || b.contains(a.name.toLowerCase())))
        .take(limit)
        .toList(growable: false);
  }

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
