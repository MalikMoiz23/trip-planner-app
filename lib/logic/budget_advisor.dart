import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/enums.dart';
import '../core/formatters.dart';
import '../models/route_info.dart';
import '../models/trip_config.dart';
import 'expense_calculator.dart';

/// One concrete change, with what it actually saves on this trip.
///
/// The saving is measured, not estimated: the trip is re-costed with the change
/// applied and the two totals subtracted. That matters because the levers
/// interact — dropping a day removes a night *and* three meals per person — and
/// a hand-written rule of thumb would quietly get that wrong.
class BudgetLever {
  const BudgetLever({
    required this.id,
    required this.title,
    required this.detail,
    required this.saving,
    required this.icon,
    required this.apply,
  });

  final String id;
  final String title;

  /// What changes, in plain words.
  final String detail;

  /// Rupees off the total. Always positive; a change that costs more is not
  /// offered.
  final double saving;

  final IconData icon;

  /// Mutates a config into the cheaper variant. Held so the UI can offer to
  /// apply it rather than making the user reproduce it by hand.
  final TripConfig Function(TripConfig) apply;
}

/// Whether the trip fits, and what to do about it if not.
class BudgetAdvice {
  const BudgetAdvice({
    required this.budget,
    required this.total,
    required this.levers,
    required this.reachable,
  });

  final double budget;
  final double total;

  /// Ordered by saving, largest first.
  final List<BudgetLever> levers;

  /// True when the offered levers together close the gap.
  final bool reachable;

  bool get fits => total <= budget;
  double get gap => math.max(0, total - budget);
  double get headroom => math.max(0, budget - total);

  /// 0 to 1+, for the meter. Values over 1 mean over budget.
  double get ratio => budget <= 0 ? 0 : total / budget;

  /// The smallest set of levers that closes the gap, greedily by size.
  List<BudgetLever> get minimalSet {
    if (fits) return const [];
    final chosen = <BudgetLever>[];
    var saved = 0.0;
    for (final lever in levers) {
      if (saved >= gap) break;
      chosen.add(lever);
      saved += lever.saving;
    }
    return chosen;
  }
}

/// Works out how to bring a trip inside a budget.
class BudgetAdvisor {
  const BudgetAdvisor._();

