import 'package:flutter_test/flutter_test.dart';
import 'package:trip_planner/core/enums.dart';
import 'package:trip_planner/domain/budget_advisor.dart';
import 'package:trip_planner/domain/expense_calculator.dart';
import 'package:trip_planner/domain/packing_builder.dart';
import 'package:trip_planner/data/models/attraction.dart';
import 'package:trip_planner/data/models/destination.dart';
import 'package:trip_planner/data/models/route_info.dart';
import 'package:trip_planner/data/models/trip_config.dart';
import 'package:trip_planner/data/models/trip_stop.dart';
import 'package:trip_planner/data/models/weather.dart';

Destination _destination({
  int altitude = 2400,
  bool requires4x4 = false,
  String province = 'Khyber Pakhtunkhwa',
  List<Attraction> attractions = const [],
}) =>
    Destination(
      id: 'test',
      name: 'Testville',
      region: 'Test Valley',
      province: province,
      category: 'Mountains',
      lat: 34.9086,
      lng: 73.6503,
      altitudeM: altitude,
      recommendedDays: 3,
      roadFactor: 1.75,
      requires4x4: requires4x4,
      difficulty: 'Moderate',
      bestMonths: const [5, 6, 7, 8, 9],
      tagline: '',
      description: '',
      highlights: const [],
      attractions: attractions,
    );

TripConfig _config({
  int days = 4,
  int persons = 4,
  StayStyle stay = StayStyle.resort,
  FoodStyle food = FoodStyle.hotelDining,
  int mealsPerDay = 3,
  TravelMode mode = TravelMode.ownVehicle,
  double buffer = 15,
  List<Attraction> stops = const [],
  Destination? destination,
  DateTime? start,
}) =>
    TripConfig(
      originName: 'Origin',
      originLat: 33.6844,
      originLng: 73.0479,
      stops: [
        TripStop(
          destination: destination ?? _destination(),
          nights: days > 1 ? days - 1 : 0,
          selectedAttractions: stops,
        ),
      ],
      startDate: start ?? DateTime(2026, 7, 1),
      days: days,
      persons: persons,
      mode: mode,
      vehicleId: 'suv',
      mileage: 9,
      fuelPrice: 371.61,
      fuel: FuelKind.diesel,
      publicRatePerKm: 5,
      localTransportPerPersonDay: 800,
      roomOccupancy: stay.defaultOccupancy,
      stayStyle: stay,
      stayRatePerUnitNight: stay.defaultRatePerUnitNight,
      foodStyle: food,
      pricePerMeal: food.defaultPricePerMeal,
      mealsPerDay: mealsPerDay,
      campKitchenCost: 3000,
      fuelPriceIsDefault: false,
      bufferPercent: buffer,
      tollsAndParking: 1500,
    );

const _route = RouteInfo(distanceKm: 260, duration: Duration(hours: 7));

/// Out and back for a single-destination trip. The calculator wants one leg
/// more than there are stops, so a one-stop trip is two legs.
const _legs2 = [_route, _route];

double _totalOf(TripConfig c) =>
    ExpenseCalculator.compute(config: c, legs: _legs2).total;

