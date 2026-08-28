import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_planner/core/fuzzy.dart';
import 'package:trip_planner/logic/rate_estimator.dart';
import 'package:trip_planner/services/destination_repository.dart';

/// Regression cases: "Thandyani Top" and "Panj Peer Rocks" both returned
/// nothing, from the bundled guide and from the geocoder alike.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('normalisation', () {
    test('strips punctuation and case', () {
      expect(normalize('Saif-ul-Malook'), 'saif ul malook');
      expect(normalize('  Panj  Peer   Rocks '), 'panj peer rocks');
    });

    test('drops place-kind words but never everything', () {
      expect(stripGenerics('thandyani top'), 'thandyani');
      expect(stripGenerics('panj peer rocks'), 'panj peer');
      expect(stripGenerics('lulusar lake'), 'lulusar');
      // A query made only of generic words survives intact.
      expect(stripGenerics('lake'), 'lake');
    });

    test('fold key collides on transliteration variants', () {
      expect(foldKey('Thandyani'), foldKey('Thandiani'));
      expect(foldKey('Panjpeer'), foldKey('Panj Peer'));
      expect(foldKey('Nathiagali'), foldKey('Nathia Gali'));
      expect(foldKey('Muzaffarabad'), foldKey('Muzafarabad'));
    });

    test('fold key still separates unrelated names', () {
      expect(foldKey('Naran'), isNot(foldKey('Naltar')));
      expect(foldKey('Skardu'), isNot(foldKey('Shogran')));
      expect(foldKey('Hunza'), isNot(foldKey('Chitral')));
    });
  });

  group('edit distance', () {
    test('counts single edits', () {
      expect(editDistance('naran', 'naran'), 0);
      expect(editDistance('naran', 'naraan'), 1);
      expect(editDistance('murree', 'muree'), 1);
    });

    test('counts a transposition as one edit', () {
      expect(editDistance('panjpeer', 'panjpere'), 1);
    });

    test('bounds cheaply', () {
      expect(editDistance('a' * 40, 'b' * 40, maxDistance: 3), greaterThan(3));
    });
  });

  group('scoring', () {
    test('a misspelling still scores as a match', () {
      for (final pair in [
        ('Thandyani Top', 'Thandiani'),
        ('thandyani', 'Thandiani'),
        ('Panjpeer Rocks', 'Panj Peer Rocks'),
        ('panj pir', 'Panj Peer Rocks'),
        ('Nathiagali', 'Nathia Gali'),
        ('Saiful Malook', 'Lake Saif-ul-Malook'),
        ('Muree', 'Murree'),
        ('Atabad lake', 'Attabad Lake'),
        ('Rati Gali', 'Ratti Gali Lake'),
        ('Deosai plains', 'Deosai National Park'),
      ]) {
        expect(
          scoreCandidate(pair.$1, pair.$2),
          greaterThanOrEqualTo(fuzzyThreshold),
          reason: '"${pair.$1}" should match "${pair.$2}"',
        );
      }
    });

    test('unrelated names stay below the threshold', () {
      for (final pair in [
        ('Karachi', 'Thandiani'),
        ('Lahore', 'Deosai National Park'),
        ('Gwadar', 'Nathia Gali'),
      ]) {
        expect(
          scoreCandidate(pair.$1, pair.$2),
          lessThan(fuzzyThreshold),
          reason: '"${pair.$1}" should not match "${pair.$2}"',
        );
      }
    });

    test('an exact match outranks an approximate one', () {
      final exact = scoreCandidate('Naran', 'Naran');
      final fuzzy = scoreCandidate('Naraan', 'Naran');
      expect(exact, 1.0);
      expect(fuzzy, lessThan(exact));
      expect(fuzzy, greaterThanOrEqualTo(fuzzyThreshold));
    });
  });

  group('geocoder query relaxation', () {
    test('drops the place-kind word that made Nominatim return nothing', () {
      final variants = queryVariants('Thandyani Top');
      expect(variants.first, 'Thandyani Top');
      expect(variants, contains('Thandyani'));
    });

    test('shortens progressively', () {
      final variants = queryVariants('Panj Peer Rocks');
      expect(variants, contains('Panj Peer'));
      expect(variants.length, lessThanOrEqualTo(4));
    });

    test('leaves a single plain word alone', () {
      expect(queryVariants('Hunza'), ['Hunza']);
    });

    test('ignores a query too short to be meaningful', () {
      expect(queryVariants('ab'), isEmpty);
    });
  });

  group('repository search over the real catalogue', () {
    late DestinationRepository repo;

    setUpAll(() async {
      repo = DestinationRepository();
      await repo.load();
    });

    test('finds the two places that originally failed', () {
      final thandiani = repo.searchRanked('Thandyani Top');
      expect(thandiani, isNotEmpty);
      expect(thandiani.first.destination.name, 'Thandiani');

      final panjPeer = repo.searchRanked('Panj Peer Rocks');
      expect(panjPeer, isNotEmpty);
      expect(panjPeer.first.matchedStop, 'Panj Peer Rocks');
    });

    test('a listed alias is an exact match, an unlisted typo is approximate', () {
      // "Thandyani Top" is in the alias list, so it should not be flagged as a
      // guess. A spelling nobody wrote down should be.
      expect(repo.searchRanked('Thandyani Top').first.isApproximate, isFalse);

      final guess = repo.searchRanked('thandyaani top');
      expect(guess, isNotEmpty);
      expect(guess.first.destination.name, 'Thandiani');
      expect(guess.first.isApproximate, isTrue);
    });

    test('a stop match explains itself', () {
      final hits = repo.searchRanked('panjpeer');
      expect(hits.first.matchedStop, isNotNull,
          reason: 'the row must be able to say why Murree is the answer');
    });

    test('survives a range of real misspellings', () {
      const cases = {
        'thandiani': 'Thandiani',
        'thandyani': 'Thandiani',
        'nathiagali': 'Nathia Gali',
        'muree': 'Murree',
        'karimabad': 'Hunza (Karimabad)',
        'skardo': 'Skardu',
        'muzafarabad': 'Muzaffarabad',
        'neelam valley': 'Neelum Valley (Keran)',
        'kumrat valley': 'Kumrat Valley',
        'fairy meadow': 'Fairy Meadows',
        'gawadar': 'Gwadar',
        'rawlakot': 'Rawalakot',
        'phandar': 'Phander Valley',
      };
      cases.forEach((query, expected) {
        final hits = repo.searchRanked(query);
        expect(hits, isNotEmpty, reason: 'no hit for "$query"');
        expect(hits.first.destination.name, expected, reason: 'for query "$query"');
      });
    });

    test('finds a destination by one of its stops', () {
      const cases = {
        'saiful malook': 'Naran',
        'ratti gali': 'Neelum Valley (Keran)',
        'attabad': 'Hunza (Karimabad)',
        'deosai': 'Skardu',
        'derawar fort': 'Bahawalpur & Cholistan',
        'katas raj': 'Katas Raj & Kallar Kahar',
        'toli peer': 'Rawalakot',
        'makli': 'Thatta & Keenjhar',
      };
      cases.forEach((query, expected) {
        final hits = repo.searchRanked(query);
        expect(hits, isNotEmpty, reason: 'no hit for "$query"');
        expect(hits.first.destination.name, expected, reason: 'for query "$query"');
      });
    });

    test('nonsense returns nothing rather than a random place', () {
      expect(repo.searchRanked('zzzqqqxyw'), isEmpty);
      expect(repo.hasLocalMatch('zzzqqqxyw'), isFalse);
    });

    test('an empty query returns the whole catalogue', () {
      expect(repo.searchRanked('').length, repo.all.length);
    });

    test('results are ordered best first', () {
      final hits = repo.searchRanked('lake');
      for (var i = 1; i < hits.length; i++) {
        expect(hits[i - 1].score, greaterThanOrEqualTo(hits[i].score));
      }
    });
  });

  group('catalogue coverage', () {
    test('every destination and stop carries an aliases list', () async {
      final raw = await rootBundle.loadString('assets/data/destinations.json');
      final doc = jsonDecode(raw) as Map<String, dynamic>;
      final destinations = doc['destinations'] as List;

      expect(destinations.length, greaterThanOrEqualTo(30));

      for (final d in destinations) {
        final dest = d as Map<String, dynamic>;
        expect(dest['aliases'], isA<List>(), reason: '${dest['id']} has no aliases key');
        for (final a in dest['attractions'] as List) {
          expect((a as Map<String, dynamic>)['aliases'], isA<List>(),
              reason: '${a['id']} has no aliases key');
        }
      }
    });
  });

  group('rate estimator', () {
    test('gives every known category a usable, non-negative rate', () {
      for (final category in RateEstimator.knownCategories) {
        final rates = RateEstimator.forCategory(category);
        expect(rates.entryFee, greaterThanOrEqualTo(0), reason: category);
        expect(rates.localTransport, greaterThanOrEqualTo(0), reason: category);
        expect(rates.visitHours, greaterThan(0), reason: category);
      }
    });

    test('an unknown category falls back rather than costing nothing', () {
      final rates = RateEstimator.forCategory('SomethingNew');
      expect(rates.entryFee + rates.localTransport, greaterThan(0));
    });

    test('a jeep-only category carries a transport cost and the 4x4 flag', () {
      final plateau = RateEstimator.forCategory('Plateau');
      expect(plateau.localTransport, greaterThan(0));
      expect(plateau.requires4x4, isTrue);
    });
  });
}
