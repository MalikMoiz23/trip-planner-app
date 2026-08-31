import 'package:trip_planner/core/enums.dart';

/// What gets eaten on each day of the trip, and what each sitting costs.
///
/// Replaces a single "meals per day" number, which could not describe a real
/// trip: two meals on the day you drive out, one on the day you drive home,
/// breakfast at a fraction of dinner's price, and sometimes one combined meal
/// at five or six instead of both.
///
/// [days] is one entry per day of the trip, in order. [prices] is per person
/// per sitting.
class MealPlan {
  const MealPlan({required this.days, required this.prices});

  /// The sittings taken on each day. Index 0 is day one.
  final List<Set<MealSlot>> days;

  /// Per person, per sitting. Every slot has an entry so the UI never has to
  /// guess a missing one.
  final Map<MealSlot, double> prices;

  /// A sensible starting plan: full days in the middle, lighter on the days you
  /// are mostly in the car.
  ///
  /// [basePrice] is the food style's per-meal figure; each slot scales off it,
  /// so switching from dhaba to hotel dining moves every sitting at once.
  factory MealPlan.standard({required int dayCount, required double basePrice}) {
    final total = dayCount < 1 ? 1 : dayCount;
    return MealPlan(
      days: [
        for (var i = 0; i < total; i++) _defaultDay(i, total),
      ],
      prices: {
        for (final slot in MealSlot.values) slot: basePrice * slot.priceFactor,
      },
    );
  }

  /// Departure day: you leave after breakfast and eat once on the road.
  /// Return day: breakfast then home. Everything between is a full day.
  static Set<MealSlot> _defaultDay(int index, int total) {
    if (total == 1) return {MealSlot.lunchDinner};
    if (index == 0) return {MealSlot.breakfast, MealSlot.lunchDinner};
    if (index == total - 1) return {MealSlot.breakfast, MealSlot.lunch};
    return {MealSlot.breakfast, MealSlot.lunch, MealSlot.dinner};
  }

  double priceOf(MealSlot slot) => prices[slot] ?? 0;

  /// Sittings across the whole trip for one person.
  int get sittingsPerPerson => days.fold(0, (n, day) => n + day.length);

  /// Total sittings paid for, all travellers.
  int sittings(int persons) => sittingsPerPerson * persons;

  /// The food bill for [persons], before any one-off kitchen kit.
  double cost(int persons) {
    var total = 0.0;
    for (final day in days) {
      for (final slot in day) {
        total += priceOf(slot) * persons;
      }
    }
    return total;
  }

  /// How many of each sitting the trip holds, for a breakdown that explains
  /// itself rather than showing one lump figure.
  Map<MealSlot, int> countBySlot() {
    final out = <MealSlot, int>{};
    for (final day in days) {
      for (final slot in day) {
        out[slot] = (out[slot] ?? 0) + 1;
      }
    }
    return out;
  }

  /// Grown or trimmed to match a new day count.
  ///
  /// Days already chosen are kept as they are — changing the trip length should
  /// not silently rewrite decisions already made about the days that remain.
  /// New days copy the pattern the standard plan would use for that position.
  MealPlan resized(int dayCount) {
    final total = dayCount < 1 ? 1 : dayCount;
    if (total == days.length) return this;

    return MealPlan(
      days: [
        for (var i = 0; i < total; i++)
          if (i < days.length) days[i] else _defaultDay(i, total),
      ],
      prices: prices,
    );
  }

  /// Adds or removes one sitting on one day, clearing anything it contradicts.
  MealPlan toggled(int dayIndex, MealSlot slot) {
    if (dayIndex < 0 || dayIndex >= days.length) return this;

    final next = [for (final d in days) {...d}];
    final day = next[dayIndex];

    if (day.contains(slot)) {
      day.remove(slot);
    } else {
      day.removeAll(slot.conflicts);
      day.add(slot);
    }

    return MealPlan(days: next, prices: prices);
  }

  MealPlan withPrice(MealSlot slot, double value) => MealPlan(
        days: days,
        prices: {...prices, slot: value < 0 ? 0 : value},
      );

  /// Rebases every price on a new per-meal figure, keeping the day pattern.
  /// Used when the food style changes.
  MealPlan rebased(double basePrice) => MealPlan(
        days: days,
        prices: {
          for (final slot in MealSlot.values) slot: basePrice * slot.priceFactor,
        },
      );

  /// Copies one day's choices onto every other day.
  MealPlan appliedToAll(int dayIndex) {
    if (dayIndex < 0 || dayIndex >= days.length) return this;
    final pattern = {...days[dayIndex]};
    return MealPlan(
      days: [for (var i = 0; i < days.length; i++) {...pattern}],
      prices: prices,
    );
  }

  Map<String, dynamic> toJson() => {
        'days': [
          for (final day in days) [for (final slot in day) slot.name],
        ],
        'prices': {
          for (final entry in prices.entries) entry.key.name: entry.value,
        },
      };

  factory MealPlan.fromJson(Map<String, dynamic> j) {
    final rawDays = (j['days'] as List?) ?? const [];
    final rawPrices = (j['prices'] as Map?) ?? const {};

    return MealPlan(
      days: [
        for (final day in rawDays)
          {
            for (final slot in (day as List? ?? const []))
              MealSlot.byName(slot as String?),
          },
      ],
      prices: {
        for (final slot in MealSlot.values)
          slot: (rawPrices[slot.name] as num?)?.toDouble() ?? 0,
      },
    );
  }

  /// Rebuilds a plan from the single-number schema this replaced, so a trip
  /// saved before per-day meals existed still opens and still costs the same.
  factory MealPlan.fromLegacy({
    required int dayCount,
    required int mealsPerDay,
    required double pricePerMeal,
  }) {
    final total = dayCount < 1 ? 1 : dayCount;
    // The old figure was a flat count with one price, so it is reproduced as
    // the same sittings every day at the same price rather than pretending to
    // know which meals they were.
    final slots = <MealSlot>[
      if (mealsPerDay >= 1) MealSlot.lunch,
      if (mealsPerDay >= 2) MealSlot.breakfast,
      if (mealsPerDay >= 3) MealSlot.dinner,
    ];

    return MealPlan(
      days: [for (var i = 0; i < total; i++) {...slots}],
      prices: {
        // Flat: the old model charged the same for every sitting, and changing
        // that here would change what a saved trip costs.
        for (final slot in MealSlot.values) slot: pricePerMeal,
      },
    );
  }
}
