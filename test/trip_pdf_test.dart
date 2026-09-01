import 'package:flutter_test/flutter_test.dart';
import 'package:trip_planner/core/enums.dart';
import 'package:trip_planner/data/models/attraction.dart';
import 'package:trip_planner/data/models/destination.dart';
import 'package:trip_planner/data/models/route_info.dart';
import 'package:trip_planner/data/models/meal_plan.dart';
import 'package:trip_planner/data/models/trip_config.dart';
import 'package:trip_planner/data/models/trip_stop.dart';
import 'package:trip_planner/domain/expense_calculator.dart';
import 'package:trip_planner/domain/itinerary_builder.dart';
import 'package:trip_planner/domain/packing_builder.dart';
import 'package:trip_planner/features/summary/trip_pdf.dart';

Destination _town(String id, String name, double lat, double lng) => Destination(
      id: id,
      name: name,
      region: 'Region',
      province: 'Khyber Pakhtunkhwa',
      category: 'Mountains',
      lat: lat,
      lng: lng,
      altitudeM: 2400,
      recommendedDays: 3,
      roadFactor: 1.7,
      requires4x4: true,
      difficulty: 'Moderate',
      bestMonths: const [5, 6, 7, 8, 9],
      tagline: 'A place',
      description: 'Somewhere worth going.',
      highlights: const [],
      attractions: const [],
    );

TripConfig _config({int stops = 1}) => TripConfig(
      originName: 'Islamabad',
      originLat: 33.6844,
      originLng: 73.0479,
      stops: [
        TripStop(
          destination: _town('naran', 'Naran', 34.9086, 73.6503),
          nights: 2,
          selectedAttractions: const [
            Attraction(
              id: 'lake',
              name: 'Lake Saif-ul-Malook',
              category: 'Lake',
              lat: 34.8776,
              lng: 73.6936,
              entryFee: 300,
              localTransport: 2500,
              visitHours: 4,
              requires4x4: true,
            ),
          ],
        ),
        if (stops > 1)
          TripStop(destination: _town('hunza', 'Hunza', 36.3167, 74.6667), nights: 2),
      ],
      startDate: DateTime(2026, 7, 1),
      days: stops > 1 ? 6 : 3,
      persons: 4,
      mode: TravelMode.ownVehicle,
      vehicleId: 'suv',
      mileage: 9,
      fuelPrice: 371.61,
      fuel: FuelKind.diesel,
      publicRatePerKm: 5,
      localTransportPerPersonDay: 800,
      roomOccupancy: 2,
      stayStyle: StayStyle.hotel,
      stayRatePerUnitNight: 11000,
      foodStyle: FoodStyle.restaurant,
      mealPlan: MealPlan.fromLegacy(
        dayCount: stops > 1 ? 6 : 3,
        mealsPerDay: 3,
        pricePerMeal: 1200,
      ),
      campKitchenCost: 0,
      fuelPriceIsDefault: false,
      bufferPercent: 10,
      tollsAndParking: 1500,
    );

const _leg = RouteInfo(distanceKm: 270, duration: Duration(hours: 7));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<List<int>> render({int stops = 1}) async {
    final config = _config(stops: stops);
    final legs = List.filled(config.stops.length + 1, _leg);
    final breakdown = ExpenseCalculator.compute(config: config, legs: legs);
    return TripPdf.build(
      config: config,
      breakdown: breakdown,
      itinerary: ItineraryBuilder.build(config: config, legs: legs),
      packing: PackingBuilder.build(config: config),
      generatedAt: DateTime(2026, 8, 31),
    );
  }

  group('the exported PDF', () {
    test('is a real document, not an empty shell', () async {
      final bytes = await render();

      // A PDF starts with %PDF- and ends with the EOF marker.
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
      expect(String.fromCharCodes(bytes.skip(bytes.length - 6)), contains('EOF'));

      // Fonts and a logo are embedded, so anything trivial is a bug.
      expect(bytes.length, greaterThan(40 * 1024),
          reason: 'a document with embedded fonts should not be tiny');
    });

    test('a multi-stop route renders too', () async {
      final one = await render();
      final two = await render(stops: 2);
      expect(String.fromCharCodes(two.take(5)), '%PDF-');
      expect(two.length, greaterThan(1000));
      // More stops means more rows, so more content.
      expect(two.length, isNot(one.length));
    });

    test('the filename says where and when, and is safe on any filesystem', () {
      final name = TripPdf.fileName(_config());
      expect(name, 'Triplyst-Naran-2026-07-01.pdf');
      expect(RegExp(r'^[A-Za-z0-9._-]+$').hasMatch(name), isTrue);
    });

    test('a name with punctuation still yields a clean filename', () {
      final config = _config().copyWith(
        stops: [
          TripStop(
            destination: _town('h', 'Hunza (Karimabad)', 36.3, 74.6),
            nights: 1,
          ),
        ],
      );
      final name = TripPdf.fileName(config);
      expect(RegExp(r'^[A-Za-z0-9._-]+$').hasMatch(name), isTrue,
          reason: 'brackets and spaces must not reach the filesystem: $name');
      expect(name, contains('Hunza-Karimabad'));
    });
  });
}
