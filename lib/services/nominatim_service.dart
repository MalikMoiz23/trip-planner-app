import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../core/app_constants.dart';

class PlaceHit {
  const PlaceHit({
    required this.id,
    required this.name,
    required this.context,
    required this.point,
  });

  final String id;
  final String name;

  /// The rest of the address line, e.g. "Mansehra, Khyber Pakhtunkhwa".
  final String context;
  final LatLng point;
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

  Future<List<PlaceHit>> search(String query, {String countryCodes = 'pk'}) async {
    final q = query.trim();
    if (q.length < 3) return const [];
    final cached = _searchCache[q.toLowerCase()];
    if (cached != null) return cached;

    final uri = Uri.parse('${Endpoints.nominatimBase}/search').replace(queryParameters: {
      'q': q,
      'format': 'jsonv2',
      'limit': '8',
      'addressdetails': '1',
      'countrycodes': countryCodes,
    });

    try {
      final res = await _client.get(uri, headers: _headers).timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) return const [];
      final data = jsonDecode(res.body) as List<dynamic>;
      final hits = data.map((raw) {
        final m = raw as Map<String, dynamic>;
        final display = (m['display_name'] as String?) ?? '';
        final parts = display.split(',').map((p) => p.trim()).toList();
        final name = (m['name'] as String?)?.trim().isNotEmpty == true
            ? m['name'] as String
            : (parts.isNotEmpty ? parts.first : display);
        final context = parts.length > 1 ? parts.sublist(1).take(3).join(', ') : '';
        return PlaceHit(
          id: '${m['osm_type']}_${m['osm_id']}',
          name: name,
          context: context,
          point: LatLng(
            double.parse(m['lat'] as String),
            double.parse(m['lon'] as String),
          ),
        );
      }).toList(growable: false);
      _searchCache[q.toLowerCase()] = hits;
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
