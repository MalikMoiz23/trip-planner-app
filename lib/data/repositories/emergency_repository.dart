import 'package:latlong2/latlong.dart';

import 'package:trip_planner/core/geo.dart';
import 'package:trip_planner/data/models/destination.dart';
import 'package:trip_planner/data/models/help_place.dart';
import 'package:trip_planner/data/sources/osrm_service.dart';
import 'package:trip_planner/data/sources/overpass_service.dart';

/// Finds the nearest petrol pump, hospital, police station or workshop.
///
/// Two sources, in order. OpenStreetMap through Overpass knows where the pumps
/// are and is free and key-less, but it needs a signal — and running out of
/// fuel and running out of bars happen in the same places. So when the lookup
/// comes back with nothing, the app's own bundled towns stand in: a town is not
/// a pump, but "the nearest place that will have one is Balakot, 31 km back
/// down the road" is a usable answer, and it needs no network at all.
class EmergencyRepository {
  EmergencyRepository({
    OverpassService? overpass,
    OsrmService? osrm,
  })  : _overpass = overpass ?? OverpassService(),
        _osrm = osrm ?? OsrmService();

  final OverpassService _overpass;
  final OsrmService _osrm;

  /// How many of the nearest results get a real road distance.
  ///
  /// Routing is one request each against a shared free server, so this is
  /// deliberately small. The straight line decides the shortlist; the road
  /// decides the order it is shown in, because the nearest pin and the nearest
  /// pump are not the same thing on a valley road.
  static const int _routeTop = 4;

  Future<List<HelpPlace>> nearest(
    LatLng from,
    HelpKind kind, {
    List<Destination> catalogue = const [],
    int radiusMetres = 40000,
    int limit = 8,
  }) async {
    final found = await _overpass.help(from, kind, radiusMetres: radiusMetres, limit: limit);

    if (found.isEmpty) {
      return _fromCatalogue(from, kind, catalogue, limit);
    }

    final places = [
      for (final p in found)
        HelpPlace(
          name: p.name,
          kind: kind.label,
          point: p.point,
          straightKm: haversineKm(from, p.point),
        ),
    ];

    final routed = await _route(from, places.take(_routeTop).toList(growable: false));
    final rest = places.skip(_routeTop);
    final all = [...routed, ...rest];

    all.sort((a, b) => a.bestKm.compareTo(b.bestKm));
    return all;
  }

  Future<List<HelpPlace>> _route(LatLng from, List<HelpPlace> places) async {
    if (places.isEmpty) return const [];

    final targets = <String, LatLng>{
      for (var i = 0; i < places.length; i++) '$i': places[i].point,
    };
    final routes = await _osrm.routeMany(from, targets);

    return [
      for (var i = 0; i < places.length; i++)
        if (routes['$i'] case final route? when !route.estimated && route.distanceKm > 0)
          HelpPlace(
            name: places[i].name,
            kind: places[i].kind,
            point: places[i].point,
            straightKm: places[i].straightKm,
            roadKm: route.distanceKm,
            driveTime: route.duration,
          )
        else
          places[i],
    ];
  }

  /// No signal, or OpenStreetMap has nothing mapped here. The bundled towns are
  /// all real settlements on real roads, so the nearest few are a genuine
  /// answer to "which way do I walk" even though none of them is a pump.
  List<HelpPlace> _fromCatalogue(
    LatLng from,
    HelpKind kind,
    List<Destination> catalogue,
    int limit,
  ) {
    if (catalogue.isEmpty) return const [];

    final byDistance = [
      for (final d in catalogue) (d, haversineKm(from, d.point)),
    ]..sort((a, b) => a.$2.compareTo(b.$2));

    return [
      for (final (d, km) in byDistance.take(limit))
        HelpPlace(
          name: d.name,
          kind: 'Town — likely to have a ${kind.label.toLowerCase()}',
          point: d.point,
          straightKm: km,
          fromCatalogue: true,
        ),
    ];
  }
}
