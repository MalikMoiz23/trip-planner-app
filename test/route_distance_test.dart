import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:trip_planner/core/enums.dart';
import 'package:trip_planner/core/geo.dart';
import 'package:trip_planner/data/models/destination.dart';
import 'package:trip_planner/data/models/meal_plan.dart';
import 'package:trip_planner/data/models/route_info.dart';
import 'package:trip_planner/data/models/trip_config.dart';
import 'package:trip_planner/data/models/trip_stop.dart';
import 'package:trip_planner/data/sources/osrm_service.dart';
import 'package:trip_planner/domain/expense_calculator.dart';

/// The real coordinates from the report: the app showed 135 km out to Panjpeer
/// Rocks and 105 km back from it, for one road.
const _wah = LatLng(33.7863064, 72.7267564);
const _panjpeer = LatLng(33.7344714, 73.5298703);

// ---------------------------------------------------------------------------
// A fake OSRM that reproduces the asymmetry the live server actually returned.
// ---------------------------------------------------------------------------

class _FakeOsrm extends http.BaseClient {
  _FakeOsrm(this.routesFor);

  /// Distances in kilometres for a request, in the order OSRM would list them
  /// (fastest first). Null means the server failed.
  final List<double>? Function(LatLng from, LatLng to) routesFor;

  final List<String> calls = [];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final coords = Uri.decodeComponent(request.url.pathSegments.last).split(';');
    LatLng parse(String s) {
      final parts = s.split(',');
      return LatLng(double.parse(parts[1]), double.parse(parts[0]));
    }

    final from = parse(coords[0]);
    final to = parse(coords[1]);
    calls.add(coords.join(';'));

    final distances = routesFor(from, to);
    if (distances == null) {
      return http.StreamedResponse(const Stream.empty(), 500, request: request);
    }

    final body = jsonEncode({
      'code': 'Ok',
      'routes': [
        for (final km in distances)
          {
            'distance': km * 1000,
            // Roughly 55 km/h, which is what these roads run at. The exact
            // figure does not matter: nothing here is chosen by time.
            'duration': (km / 55 * 3600).round(),
            'geometry': _polyline([from, to]),
          },
      ],
    });
    return http.StreamedResponse(Stream.value(utf8.encode(body)), 200, request: request);
  }
}

/// Encodes points the way OSRM does with `geometries=polyline`, so the decoder
/// under test gets a real string rather than a hand-written one.
String _polyline(List<LatLng> points) {
  final sb = StringBuffer();
  var lat = 0, lng = 0;
  for (final p in points) {
    final la = (p.latitude * 1e5).round();
    final ln = (p.longitude * 1e5).round();
    _chunk(sb, la - lat);
    _chunk(sb, ln - lng);
    lat = la;
    lng = ln;
  }
  return sb.toString();
}

void _chunk(StringBuffer sb, int value) {
  var v = value < 0 ? ~(value << 1) : (value << 1);
  while (v >= 0x20) {
    sb.writeCharCode((0x20 | (v & 0x1f)) + 63);
    v >>= 5;
  }
  sb.writeCharCode(v + 63);
}

// ---------------------------------------------------------------------------
// Trip fixtures
// ---------------------------------------------------------------------------

Destination _town(String id, LatLng at, {double roadFactor = 1.6}) => Destination(
      id: id,
      name: id.toUpperCase(),
      region: 'R',
      province: 'P',
      category: 'Mountains',
      lat: at.latitude,
      lng: at.longitude,
      altitudeM: 1500,
      recommendedDays: 2,
      roadFactor: roadFactor,
      requires4x4: false,
      difficulty: 'Moderate',
      bestMonths: const [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12],
      tagline: '',
      description: '',
      highlights: const [],
      attractions: const [],
    );

TripConfig _config(List<TripStop> stops) => TripConfig(
      originName: 'Wah',
      originLat: _wah.latitude,
      originLng: _wah.longitude,
      stops: stops,
      startDate: DateTime(2026, 7, 1),
      days: 3,
      persons: 2,
      mode: TravelMode.ownVehicle,
      vehicleId: 'sedan',
      mileage: 12,
      fuelPrice: 342.60,
      fuel: FuelKind.petrol,
      publicRatePerKm: 5,
      localTransportPerPersonDay: 800,
      roomOccupancy: 2,
      stayStyle: StayStyle.hotel,
      stayRatePerUnitNight: 11000,
      foodStyle: FoodStyle.restaurant,
      mealPlan: MealPlan.standard(dayCount: 3, basePrice: 1200),
      campKitchenCost: 0,
      fuelPriceIsDefault: false,
      bufferPercent: 10,
      tollsAndParking: 1500,
    );

