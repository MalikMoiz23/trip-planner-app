import 'package:trip_planner/data/models/route_info.dart';
import 'package:trip_planner/data/models/trip_config.dart';

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
    this.packedItemIds = const {},
    this.budget = 0,
  });

  final String id;
  final DateTime createdAt;
  final TripConfig config;
  final RouteInfo outboundRoute;
  final double total;
  final double perPerson;
  final double totalKm;

  /// Packing-list items already ticked off, kept so the list survives a restart.
  final Set<String> packedItemIds;

  /// What the traveller said they could spend, zero when they never said.
  final double budget;

  Map<String, dynamic> toJson() => {
        'id': id,
        'createdAt': createdAt.toIso8601String(),
        'config': config.toJson(),
        'outboundRoute': outboundRoute.toJson(),
        'total': total,
        'perPerson': perPerson,
        'totalKm': totalKm,
        'packedItemIds': packedItemIds.toList(),
        'budget': budget,
      };

  SavedTrip withPacked(Set<String> ids) => SavedTrip(
        id: id,
        createdAt: createdAt,
        config: config,
        outboundRoute: outboundRoute,
        total: total,
        perPerson: perPerson,
        totalKm: totalKm,
        packedItemIds: ids,
        budget: budget,
      );

  factory SavedTrip.fromJson(Map<String, dynamic> j) => SavedTrip(
        id: j['id'] as String,
        createdAt: DateTime.parse(j['createdAt'] as String),
        config: TripConfig.fromJson(j['config'] as Map<String, dynamic>),
        outboundRoute: RouteInfo.fromJson(j['outboundRoute'] as Map<String, dynamic>),
        total: (j['total'] as num).toDouble(),
        perPerson: (j['perPerson'] as num).toDouble(),
        totalKm: (j['totalKm'] as num?)?.toDouble() ?? 0,
        packedItemIds: ((j['packedItemIds'] as List?) ?? const [])
            .map((e) => e as String)
            .toSet(),
        budget: (j['budget'] as num?)?.toDouble() ?? 0,
      );
}
