import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../core/app_constants.dart';
import '../core/fuzzy.dart';

class PlaceHit {
  const PlaceHit({
    required this.id,
    required this.name,
    required this.context,
    required this.point,
    this.viaQuery,
  });

  final String id;
  final String name;

  /// The rest of the address line, e.g. "Mansehra, Khyber Pakhtunkhwa".
  final String context;
  final LatLng point;

  /// Set when the hit came from a rewritten query rather than what the user
  /// typed, so the UI can admit what it actually searched for.
  final String? viaQuery;
}

/// Free geocoding over OpenStreetMap's Nominatim. The public instance allows
/// roughly one request per second and requires an identifying User-Agent, so
/// callers are debounced and results are cached for the session.
class NominatimService {
  NominatimService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  final Map<String, List<PlaceHit>> _searchCache = {};
  final Map<String, String> _reverseCache = {};

  static const Map<String, String> _headers = {
    'User-Agent': Endpoints.userAgent,
    'Accept': 'application/json',
  };

  /// Searches for a place, relaxing the query until something comes back.
  ///
  /// Nominatim matches near-exactly: "Thandyani Top" returns nothing while
  /// "Thandiani" returns the hill station, and "Panj Peer Rocks" returns
  /// nothing while "Panj Pir" returns the ridge. So the query is retried
  /// without place-kind words and then progressively shortened, stopping at the
  /// first variant that produces hits.
  ///
  /// Attempts are capped and run one at a time: the public instance asks for
  /// roughly one request per second.
  Future<List<PlaceHit>> search(String query, {String countryCodes = 'pk'}) async {
    final q = query.trim();
    if (q.length < 3) return const [];
    final cached = _searchCache[q.toLowerCase()];
    if (cached != null) return cached;

    final variants = queryVariants(q);
    for (var i = 0; i < variants.length; i++) {
      final variant = variants[i];
      final isOriginal = i == 0;
      var hits = await _searchExact(variant, countryCodes);
      if (hits.isEmpty) continue;

      if (isOriginal) {
        // The user's own words: trust the geocoder's ranking. It can make
        // connections the string comparison cannot — "Kotli Sattian Rocks"
        // legitimately resolves to Panjpeer Rocks.
        _searchCache[q.toLowerCase()] = hits;
        return hits;
      }

      // A query I rewrote. Shortening can land somewhere else entirely —
      // "Neela Sandh Waterfall" trimmed to "Neela" returns Neela Botho — so
      // each hit has to still resemble what was actually asked for.
      final scored = hits
          .map((h) => (hit: h, score: scoreCandidate(q, h.name)))
          .where((e) => e.score >= _relaxedHitFloor)
          .toList()
        ..sort((a, b) => b.score.compareTo(a.score));

      hits = scored
          .map((e) => PlaceHit(
                id: e.hit.id,
                name: e.hit.name,
                context: e.hit.context,
                point: e.hit.point,
                viaQuery: variant,
              ))
          .toList(growable: false);

      if (hits.isNotEmpty) {
        _searchCache[q.toLowerCase()] = hits;
        return hits;
      }
    }
    _searchCache[q.toLowerCase()] = const [];
    return const [];
  }

  /// How closely a hit from a rewritten query must still resemble the original.
  /// Deliberately below [fuzzyThreshold]: geocoder names carry extra words the
  /// user never typed.
  static const double _relaxedHitFloor = 0.60;

  Future<List<PlaceHit>> _searchExact(String q, String countryCodes) async {
    final uri = Uri.parse('${Endpoints.nominatimBase}/search').replace(queryParameters: {
      'q': q,
      'format': 'jsonv2',
      'limit': '8',
      'addressdetails': '1',
      'namedetails': '1',
      'accept-language': 'en',
      'countrycodes': countryCodes,
    });

    try {
      final res = await _client.get(uri, headers: _headers).timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) return const [];
      final data = jsonDecode(res.body) as List<dynamic>;
      final hits = <PlaceHit>[];

      for (final raw in data) {
        final m = raw as Map<String, dynamic>;
        final display = (m['display_name'] as String?) ?? '';
        final parts = display.split(',').map((p) => p.trim()).toList();
        final names = (m['namedetails'] as Map<String, dynamic>?) ?? const {};

        // Prefer an English name: rural nodes often carry only an Urdu `name`,
        // which reads as mojibake beside the rest of the UI.
        final candidates = <String?>[
          names['name:en'] as String?,
          names['int_name'] as String?,
          m['name'] as String?,
          parts.isNotEmpty ? parts.first : null,
        ];
        final name = candidates.firstWhere(
          (c) => c != null && c.trim().isNotEmpty && RegExp(r'[A-Za-z]').hasMatch(c),
          orElse: () => null,
        );
        if (name == null) continue;

        hits.add(PlaceHit(
          id: '${m['osm_type']}_${m['osm_id']}',
          name: name.trim(),
          context: parts.length > 1 ? parts.sublist(1).take(3).join(', ') : '',
          point: LatLng(
            double.parse(m['lat'] as String),
            double.parse(m['lon'] as String),
          ),
        ));
      }
      return hits;
    } on Exception {
      return const [];
    }
  }

  /// Best-effort place name for a coordinate. Returns a coordinate string when
  /// the lookup fails, never throws.
  Future<String> reverse(LatLng point) async {
    final key = '${point.latitude.toStringAsFixed(3)},${point.longitude.toStringAsFixed(3)}';
    final cached = _reverseCache[key];
    if (cached != null) return cached;

    final uri = Uri.parse('${Endpoints.nominatimBase}/reverse').replace(queryParameters: {
      'lat': '${point.latitude}',
      'lon': '${point.longitude}',
      'format': 'jsonv2',
      'zoom': '12',
      'addressdetails': '1',
    });

    try {
      final res = await _client.get(uri, headers: _headers).timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) return _coordLabel(point);
      final m = jsonDecode(res.body) as Map<String, dynamic>;
      final addr = (m['address'] as Map<String, dynamic>?) ?? const {};
      final locality = addr['city'] ??
          addr['town'] ??
          addr['village'] ??
          addr['municipality'] ??
          addr['county'] ??
          addr['state_district'];
      final region = addr['state'];
      final label = [locality, region].whereType<String>().join(', ');
      final result = label.isEmpty ? _coordLabel(point) : label;
      _reverseCache[key] = result;
      return result;
    } on Exception {
      return _coordLabel(point);
    }
  }

  String _coordLabel(LatLng p) =>
      '${p.latitude.toStringAsFixed(3)}, ${p.longitude.toStringAsFixed(3)}';
}
