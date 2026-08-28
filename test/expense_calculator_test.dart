import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:trip_planner/core/enums.dart';
import 'package:trip_planner/logic/expense_calculator.dart';
import 'package:trip_planner/logic/itinerary_builder.dart';
import 'package:trip_planner/models/attraction.dart';
import 'package:trip_planner/models/destination.dart';
import 'package:trip_planner/models/route_info.dart';
import 'package:trip_planner/models/trip_config.dart';

/// A stand-in base town roughly where Naran is, so the terrain road factor is
/// realistic when a leg has to fall back to straight-line distance.
Destination _destination({
  int recommendedDays = 3,
  bool requires4x4 = false,
  int altitude = 2400,
  List<Attraction> attractions = const [],
  List<int> bestMonths = const [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12],
}) =>
    Destination(
      id: 'test',
      name: 'Testville',
      region: 'Test Valley',
      province: 'Test',
      category: 'Mountains',
      lat: 34.9086,
      lng: 73.6503,
      altitudeM: altitude,
      recommendedDays: recommendedDays,
      roadFactor: 1.75,
      requires4x4: requires4x4,
      difficulty: 'Moderate',
      bestMonths: bestMonths,
      tagline: '',
      description: '',
      highlights: const [],
      attractions: attractions,
    );

TripConfig _config({
  int days = 3,
  int persons = 4,
  TravelMode mode = TravelMode.ownVehicle,
  double mileage = 10,
  double fuelPrice = 300,
  double stayRate = 9000,
  double mealRate = 2800,
  int occupancy = 2,
  double buffer = 10,
  double tolls = 1500,
  String vehicleId = 'sedan',
  List<Attraction> stops = const [],
  Destination? destination,
  DateTime? start,
}) =>
    TripConfig(
      originName: 'Origin',
      originLat: 33.6844,
      originLng: 73.0479,
      destination: destination ?? _destination(),
      startDate: start ?? DateTime(2026, 7, 1),
      days: days,
      persons: persons,
      mode: mode,
      vehicleId: vehicleId,
      mileage: mileage,
      fuelPrice: fuelPrice,
      fuel: FuelKind.petrol,
      publicRatePerKm: 5,
      localTransportPerPersonDay: 800,
      roomOccupancy: occupancy,
      stayTier: StayTier.standard,
      stayRatePerRoomNight: stayRate,
      mealTier: MealTier.standard,
      mealRatePerPersonDay: mealRate,
      selectedAttractions: stops,
      bufferPercent: buffer,
      tollsAndParking: tolls,
    );

const _route100km = RouteInfo(distanceKm: 100, duration: Duration(hours: 3));

