/// Trip-wide enumerations, kept in one place so persistence can round-trip them
/// by name instead of by index.
library;

enum FuelKind {
  petrol('Petrol'),
  diesel('Diesel');

  const FuelKind(this.label);
  final String label;

  static FuelKind byName(String? name) =>
      FuelKind.values.firstWhere((e) => e.name == name, orElse: () => FuelKind.petrol);
}

enum TravelMode {
  ownVehicle('Own vehicle'),
  publicTransport('Public transport');

  const TravelMode(this.label);
  final String label;

  static TravelMode byName(String? name) =>
      TravelMode.values.firstWhere((e) => e.name == name, orElse: () => TravelMode.ownVehicle);
}

enum StayTier {
  budget('Budget', 'Guest house, shared bath', 4000),
  standard('Standard', 'Mid-range hotel room', 9000),
  premium('Premium', 'Resort or heritage stay', 20000);

  const StayTier(this.label, this.blurb, this.defaultRatePerRoomNight);
  final String label;
  final String blurb;
  final double defaultRatePerRoomNight;

  static StayTier byName(String? name) =>
      StayTier.values.firstWhere((e) => e.name == name, orElse: () => StayTier.standard);
}

enum MealTier {
  basic('Basic', 'Dhaba and local food', 1500),
  standard('Standard', 'Restaurant meals', 2800),
  premium('Premium', 'Hotel dining', 5000);

  const MealTier(this.label, this.blurb, this.defaultRatePerPersonDay);
  final String label;
  final String blurb;
  final double defaultRatePerPersonDay;

  static MealTier byName(String? name) =>
      MealTier.values.firstWhere((e) => e.name == name, orElse: () => MealTier.standard);
}

/// Severity used to colour the advisories shown on the summary screen.
enum WarningLevel { info, caution, blocker }
