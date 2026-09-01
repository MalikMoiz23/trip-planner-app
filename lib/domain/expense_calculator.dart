import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import 'package:trip_planner/core/constants.dart';
import 'package:trip_planner/core/enums.dart';
import 'package:trip_planner/core/formatters.dart';
import 'package:trip_planner/core/geo.dart';
import 'package:trip_planner/data/models/expense_breakdown.dart';
import 'package:trip_planner/data/models/route_info.dart';
import 'package:trip_planner/data/models/trip_config.dart';

/// The whole cost model, in one pure function.
///
/// Distance model: the trip is a loop. You drive from home to the first stop,
/// on to each stop in turn, and back home from the last — that is
/// `stops.length + 1` legs. From whichever stop you are based at, each chosen
/// attraction is a return day trip.
///
/// A single-destination trip is the one-stop case of exactly that: two legs,
/// out and back, which is what it always was.
class ExpenseCalculator {
  const ExpenseCalculator._();

  /// Fills in any leg the router could not supply, so one failed request costs
  /// accuracy on that leg alone rather than dropping it from the total.
  ///
  /// A leg is filled from the same road travelled the other way if that one is
  /// known, and only otherwise from a terrain-corrected straight line. The out
  /// and back of a single-destination trip are one pair of points, so while the
  /// second request was still in flight the screen used to read "out 133 km,
  /// back 106 km" — the second figure being the straight-line stand-in, sitting
  /// next to a real one with nothing to say which was which.
  static List<RouteInfo> _resolveLegs(TripConfig config, List<RouteInfo> given) {
    final points = [
      config.origin,
      for (final s in config.stops) s.destination.point,
      config.origin,
    ];
    final wanted = points.length - 1;

    bool known(int i) => i < given.length && given[i].distanceKm > 0;

    /// A known leg running between the same two points, backwards.
    int? mirrorOf(int i) {
      for (var j = 0; j < wanted; j++) {
        if (j == i || !known(j)) continue;
        if (samePoint(points[j], points[i + 1]) && samePoint(points[j + 1], points[i])) {
          return j;
        }
      }
      return null;
    }

    final out = <RouteInfo>[];
    for (var i = 0; i < wanted; i++) {
      if (known(i)) {
        out.add(given[i]);
        continue;
      }
      final mirror = mirrorOf(i);
      out.add(mirror != null
          ? given[mirror]
          : _estimate(points[i], points[i + 1], _roadFactorForLeg(config, i)));
    }
    return out;
  }

  /// Leg `i` runs to stop `i`; the last one runs home from the final stop. Each
  /// takes that stop's own terrain factor rather than the first stop's, which on
  /// a Murree-then-Skardu route had the drive home costed as if it were Murree.
  static double _roadFactorForLeg(TripConfig config, int i) {
    if (config.stops.isEmpty) return AppDefaults.fallbackRoadFactor;
    return config.stops[math.min(i, config.stops.length - 1)].destination.roadFactor;
  }

  static RouteInfo _estimate(LatLng a, LatLng b, double roadFactor) {
    final km = haversineKm(a, b) * roadFactor;
    return RouteInfo(
      distanceKm: km,
      duration: Duration(minutes: ((km / AppDefaults.fallbackAverageSpeedKmh) * 60).round()),
      estimated: true,
    );
  }