  /// Re-costs the trip under each candidate change and keeps the ones that
  /// genuinely save money.
  static BudgetAdvice advise({
    required TripConfig config,
    required RouteInfo outbound,
    required Map<String, RouteInfo> attractionRoutes,
    required double budget,
  }) {
    double totalOf(TripConfig c) => ExpenseCalculator.compute(
          config: c,
          outbound: outbound,
          attractionRoutes: attractionRoutes,
        ).total;

    final baseline = totalOf(config);
    final levers = <BudgetLever>[];

    void consider({
      required String id,
      required String title,
      required String detail,
      required IconData icon,
      required TripConfig Function(TripConfig) apply,
    }) {
      final TripConfig variant;
      try {
        variant = apply(config);
      } on Exception {
        return;
      }
      final saving = baseline - totalOf(variant);
      // A percent or two is noise, not advice.
      if (saving < baseline * 0.01 || saving <= 0) return;
      levers.add(BudgetLever(
        id: id,
        title: title,
        detail: detail,
        saving: saving,
        icon: icon,
        apply: apply,
      ));
    }

    // ---- Shorten the trip -------------------------------------------------
    if (config.days > 1) {
      consider(
        id: 'one-fewer-day',
        title: 'Go for ${plural(config.days - 1, 'day', 'days')} instead',
        detail: 'One night less, and ${config.persons * config.mealsPerDay} fewer meals.',
        icon: Icons.event_busy_rounded,
        apply: (c) => c.copyWith(days: c.days - 1),
      );
    }

    // ---- Sleep cheaper ----------------------------------------------------
    for (final style in StayStyle.values) {
      if (style.defaultRatePerUnitNight >= config.stayRatePerUnitNight) continue;
      if (config.nights == 0) break;
      consider(
        id: 'stay-${style.name}',
        title: style.isFree ? 'Camp in your own tent' : 'Stay in a ${style.label.toLowerCase()}',
        detail: style.isFree
            ? 'Accommodation drops out of the total entirely.'
            : '${money(style.defaultRatePerUnitNight)} a night instead of '
                '${money(config.stayRatePerUnitNight)}.',
        icon: style.isCamping ? Icons.cabin_rounded : Icons.hotel_rounded,
        apply: (c) => c.copyWith(
          stayStyle: style,
          stayRatePerUnitNight: style.defaultRatePerUnitNight,
          roomOccupancy: style.defaultOccupancy,
        ),
      );
    }

    // ---- Share rooms ------------------------------------------------------
    if (config.persons > config.roomOccupancy && config.nights > 0) {
      final tighter = math.min(config.roomOccupancy + 1, 6);
      consider(
        id: 'share-rooms',
        title: 'Put $tighter people in a ${config.stayStyle.unitLabel}',
        detail: 'Fewer ${config.stayStyle.unitLabelPlural} to pay for each night.',
        icon: Icons.groups_rounded,
        apply: (c) => c.copyWith(roomOccupancy: tighter),
      );
    }

    // ---- Eat cheaper ------------------------------------------------------
    for (final style in FoodStyle.values) {
      if (style.defaultPricePerMeal >= config.pricePerMeal) continue;
      consider(
        id: 'food-${style.name}',
        title: style == FoodStyle.selfCooking
            ? 'Cook for yourselves'
            : 'Eat at ${style.label.toLowerCase()} level',
        detail: '${money(style.defaultPricePerMeal)} a meal instead of '
            '${money(config.pricePerMeal)}'
            '${style.needsKitchen ? ', after a one-off stove and gas' : ''}.',
        icon: style.needsKitchen
            ? Icons.local_fire_department_rounded
            : Icons.restaurant_rounded,
        apply: (c) => c.copyWith(
          foodStyle: style,
          pricePerMeal: style.defaultPricePerMeal,
        ),
      );
    }

    if (config.mealsPerDay > 2) {
      consider(
        id: 'fewer-meals',
        title: 'Budget for ${config.mealsPerDay - 1} meals a day',
        detail: 'Breakfast at the hotel, one proper meal, snacks in between.',
        icon: Icons.no_meals_rounded,
        apply: (c) => c.copyWith(mealsPerDay: c.mealsPerDay - 1),
      );
    }

    // ---- Drop the priciest stop -------------------------------------------
    if (config.selectedAttractions.isNotEmpty) {
      final dearest = [...config.selectedAttractions]
        ..sort((a, b) => b.costPerPerson().compareTo(a.costPerPerson()));
      final drop = dearest.first;
      if (drop.costPerPerson() > 0) {
        consider(
          id: 'drop-${drop.id}',
          title: 'Skip ${drop.name}',
          detail: '${money(drop.costPerPerson())} per person in tickets and fares, '
              'plus the fuel to get there.',
          icon: Icons.remove_circle_outline_rounded,
          apply: (c) => c.copyWith(
            selectedAttractions:
                c.selectedAttractions.where((a) => a.id != drop.id).toList(),
          ),
        );
      }
    }

    // ---- Travel differently ------------------------------------------------
    if (config.isSelfDriving) {
      consider(
        id: 'public-transport',
        title: 'Take public transport',
        detail: 'No fuel or tolls, but a daily allowance for taxis once there.',
        icon: Icons.directions_bus_rounded,
        apply: (c) => c.copyWith(mode: TravelMode.publicTransport),
      );
    }

    // ---- Trim the contingency ----------------------------------------------
    // Offered last and deliberately framed as a worse idea than the others: it
    // does not make the trip cheaper, only the estimate smaller.
    if (config.bufferPercent > 10) {
      consider(
        id: 'buffer-10',
        title: 'Hold a 10% contingency instead of '
            '${config.bufferPercent.toStringAsFixed(0)}%',
        detail: 'This does not make the trip cheaper — it only budgets less slack '
            'for things going wrong.',
        icon: Icons.savings_outlined,
        apply: (c) => c.copyWith(bufferPercent: 10),
      );
    }

    levers.sort((a, b) => b.saving.compareTo(a.saving));

    final gap = math.max(0.0, baseline - budget);
    final bestCase = levers.fold<double>(0, (sum, l) => sum + l.saving);

    return BudgetAdvice(
      budget: budget,
      total: baseline,
      levers: levers,
      // Savings do not strictly add — applying two overlapping levers saves less
      // than the sum — so this is an optimistic bound, and the UI says as much
      // rather than promising the trip can be squeezed to fit.
      reachable: bestCase >= gap,
    );
  }
}
