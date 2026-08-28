import 'route_info.dart';
import 'trip_config.dart';

/// A trip the user chose to keep. The headline figures are stored alongside the
/// config so the list renders with no network and no recalculation.
class SavedTrip {
  const SavedTrip({
    required this.id,
    required this.createdAt,
    required this.config,
    required this.outboundRoute,
    required this.total,
    required this.perPerson,
    required this.totalKm,
  });

  final String id;
  final DateTime createdAt;
  final TripConfig config;
  final RouteInfo outboundRoute;
  final double total;
  final double perPerson;
  final double totalKm;

  Map<String, dynamic> toJson() => {
        'id': id,
        'createdAt': createdAt.toIso8601String(),
        'config': config.toJson(),
        'outboundRoute': outboundRoute.toJson(),
        'total': total,
        'perPerson': perPerson,
        'totalKm': totalKm,
      };

  factory SavedTrip.fromJson(Map<String, dynamic> j) => SavedTrip(
        id: j['id'] as String,
        createdAt: DateTime.parse(j['createdAt'] as String),
        config: TripConfig.fromJson(j['config'] as Map<String, dynamic>),
        outboundRoute: RouteInfo.fromJson(j['outboundRoute'] as Map<String, dynamic>),
        total: (j['total'] as num).toDouble(),
        perPerson: (j['perPerson'] as num).toDouble(),
        totalKm: (j['totalKm'] as num?)?.toDouble() ?? 0,
      );
}
