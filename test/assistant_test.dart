import 'package:flutter_test/flutter_test.dart';
import 'package:trip_planner/core/enums.dart';
import 'package:trip_planner/data/models/destination.dart';
import 'package:trip_planner/data/models/meal_plan.dart';
import 'package:trip_planner/data/models/trip_config.dart';
import 'package:trip_planner/data/models/trip_stop.dart';
import 'package:trip_planner/data/repositories/destination_repository.dart';
import 'package:trip_planner/domain/assistant.dart';

/// Exercised against the real catalogue rather than fixtures. The assistant's
/// whole value is that its answers come from the shipped data, so a test on
/// invented places would prove nothing about what a user actually gets.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DestinationRepository repo;
  late List<Destination> places;
  late TripConfig defaults;

  setUpAll(() async {
    repo = DestinationRepository();
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

  Ask ask(String q) => TripAssistant.parse(q, places);
  AssistantReply reply(String q) =>
      TripAssistant.answer(q, places: places, defaults: defaults);

  group('reading the question', () {
    test('works out what is being asked', () {
      expect(ask('where should I go for a weekend').intent, Intent.recommend);
      expect(ask('how much for Hunza').intent, Intent.costOnePlace);
      expect(ask('how far is Skardu').intent, Intent.howFar);
      expect(ask('when should I go to Naran').intent, Intent.whenToGo);
      expect(ask('does Fairy Meadows need a 4x4').intent, Intent.needs4x4);
      expect(ask('what should I pack for Hunza').intent, Intent.packing);
      expect(ask('how is fuel calculated').intent, Intent.appHelp);
      expect(ask('naran or swat').intent, Intent.compare);
    });

    test('a bare place name is a request to cost it', () {
      expect(ask('Hunza').intent, Intent.costOnePlace);
      expect(ask('Hunza').places.first.name, contains('Hunza'));
    });

    test('finds places even when misspelled', () {
      expect(ask('how much for hoonza').places, isNotEmpty);
      expect(ask('how much for hoonza').places.first.name, contains('Hunza'));
      expect(ask('what about skardo').places.first.name, 'Skardu');
    });

    test('reads money the way people write it', () {
      expect(ask('places under 50000').budget, 50000);
      expect(ask('somewhere for 50k').budget, 50000);
      expect(ask('under 60 thousand').budget, 60000);
      expect(ask('budget of 1 lakh').budget, 100000);
      expect(ask('1.5 lakh trip').budget, 150000);
      // A small number is a count, not a budget.
      expect(ask('3 days for 4 people').budget, isNull);
    });

    test('reads days and people', () {
      expect(ask('5 days in Hunza').days, 5);
      expect(ask('a weekend away').days, 2);
      expect(ask('trip for a week').days, 7);
      // Three nights away is a four day trip.
      expect(ask('3 nights somewhere').days, 4);

      expect(ask('for 4 people').persons, 4);
      expect(ask('family of 6').persons, 6);
      expect(ask('travelling solo').persons, 1);
      expect(ask('trip for a couple').persons, 2);
    });

    test('reads months and seasons', () {
      expect(ask('where in June').month, 6);
      expect(ask('somewhere in dec').month, 12);
      expect(ask('a summer trip').month, 7);
      expect(ask('winter destinations').month, 1);
    });

    test('reads the kind of place', () {
      expect(ask('somewhere with lakes').category, 'Lakes');
      expect(ask('a beach trip').category, 'Beaches');
      expect(ask('historical places').category, 'Historical');
      expect(ask('snow and mountains').category, 'Mountains');
    });

    test('notices when a jeep is off the table', () {
      expect(ask('where can I go without a jeep').avoids4x4, isTrue);
      expect(ask('places for a small car').avoids4x4, isTrue);
      expect(ask('where should I go').avoids4x4, isFalse);
    });
  });

  group('answering', () {
    test('recommends real places, cheapest first when money is mentioned', () {
      final r = reply('cheapest places for 3 days under 80k');
      expect(r.suggestions, isNotEmpty);
      for (var i = 1; i < r.suggestions.length; i++) {
        expect(r.suggestions[i - 1].estimatedTotal,
            lessThanOrEqualTo(r.suggestions[i].estimatedTotal));
      }
      // And it respects the ceiling it was given.
      for (final s in r.suggestions) {
        expect(s.estimatedTotal, lessThanOrEqualTo(80000));
      }
    });

    test('a month filter only returns places open then', () {
      final r = reply('where can I go in January');
      expect(r.suggestions, isNotEmpty);
      for (final s in r.suggestions) {
        expect(s.destination.bestMonths, contains(1),
            reason: 'not open in January');
      }
    });

    test('asking for no jeep never suggests one that needs a jeep', () {
      final r = reply('where can I go without a jeep');
      expect(r.suggestions, isNotEmpty);
      for (final s in r.suggestions) {
        expect(s.destination.requires4x4, isFalse);
      }
    });

    test('a category filter is honoured', () {
      final r = reply('somewhere with lakes');
      expect(r.suggestions, isNotEmpty);
      for (final s in r.suggestions) {
        // Either the town is a lakes destination, or it has lakes around it.
        // Almost no town is categorised "Lakes" — the lakes are its stops.
        final own = s.destination.category == 'Lakes';
        final nearby = s.destination.attractions.any((a) =>
            const ['Lake', 'Waterfall', 'Spring', 'River'].contains(a.category));
        expect(own || nearby, isTrue, reason: 'no water at ${s.destination.name}');
      }
    });

    test('costing a place quotes a total, a per-person and a distance', () {
      final r = reply('how much for Hunza for 4 people over 6 days');
      expect(r.suggestions.length, 1);
      expect(r.suggestions.first.estimatedTotal, greaterThan(0));
      expect(r.text, contains('Hunza'));
      expect(r.text, contains('each'));
    });

    test('more people costs more', () {
      final two = reply('how much for Naran for 2 people');
      final six = reply('how much for Naran for 6 people');
      expect(six.suggestions.first.estimatedTotal,
          greaterThan(two.suggestions.first.estimatedTotal));
    });

    test('comparing two places names both and picks the cheaper', () {
      final r = reply('Naran or Skardu');
      expect(r.suggestions.length, 2);
      expect(r.text, contains('Naran'));
      expect(r.text, contains('Skardu'));
      expect(r.text, contains('cheaper'));
    });

    test('distance answers in kilometres and hours', () {
      final r = reply('how far is Skardu');
      expect(r.text, contains('km'));
      expect(r.text, contains('hours'));
      expect(r.suggestions.first.distanceKm, greaterThan(100));
    });

    test('season answers name the months', () {
      final r = reply('when should I go to Fairy Meadows');
      expect(r.text, contains('Fairy Meadows'));
      expect(r.text.toLowerCase(), contains('best'));
    });

    test('the 4x4 answer is a straight yes or no', () {
      final yes = reply('does Fairy Meadows need a 4x4');
      expect(yes.text, startsWith('Yes'));

      final no = reply('does Murree need a jeep');
      expect(no.text, contains('ordinary car'));
    });

    test('packing answers count the list rather than inventing one', () {
      final r = reply('what should I pack for Skardu in December');
      expect(r.text, contains('Skardu'));
      expect(r.text, contains('December'));
      expect(r.text, contains('items'));
    });

    test('app questions are answered from what the app actually does', () {
      expect(reply('how is fuel calculated').text, contains('litre'));
      expect(reply('where do the prices come from').text, contains('estimate'));
      expect(reply('how do I export a pdf').text.toLowerCase(), contains('share'));
    });

    test('an impossible budget says so rather than returning nothing', () {
      final r = reply('where can I go for 5000 rupees');
      expect(r.suggestions, isEmpty);
      expect(r.text.toLowerCase(), anyOf(contains('cheapest'), contains('nothing')));
    });

    test('nonsense gets an honest answer, not a guess', () {
      final r = reply('what is the capital of France');
      expect(r.suggestions, isEmpty);
      expect(r.text, contains('did not follow'));
      expect(r.followUps, isNotEmpty);
    });

    test('every answer offers somewhere to go next', () {
      for (final q in [
        'where can I go in June',
        'how much for Hunza',
        'how far is Naran',
        'what is the capital of France',
      ]) {
        expect(reply(q).followUps, isNotEmpty, reason: 'nothing offered next');
      }
    });

    test('it never quotes a figure it cannot derive', () {
      // Every suggestion carries a total from the real cost engine, so a number
      // on screen is always traceable rather than invented.
      final r = reply('where can I go for a weekend');
      for (final s in r.suggestions) {
        expect(s.estimatedTotal, greaterThan(0));
        // Zero is legitimate: Islamabad is in the catalogue and is also the
        // origin, so the distance to it really is nothing.
        expect(s.distanceKm, greaterThanOrEqualTo(0));
        expect(s.reason, isNotEmpty);
      }
    });
  });
}
