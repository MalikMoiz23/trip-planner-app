import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import 'package:trip_planner/core/constants.dart';
import 'package:trip_planner/data/sources/nominatim_service.dart' show PlaceHit;

/// A second free geocoder over the same OpenStreetMap data, and it exists
/// because the two fail in opposite directions.
///
/// Nominatim matches near-exactly: it is authoritative when the spelling is
/// right and returns nothing when it is not. Photon is built for type-ahead —
/// it is forgiving of partial and misspelled input, and finds Thandiani from
/// "Thandyani" where Nominatim finds nothing. Running both and merging covers
/// far more of the country than either alone.
///
/// Free, no key, no account. Komoot ask for an identifying User-Agent and
/// reasonable use, which the debounce and cache in the repository provide.
class PhotonService {
  PhotonService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  final Map<String, List<PlaceHit>> _cache = {};

  static const Duration _timeout = Duration(seconds: 10);

  /// Roughly Pakistan, west to east and south to north.
  ///
  /// Without it the global index wins on name alone: "Naran" returns places in
  /// Europe and nothing in Pakistan at all.
  static const String _pakistanBbox = '60.87,23.63,77.84,37.10';

  /// OSM values that name a place worth travelling to. Photon happily returns
  /// bakeries, bus stops and government offices for a valley name, and a search
  /// for somewhere to go should not be answered with a clothes shop.
  static const Set<String> _wanted = {
    // Settlements
    'city', 'town', 'village', 'hamlet', 'suburb', 'locality', 'municipality',
    'neighbourhood', 'district', 'region', 'province', 'county', 'state',
    // Natural features
    'valley', 'peak', 'ridge', 'glacier', 'water', 'lake', 'river', 'bay',
    'beach', 'cliff', 'cave_entrance', 'hot_spring', 'spring', 'waterfall',
    'wood', 'forest', 'desert', 'plateau', 'saddle', 'mountain_range',
    // Somewhere to visit
    'attraction', 'viewpoint', 'museum', 'monument', 'memorial', 'ruins',
    'archaeological_site', 'fort', 'castle', 'tomb', 'national_park',
    'nature_reserve', 'park', 'protected_area', 'zoo', 'theme_park',
    'picnic_site', 'camp_site', 'alpine_hut', 'wilderness_hut',
    'administrative',
  };

  Future<List<PlaceHit>> search(String query) async {
    final q = query.trim();
    if (q.length < 3) return const [];

    final key = q.toLowerCase();
    final hit = _cache[key];
    if (hit != null) return hit;

    final uri = Uri.parse('${Endpoints.photonBase}?'
        'q=${Uri.encodeQueryComponent(q)}'
        '&limit=12&lang=en&bbox=$_pakistanBbox');

    try {
      final res = await _client.get(
        uri,
        headers: const {'User-Agent': Endpoints.userAgent},
      ).timeout(_timeout);

      if (res.statusCode != 200) return const [];

      final body = jsonDecode(res.body);
      if (body is! Map<String, dynamic>) return const [];
      final features = (body['features'] as List?) ?? const [];

      final out = <PlaceHit>[];
      for (final raw in features) {
        if (raw is! Map<String, dynamic>) continue;
        final props = (raw['properties'] as Map<String, dynamic>?) ?? const {};

        // The bbox biases ranking but does not restrict results, so anything
        // outside Pakistan is dropped here.
        if (props['countrycode'] != 'PK') continue;

        final value = props['osm_value'] as String?;
        if (value == null || !_wanted.contains(value)) continue;

        final name = props['name'] as String?;
        if (name == null || name.trim().isEmpty) continue;

        final coords = ((raw['geometry'] as Map<String, dynamic>?)?['coordinates'] as List?);
        if (coords == null || coords.length < 2) continue;
        final lng = (coords[0] as num).toDouble();
        final lat = (coords[1] as num).toDouble();

        out.add(PlaceHit(
          id: 'photon_${props['osm_type'] ?? 'x'}_${props['osm_id'] ?? name}',
          name: name.trim(),
          context: _contextOf(props),
          point: LatLng(lat, lng),
        ));
      }

      _cache[key] = out;
      return out;
    } on Exception {
      // A geocoder being down is not an error worth showing: the other one and
      // the bundled catalogue still answer.
      return const [];
    }
  }

  /// "Mansehra, Khyber Pakhtunkhwa" from whichever fields are present.
  static String _contextOf(Map<String, dynamic> props) {
    final parts = <String>[
      for (final key in ['district', 'county', 'city', 'state'])
        if (props[key] is String && (props[key] as String).trim().isNotEmpty)
          (props[key] as String).trim(),
    ];
    // Photon often repeats the same name across levels.
    final seen = <String>{};
    final unique = parts.where((p) => seen.add(p.toLowerCase())).toList();
    return unique.isEmpty ? 'Pakistan' : unique.take(2).join(', ');
  }
}
