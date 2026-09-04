import 'package:latlong2/latlong.dart';

/// Somewhere that can help, with how far away it actually is.
class HelpPlace {
  const HelpPlace({
    required this.name,
    required this.kind,
    required this.point,
    required this.straightKm,
    this.roadKm,
    this.driveTime,
    this.fromCatalogue = false,
  });

  final String name;

  /// What it is, in words — "Petrol pump", "Hospital".
  final String kind;

  final LatLng point;

  /// Great-circle distance. Always known, always an understatement.
  final double straightKm;

  /// Road distance, when the router could be reached. Null means only the
  /// straight line is known, and the screen has to say so — telling someone on
  /// an empty tank that a pump is 4 km away when the road is 19 km round a
  /// ridge is the kind of wrong that strands them.
  final double? roadKm;

  final Duration? driveTime;

  /// True when this came out of the app's own bundled list of towns rather than
  /// from OpenStreetMap, because there was no signal to ask.
  final bool fromCatalogue;

  /// The best distance figure available, for sorting and for display.
  double get bestKm => roadKm ?? straightKm;

  bool get isRouted => roadKm != null;
}
