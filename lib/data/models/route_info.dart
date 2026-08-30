import 'package:latlong2/latlong.dart';

/// One leg of travel. `estimated` is true when OSRM could not be reached and
/// the numbers came from great-circle distance times the terrain road factor.
class RouteInfo {
  const RouteInfo({
    required this.distanceKm,
    required this.duration,
    this.geometry = const [],
    this.estimated = false,
  });

  final double distanceKm;
  final Duration duration;
  final List<LatLng> geometry;
  final bool estimated;

  static const RouteInfo zero = RouteInfo(distanceKm: 0, duration: Duration.zero);

  /// Geometry is deliberately dropped when persisting — a saved trip only needs
  /// the numbers, and polylines would bloat shared_preferences.
  Map<String, dynamic> toJson() => {
        'distanceKm': distanceKm,
        'durationSeconds': duration.inSeconds,
        'estimated': estimated,
      };

  factory RouteInfo.fromJson(Map<String, dynamic> j) => RouteInfo(
        distanceKm: (j['distanceKm'] as num?)?.toDouble() ?? 0,
        duration: Duration(seconds: (j['durationSeconds'] as num?)?.toInt() ?? 0),
        estimated: (j['estimated'] as bool?) ?? true,
      );
}