void main() {
  group('ExpenseCalculator, own vehicle', () {
    test('adds up fuel, rooms, food, tolls and buffer', () {
      final b = ExpenseCalculator.compute(config: _config(), outbound: _route100km);

      // 100 km out, 100 km back.
      expect(b.totalKm, 200);
      expect(b.litres, closeTo(20, 0.001)); // 200 km / 10 km per litre
      expect(b.travelCost, closeTo(6000, 0.01)); // 20 L x Rs 300

      // 3 days is 2 nights; 4 people at 2 per room is 2 rooms.
      expect(b.nights, 2);
      expect(b.rooms, 2);
      expect(b.stayCost, closeTo(36000, 0.01));

      expect(b.mealCost, closeTo(33600, 0.01)); // 3 days x 4 people x Rs 2,800
      expect(b.tollsCost, closeTo(1500, 0.01));
      expect(b.subtotal, closeTo(77100, 0.01));
      expect(b.bufferCost, closeTo(7710, 0.01)); // 10%
      expect(b.total, closeTo(84810, 0.01));
      expect(b.perPerson, closeTo(21202.5, 0.01));
      expect(b.perDay, closeTo(28270, 0.01));
      expect(b.perPersonPerDay, closeTo(7067.5, 0.01));
    });

    test('odd group sizes round rooms up', () {
      final b = ExpenseCalculator.compute(
        config: _config(persons: 5, occupancy: 2),
        outbound: _route100km,
      );
      expect(b.rooms, 3);
      expect(b.stayCost, closeTo(2 * 3 * 9000, 0.01));
    });

    test('a single day books no rooms', () {
      final b = ExpenseCalculator.compute(config: _config(days: 1), outbound: _route100km);
      expect(b.nights, 0);
      expect(b.stayCost, 0);
    });

    test('the lines always sum to the total', () {
      final b = ExpenseCalculator.compute(config: _config(), outbound: _route100km);
      final sum = b.lines.fold<double>(0, (acc, l) => acc + l.amount);
      expect(sum, closeTo(b.total, 0.01));
    });
  });

  group('ExpenseCalculator, stops', () {
    final stop = Attraction(
      id: 'stop',
      name: 'Lake',
      category: 'Lake',
      lat: 34.8776,
      lng: 73.6936,
      entryFee: 300,
      localTransport: 2500,
      visitHours: 4,
    );

    test('a stop is charged as a return day trip and its fees scale per person', () {
      final b = ExpenseCalculator.compute(
        config: _config(stops: [stop]),
        outbound: _route100km,
        attractionRoutes: const {
          'stop': RouteInfo(distanceKm: 12, duration: Duration(minutes: 40)),
        },
      );

      expect(b.attractionsKm, closeTo(24, 0.001)); // 12 km each way
      expect(b.totalKm, closeTo(224, 0.001));
      expect(b.entryCost, closeTo(300 * 4, 0.01));
      expect(b.localTransportCost, closeTo(2500 * 4, 0.01));
      expect(b.sightseeingHours, 4);
    });

    test('an unrouted stop still contributes distance and flags the estimate', () {
      final b = ExpenseCalculator.compute(
        config: _config(stops: [stop]),
        outbound: _route100km,
      );
      expect(b.attractionsKm, greaterThan(0));
      expect(b.routeEstimated, isTrue);
    });
  });

  group('ExpenseCalculator, public transport', () {
    test('fares scale with head count and no fuel or tolls are charged', () {
      final b = ExpenseCalculator.compute(
        config: _config(mode: TravelMode.publicTransport),
        outbound: _route100km,
      );

      expect(b.litres, 0);
      expect(b.tollsCost, 0);
      expect(b.travelCost, closeTo(200 * 5 * 4, 0.01)); // km x rate x people
      expect(b.localTransportCost, closeTo(800 * 3 * 4, 0.01)); // daily allowance
    });
  });

  group('Warnings', () {
    test('flags a group larger than the vehicle', () {
      final b = ExpenseCalculator.compute(
        config: _config(persons: 6, vehicleId: 'hatchback'),
        outbound: _route100km,
      );
      expect(
        b.warnings.any((w) => w.title.contains('More people than seats')),
        isTrue,
      );
    });

    test('flags a trip that is too short for the plan', () {
      final stop = const Attraction(
        id: 'a',
        name: 'Long day',
        category: 'Trek',
        lat: 34.83,
        lng: 73.67,
        visitHours: 10,
      );
      final b = ExpenseCalculator.compute(
        config: _config(days: 2, stops: [stop]),
        outbound: _route100km,
      );
      expect(b.warnings.any((w) => w.title.contains('Too tight')), isTrue);
    });

    test('flags an out-of-season departure', () {
      final b = ExpenseCalculator.compute(
        config: _config(
          destination: _destination(bestMonths: const [6, 7, 8]),
          start: DateTime(2026, 1, 10),
        ),
        outbound: _route100km,
      );
      expect(b.warnings.any((w) => w.title.contains('out of season')), isTrue);
    });

    test('stays quiet when the plan is sound', () {
      final b = ExpenseCalculator.compute(
        config: _config(days: 4, persons: 2, vehicleId: 'suv', destination: _destination(altitude: 1500)),
        outbound: _route100km,
      );
      expect(b.warnings.where((w) => w.title.contains('More people')), isEmpty);
      expect(b.warnings.where((w) => w.title.contains('Too tight')), isEmpty);
    });
  });

  group('ItineraryBuilder', () {
    test('produces exactly one entry per day', () {
      for (final days in [1, 2, 3, 5, 8]) {
        final plan = ItineraryBuilder.build(
          config: _config(days: days),
          outbound: _route100km,
        );
        expect(plan.length, days, reason: 'for a $days day trip');
      }
    });

    test('first day travels out and last day travels back', () {
      final plan = ItineraryBuilder.build(config: _config(days: 4), outbound: _route100km);
      expect(plan.first.title, contains('Travel to'));
      expect(plan.last.title, contains('Return to'));
    });

    test('every selected stop lands on some day', () {
      final stops = [
        const Attraction(id: 'a', name: 'Alpha', category: 'Lake', lat: 34.87, lng: 73.69, visitHours: 4),
        const Attraction(id: 'b', name: 'Beta', category: 'Pass', lat: 35.14, lng: 74.01, visitHours: 3),
        const Attraction(id: 'c', name: 'Gamma', category: 'Meadow', lat: 34.65, lng: 73.45, visitHours: 4),
      ];
      final plan = ItineraryBuilder.build(
        config: _config(days: 5, stops: stops),
        outbound: _route100km,
      );
      final titles = plan.expand((d) => d.items).map((i) => i.title).toSet();
      for (final s in stops) {
        expect(titles, contains(s.name));
      }
    });

    test('splits the drive when one way is over nine hours', () {
      final plan = ItineraryBuilder.build(
        config: _config(days: 5),
        outbound: const RouteInfo(distanceKm: 700, duration: Duration(hours: 14)),
      );
      expect(plan.first.title, contains('Drive out'));
      expect(plan.any((d) => d.items.any((i) => i.title.contains('Overnight stop'))), isTrue);
    });
  });

  group('Serialisation', () {
    test('a config survives a JSON round trip', () {
      final original = _config(
        stops: [
          const Attraction(
            id: 'a',
            name: 'Alpha',
            category: 'Lake',
            lat: 1,
            lng: 2,
            entryFee: 500,
            localTransport: 1000,
          ),
        ],
      );
      final copy = TripConfig.fromJson(original.toJson());

      expect(copy.days, original.days);
      expect(copy.persons, original.persons);
      expect(copy.mode, original.mode);
      expect(copy.fuel, original.fuel);
      expect(copy.stayTier, original.stayTier);
      expect(copy.mealTier, original.mealTier);
      expect(copy.selectedAttractions.length, 1);
      expect(copy.selectedAttractions.first.entryFee, 500);
      expect(copy.destination.id, original.destination.id);
      expect(copy.origin, const LatLng(33.6844, 73.0479));
    });
  });
}
