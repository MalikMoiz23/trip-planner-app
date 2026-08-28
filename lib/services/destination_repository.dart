import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:latlong2/latlong.dart';

import '../models/attraction.dart';
import '../models/destination.dart';
import 'nominatim_service.dart';
import 'overpass_service.dart';

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
  String _dataNote = '';
  bool _loaded = false;

  List<Destination> get all => List.unmodifiable(_destinations);
  String get dataNote => _dataNote;
  bool get isLoaded => _loaded;

  List<String> get categories {
    final set = <String>{for (final d in _destinations) d.category};
    final ordered = ['Mountains', 'Valleys', 'Hills', 'Beaches', 'Historical', 'City'];
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
    _loaded = true;
  }

  Destination? byId(String id) {
    for (final d in _destinations) {
      if (d.id == id) return d;
    }
    return null;
  }

  /// Substring match over name, region, province and highlight names.
  List<Destination> search(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return all;
    return _destinations.where((d) {
      if (d.name.toLowerCase().contains(q)) return true;
      if (d.region.toLowerCase().contains(q)) return true;
      if (d.province.toLowerCase().contains(q)) return true;
      if (d.category.toLowerCase().contains(q)) return true;
      return d.attractions.any((a) => a.name.toLowerCase().contains(q));
    }).toList(growable: false);
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
