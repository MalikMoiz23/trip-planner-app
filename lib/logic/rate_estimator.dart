/// Typical per-person costs for a stop, by what kind of place it is.
///
/// OpenStreetMap carries names and coordinates but no prices, so a stop pulled
/// from a live lookup used to arrive costed at zero — which made a plan built
/// around searched places read as travel-only. These are ordinary 2026 figures
/// for Pakistan: a park gate fee, a boat at a lake, a jeep up to a meadow.
///
/// They are estimates and the app says so everywhere it shows one. Every field
/// is editable per stop, and a curated entry in the bundled catalogue always
/// wins over anything here.
class EstimatedRates {
  const EstimatedRates({
    required this.entryFee,
    required this.localTransport,
    required this.visitHours,
    required this.requires4x4,
  });

  /// Gate or ticket price, per person.
  final double entryFee;

  /// Jeep, boat, chairlift or shared van to reach it, per person.
  final double localTransport;

  final double visitHours;
  final bool requires4x4;
}

class RateEstimator {
  const RateEstimator._();

  static const EstimatedRates _fallback = EstimatedRates(
    entryFee: 200,
    localTransport: 0,
    visitHours: 2,
    requires4x4: false,
  );

  static const Map<String, EstimatedRates> _byCategory = {
    // Water
    'Lake': EstimatedRates(entryFee: 200, localTransport: 600, visitHours: 3, requires4x4: false),
    'Waterfall': EstimatedRates(entryFee: 100, localTransport: 0, visitHours: 2, requires4x4: false),
    'Spring': EstimatedRates(entryFee: 100, localTransport: 0, visitHours: 2, requires4x4: false),
    'River': EstimatedRates(entryFee: 0, localTransport: 0, visitHours: 2, requires4x4: false),

    // High ground
    'Viewpoint': EstimatedRates(entryFee: 0, localTransport: 400, visitHours: 2, requires4x4: false),
    'Pass': EstimatedRates(entryFee: 0, localTransport: 0, visitHours: 3, requires4x4: false),
    'Meadow': EstimatedRates(entryFee: 200, localTransport: 1800, visitHours: 4, requires4x4: true),
    'Plateau': EstimatedRates(entryFee: 400, localTransport: 3000, visitHours: 6, requires4x4: true),
    'Trek': EstimatedRates(entryFee: 0, localTransport: 1200, visitHours: 6, requires4x4: false),
    'Walk': EstimatedRates(entryFee: 0, localTransport: 0, visitHours: 2, requires4x4: false),
    'Valley': EstimatedRates(entryFee: 0, localTransport: 800, visitHours: 5, requires4x4: false),
    'Glacier': EstimatedRates(entryFee: 0, localTransport: 1500, visitHours: 5, requires4x4: true),

    // Built
    'Historical': EstimatedRates(entryFee: 400, localTransport: 0, visitHours: 2, requires4x4: false),
    'Culture': EstimatedRates(entryFee: 300, localTransport: 500, visitHours: 3, requires4x4: false),
    'Bazaar': EstimatedRates(entryFee: 0, localTransport: 200, visitHours: 2, requires4x4: false),
    'Food': EstimatedRates(entryFee: 0, localTransport: 200, visitHours: 2, requires4x4: false),
    'Resort': EstimatedRates(entryFee: 500, localTransport: 900, visitHours: 4, requires4x4: false),
    'Transit': EstimatedRates(entryFee: 0, localTransport: 2500, visitHours: 3, requires4x4: true),

    // Open country
    'Park': EstimatedRates(entryFee: 300, localTransport: 0, visitHours: 3, requires4x4: false),
    'Nature': EstimatedRates(entryFee: 200, localTransport: 500, visitHours: 3, requires4x4: false),
    'Desert': EstimatedRates(entryFee: 200, localTransport: 1200, visitHours: 3, requires4x4: true),
    'Beach': EstimatedRates(entryFee: 0, localTransport: 500, visitHours: 3, requires4x4: false),
    'Island': EstimatedRates(entryFee: 0, localTransport: 4000, visitHours: 8, requires4x4: false),
    'Attraction': _fallback,
  };

  static EstimatedRates forCategory(String category) =>
      _byCategory[category] ?? _fallback;

  /// Every category the estimator knows, for the settings screen and tests.
  static Iterable<String> get knownCategories => _byCategory.keys;
}
