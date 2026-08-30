import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:latlong2/latlong.dart';

import 'package:trip_planner/core/fuzzy.dart';
import 'package:trip_planner/core/geo.dart';
import 'package:trip_planner/data/models/attraction.dart';
import 'package:trip_planner/data/models/destination.dart';
import 'package:trip_planner/data/sources/nominatim_service.dart';
import 'package:trip_planner/data/sources/overpass_service.dart';
import 'package:trip_planner/data/sources/photon_service.dart';
import 'package:trip_planner/domain/rate_estimator.dart';

/// Which half of the catalogue to look at.
enum PlaceKind {
  all('All places'),
  towns('Base towns'),
  spots('Individual spots');

  const PlaceKind(this.label);
  final String label;
}

/// One ranked search result.
class SearchHit {
  const SearchHit({
    required this.destination,
    required this.score,
    this.matchedStop,
  });

  final Destination destination;

  /// 0 to 1. Above [fuzzyThreshold] is worth showing.
  final double score;

  /// Set when the query matched a stop inside this destination rather than the
  /// destination's own name, so the UI can say which one.
  final String? matchedStop;

  /// True when the spelling did not line up exactly, which is worth telling the
  /// user about so a surprising result reads as intentional.
  bool get isApproximate => score < 0.93;
}

/// Owns the bundled catalogue and knows when to reach for the live services.
///
/// Bundled data is the source of truth: it has curated fees, visit durations
/// and 4x4 flags. Overpass and Nominatim only fill gaps — places the dataset
/// does not cover.
class DestinationRepository {
  DestinationRepository({
    NominatimService? nominatim,
    OverpassService? overpass,
    PhotonService? photon,
  })  : _nominatim = nominatim ?? NominatimService(),
        _overpass = overpass ?? OverpassService(),
        _photon = photon ?? PhotonService();

  final NominatimService _nominatim;
  final OverpassService _overpass;
  final PhotonService _photon;

  final List<Destination> _destinations = [];

  /// Every stop, promoted to a place you can plan a trip to on its own.
  final List<Destination> _spots = [];

  String _dataNote = '';
  bool _loaded = false;

  /// Base towns only.
  List<Destination> get towns => List.unmodifiable(_destinations);

  /// Individual landmarks, each plannable in its own right.
  List<Destination> get spots => List.unmodifiable(_spots);

  /// Everything, towns first.
  List<Destination> get all => List.unmodifiable([..._destinations, ..._spots]);

  String get dataNote => _dataNote;
  bool get isLoaded => _loaded;

  /// Spots are flattened onto the same canonical categories as towns, so this
  /// stays a short chip row rather than one chip per stop type.
  List<String> get categories {
    final set = <String>{for (final d in all) d.category};
    final ordered = [
      'Mountains',
      'Valleys',
      'Hills',
      'Lakes',
      'Beaches',
      'Historical',
      'City',
      'Desert',
    ];
    final out = ordered.where(set.contains).toList();
    out.addAll(set.where((c) => !out.contains(c)));
    return out;
  }

  Future<void> load() async {
    if (_loaded) return;
    final raw = await rootBundle.loadString('assets/data/destinations.json');
    final map = jsonDecode(raw) as Map<String, dynamic>;
    _dataNote = (map['dataNote'] as String?) ?? '';
    _destinations
      ..clear()
      ..addAll(((map['destinations'] as List?) ?? const [])
          .map((e) => Destination.fromJson(e as Map<String, dynamic>)));

    // Each curated stop also stands alone. Derived here rather than stored, so
    // the JSON keeps one copy of every fee.
    _spots
      ..clear()
      ..addAll([
        for (final town in _destinations)
          for (final stop in town.attractions) Destination.fromStop(stop, town),
      ]);

    _loaded = true;
  }

  Destination? byId(String id) {
    for (final d in _destinations) {
      if (d.id == id) return d;
    }
    for (final s in _spots) {
      if (s.id == id) return s;
    }
    return null;
  }

  /// The town a spot belongs to, or null for a town.
  Destination? parentOf(Destination d) =>
      d.parentId == null ? null : byId(d.parentId!);

