import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_planner/core/fuzzy.dart';
import 'package:trip_planner/domain/rate_estimator.dart';
import 'package:trip_planner/data/repositories/destination_repository.dart';

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
      // "Thandyani Top" names the viewpoint, which is now its own place; the
      // hill station itself answers to "Thandyani".
      final top = repo.searchRanked('Thandyani Top');
      expect(top, isNotEmpty);
      expect(top.first.destination.name, 'Thandiani Top');
      expect(top.first.destination.parentName, 'Thandiani');

      final thandiani = repo.searchRanked('Thandyani');
      expect(thandiani, isNotEmpty);
      expect(thandiani.first.destination.name, 'Thandiani');
      expect(thandiani.first.destination.isSpot, isFalse);

      // Panj Peer Rocks is somewhere you can go on its own, so the landmark
      // itself must win — not the town that happens to contain it.
      final panjPeer = repo.searchRanked('Panj Peer Rocks');
      expect(panjPeer, isNotEmpty);
      expect(panjPeer.first.destination.name, 'Panj Peer Rocks');
      expect(panjPeer.first.destination.isSpot, isTrue);
      expect(panjPeer.first.destination.parentName, 'Murree');
    });

    test('every stop is plannable on its own', () {
      expect(repo.towns.length, greaterThanOrEqualTo(30));
      expect(repo.spots.length, greaterThanOrEqualTo(120));
      expect(repo.all.length, repo.towns.length + repo.spots.length);

      // Ids stay unique once stops join the same namespace as towns.
      final ids = <String>{};
      for (final place in repo.all) {
        expect(ids.add(place.id), isTrue, reason: 'duplicate id ${place.id}');
      }

      // And each one resolves back through byId.
      for (final place in repo.all) {
        expect(repo.byId(place.id)?.name, place.name);
      }
    });

    test('a promoted spot offers its town and siblings as its own stops', () {
      final spot = repo.searchRanked('Panj Peer Rocks').first.destination;
      final names = spot.attractions.map((a) => a.name).toList();

      // The town it belongs to is reachable from it.
      expect(names, contains('Murree'));
      // As are the town's other stops.
      expect(names, contains('Patriata (New Murree)'));
      // But not itself.
      expect(names, isNot(contains('Panj Peer Rocks')));

      expect(repo.parentOf(spot)?.name, 'Murree');
      expect(spot.roadFactor, repo.byId('murree')!.roadFactor);
      expect(spot.bestMonths, repo.byId('murree')!.bestMonths);
    });

    test('filtering by kind narrows the pool', () {
      final townsOnly = repo.searchRanked('', kind: PlaceKind.towns);
      final spotsOnly = repo.searchRanked('', kind: PlaceKind.spots);

      expect(townsOnly.every((h) => !h.destination.isSpot), isTrue);
      expect(spotsOnly.every((h) => h.destination.isSpot), isTrue);
      expect(townsOnly.length + spotsOnly.length, repo.all.length);

      // Searching towns only still finds Murree via the stop it contains.
      final viaTown = repo.searchRanked('Panj Peer Rocks', kind: PlaceKind.towns);
      expect(viaTown.first.destination.name, 'Murree');
      expect(viaTown.first.matchedStop, 'Panj Peer Rocks');
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

    test('a town matched through its contents still explains itself', () {
      final hits = repo.searchRanked('panjpeer', kind: PlaceKind.towns);
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

    test('a landmark query returns the landmark, and names its town', () {
      // Each of these is a place someone might travel to for its own sake, so
      // the spot outranks the town, and the town is still named on the result.
      const cases = {
        'saiful malook': ('Lake Saif-ul-Malook', 'Naran'),
        'ratti gali': ('Ratti Gali Lake', 'Neelum Valley (Keran)'),
        'attabad': ('Attabad Lake', 'Hunza (Karimabad)'),
        'deosai': ('Deosai National Park', 'Skardu'),
        'derawar fort': ('Derawar Fort', 'Bahawalpur & Cholistan'),
        'toli peer': ('Toli Peer', 'Rawalakot'),
        'makli': ('Makli Necropolis', 'Thatta & Keenjhar'),
        'katora lake': ('Katora Lake', 'Kumrat Valley'),
      };
      cases.forEach((query, expected) {
        final hits = repo.searchRanked(query);
        expect(hits, isNotEmpty, reason: 'no hit for "$query"');
        expect(hits.first.destination.name, expected.$1, reason: 'for query "$query"');
        expect(hits.first.destination.parentName, expected.$2,
            reason: 'for query "$query"');
      });
    });

    test('a town query still returns the town', () {
      const cases = {
        'naran': 'Naran',
        'hunza': 'Hunza (Karimabad)',
        'skardu': 'Skardu',
        'katas raj': 'Katas Raj & Kallar Kahar',
      };
      cases.forEach((query, expected) {
        final hits = repo.searchRanked(query);
        expect(hits.first.destination.name, expected, reason: 'for query "$query"');
        expect(hits.first.destination.isSpot, isFalse, reason: 'for query "$query"');
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
  group('when the live lookup is allowed to run', () {
    late DestinationRepository repo;

    setUpAll(() async {
      repo = DestinationRepository();
      await repo.load();
    });

    test('a weak fuzzy match no longer suppresses the network', () {
      // "Siran Valley" scores about 0.72 against "Naran" — one letter apart once
      // the vowels fold. Gating the geocoder on any local match meant a real
      // place was answered with a near-homophone and the network never ran.
      expect(repo.hasLocalMatch('Siran Valley'), isTrue);
      expect(
        repo.hasExactLocalMatch('Siran Valley'),
        isTrue,
        reason: 'Siran Valley is in the catalogue now, so it needs no lookup',
      );

      // Somewhere genuinely absent must still reach for the network.
      expect(repo.hasExactLocalMatch('Jhelum'), isFalse);
      expect(repo.hasExactLocalMatch('Bhurban'), isFalse);
      expect(repo.hasExactLocalMatch('Sialkot'), isFalse);
    });

    test('a place the catalogue really holds does not hit the network', () {
      for (final q in ['Naran', 'Hunza', 'Skardu', 'Siran Valley', 'Kalash Valleys']) {
        expect(repo.hasExactLocalMatch(q), isTrue, reason: 'for "$q"');
      }
    });

    test('the valleys OpenStreetMap does not name are in the guide', () {
      // Neither Nominatim nor Photon returns anything for these under the name
      // people actually use, so the catalogue has to own them.
      const cases = {
        'Siran Valley': 'Siran Valley',
        'siran valey': 'Siran Valley',
        'Ghizer': 'Ghizer Valley',
        'Yasin Valley': 'Yasin Valley',
        'Kalash': 'Kalash Valleys',
        'Hingol': 'Hingol National Park',
        'Kaghan': 'Kaghan',
      };
      cases.forEach((query, expected) {
        final hits = repo.searchRanked(query);
        expect(hits, isNotEmpty, reason: 'no hit for "$query"');
        expect(hits.first.destination.name, expected, reason: 'for "$query"');
      });
    });
  });
}