void main() {
  group('OsrmService.pairRoute', () {
    test('one road gives one distance, whichever way it is asked', () async {
      // Exactly what router.project-osrm.org returned on 2026-09-01: going out
      // it offered a single 132.7 km road, coming back it also offered the
      // 114.1 km one. Picking the shortest per direction is what produced two
      // different numbers for the same drive.
      final fake = _FakeOsrm((from, to) =>
          samePoint(from, _wah) ? const [132.7] : const [133.6, 114.1]);
      final osrm = OsrmService(client: fake);

      final out = await osrm.pairRoute(_wah, _panjpeer);
      final back = await osrm.pairRoute(_panjpeer, _wah);

      expect(out.distanceKm, closeTo(114.1, 0.001));
      expect(back.distanceKm, closeTo(out.distanceKm, 0.001));
      expect(out.estimated, isFalse);
    });

    test('the second leg costs no extra request', () async {
      final fake = _FakeOsrm((from, to) =>
          samePoint(from, _wah) ? const [132.7] : const [133.6, 114.1]);
      final osrm = OsrmService(client: fake);

      await osrm.pairRoute(_wah, _panjpeer);
      await osrm.pairRoute(_panjpeer, _wah);

      // Two: one per direction, asked once for the pair and then cached.
      expect(fake.calls.length, 2);
    });

    test('the drawn line still runs the way it was asked for', () async {
      // The winning road was measured coming back, so its polyline arrives
      // pointing the wrong way. A map that drew it as given would show the trip
      // starting at the destination.
      final fake = _FakeOsrm((from, to) =>
          samePoint(from, _wah) ? const [132.7] : const [133.6, 114.1]);
      final osrm = OsrmService(client: fake);

      final out = await osrm.pairRoute(_wah, _panjpeer);
      expect(out.geometry, hasLength(2));
      expect(out.geometry.first.latitude, closeTo(_wah.latitude, 0.001));
      expect(out.geometry.last.latitude, closeTo(_panjpeer.latitude, 0.001));

      final back = await osrm.pairRoute(_panjpeer, _wah);
      expect(back.geometry.first.latitude, closeTo(_panjpeer.latitude, 0.001));
    });

    test('a straight-line estimate never wins on distance', () async {
      // The fallback is short because it ignores the mountain. Letting it win
      // would quietly halve the fuel bill whenever one request failed.
      final fake = _FakeOsrm((from, to) => samePoint(from, _wah) ? const [132.7] : null);
      final osrm = OsrmService(client: fake);

      final out = await osrm.pairRoute(_wah, _panjpeer);
      expect(out.distanceKm, closeTo(132.7, 0.001));
      expect(out.estimated, isFalse);

      final back = await osrm.pairRoute(_panjpeer, _wah);
      expect(back.distanceKm, closeTo(132.7, 0.001));
    });

    test('with the server down both directions agree on the estimate', () async {
      final fake = _FakeOsrm((from, to) => null);
      final osrm = OsrmService(client: fake);

      final out = await osrm.pairRoute(_wah, _panjpeer, roadFactor: 1.45);
      final back = await osrm.pairRoute(_panjpeer, _wah, roadFactor: 1.45);

      expect(out.estimated, isTrue);
      expect(out.distanceKm, closeTo(haversineKm(_wah, _panjpeer) * 1.45, 0.001));
      expect(back.distanceKm, closeTo(out.distanceKm, 0.001));
    });

    test('a place is nought kilometres from itself', () async {
      final fake = _FakeOsrm((from, to) => const [10.0]);
      final osrm = OsrmService(client: fake);

      expect((await osrm.pairRoute(_wah, _wah)).distanceKm, 0);
      expect(fake.calls, isEmpty);
    });
  });

  group('ExpenseCalculator leg resolution', () {
    test('a missing return leg mirrors the outbound one', () {
      // While the second request is in flight the screen shows both figures.
      // A straight-line stand-in there read 257 km back against 133 km out.
      final b = ExpenseCalculator.compute(
        config: _config([TripStop(destination: _town('p', _panjpeer), nights: 2)]),
        legs: const [RouteInfo(distanceKm: 114.1, duration: Duration(hours: 2))],
      );

      expect(b.oneWayKm, closeTo(114.1, 0.001));
      expect(b.returnKm, closeTo(114.1, 0.001));
      expect(b.travelKm, closeTo(228.2, 0.001));
      // Mirrored, not guessed: the figure came off a real routed road.
      expect(b.routeEstimated, isFalse);
    });

    test('an estimated leg takes its own stop terrain, not the first stop\'s', () {
      final a = _town('a', const LatLng(34.9, 73.6), roadFactor: 1.2);
      final z = _town('z', const LatLng(36.3, 74.6), roadFactor: 2.0);

      final b = ExpenseCalculator.compute(
        config: _config([
          TripStop(destination: a, nights: 1),
          TripStop(destination: z, nights: 1),
        ]),
        legs: const [RouteInfo(distanceKm: 100, duration: Duration(hours: 3))],
      );

      // Legs 1 and 2 are unrouted and have no mirror, so both are estimated
      // against Z's terrain — the drive home from Z is not a Murree road.
      expect(b.legKms[1], closeTo(haversineKm(a.point, z.point) * 2.0, 0.001));
      expect(b.legKms[2], closeTo(haversineKm(z.point, _wah) * 2.0, 0.001));
      expect(b.routeEstimated, isTrue);
    });

    test('routed legs are left exactly as the router gave them', () {
      final b = ExpenseCalculator.compute(
        config: _config([TripStop(destination: _town('p', _panjpeer), nights: 2)]),
        legs: const [
          RouteInfo(distanceKm: 114.1, duration: Duration(hours: 2)),
          RouteInfo(distanceKm: 114.1, duration: Duration(hours: 2)),
        ],
      );

      expect(b.legKms, hasLength(2));
      expect(b.totalKm, closeTo(228.2, 0.001));
    });
  });
}
