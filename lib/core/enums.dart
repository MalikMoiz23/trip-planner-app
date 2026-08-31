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

/// Where you sleep. The rate is per unit per night — a unit being a room, or a
/// tent when camping.
///
/// Carrying your own tent is the one genuinely free option, so it is priced at
/// zero rather than hidden behind a tier.
enum StayStyle {
  ownTent('Own tent', 'You carry it — nothing to pay per night', 0, 3, true),
  rentedTent('Rented tent', 'Hired at the campsite, per tent', 2500, 3, true),
  guestHouse('Guest house', 'Basic room, often a shared bath', 5000, 2, false),
  hotel('Hotel', 'Mid-range room', 11000, 2, false),
  resort('Resort', 'Resort or heritage property', 25000, 2, false);

  const StayStyle(
    this.label,
    this.blurb,
    this.defaultRatePerUnitNight,
    this.defaultOccupancy,
    this.isCamping,
  );

  final String label;
  final String blurb;

  /// Per room, or per tent when [isCamping].
  final double defaultRatePerUnitNight;

  /// How many people normally share one unit.
  final int defaultOccupancy;
  final bool isCamping;

  /// "room" or "tent", for copy that has to name the unit.
  String get unitLabel => isCamping ? 'tent' : 'room';
  String get unitLabelPlural => isCamping ? 'tents' : 'rooms';

  bool get isFree => defaultRatePerUnitNight == 0;

  static StayStyle byName(String? name) =>
      StayStyle.values.firstWhere((e) => e.name == name, orElse: () => StayStyle.hotel);

  /// Maps the three tiers this app shipped with before tents existed, so a trip
  /// saved under the old schema still opens.
  static StayStyle fromLegacyTier(String? tier) => switch (tier) {
        'budget' => StayStyle.guestHouse,
        'premium' => StayStyle.resort,
        _ => StayStyle.hotel,
      };
}

/// How you eat. Priced per person per meal so that the number of meals a day
/// drives the bill for every option, cooking included.
enum FoodStyle {
  selfCooking('Self-cooking', 'Groceries you cook yourself', 350, true),
  dhaba('Dhaba', 'Roadside and local places', 600, false),
  restaurant('Restaurant', 'Mid-range sit-down meal', 1200, false),
  hotelDining('Hotel dining', 'Eating where you are staying', 2200, false);

  const FoodStyle(this.label, this.blurb, this.defaultPricePerMeal, this.needsKitchen);

  final String label;
  final String blurb;

  /// Per person, per meal.
  final double defaultPricePerMeal;

  /// True when the style implies carrying a stove, gas and utensils, which is a
  /// one-off cost for the trip rather than a per-meal one.
  final bool needsKitchen;

  static FoodStyle byName(String? name) =>
      FoodStyle.values.firstWhere((e) => e.name == name, orElse: () => FoodStyle.restaurant);

  /// Maps the three tiers this app shipped with before cooking existed.
  static FoodStyle fromLegacyTier(String? tier) => switch (tier) {
        'basic' => FoodStyle.dhaba,
        'premium' => FoodStyle.hotelDining,
        _ => FoodStyle.restaurant,
      };
}

/// Severity used to colour the advisories shown on the summary screen.
enum WarningLevel { info, caution, blocker }

/// One sitting in a day, priced on its own.
///
/// A single "meals per day" number could not say what people actually do on a
/// road trip: breakfast at the hotel is a fraction of the price of dinner, and
/// on a long driving day you often skip a midday stop entirely and eat once at
/// five or six. So a day is a set of these rather than a count, and each
/// carries its own price.
enum MealSlot {
  breakfast(
    'Breakfast',
    'Early, and usually the cheapest of the day',
    'around 7–9am',
    0.55,
  ),
  lunch(
    'Lunch',
    'A midday stop',
    'around 12–2pm',
    1.0,
  ),
  dinner(
    'Dinner',
    'The evening meal',
    'around 8–10pm',
    1.0,
  ),

  /// The one meal that replaces two. Common on a driving day: you reach
  /// somewhere at five or six, eat properly, and that is the day done.
  lunchDinner(
    'Lunch and dinner together',
    'One bigger meal instead of two, late afternoon',
    'around 5–6pm',
    1.4,
  );

  const MealSlot(this.label, this.blurb, this.timeHint, this.priceFactor);

  final String label;
  final String blurb;

  /// When this sitting normally happens, so the choice reads as a real day.
  final String timeHint;

  /// Starting price relative to the food style's per-meal figure. Breakfast is
  /// cheaper, a combined meal dearer than one but cheaper than two.
  final double priceFactor;

  bool get replacesTwo => this == MealSlot.lunchDinner;

  /// Choosing a combined meal and also a separate lunch or dinner is
  /// contradictory, so picking one clears the others.
  Set<MealSlot> get conflicts => switch (this) {
        MealSlot.lunchDinner => {MealSlot.lunch, MealSlot.dinner},
        MealSlot.lunch || MealSlot.dinner => {MealSlot.lunchDinner},
        MealSlot.breakfast => const {},
      };

  static MealSlot byName(String? name) =>
      MealSlot.values.firstWhere((e) => e.name == name, orElse: () => MealSlot.lunch);
}
