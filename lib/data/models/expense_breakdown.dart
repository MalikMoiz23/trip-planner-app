import 'package:flutter/material.dart';

import 'package:trip_planner/core/enums.dart';

class ExpenseLine {
  const ExpenseLine({
    required this.slot,
    required this.label,
    required this.detail,
    required this.amount,
    required this.icon,
  });

  /// Fixed categorical slot. The colour is resolved at paint time from the
  /// theme's series palette, so a category keeps its hue in light and dark and
  /// re-sorting the legend never reassigns colours.
  final int slot;

  final String label;

  /// The arithmetic behind the number, spelled out so nothing looks invented.
  final String detail;
  final double amount;
  final IconData icon;
}

class TripWarning {
  const TripWarning(this.level, this.title, this.detail);

  final WarningLevel level;
  final String title;
  final String detail;
}

class ExpenseBreakdown {
  const ExpenseBreakdown({
    required this.oneWayKm,
    required this.returnKm,
    required this.attractionsKm,
    required this.totalKm,
    required this.travelKm,
    required this.legKms,
    required this.longestLegDrive,
    required this.litres,
    required this.costPerKm,
    required this.oneWayDrive,
    required this.totalDriveTime,
    required this.routeEstimated,
    required this.travelCost,
    required this.stayCost,
    required this.mealCost,
    required this.entryCost,
    required this.localTransportCost,
    required this.tollsCost,
    required this.bufferCost,
    required this.subtotal,
    required this.total,
    required this.perPerson,
    required this.perDay,
    required this.perPersonPerDay,
    required this.nights,
    required this.rooms,
    required this.unitLabel,
    required this.mealCount,
    required this.mealsCost,
    required this.kitchenCost,
    required this.sightseeingHours,
    required this.lines,
    required this.warnings,
  });

  final double oneWayKm;
  final double returnKm;

  /// Sum of the round-trip detours from the base town out to each chosen spot.
  final double attractionsKm;
  final double totalKm;

  /// The point-to-point driving: home to the first stop, between the stops,
  /// home again. Excludes day trips out and back from a base.
  final double travelKm;

  /// One entry per leg, in order. Holds one more than there are stops.
  final List<double> legKms;

  /// The longest single leg. On a route it is this, not the total, that decides
  /// whether a driving day is realistic.
  final Duration longestLegDrive;
  final double litres;

  /// What a kilometre actually costs on this trip, fuel or fare.
  final double costPerKm;

  final Duration oneWayDrive;
  final Duration totalDriveTime;

  /// True when any leg fell back to straight-line estimation.
  final bool routeEstimated;

  final double travelCost;
  final double stayCost;
  final double mealCost;
  final double entryCost;
  final double localTransportCost;
  final double tollsCost;
  final double bufferCost;

  final double subtotal;
  final double total;
  final double perPerson;
  final double perDay;
  final double perPersonPerDay;

  final int nights;

  /// Rooms, or tents when camping.
  final int rooms;

  /// "room" or "tent", so copy can name the unit correctly.
  final String unitLabel;

  /// Meals bought or cooked across the whole trip.
  final int mealCount;

  /// The meals alone, before any one-off kitchen kit.
  final double mealsCost;

  /// Stove, gas and utensils. Zero unless self-cooking.
  final double kitchenCost;
  final double sightseeingHours;

  final List<ExpenseLine> lines;
  final List<TripWarning> warnings;

  /// Non-zero lines only, largest first — what the bar chart and legend render.
  List<ExpenseLine> get visibleLines {
    final list = lines.where((l) => l.amount > 0).toList()
      ..sort((a, b) => b.amount.compareTo(a.amount));
    return list;
  }

  double shareOf(ExpenseLine line) => total <= 0 ? 0 : line.amount / total;
}
