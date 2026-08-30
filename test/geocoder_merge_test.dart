import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:trip_planner/data/repositories/destination_repository.dart';
import 'package:trip_planner/data/sources/nominatim_service.dart';
import 'package:trip_planner/data/sources/photon_service.dart';

/// Serves canned responses so the merge can be tested without a network.
class _FakeClient extends http.BaseClient {
  _FakeClient(this.bodyFor);

  final String? Function(Uri uri) bodyFor;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final body = bodyFor(request.url);
    if (body == null) {
      return http.StreamedResponse(const Stream.empty(), 500);
    }
    return http.StreamedResponse(
      Stream.value(utf8.encode(body)),
      200,
      request: request,
    );
  }
}

String _nominatimBody(List<(String, double, double)> places) => jsonEncode([
      for (final (name, lat, lng) in places)
        {
          'place_id': name.hashCode,
          'name': name,
          'display_name': '$name, Pakistan',
          'lat': '$lat',
          'lon': '$lng',
        },
    ]);

String _photonBody(List<(String, String, double, double)> places) => jsonEncode({
      'features': [
        for (final (name, value, lat, lng) in places)
          {
            'geometry': {'coordinates': [lng, lat]},
            'properties': {
              'name': name,
              'countrycode': 'PK',
              'osm_value': value,
              'osm_id': name.hashCode,
              'osm_type': 'N',
              'district': 'Somewhere',
            },
          },
      ],
    });

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  DestinationRepository build({
    required String nominatim,
    required String photon,
  }) =>
      DestinationRepository(
        nominatim: NominatimService(client: _FakeClient((_) => nominatim)),
        photon: PhotonService(client: _FakeClient((_) => photon)),
      );

  group('the two geocoders together', () {
    test('answers from both are merged, Nominatim first', () async {
      final repo = build(
        nominatim: _nominatimBody([('Jhelum', 32.94, 73.73)]),
        photon: _photonBody([('Bhurban', 'village', 33.95, 73.45)]),
      );

      final hits = await repo.searchRemote('somewhere');
      expect(hits.map((h) => h.name), ['Jhelum', 'Bhurban']);
    });

    test('the same place from both sources appears once', () async {
      // Nominatim and Photon both know Jhelum, a few hundred metres apart.
      final repo = build(
        nominatim: _nominatimBody([('Jhelum', 32.9400, 73.7300)]),
        photon: _photonBody([('Jhelum', 'city', 32.9410, 73.7315)]),
      );

      final hits = await repo.searchRemote('jhelum');
      expect(hits.length, 1, reason: 'one place, not two rows');
      expect(hits.first.name, 'Jhelum');
    });

    test('two different places that share a name both survive', () async {
      // Far apart, so they are genuinely different places.
      final repo = build(
        nominatim: _nominatimBody([('Ziarat', 30.38, 67.72)]),
        photon: _photonBody([('Ziarat', 'village', 34.60, 73.10)]),
      );

      final hits = await repo.searchRemote('ziarat');
      expect(hits.length, 2);
    });

    test('Photon noise is filtered out', () async {
      // A search for a valley should not be answered with a bakery.
      final repo = build(
        nominatim: _nominatimBody([]),
        photon: _photonBody([
          ('Gojal Bakers', 'bakery', 36.4, 74.8),
          ('Gojal Magistrate', 'government', 36.4, 74.8),
          ('Gojal Bus Stop', 'bus_stop', 36.4, 74.8),
          ('Gojal', 'village', 36.41, 74.85),
        ]),
      );

      final hits = await repo.searchRemote('gojal');
      expect(hits.map((h) => h.name), ['Gojal']);
    });

    test('one geocoder failing does not take the other down', () async {
      final repo = DestinationRepository(
        nominatim: NominatimService(client: _FakeClient((_) => null)),
        photon: PhotonService(
          client: _FakeClient((_) => _photonBody([('Sost', 'village', 36.68, 74.85)])),
        ),
      );

      final hits = await repo.searchRemote('sost');
      expect(hits.map((h) => h.name), ['Sost']);
    });

    test('anything outside Pakistan is dropped', () async {
      final repo = build(
        nominatim: _nominatimBody([]),
        photon: jsonEncode({
          'features': [
            {
              'geometry': {'coordinates': [2.35, 48.85]},
              'properties': {
                'name': 'Naran',
                'countrycode': 'FR',
                'osm_value': 'village',
                'osm_id': 1,
                'osm_type': 'N',
              },
            },
          ],
        }),
      );

      expect(await repo.searchRemote('naran'), isEmpty);
    });
  });
}
