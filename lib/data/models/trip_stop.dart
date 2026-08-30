import 'package:trip_planner/data/models/attraction.dart';
import 'package:trip_planner/data/models/destination.dart';

/// One place you stay on the way round, and what you do while you are there.
///
/// A trip used to be a single base with day trips radiating out of it. That is
/// how you tour one valley, but it is not how anyone drives to the north: you
/// go Islamabad, Naran, Hunza, Skardu, home, sleeping in a different town most
/// nights. A stop is that unit — somewhere you sleep, for a number of nights,
/// with its own list of places to see from there.
class TripStop {
  const TripStop({
    required this.destination,
    required this.nights,
    this.selectedAttractions = const [],
    this.stayRatePerUnitNight,
  });

  final Destination destination;

  /// Nights slept here. Zero means you pass through on the way to somewhere
  /// else, which is a legitimate thing to do — Chilas is mostly that.
  final int nights;

  /// Day trips taken from this base, not from any other.
  final List<Attraction> selectedAttractions;

  /// Overrides the trip-wide nightly rate. A guest house in Chilas and a hotel
  /// in Hunza are not the same price, and once a trip has four stops that
  /// difference stops being noise.
  final double? stayRatePerUnitNight;

  bool get isPassThrough => nights == 0;

  double get sightseeingHours =>
      selectedAttractions.fold(0.0, (sum, a) => sum + a.visitHours);

  /// Tickets and jeep fares for everything chosen here, per person.
  double get perPersonSiteCost =>
      selectedAttractions.fold(0.0, (sum, a) => sum + a.entryFee + a.localTransport);

  TripStop copyWith({
    Destination? destination,
    int? nights,
    List<Attraction>? selectedAttractions,
    double? stayRatePerUnitNight,
    bool clearRate = false,
  }) =>
      TripStop(
        destination: destination ?? this.destination,
        nights: nights ?? this.nights,
        selectedAttractions: selectedAttractions ?? this.selectedAttractions,
        stayRatePerUnitNight:
            clearRate ? null : (stayRatePerUnitNight ?? this.stayRatePerUnitNight),
      );

  Map<String, dynamic> toJson() => {
        'destination': destination.toJson(),
        'nights': nights,
        'selectedAttractions': selectedAttractions.map((a) => a.toJson()).toList(),
        'stayRatePerUnitNight': stayRatePerUnitNight,
      };

  factory TripStop.fromJson(Map<String, dynamic> j) => TripStop(
        destination: Destination.fromJson(j['destination'] as Map<String, dynamic>),
        nights: (j['nights'] as num?)?.toInt() ?? 0,
        selectedAttractions: ((j['selectedAttractions'] as List?) ?? const [])
            .map((e) => Attraction.fromJson(e as Map<String, dynamic>))
            .toList(growable: false),
        stayRatePerUnitNight: (j['stayRatePerUnitNight'] as num?)?.toDouble(),
      );
}
