import 'package:trip_planner/data/models/attraction.dart';
import 'package:trip_planner/data/models/destination.dart';
import 'package:trip_planner/data/models/trip_stop.dart';

/// One stop while it is still being edited.
///
/// The immutable [TripStop] is what the cost engine reads; this is the mutable
/// working copy the planner screen edits, and it also carries the things that
/// exist only while planning — which nearby places have been fetched, and
/// whether that fetch has been tried.
class PlannedStop {
  PlannedStop({
    required this.destination,
    required this.nights,
    List<Attraction>? curated,
  }) : curated = curated ?? destination.attractions;

  Destination destination;
  int nights;

  /// From the bundled catalogue.
  List<Attraction> curated;

  /// Pulled live from OpenStreetMap for this stop specifically.
  List<Attraction> live = const [];

  /// Distinguishes "no nearby places exist" from "we have not looked yet".
  bool liveAttempted = false;

  final Set<String> selectedIds = {};

  List<Attraction> get candidates => [...curated, ...live];

  List<Attraction> get selected =>
      candidates.where((a) => selectedIds.contains(a.id)).toList(growable: false);

  double get sightseeingHours =>
      selected.fold(0.0, (sum, a) => sum + a.visitHours);

  TripStop toTripStop() => TripStop(
        destination: destination,
        nights: nights,
        selectedAttractions: selected,
      );
}