  /// [legs] runs home → stop 1 → … → stop n → home, so it holds one more entry
  /// than there are stops. A short list is tolerated and the missing legs are
  /// estimated, because a routing failure should degrade rather than throw.
  static ExpenseBreakdown compute({
    required TripConfig config,
    required List<RouteInfo> legs,
    Map<String, RouteInfo> attractionRoutes = const {},
  }) {
    final persons = math.max(1, config.persons);
    final days = math.max(1, config.days);
    final rooms = math.max(1, config.rooms);

    // Nights come from the stops, not from the day count, so an itinerary that
    // does not add up is costed as written and flagged rather than silently
    // corrected. A one-stop trip still gets days - 1.
    final nights = config.allocatedNights;

    // ---- Distance ---------------------------------------------------------
    final resolvedLegs = _resolveLegs(config, legs);
    final travelKm = resolvedLegs.fold(0.0, (sum, l) => sum + l.distanceKm);
    final travelTime = resolvedLegs.fold(
      Duration.zero,
      (sum, l) => sum + l.duration,
    );
    var routeEstimated = resolvedLegs.any((l) => l.estimated);

    /// The longest single leg — what decides whether a driving day is sane.
    final longestLeg = resolvedLegs.isEmpty
        ? Duration.zero
        : resolvedLegs.map((l) => l.duration).reduce((a, b) => a > b ? a : b);

    var attractionsKm = 0.0;
    var attractionDetourTime = Duration.zero;

    // Each stop's day trips are measured from that stop, not from the first
    // one. Getting this wrong on a four-stop route would have costed a Skardu
    // day trip as if it started in Naran.
    for (final stop in config.stops) {
      for (final a in stop.selectedAttractions) {
        final leg = attractionRoutes[a.id];
        if (leg != null && leg.distanceKm > 0) {
          attractionsKm += leg.distanceKm * 2;
          attractionDetourTime += leg.duration * 2;
          routeEstimated = routeEstimated || leg.estimated;
        } else {
          final straight = haversineKm(stop.destination.point, a.point);
          final legKm = straight * stop.destination.roadFactor;
          attractionsKm += legKm * 2;
          attractionDetourTime += Duration(
            minutes: ((legKm / AppDefaults.fallbackAverageSpeedKmh) * 60 * 2).round(),
          );
          routeEstimated = true;
        }
      }
    }

    final oneWayKm = resolvedLegs.isEmpty ? 0.0 : resolvedLegs.first.distanceKm;
    final returnKm = resolvedLegs.length < 2 ? 0.0 : resolvedLegs.last.distanceKm;
    final totalKm = travelKm + attractionsKm;
    final totalDriveTime = travelTime + attractionDetourTime;

    // ---- Travel -----------------------------------------------------------
    double litres = 0;
    double costPerKm = 0;
    double travelCost;
    String travelDetail;

    if (config.isSelfDriving) {
      // Average (km/L) and distance give litres; litres times the pump price
      // gives the bill. Every one of those four numbers is surfaced, because a
      // fuel figure nobody can reproduce is a figure nobody should trust.
      final mileage = config.mileage <= 0 ? 1 : config.mileage;
      litres = totalKm / mileage;
      travelCost = litres * config.fuelPrice;
      costPerKm = totalKm > 0 ? travelCost / totalKm : 0;
      travelDetail = '${km(totalKm)} ÷ ${config.mileage.toStringAsFixed(1)} km/L '
          '= ${litres.toStringAsFixed(1)} L, × ${moneyExact(config.fuelPrice)}/L '
          '${config.fuel.label.toLowerCase()} — about ${money(costPerKm)} per km';
    } else {
      final intercityKm = oneWayKm + returnKm;
      travelCost = intercityKm * config.publicRatePerKm * persons;
      costPerKm = intercityKm > 0 ? travelCost / intercityKm : 0;
      travelDetail = '${km(intercityKm)} return at '
          '${money(config.publicRatePerKm)}/km per person × $persons people';
    }

    // ---- Stay -------------------------------------------------------------
    final unit = config.stayStyle.unitLabel;
    final unitPlural = config.stayStyle.unitLabelPlural;
    final stayCost = nights * rooms * config.stayRatePerUnitNight;
    final String stayDetail;
    if (nights == 0) {
      stayDetail = 'Day trip, no overnight stay';
    } else if (config.stayRatePerUnitNight == 0) {
      stayDetail = '${config.stayStyle.label}: '
          '${plural(rooms, unit, unitPlural)} for ${plural(nights, 'night', 'nights')}, '
          'nothing to pay';
    } else {
      stayDetail = '${plural(nights, 'night', 'nights')} × '
          '${plural(rooms, unit, unitPlural)} × '
          '${money(config.stayRatePerUnitNight)} per $unit per night';
    }

    // ---- Food -------------------------------------------------------------
    // Summed sitting by sitting rather than from a daily average. Breakfast is
    // a fraction of dinner's price and a day on the road may hold one meal
    // rather than three, so an average would be wrong on most real trips.
    final plan = config.mealPlan;
    final mealCount = plan.sittings(persons);
    final mealsCost = plan.cost(persons);
    final kitchenCost = config.effectiveKitchenCost;

    final bySlot = plan.countBySlot();
    final mealDetail = bySlot.isEmpty
        ? 'No meals costed — nothing selected on any day'
        : '${bySlot.entries.map((e) => '${e.value}× ${e.key.label.toLowerCase()} '
            'at ${money(plan.priceOf(e.key))}').join(', ')} '
            '× $persons ${persons == 1 ? 'person' : 'people'} '
            '(${config.foodStyle.label.toLowerCase()})';

    // ---- Entries and site transport ---------------------------------------
    var entryPerPerson = 0.0;
    var siteTransportPerPerson = 0.0;
    var sightseeingHours = 0.0;
    for (final a in config.selectedAttractions) {
      entryPerPerson += a.entryFee;
      siteTransportPerPerson += a.localTransport;
      sightseeingHours += a.visitHours;
    }

    final entryCost = entryPerPerson * persons;
    final entryDetail = config.selectedAttractions.isEmpty
        ? 'No paid stops selected'
        : '${plural(config.selectedAttractions.length, 'stop', 'stops')}, '
            '${money(entryPerPerson)} per person in tickets';

    // Jeeps, boats and chairlifts are charged in both travel modes; the daily
    // taxi allowance is only charged when you are not driving yourself.
    final dailyLocal =
        config.isSelfDriving ? 0.0 : config.localTransportPerPersonDay * days * persons;
    final localTransportCost = siteTransportPerPerson * persons + dailyLocal;
    final localParts = <String>[
      if (siteTransportPerPerson > 0)
        '${money(siteTransportPerPerson)} per person in jeep and boat fares',
      if (dailyLocal > 0)
        '${money(config.localTransportPerPersonDay)} per person per day for local transport',
    ];
    final localDetail = localParts.isEmpty ? 'Nothing extra needed' : localParts.join(' + ');

    // ---- Tolls ------------------------------------------------------------
    final tollsCost = config.isSelfDriving ? config.tollsAndParking : 0.0;
    final tollDetail = config.isSelfDriving
        ? 'Motorway tolls and parking for the whole trip'
        : 'Not applicable on public transport';

    // ---- Totals -----------------------------------------------------------
    final mealCost = mealsCost + kitchenCost;
    final subtotal = travelCost + stayCost + mealCost + entryCost + localTransportCost + tollsCost;
    final bufferCost = subtotal * (config.bufferPercent / 100.0);
    final total = subtotal + bufferCost;

    final lines = <ExpenseLine>[
      ExpenseLine(
        slot: 0,
        label: config.isSelfDriving ? 'Fuel' : 'Intercity travel',
        detail: travelDetail,
        amount: travelCost,
        icon: config.isSelfDriving ? Icons.local_gas_station_rounded : Icons.directions_bus_rounded,
      ),
      ExpenseLine(
        slot: 1,
        label: config.isCamping ? 'Camping' : 'Accommodation',
        detail: stayDetail,
        amount: stayCost,
        icon: config.isCamping ? Icons.cabin_rounded : Icons.hotel_rounded,
      ),
      ExpenseLine(
        slot: 2,
        label: 'Food',
        detail: kitchenCost > 0
            ? '$mealDetail, plus ${money(kitchenCost)} for a stove and gas'
            : mealDetail,
        amount: mealCost,
        icon: config.isSelfCooking
            ? Icons.local_fire_department_rounded
            : Icons.restaurant_rounded,
      ),
      ExpenseLine(
        slot: 3,
        label: 'Entry tickets',
        detail: entryDetail,
        amount: entryCost,
        icon: Icons.confirmation_number_rounded,
      ),
      ExpenseLine(
        slot: 4,
        label: 'Local transport',
        detail: localDetail,
        amount: localTransportCost,
        icon: Icons.airport_shuttle_rounded,
      ),
      ExpenseLine(
        slot: 5,
        label: 'Tolls and parking',
        detail: tollDetail,
        amount: tollsCost,
        icon: Icons.toll_rounded,
      ),
      ExpenseLine(
        slot: 6,
        label: 'Contingency',
        detail: '${config.bufferPercent.toStringAsFixed(0)}% on top of ${money(subtotal)}',
        amount: bufferCost,
        icon: Icons.savings_rounded,
      ),
    ];

    return ExpenseBreakdown(
      oneWayKm: oneWayKm,
      returnKm: returnKm,
      attractionsKm: attractionsKm,
      totalKm: totalKm,
      litres: litres,
      costPerKm: costPerKm,
      oneWayDrive: resolvedLegs.isEmpty ? Duration.zero : resolvedLegs.first.duration,
      travelKm: travelKm,
      legKms: [for (final l in resolvedLegs) l.distanceKm],
      longestLegDrive: longestLeg,
      totalDriveTime: totalDriveTime,
      routeEstimated: routeEstimated,
      travelCost: travelCost,
      stayCost: stayCost,
      mealCost: mealCost,
      entryCost: entryCost,
      localTransportCost: localTransportCost,
      tollsCost: tollsCost,
      bufferCost: bufferCost,
      subtotal: subtotal,
      total: total,
      perPerson: total / persons,
      perDay: total / days,
      perPersonPerDay: total / (persons * days),
      nights: nights,
      rooms: rooms,
      unitLabel: unit,
      mealCount: mealCount,
      mealsCost: mealsCost,
      kitchenCost: kitchenCost,
      sightseeingHours: sightseeingHours,
      lines: lines,
      warnings: _warnings(
        config: config,
        legs: resolvedLegs,
        longestLeg: longestLeg,
        sightseeingHours: sightseeingHours,
        routeEstimated: routeEstimated,
      ),
    );
  }

  /// Minimum number of days this itinerary actually needs.
  ///
  /// Every leg costs at least a day, and a leg longer than a sane driving day
  /// costs as many days as it takes to break up. Sightseeing beyond the first
  /// day adds on top, since you can usually see something on an arrival day.
  ///
  /// For a single destination this is the two legs out and back, which is what
  /// it computed before stops existed.
  static int requiredDays({
    required TripConfig config,
    required List<RouteInfo> legs,
    required double sightseeingHours,
  }) {
    var travelDays = 0;
    for (final leg in legs) {
      final h = leg.duration.inMinutes / 60.0;
      travelDays += math.max(1, (h / AppDefaults.longDrivingDayHours).ceil());
    }
    if (travelDays == 0) travelDays = 2;

    final sightDays = sightseeingHours <= 0
        ? 0
        : (sightseeingHours / AppDefaults.maxSightseeingHoursPerDay).ceil();
    return travelDays + math.max(0, sightDays - 1);
  }

  static List<TripWarning> _warnings({
    required TripConfig config,
    required List<RouteInfo> legs,
    required Duration longestLeg,
    required double sightseeingHours,
    required bool routeEstimated,
  }) {
    final out = <TripWarning>[];
    final vehicle = AppDefaults.vehicleById(config.vehicleId);
    final oneWayHours = longestLeg.inMinutes / 60.0;

    // A route only holds together if the nights add up to the days.
    if (config.isMultiStop && config.allocatedNights != config.nights) {
      final allocated = config.allocatedNights;
      final expected = config.nights;
      out.add(TripWarning(
        WarningLevel.caution,
        'Nights do not match the days',
        'Your stops account for ${plural(allocated, 'night', 'nights')} but '
            '${plural(config.days, 'day', 'days')} means '
            '${plural(expected, 'night', 'nights')} away. The figures below use the '
            '${plural(allocated, 'night', 'nights')} you allocated, so '
            '${allocated > expected ? 'shorten a stay' : 'add a night somewhere'} '
            'or change the day count.',
      ));
    }

    if (routeEstimated) {
      out.add(const TripWarning(
        WarningLevel.info,
        'Distance is estimated',
        'The routing service could not be reached, so distance was derived from '
            'straight-line distance and the terrain factor for this route. Real road '
            'distance is usually within 15% of this figure but can be further off in '
            'the mountains.',
      ));
    }

    final needed = requiredDays(
      config: config,
      legs: legs,
      sightseeingHours: sightseeingHours,
    );
    if (config.days < needed) {
      final driveNote = config.isMultiStop
          ? '${legs.length} legs, the longest ${durationText(longestLeg)}'
          : '${durationText(longestLeg)} each way';
      out.add(TripWarning(
        WarningLevel.caution,
        'Too tight for $needed days of plan',
        'You picked ${plural(config.days, 'day', 'days')} but the driving '
            '($driveNote) plus ${hours(sightseeingHours)} of sightseeing needs about '
            '${plural(needed, 'day', 'days')}. Add days or drop a stop.',
      ));
    }

    if (!config.destination.inSeason(config.startDate) &&
        config.destination.bestMonths.isNotEmpty) {
      final months = config.destination.bestMonths.map(shortMonthName).join(', ');
      out.add(TripWarning(
        WarningLevel.caution,
        '${monthName(config.startDate.month)} is out of season',
        '${config.destination.name} is normally visited in $months. Roads and hotels '
            'may be closed outside that window.',
      ));
    }

    if (config.isSelfDriving && config.destination.requires4x4 && !vehicle.is4x4) {
      out.add(TripWarning(
        WarningLevel.caution,
        'This route wants a 4x4',
        '${config.destination.name} has unpaved sections. A ${vehicle.label.toLowerCase()} '
            'can usually reach the town but not the tracks beyond it — budget for hired '
            'jeeps, which are already included for the stops that need them.',
      ));
    }

    final needs4x4Stops =
        config.selectedAttractions.where((a) => a.requires4x4).map((a) => a.name).toList();
    if (config.isSelfDriving && !vehicle.is4x4 && needs4x4Stops.isNotEmpty) {
      out.add(TripWarning(
        WarningLevel.info,
        'Jeep needed for ${plural(needs4x4Stops.length, 'stop', 'stops')}',
        '${needs4x4Stops.join(', ')} can only be reached by 4x4. The hire cost is '
            'counted under local transport.',
      ));
    }

    if (config.isSelfDriving && config.persons > vehicle.seats) {
      out.add(TripWarning(
        WarningLevel.blocker,
        'More people than seats',
        'A ${vehicle.label.toLowerCase()} seats ${vehicle.seats}. You have '
            '${config.persons} travellers, so fuel for a single vehicle understates '
            'the real cost. Pick a bigger vehicle.',
      ));
    }

    if (oneWayHours > AppDefaults.longDrivingDayHours) {
      out.add(TripWarning(
        WarningLevel.caution,
        config.isMultiStop
            ? '${durationText(longestLeg)} on the longest leg'
            : '${durationText(longestLeg)} of driving each way',
        'That is beyond a comfortable single day. The itinerary splits it across two '
            'days — budget for the extra night if you have not already.',
      ));
    }

    if (config.destination.altitudeM >= 3000) {
      out.add(TripWarning(
        WarningLevel.info,
        'High altitude',
        '${config.destination.name} sits at ${config.destination.altitudeM} m. Allow a '
            'day to acclimatise and expect slower driving.',
      ));
    }

    final estimatedStops = config.selectedAttractions.where((a) => a.ratesEstimated).toList();
    if (estimatedStops.isNotEmpty) {
      final n = estimatedStops.length;
      final estimatedTotal =
          estimatedStops.fold<double>(0, (sum, a) => sum + a.costPerPerson()) * config.persons;
      out.add(TripWarning(
        WarningLevel.info,
        '$n ${n == 1 ? 'stop is' : 'stops are'} priced from typical rates',
        'OpenStreetMap publishes no prices, so ${n == 1 ? 'this stop' : 'these stops'} '
            '${n == 1 ? 'is' : 'are'} costed at what a place of that kind normally charges — '
            '${money(estimatedTotal)} of the total. Tap the pencil on any stop to put in a '
            'real figure.',
      ));
    }

    // Pakistan prices petrol daily, so a bundled default is wrong almost
    // immediately. Rather than quietly using a stale number, say how old it is.
    if (config.isSelfDriving && config.fuelPriceIsDefault) {
      final age = DateTime.now().difference(AppDefaults.fuelPriceAsOf).inDays;
      if (age > AppDefaults.fuelPriceStaleAfterDays) {
        out.add(TripWarning(
          WarningLevel.caution,
          'Confirm the fuel price',
          'Fuel is still at the ${moneyExact(config.fuelPrice)}/L this app shipped with, '
              'which was the rate on ${fullDate(AppDefaults.fuelPriceAsOf)} — '
              '${plural(age, 'day', 'days')} ago. Pakistan reprices petrol daily, so '
              'check the pump and put the real figure in; it moves the whole total.',
        ));
      }
    }

    if (config.isCamping && config.destination.altitudeM >= 3000) {
      out.add(TripWarning(
        WarningLevel.caution,
        'Camping at ${config.destination.altitudeM} m',
        'Nights go below freezing at this altitude even in summer. A three-season '
            'tent and bag are not enough, and there may be no shelter to retreat to.',
      ));
    }

    if (config.isSelfCooking) {
      out.add(TripWarning(
        WarningLevel.info,
        'Cooking for yourself',
        'Food is costed sitting by sitting — ${money(config.mealPlan.priceOf(MealSlot.breakfast))} '
            'a breakfast, ${money(config.mealPlan.priceOf(MealSlot.lunch))} a main meal — for '
            'groceries, plus ${money(config.campKitchenCost)} once for a stove and gas. '
            'Buy supplies in the last proper town — village shops in the valleys are '
            'small and dearer.',
      ));
    }

    if (config.bufferPercent <= 0) {
      out.add(const TripWarning(
        WarningLevel.info,
        'No contingency set',
        'Mountain trips routinely run over on fuel, weather delays and jeep hire. '
            '10% is a sensible floor.',
      ));
    }

    return out;
  }
}