  /// Typo-tolerant search over destination names, aliases, regions, categories
  /// and the names of the stops inside each destination.
  ///
  /// Ranked, because fuzzy matching returns a spread rather than a yes or no.
  /// A stop match carries the stop's name back out so the row can explain
  /// itself — searching "panj peer rocks" surfaces Murree, and without that
  /// note the result looks like a mistake.
  List<SearchHit> searchRanked(String query, {PlaceKind kind = PlaceKind.all}) {
    final pool = switch (kind) {
      PlaceKind.all => all,
      PlaceKind.towns => towns,
      PlaceKind.spots => spots,
    };

    final q = query.trim();
    if (q.isEmpty) {
      return pool.map((d) => SearchHit(destination: d, score: 1)).toList(growable: false);
    }

    final hits = <SearchHit>[];
    for (final d in pool) {
      final direct = scoreLabels(q, d.searchLabels);
      var best = direct.score;
      String? matchedStop;

      // Region, province and category match, but rank below a name match.
      final contextScore = scoreLabels(q, [d.region, d.province, d.category]).score * 0.82;
      if (contextScore > best) best = contextScore;

      // A town also matches on what it contains, discounted so that the stop
      // itself outranks the town holding it.
      //
      // Only a town, though. A promoted spot carries its neighbours in the same
      // field, and they are options to add once you are there, not things it
      // contains — Ayubia does not "have" Panj Peer Rocks, and saying so put
      // every sibling into the results for a query about one of them.
      if (!d.isSpot) {
        for (final a in d.attractions) {
          final stop = scoreLabels(q, a.searchLabels);
          final scaled = stop.score * 0.90;
          if (scaled > best) {
            best = scaled;
            matchedStop = a.name;
          }
        }
      }

      if (best >= fuzzyThreshold) {
        hits.add(SearchHit(destination: d, score: best, matchedStop: matchedStop));
      }
    }

    hits.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      return byScore != 0 ? byScore : a.destination.name.compareTo(b.destination.name);
    });
    return hits;
  }

  /// Destinations only, for callers that do not need the match metadata.
  List<Destination> search(String query) =>
      searchRanked(query).map((h) => h.destination).toList(growable: false);

  /// True when the query matched anything at all above the fuzzy threshold.
  bool hasLocalMatch(String query) => searchRanked(query).isNotEmpty;

  /// True when the catalogue holds something so close to the query that going
  /// to the network would only add latency.
  ///
  /// This is deliberately much stricter than [hasLocalMatch]. Fuzzy matching is
  /// generous by design — "Siran Valley" scores 0.72 against "Naran", one letter
  /// apart once the vowels fold — and gating the live lookup on *any* match
  /// meant a real place the catalogue has never heard of was answered with a
  /// near-homophone and the network was never consulted. Only a near-exact hit
  /// earns the right to suppress the search: an exact name or alias, a prefix
/// ("Hunza" for "Hunza (Karimabad)", 0.95), or a transliteration variant the
/// phonetic fold resolves ("Thandyani" for "Thandiani", 0.91). The Siran case
/// sat at 0.72 and now correctly falls through to the geocoders.
  bool hasExactLocalMatch(String query) {
    final hits = searchRanked(query);
    return hits.isNotEmpty && hits.first.score >= 0.90;
  }

  List<Destination> byCategory(String category) =>
      _destinations.where((d) => d.category == category).toList(growable: false);

  /// Places to suggest first: the ones with the most curated content.
  List<Destination> get featured {
    final sorted = [..._destinations]
      ..sort((a, b) => b.attractions.length.compareTo(a.attractions.length));
    return sorted.take(6).toList(growable: false);
  }

  /// Live geocoding for anything the bundled list does not have.
  ///
  /// Both geocoders are asked at once and their answers merged. They read the
  /// same OpenStreetMap data but fail in opposite directions: Nominatim is
  /// near-exact and authoritative, Photon is typo-tolerant and built for
  /// type-ahead. "Thandyani" gets nothing from the first and the right hill
  /// station from the second; a precise address is the other way round.
  ///
  /// Nominatim's hits are listed first because when it does answer it is the
  /// better answer, and duplicates are dropped by name and position — the same
  /// village from two sources is one place, not two rows.
  Future<List<PlaceHit>> searchRemote(String query) async {
    final results = await Future.wait([
      _nominatim.search(query),
      _photon.search(query),
    ]);

    final out = <PlaceHit>[];
    final seenNames = <String>{};

    for (final hit in [...results[0], ...results[1]]) {
      // Two sources describing one place: same fold key, and within about a
      // kilometre of each other.
      final key = foldKey(hit.name);
      final duplicate = seenNames.contains(key) &&
          out.any((existing) =>
              foldKey(existing.name) == key &&
              haversineKm(existing.point, hit.point) < 1.0);
      if (duplicate) continue;

      seenNames.add(key);
      out.add(hit);
      if (out.length >= 12) break;
    }

    return out;
  }

  Future<String> reverseName(LatLng point) => _nominatim.reverse(point);

  /// Extra nearby places from OpenStreetMap, excluding anything already curated
  /// for this destination so the picker never shows a duplicate.
  ///
  /// OSM has no prices, so each row is costed from typical rates for its kind.
  /// That join happens here rather than in the source: fetching is data work,
  /// deciding what a waterfall costs is a pricing assumption, and the repository
  /// is the seam where raw rows become something the rest of the app can use.
  Future<List<Attraction>> liveNearby(Destination d, {int radiusMetres = 35000}) async {
    final places = await _overpass.nearby(
      d.point,
      radiusMetres: radiusMetres,
      excludeNames: d.attractions.map((a) => a.name).toSet(),
    );
    return places.map(_priceOsmPlace).toList(growable: false);
  }

  Attraction _priceOsmPlace(OsmPlace place) {
    final rates = RateEstimator.forCategory(place.category);
    return Attraction(
      id: place.id,
      name: place.name,
      category: place.category,
      description: 'From OpenStreetMap. It publishes no prices, so the figures below '
          'are typical rates for a ${place.category.toLowerCase()} — tap the pencil to '
          'put in what you are actually quoted.',
      lat: place.lat,
      lng: place.lng,
      entryFee: place.feeExplicitlyFree ? 0 : rates.entryFee,
      localTransport: rates.localTransport,
      visitHours: rates.visitHours,
      requires4x4: rates.requires4x4,
      isLive: true,
      ratesEstimated: true,
    );
  }

}
