import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:trip_planner/core/enums.dart';
import 'package:trip_planner/data/models/destination.dart';
import 'package:trip_planner/data/models/meal_plan.dart';
import 'package:trip_planner/data/models/trip_config.dart';
import 'package:trip_planner/data/models/trip_stop.dart';
import 'package:trip_planner/data/repositories/destination_repository.dart';
import 'package:trip_planner/data/repositories/emergency_repository.dart';
import 'package:trip_planner/data/sources/osrm_service.dart';
import 'package:trip_planner/data/sources/overpass_service.dart';
import 'package:trip_planner/domain/assistant.dart';
import 'package:trip_planner/domain/survival.dart';

/// Serves Overpass and OSRM from one fake, because the emergency lookup uses
/// both and the interesting behaviour is what happens when they disagree.
class _FakeNet extends http.BaseClient {
  _FakeNet({this.overpass, this.osrmKmByIndex});

  /// Null means the Overpass server failed, which is the offline case.
  final List<(String name, double lat, double lng)>? overpass;

  /// Road distance in km for each destination, keyed by its position in
  /// [overpass]. A missing entry makes that route fail.
  final Map<int, double>? osrmKmByIndex;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final url = request.url;

    if (url.host.contains('overpass')) {
      if (overpass == null) {
        return http.StreamedResponse(const Stream.empty(), 504, request: request);
      }
      final body = jsonEncode({
        'elements': [
          for (var i = 0; i < overpass!.length; i++)
            {
              'type': 'node',
              'id': 1000 + i,
              'lat': overpass![i].$2,
              'lon': overpass![i].$3,
              if (overpass![i].$1.isNotEmpty) 'tags': {'name': overpass![i].$1},
            },
        ],
      });
      return http.StreamedResponse(Stream.value(utf8.encode(body)), 200, request: request);
    }

    // OSRM. Work out which destination this is by matching the coordinates.
    final coords = url.pathSegments.last.split(';');
    final to = coords[1].split(',');
    final lng = double.parse(to[0]);
    final lat = double.parse(to[1]);

    int? index;
    for (var i = 0; i < (overpass?.length ?? 0); i++) {
      if ((overpass![i].$2 - lat).abs() < 1e-6 && (overpass![i].$3 - lng).abs() < 1e-6) {
        index = i;
      }
    }
    final km = index == null ? null : osrmKmByIndex?[index];
    if (km == null) {
      return http.StreamedResponse(const Stream.empty(), 500, request: request);
    }

    final body = jsonEncode({
      'code': 'Ok',
      'routes': [
        {'distance': km * 1000, 'duration': (km / 50 * 3600).round()},
      ],
    });
    return http.StreamedResponse(Stream.value(utf8.encode(body)), 200, request: request);
  }
}

