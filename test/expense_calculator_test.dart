import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:trip_planner/core/constants.dart';
import 'package:trip_planner/core/enums.dart';
import 'package:trip_planner/domain/expense_calculator.dart';
import 'package:trip_planner/domain/itinerary_builder.dart';
import 'package:trip_planner/data/models/attraction.dart';
import 'package:trip_planner/data/models/destination.dart';
import 'package:trip_planner/data/models/route_info.dart';
import 'package:trip_planner/data/models/trip_config.dart';

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
  double pricePerMeal = 1200,
  int mealsPerDay = 3,
  double campKitchen = 0,
  StayStyle stayStyle = StayStyle.hotel,
  FoodStyle foodStyle = FoodStyle.restaurant,
  bool fuelPriceIsDefault = false,
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
      stayStyle: stayStyle,
      stayRatePerUnitNight: stayRate,
      foodStyle: foodStyle,
      pricePerMeal: pricePerMeal,
      mealsPerDay: mealsPerDay,
      campKitchenCost: campKitchen,
      fuelPriceIsDefault: fuelPriceIsDefault,
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

      // 3 days x 4 people x 3 meals = 36 meals, at Rs 1,200 each.
      expect(b.mealCount, 36);
      expect(b.mealCost, closeTo(43200, 0.01));
      expect(b.kitchenCost, 0); // not self-cooking

      expect(b.tollsCost, closeTo(1500, 0.01));
      expect(b.subtotal, closeTo(86700, 0.01));
      expect(b.bufferCost, closeTo(8670, 0.01)); // 10%
      expect(b.total, closeTo(95370, 0.01));
      expect(b.perPerson, closeTo(23842.5, 0.01));
      expect(b.perDay, closeTo(31790, 0.01));
      expect(b.perPersonPerDay, closeTo(7947.5, 0.01));
    });

    test('cost per kilometre follows from average and pump price', () {
      final b = ExpenseCalculator.compute(
        config: _config(mileage: 10, fuelPrice: 300),
        outbound: _route100km,
      );
      // Rs 300 a litre over 10 km per litre is Rs 30 a kilometre.
      expect(b.costPerKm, closeTo(30, 0.001));
    });

    test('a thirstier vehicle costs proportionally more fuel', () {
      final thirsty = ExpenseCalculator.compute(
        config: _config(mileage: 5, fuelPrice: 300),
        outbound: _route100km,
      );
      final frugal = ExpenseCalculator.compute(
        config: _config(mileage: 20, fuelPrice: 300),
        outbound: _route100km,
      );
      expect(thirsty.litres, closeTo(frugal.litres * 4, 0.001));
      expect(thirsty.travelCost, closeTo(frugal.travelCost * 4, 0.01));
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

  group('Food', () {
    test('meals a day scales the bill proportionally', () {
      final two = ExpenseCalculator.compute(
        config: _config(mealsPerDay: 2),
        outbound: _route100km,
      );
      final four = ExpenseCalculator.compute(
        config: _config(mealsPerDay: 4),
        outbound: _route100km,
      );
      expect(two.mealCount, 3 * 4 * 2);
      expect(four.mealCount, 3 * 4 * 4);
      expect(four.mealsCost, closeTo(two.mealsCost * 2, 0.01));
    });

    test('self-cooking charges groceries per meal plus a one-off kitchen', () {
      final b = ExpenseCalculator.compute(
        config: _config(
          foodStyle: FoodStyle.selfCooking,
          pricePerMeal: 350,
          campKitchen: 3000,
        ),
        outbound: _route100km,
      );
      expect(b.mealsCost, closeTo(36 * 350, 0.01));
      expect(b.kitchenCost, closeTo(3000, 0.01));
      expect(b.mealCost, closeTo(36 * 350 + 3000, 0.01));
    });

    test('the kitchen cost is ignored when not cooking', () {
      final b = ExpenseCalculator.compute(
        // A stale kitchen figure left over from switching styles must not bill.
        config: _config(foodStyle: FoodStyle.restaurant, campKitchen: 3000),
        outbound: _route100km,
      );
      expect(b.kitchenCost, 0);
      expect(b.mealCost, closeTo(b.mealsCost, 0.01));
    });

    test('cooking is cheaper than eating out for the same trip', () {
      final cooking = ExpenseCalculator.compute(
        config: _config(
          foodStyle: FoodStyle.selfCooking,
          pricePerMeal: FoodStyle.selfCooking.defaultPricePerMeal,
          campKitchen: 3000,
        ),
        outbound: _route100km,
      );
      final dining = ExpenseCalculator.compute(
        config: _config(
          foodStyle: FoodStyle.hotelDining,
          pricePerMeal: FoodStyle.hotelDining.defaultPricePerMeal,
        ),
        outbound: _route100km,
      );
      expect(cooking.mealCost, lessThan(dining.mealCost));
    });
  });

  group('Sleeping', () {
    test('an own tent costs nothing per night', () {
      final b = ExpenseCalculator.compute(
        config: _config(stayStyle: StayStyle.ownTent, stayRate: 0),
        outbound: _route100km,
      );
      expect(b.stayCost, 0);
      expect(b.unitLabel, 'tent');
    });

    test('a rented tent is charged per tent per night', () {
      final b = ExpenseCalculator.compute(
        config: _config(
          stayStyle: StayStyle.rentedTent,
          stayRate: 2500,
          persons: 6,
          occupancy: 3,
        ),
        outbound: _route100km,
      );
      expect(b.rooms, 2); // 6 people, 3 to a tent
      expect(b.stayCost, closeTo(2 * 2 * 2500, 0.01)); // 2 nights x 2 tents
      expect(b.unitLabel, 'tent');
    });

    test('camping high up raises an advisory', () {
      final b = ExpenseCalculator.compute(
        config: _config(
          stayStyle: StayStyle.ownTent,
          stayRate: 0,
          destination: _destination(altitude: 3300),
        ),
        outbound: _route100km,
      );
      expect(b.warnings.any((w) => w.title.contains('Camping at')), isTrue);
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

    test('asks the user to confirm a stale bundled fuel price', () {
      final b = ExpenseCalculator.compute(
        config: _config(fuelPriceIsDefault: true),
        outbound: _route100km,
      );
      final stale = DateTime.now().difference(AppDefaults.fuelPriceAsOf).inDays >
          AppDefaults.fuelPriceStaleAfterDays;
      expect(
        b.warnings.any((w) => w.title.contains('Confirm the fuel price')),
        stale,
        reason: 'the advisory should appear exactly when the bundled rate has aged out',
      );
    });

    test('says nothing about fuel once the price has been typed in', () {
      final b = ExpenseCalculator.compute(
        config: _config(fuelPriceIsDefault: false),
        outbound: _route100km,
      );
      expect(b.warnings.any((w) => w.title.contains('Confirm the fuel price')), isFalse);
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
      expect(copy.stayStyle, original.stayStyle);
      expect(copy.foodStyle, original.foodStyle);
      expect(copy.mealsPerDay, original.mealsPerDay);
      expect(copy.pricePerMeal, original.pricePerMeal);
      expect(copy.selectedAttractions.length, 1);
      expect(copy.selectedAttractions.first.entryFee, 500);
      expect(copy.destination.id, original.destination.id);
      expect(copy.origin, const LatLng(33.6844, 73.0479));
    });

    test('a trip saved under the old stay/meal tiers still opens', () {
      // Exactly what the previous schema wrote, with no tents and a per-day
      // food figure rather than a per-meal one.
      final legacy = {
        'originName': 'Lahore',
        'originLat': 31.5497,
        'originLng': 74.3436,
        'destination': _destination().toJson(),
        'startDate': DateTime(2026, 7, 1).toIso8601String(),
        'days': 3,
        'persons': 4,
        'mode': 'ownVehicle',
        'vehicleId': 'sedan',
        'mileage': 12.0,
        'fuelPrice': 272.0,
        'fuel': 'petrol',
        'publicRatePerKm': 5.0,
        'localTransportPerPersonDay': 800.0,
        'roomOccupancy': 2,
        'stayTier': 'budget',
        'stayRatePerRoomNight': 4000.0,
        'mealTier': 'basic',
        'mealRatePerPersonDay': 1500.0,
        'selectedAttractions': <dynamic>[],
        'bufferPercent': 10.0,
        'tollsAndParking': 1500.0,
      };

      final config = TripConfig.fromJson(legacy);

      expect(config.stayStyle, StayStyle.guestHouse);
      expect(config.stayRatePerUnitNight, 4000.0);
      expect(config.foodStyle, FoodStyle.dhaba);
      expect(config.mealsPerDay, 3);
      // The old daily figure divided by three meals reproduces the same total.
      expect(config.pricePerMeal, closeTo(500, 0.001));
      expect(config.days * config.persons * config.mealsPerDay * config.pricePerMeal,
          closeTo(3 * 4 * 1500, 0.01));
      expect(config.campKitchenCost, 0);

      // And it still costs out without throwing.
      final b = ExpenseCalculator.compute(config: config, outbound: _route100km);
      expect(b.total, greaterThan(0));
    });
  });
}
