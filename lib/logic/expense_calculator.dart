import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/app_constants.dart';
import '../core/enums.dart';
import '../core/formatters.dart';
import '../core/geo.dart';
import '../models/expense_breakdown.dart';
import '../models/route_info.dart';
import '../models/trip_config.dart';

/// The whole cost model, in one pure function.
///
/// Distance model: you drive out to the base town and back, and each chosen
/// attraction is a return day-trip from that base. That matches how these
/// valleys are actually toured — you keep one hotel and radiate out — and it
/// never undercounts the way a single point-to-point line would.
class ExpenseCalculator {
  const ExpenseCalculator._();

  static ExpenseBreakdown compute({
    required TripConfig config,
    required RouteInfo outbound,
    Map<String, RouteInfo> attractionRoutes = const {},
  }) {
    final persons = math.max(1, config.persons);
    final days = math.max(1, config.days);
    final nights = config.nights;
    final rooms = math.max(1, config.rooms);

    // ---- Distance ---------------------------------------------------------
    final oneWayKm = outbound.distanceKm;
    final returnKm = oneWayKm;

    var attractionsKm = 0.0;
    var attractionDetourTime = Duration.zero;
    var routeEstimated = outbound.estimated;

    for (final a in config.selectedAttractions) {
      final leg = attractionRoutes[a.id];
      if (leg != null && leg.distanceKm > 0) {
        attractionsKm += leg.distanceKm * 2;
        attractionDetourTime += leg.duration * 2;
        routeEstimated = routeEstimated || leg.estimated;
      } else {
        // No routed leg for this stop — fall back to straight line for it only.
        final straight = haversineKm(config.destination.point, a.point);
        final legKm = straight * config.destination.roadFactor;
        attractionsKm += legKm * 2;
        attractionDetourTime += Duration(
          minutes: ((legKm / AppDefaults.fallbackAverageSpeedKmh) * 60 * 2).round(),
        );
        routeEstimated = true;
      }
    }

    final totalKm = oneWayKm + returnKm + attractionsKm;
    final totalDriveTime = outbound.duration * 2 + attractionDetourTime;

    // ---- Travel -----------------------------------------------------------
    double litres = 0;
    double travelCost;
    String travelDetail;

    if (config.isSelfDriving) {
      final mileage = config.mileage <= 0 ? 1 : config.mileage;
      litres = totalKm / mileage;
      travelCost = litres * config.fuelPrice;
      travelDetail = '${km(totalKm)} round trip at ${config.mileage.toStringAsFixed(1)} km/L, '
          '${litres.toStringAsFixed(1)} L of ${config.fuel.label.toLowerCase()} '
          'at ${money(config.fuelPrice)}/L';
    } else {
      final intercityKm = oneWayKm + returnKm;
      travelCost = intercityKm * config.publicRatePerKm * persons;
      travelDetail = '${km(intercityKm)} return by road at '
          '${money(config.publicRatePerKm)}/km per person x $persons';
    }

    // ---- Stay -------------------------------------------------------------
    final stayCost = nights * rooms * config.stayRatePerRoomNight;
    final stayDetail = nights == 0
        ? 'Day trip, no overnight stay'
        : '${plural(nights, 'night', 'nights')} x '
            '${plural(rooms, 'room', 'rooms')} at ${money(config.stayRatePerRoomNight)}/night';

    // ---- Meals ------------------------------------------------------------
    final mealCost = days * persons * config.mealRatePerPersonDay;
    final mealDetail = '${plural(days, 'day', 'days')} x $persons people at '
        '${money(config.mealRatePerPersonDay)} per person per day';

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
        label: 'Accommodation',
        detail: stayDetail,
        amount: stayCost,
        icon: Icons.hotel_rounded,
      ),
      ExpenseLine(
        slot: 2,
        label: 'Food',
        detail: mealDetail,
        amount: mealCost,
        icon: Icons.restaurant_rounded,
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
      oneWayDrive: outbound.duration,
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
      sightseeingHours: sightseeingHours,
      lines: lines,
      warnings: _warnings(
        config: config,
        outbound: outbound,
        sightseeingHours: sightseeingHours,
        routeEstimated: routeEstimated,
      ),
    );
  }

  /// Minimum number of days this itinerary actually needs.
  static int requiredDays({
    required TripConfig config,
    required RouteInfo outbound,
    required double sightseeingHours,
  }) {
    final oneWayHours = outbound.duration.inMinutes / 60.0;
    final travelDaysEachWay = oneWayHours > AppDefaults.longDrivingDayHours ? 2 : 1;
    final sightDays = sightseeingHours <= 0
        ? 0
        : (sightseeingHours / AppDefaults.maxSightseeingHoursPerDay).ceil();
    return travelDaysEachWay * 2 + math.max(0, sightDays - 1);
  }

  static List<TripWarning> _warnings({
    required TripConfig config,
    required RouteInfo outbound,
    required double sightseeingHours,
    required bool routeEstimated,
  }) {
    final out = <TripWarning>[];
    final vehicle = AppDefaults.vehicleById(config.vehicleId);
    final oneWayHours = outbound.duration.inMinutes / 60.0;

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
      outbound: outbound,
      sightseeingHours: sightseeingHours,
    );
    if (config.days < needed) {
      out.add(TripWarning(
        WarningLevel.caution,
        'Too tight for $needed days of plan',
        'You picked ${plural(config.days, 'day', 'days')} but the drive '
            '(${durationText(outbound.duration)} each way) plus '
            '${hours(sightseeingHours)} of sightseeing needs about '
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
        '${durationText(outbound.duration)} of driving each way',
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

    final liveStops = config.selectedAttractions.where((a) => a.isLive).length;
    if (liveStops > 0) {
      out.add(TripWarning(
        WarningLevel.info,
        '$liveStops ${liveStops == 1 ? 'stop has' : 'stops have'} no cost data',
        'These came from OpenStreetMap, which does not publish prices, so they are '
            'costed at zero. Edit their fees to make the total accurate.',
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