void main() {
  group('BudgetAdvisor', () {
    test('a generous budget fits and offers no changes to make', () {
      final config = _config();
      final advice = BudgetAdvisor.advise(
        config: config,
        legs: _legs2,
        attractionRoutes: const {},
        budget: _totalOf(config) * 2,
      );

      expect(advice.fits, isTrue);
      expect(advice.gap, 0);
      expect(advice.headroom, greaterThan(0));
      expect(advice.minimalSet, isEmpty);
      expect(advice.ratio, lessThan(1));
    });

    test('a tight budget reports the gap and offers levers', () {
      final config = _config();
      final advice = BudgetAdvisor.advise(
        config: config,
        legs: _legs2,
        attractionRoutes: const {},
        budget: _totalOf(config) * 0.6,
      );

      expect(advice.fits, isFalse);
      expect(advice.gap, greaterThan(0));
      expect(advice.levers, isNotEmpty);
    });

    test('every lever saves what it claims, measured by re-costing', () {
      final config = _config();
      final baseline = _totalOf(config);
      final advice = BudgetAdvisor.advise(
        config: config,
        legs: _legs2,
        attractionRoutes: const {},
        budget: baseline * 0.5,
      );

      for (final lever in advice.levers) {
        final after = _totalOf(lever.apply(config));
        expect(
          baseline - after,
          closeTo(lever.saving, 0.01),
          reason: 'lever "${lever.title}" does not save what it advertises',
        );
        expect(after, lessThan(baseline), reason: '"${lever.title}" made it dearer');
      }
    });

    test('levers are ordered by how much they save', () {
      final config = _config();
      final advice = BudgetAdvisor.advise(
        config: config,
        legs: _legs2,
        attractionRoutes: const {},
        budget: _totalOf(config) * 0.5,
      );

      for (var i = 1; i < advice.levers.length; i++) {
        expect(advice.levers[i - 1].saving,
            greaterThanOrEqualTo(advice.levers[i].saving));
      }
    });

    test('nothing is offered that would not move the total', () {
      // Already the cheapest of everything: no downgrade exists.
      final config = _config(
        stay: StayStyle.ownTent,
        food: FoodStyle.selfCooking,
        mealsPerDay: 1,
        days: 1,
        buffer: 10,
        mode: TravelMode.publicTransport,
      );
      final advice = BudgetAdvisor.advise(
        config: config,
        legs: _legs2,
        attractionRoutes: const {},
        budget: 1,
      );

      expect(advice.fits, isFalse);
      expect(advice.reachable, isFalse,
          reason: 'an impossible budget must not be reported as reachable');
      for (final lever in advice.levers) {
        expect(lever.saving, greaterThan(0));
      }
    });

    test('applying a lever produces a config that really is cheaper', () {
      final config = _config();
      final advice = BudgetAdvisor.advise(
        config: config,
        legs: _legs2,
        attractionRoutes: const {},
        budget: _totalOf(config) * 0.7,
      );

      final best = advice.levers.first;
      final applied = best.apply(config);
      expect(_totalOf(applied), lessThan(_totalOf(config)));
    });

    test('the minimal set is enough to close the gap on paper', () {
      final config = _config();
      final advice = BudgetAdvisor.advise(
        config: config,
        legs: _legs2,
        attractionRoutes: const {},
        budget: _totalOf(config) * 0.75,
      );

      if (advice.reachable) {
        final saved = advice.minimalSet.fold<double>(0, (s, l) => s + l.saving);
        expect(saved, greaterThanOrEqualTo(advice.gap));
      }
    });

    test('a zero budget is treated as no budget rather than an impossible one', () {
      final advice = BudgetAdvisor.advise(
        config: _config(),
        legs: _legs2,
        attractionRoutes: const {},
        budget: 0,
      );
      expect(advice.ratio, 0);
    });
  });

  group('PackingBuilder', () {
    test('camping brings a tent and a bag, hotels do not', () {
      final camping = PackingBuilder.build(
        config: _config(stay: StayStyle.ownTent),
      );
      final hotel = PackingBuilder.build(config: _config(stay: StayStyle.hotel));

      String all(List<PackSection> s) =>
          s.expand((x) => x.items).map((i) => i.label).join(' | ');

      expect(all(camping), contains('Tent'));
      expect(all(camping), contains('Sleeping bag'));
      expect(all(hotel), isNot(contains('Sleeping bag')));
    });

    test('self-cooking brings a stove, eating out does not', () {
      final cooking = PackingBuilder.build(config: _config(food: FoodStyle.selfCooking));
      final dining = PackingBuilder.build(config: _config(food: FoodStyle.restaurant));

      bool has(List<PackSection> s, String id) =>
          s.expand((x) => x.items).any((i) => i.id == id);

      expect(has(cooking, 'stove'), isTrue);
      expect(has(dining, 'stove'), isFalse);
    });

    test('altitude adds an explicit warning, and says the altitude', () {
      final high = PackingBuilder.build(
        config: _config(destination: _destination(altitude: 3300)),
      );
      final item = high
          .expand((s) => s.items)
          .firstWhere((i) => i.id == 'altitude', orElse: () => throw StateError('missing'));

      expect(item.critical, isTrue);
      expect(item.reason, contains('3300'));
    });

    test('a 4x4 stop adds a tow rope', () {
      const jeepStop = Attraction(
        id: 'jeep',
        name: 'High meadow',
        category: 'Meadow',
        lat: 34.83,
        lng: 73.67,
        requires4x4: true,
        visitHours: 5,
      );
      final list = PackingBuilder.build(config: _config(stops: [jeepStop]));
      expect(list.expand((s) => s.items).any((i) => i.id == 'tow-rope'), isTrue);
    });

    test('public transport drops the whole vehicle section', () {
      final list = PackingBuilder.build(config: _config(mode: TravelMode.publicTransport));
      expect(list.any((s) => s.title == 'Vehicle'), isFalse);
    });

    test('AJK and GB trips ask for ID photocopies', () {
      final gb = PackingBuilder.build(
        config: _config(destination: _destination(province: 'Gilgit-Baltistan')),
      );
      expect(gb.expand((s) => s.items).any((i) => i.id == 'permit-copies'), isTrue);

      final punjab = PackingBuilder.build(
        config: _config(destination: _destination(province: 'Punjab')),
      );
      expect(punjab.expand((s) => s.items).any((i) => i.id == 'permit-copies'), isFalse);
    });

    test('item ids are unique, since ticks are keyed on them', () {
      final list = PackingBuilder.build(
        config: _config(stay: StayStyle.ownTent, food: FoodStyle.selfCooking),
      );
      final ids = list.expand((s) => s.items).map((i) => i.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('every item explains why this trip needs it', () {
      final list = PackingBuilder.build(config: _config());
      for (final item in list.expand((s) => s.items)) {
        expect(item.reason.trim(), isNotEmpty, reason: '${item.id} has no reason');
      }
    });

    test('real climate overrides the altitude guess', () {
      // A warm month at altitude: without climate the lapse-rate guess would
      // call it freezing and pack a heavy jacket.
      final warm = PlaceWeather(climate: [
        for (var m = 1; m <= 12; m++)
          MonthClimate(month: m, avgMaxC: 28, avgMinC: 16, precipMm: 10, snowCm: 0),
      ]);

      final list = PackingBuilder.build(
        config: _config(destination: _destination(altitude: 3200), start: DateTime(2026, 1, 5)),
        weather: warm,
      );
      expect(list.expand((s) => s.items).any((i) => i.id == 'warm-jacket'), isFalse);

      final cold = PlaceWeather(climate: [
        for (var m = 1; m <= 12; m++)
          MonthClimate(month: m, avgMaxC: 4, avgMinC: -9, precipMm: 60, snowCm: 30),
      ]);
      final coldList = PackingBuilder.build(
        config: _config(destination: _destination(altitude: 3200), start: DateTime(2026, 1, 5)),
        weather: cold,
      );
      expect(coldList.expand((s) => s.items).any((i) => i.id == 'warm-jacket'), isTrue);
      expect(coldList.expand((s) => s.items).any((i) => i.id == 'chains'), isTrue);
    });
  });

  group('Weather model', () {
    MonthClimate m(int month, double max, double min, double rain, [double snow = 0]) =>
        MonthClimate(month: month, avgMaxC: max, avgMinC: min, precipMm: rain, snowCm: snow);

    test('a mild dry month scores above a frozen one', () {
      expect(m(6, 24, 12, 20).score, greaterThan(m(1, -2, -14, 40, 60).score));
    });

    test('a mild dry month scores above a monsoon month', () {
      expect(m(5, 24, 12, 15).score, greaterThan(m(7, 26, 16, 320).score));
    });

    test('snowbound months are flagged', () {
      expect(m(1, 0, -12, 30, 40).likelySnowbound, isTrue);
      expect(m(7, 26, 14, 30).likelySnowbound, isFalse);
    });

    test('best months are the genuinely good ones, not always three', () {
      final weather = PlaceWeather(climate: [
        for (var i = 1; i <= 12; i++)
          if (i >= 6 && i <= 8) m(i, 23, 12, 20) else m(i, -5, -18, 40, 50),
      ]);
      final best = weather.bestMonths.map((x) => x.month).toSet();
      expect(best, {6, 7, 8});
    });

    test('WMO codes map to the right sky', () {
      expect(Sky.fromWmo(0), Sky.clear);
      expect(Sky.fromWmo(3), Sky.cloudy);
      expect(Sky.fromWmo(65), Sky.rain);
      expect(Sky.fromWmo(75), Sky.snow);
      expect(Sky.fromWmo(95), Sky.storm);
      expect(Sky.fromWmo(null), Sky.cloudy);
    });

    test('an empty weather object answers safely rather than throwing', () {
      const empty = PlaceWeather();
      expect(empty.hasForecast, isFalse);
      expect(empty.hasClimate, isFalse);
      expect(empty.bestMonths, isEmpty);
      expect(empty.forMonth(5), isNull);
      expect(empty.between(DateTime(2026, 7, 1), DateTime(2026, 7, 5)), isEmpty);
    });
  });
}