Destination _town(String name, double lat, double lng) => Destination(
      id: name.toLowerCase(),
      name: name,
      region: 'R',
      province: 'P',
      category: 'City',
      lat: lat,
      lng: lng,
      altitudeM: 1000,
      recommendedDays: 2,
      roadFactor: 1.4,
      requires4x4: false,
      difficulty: 'Easy',
      bestMonths: const [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12],
      tagline: '',
      description: '',
      highlights: const [],
      attractions: const [],
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // =========================================================================
  group('the guides themselves', () {
    test('every situation has one guide and every guide has content', () {
      expect(Survival.guides.length, Emergency.values.length);
      for (final kind in Emergency.values) {
        final guide = Survival.forKind(kind);
        expect(guide.steps, isNotEmpty, reason: '${kind.name} has no steps');
        expect(guide.never, isNotEmpty, reason: '${kind.name} warns about nothing');
        expect(guide.keywords, isNotEmpty, reason: '${kind.name} cannot be found');
        expect(guide.firstThing.length, greaterThan(40),
            reason: '${kind.name} has no real first action');
        expect(guide.callFor, isNotEmpty);
      }
    });

    test('every guide says when to hand over to rescue', () {
      // A survival guide that never tells you to call anyone is a guide that
      // encourages people to keep coping past the point they should.
      for (final guide in Survival.guides) {
        expect(
          RegExp(r'\b(1122|130|115|15|hospital)\b').hasMatch(guide.callFor),
          isTrue,
          reason: '${guide.kind.name} names no number to call',
        );
      }
    });

    test('the rescue numbers are the verified ones', () {
      final numbers = Survival.rescueNumbers.map((r) => r.number).toList();
      expect(numbers, containsAll(['1122', '130', '15', '115', '16']));
      // 1122 first: it is the one to reach for when you cannot think.
      expect(numbers.first, '1122');
    });
  });

  // =========================================================================
  group('finding the right guide', () {
    void expectMatch(String question, Emergency kind) {
      final hit = Survival.match(question);
      expect(hit?.kind, kind, reason: '"$question" gave ${hit?.kind.name}');
    }

    test('the situations people actually type', () {
      expectMatch('i have no matchstick how do i light a fire', Emergency.fire);
      expectMatch('my fuel ended', Emergency.fuel);
      expectMatch('out of petrol on the road', Emergency.fuel);
      expectMatch('car stuck in mud', Emergency.stuck);
      expectMatch('landslide blocked the road', Emergency.blocked);
      expectMatch('we are lost', Emergency.lost);
      expectMatch('no signal on my phone', Emergency.noSignal);
      expectMatch('freezing and shivering', Emergency.cold);
      expectMatch('heatstroke', Emergency.heat);
      expectMatch('altitude sickness', Emergency.altitude);
      expectMatch('no drinking water', Emergency.water);
      expectMatch('flash flood coming', Emergency.storm);
      expectMatch('snake bite', Emergency.bite);
      expectMatch('he is bleeding badly', Emergency.injury);
      expectMatch('it got dark and we are still out', Emergency.night);
    });

    test('misspellings still land somewhere useful', () {
      expect(Survival.match('matchstik')?.kind, Emergency.fire);
      expect(Survival.match('hypothermea')?.kind, Emergency.cold);
    });

    test('the typo pass does not guess at a whole sentence', () {
      // It once answered "a beach trip" with what to do in a landslide. Wrong
      // guidance in an emergency is worse than none, so the loose pass only
      // runs on a query short enough to be one mistyped word.
      expect(Survival.match('a beach trip'), isNull);
      expect(Survival.match('historical places in the south'), isNull);
      expect(Survival.match('a summer trip somewhere green'), isNull);
    });

    test('nothing matches an ordinary sentence', () {
      expect(Survival.match('where should I go for a weekend'), isNull);
      expect(Survival.match('hello'), isNull);
      expect(Survival.match(''), isNull);
    });
  });

  // =========================================================================
  group('the assistant telling the two apart', () {
    late List<Destination> places;
    late TripConfig defaults;

    setUpAll(() async {
      final repo = DestinationRepository();
      await repo.load();
      places = repo.all;
      defaults = TripConfig(
        originName: 'Islamabad',
        originLat: 33.6844,
        originLng: 73.0479,
        stops: [TripStop(destination: repo.byId('naran')!, nights: 2)],
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
        campKitchenCost: 3000,
        fuelPriceIsDefault: false,
        bufferPercent: 10,
        tollsAndParking: 1500,
      );
    });

    test('an emergency is read as one', () {
      for (final q in [
        'i have no matchstick, how do i light a fire',
        'the fuel ended what do i do',
        'my car is stuck in snow',
        'snake bite help',
      ]) {
        expect(TripAssistant.parse(q, places).intent, Intent.emergency,
            reason: '"$q" was not treated as an emergency');
      }
    });

    test('an ordinary question is never hijacked by a shared word', () {
      // Every one of these contains a word that appears in a survival guide.
      // Reading them as emergencies would make the assistant useless for
      // planning, which is what it is mostly for.
      const cases = {
        'how is fuel calculated': Intent.appHelp,
        'where do the petrol prices come from': Intent.appHelp,
        'somewhere with lakes': Intent.recommend,
        // Matched the landslide guide before the typo pass was tightened.
        'a beach trip': Intent.recommend,
        'snow and mountains': Intent.recommend,
        'how much for Hunza': Intent.costOnePlace,
        'cheapest places under 60k': Intent.recommend,
        'when should I go to Naran': Intent.whenToGo,
        'what should I pack for Skardu in December': Intent.packing,
        'how do I export a pdf': Intent.appHelp,
      };
      cases.forEach((question, expected) {
        expect(TripAssistant.parse(question, places).intent, expected,
            reason: '"$question" was misread');
      });
    });

    test('the answer carries the guide and leads with one action', () {
      final r = TripAssistant.answer(
        'no matchstick, how do i light a fire',
        places: places,
        defaults: defaults,
      );
      expect(r.guide, isNotNull);
      expect(r.guide!.kind, Emergency.fire);
      expect(r.text, contains(r.guide!.firstThing));
      // And it points somewhere else useful, because these arrive together.
      expect(r.followUps, isNotEmpty);
      expect(r.suggestions, isEmpty);
    });

    test('an emergency answer never suggests a holiday', () {
      final r = TripAssistant.answer(
        'we are lost and it is getting dark',
        places: places,
        defaults: defaults,
      );
      expect(r.suggestions, isEmpty);
      expect(r.guide, isNotNull);
    });
  });

  // =========================================================================
  group('finding the nearest pump', () {
    final me = const LatLng(34.9086, 73.6503);

    test('road distance reorders what the straight line got wrong', () async {
      // The nearest pin is across a river: 5 km as the crow flies, 42 by road.
      final net = _FakeNet(
        overpass: [
          ('Across the river', 34.94, 73.66),
          ('Down the valley', 34.83, 73.62),
        ],
        osrmKmByIndex: {0: 42.0, 1: 11.5},
      );
      final repo = EmergencyRepository(
        overpass: OverpassService(client: net),
        osrm: OsrmService(client: net),
      );

      final found = await repo.nearest(me, HelpKind.fuel);

      expect(found, hasLength(2));
      expect(found.first.name, 'Down the valley');
      expect(found.first.roadKm, closeTo(11.5, 0.01));
      expect(found.first.isRouted, isTrue);
      expect(found.last.roadKm, closeTo(42.0, 0.01));
    });

    test('a pump with no name is still shown', () async {
      // Rural pumps are often mapped without one. Hiding them because the label
      // is missing would drop the only pump within reach.
      final net = _FakeNet(
        overpass: [('', 34.92, 73.64)],
        osrmKmByIndex: {0: 3.0},
      );
      final repo = EmergencyRepository(
        overpass: OverpassService(client: net),
        osrm: OsrmService(client: net),
      );

      final found = await repo.nearest(me, HelpKind.fuel);
      expect(found, hasLength(1));
      expect(found.first.name, 'Petrol pump');
    });

    test('an unroutable one keeps its straight line rather than vanishing', () async {
      final net = _FakeNet(
        overpass: [('Reachable', 34.92, 73.64), ('No route', 35.20, 73.90)],
        osrmKmByIndex: {0: 4.0},
      );
      final repo = EmergencyRepository(
        overpass: OverpassService(client: net),
        osrm: OsrmService(client: net),
      );

      final found = await repo.nearest(me, HelpKind.fuel);
      expect(found, hasLength(2));
      final unrouted = found.firstWhere((f) => f.name == 'No route');
      expect(unrouted.isRouted, isFalse);
      expect(unrouted.straightKm, greaterThan(0));
    });

    test('with no signal it falls back to the towns it already knows', () async {
      final net = _FakeNet(overpass: null);
      final repo = EmergencyRepository(
        overpass: OverpassService(client: net),
        osrm: OsrmService(client: net),
      );

      final found = await repo.nearest(
        me,
        HelpKind.fuel,
        catalogue: [
          _town('Far away', 31.5, 74.3),
          _town('Balakot', 34.55, 73.35),
        ],
      );

      expect(found, isNotEmpty);
      expect(found.first.name, 'Balakot');
      expect(found.first.fromCatalogue, isTrue);
      // Honest about what it is: a town, not a confirmed pump.
      expect(found.first.kind.toLowerCase(), contains('town'));
      expect(found.first.isRouted, isFalse);
    });

    test('no signal and no catalogue returns nothing rather than a guess', () async {
      final repo = EmergencyRepository(
        overpass: OverpassService(client: _FakeNet(overpass: null)),
        osrm: OsrmService(client: _FakeNet(overpass: null)),
      );
      expect(await repo.nearest(me, HelpKind.fuel), isEmpty);
    });
  });
}
