import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:latlong2/latlong.dart';

import '../core/fuzzy.dart';
import '../models/attraction.dart';
import '../models/destination.dart';
import 'nominatim_service.dart';
import 'overpass_service.dart';

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
  })  : _nominatim = nominatim ?? NominatimService(),
        _overpass = overpass ?? OverpassService();

  final NominatimService _nominatim;
  final OverpassService _overpass;

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

  /// True when the query matched nothing well enough to be worth showing.
  bool hasLocalMatch(String query) => searchRanked(query).isNotEmpty;

  List<Destination> byCategory(String category) =>
      _destinations.where((d) => d.category == category).toList(growable: false);

  /// Places to suggest first: the ones with the most curated content.
  List<Destination> get featured {
    final sorted = [..._destinations]
      ..sort((a, b) => b.attractions.length.compareTo(a.attractions.length));
    return sorted.take(6).toList(growable: false);
  }

  /// Live geocoding for anything the bundled list does not have.
  Future<List<PlaceHit>> searchRemote(String query) => _nominatim.search(query);

  Future<String> reverseName(LatLng point) => _nominatim.reverse(point);

  /// Extra nearby places from OpenStreetMap, excluding anything already curated
  /// for this destination so the picker never shows a duplicate.
  Future<List<Attraction>> liveNearby(Destination d, {int radiusMetres = 35000}) =>
      _overpass.nearby(
        d.point,
        radiusMetres: radiusMetres,
        excludeNames: d.attractions.map((a) => a.name).toSet(),
      );
}
