import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:trip_planner/core/constants.dart';
import 'package:trip_planner/core/formatters.dart';
import 'package:trip_planner/core/geo.dart';
import 'package:trip_planner/core/theme.dart';
import 'package:trip_planner/data/models/itinerary.dart';
import 'package:trip_planner/data/models/route_info.dart';
import 'package:trip_planner/data/models/trip_config.dart';

/// Turns the chosen stops into a day-by-day plan.
///
/// Rules: the first and last days belong to the drive, a drive longer than
/// [AppDefaults.longDrivingDayHours] consumes two days, and each remaining day
/// takes stops until it hits the sightseeing ceiling.
class ItineraryBuilder {
  const ItineraryBuilder._();

  static List<ItineraryDay> build({
    required TripConfig config,
    required RouteInfo outbound,
    Map<String, RouteInfo> attractionRoutes = const {},
  }) {
    final days = math.max(1, config.days);
    final oneWayHours = outbound.duration.inMinutes / 60.0;
    final splitDrive = oneWayHours > AppDefaults.longDrivingDayHours;

    final outboundDays = splitDrive ? 2 : 1;
    final returnDays = splitDrive ? 2 : 1;

    final result = <ItineraryDay>[];
    var cursor = 1;

    // ---- Outbound ---------------------------------------------------------
    if (splitDrive && days >= 3) {
      final half = outbound.duration ~/ 2;
      result.add(_day(config, cursor++, 'Drive out, day 1', [
        ItineraryItem(
          title: 'Leave ${config.originName}',
          subtitle: 'About ${durationText(half)} on the road, roughly '
              '${km(outbound.distanceKm / 2)}',
          icon: Icons.trip_origin_rounded,
          hours: half.inMinutes / 60.0,
        ),
        const ItineraryItem(
          title: 'Overnight stop en route',
          subtitle: 'Break the drive rather than arriving after dark',
          icon: Icons.nightlight_round,
          hours: 0,
        ),
      ]));
      result.add(_day(config, cursor++, 'Arrive ${config.destination.name}', [
        ItineraryItem(
          title: 'Finish the drive',
          subtitle: 'Remaining ${durationText(half)} to ${config.destination.name}',
          icon: Icons.directions_car_filled_rounded,
          hours: half.inMinutes / 60.0,
        ),
        _checkIn(config),
      ]));
    } else {
      result.add(_day(config, cursor++, 'Travel to ${config.destination.name}', [
        ItineraryItem(
          title: '${config.originName} to ${config.destination.name}',
          subtitle: '${km(outbound.distanceKm)}, about '
              '${durationText(outbound.duration)} of driving',
          icon: config.isSelfDriving
              ? Icons.directions_car_filled_rounded
              : Icons.directions_bus_filled_rounded,
          hours: oneWayHours,
        ),
        _checkIn(config),
      ]));
    }

    // ---- Sightseeing ------------------------------------------------------
    final sightseeingDays = days - outboundDays - returnDays;
    final stops = [...config.selectedAttractions]
      ..sort((a, b) => b.visitHours.compareTo(a.visitHours));

    if (sightseeingDays > 0) {
      final buckets = List.generate(sightseeingDays, (_) => <ItineraryItem>[]);
      final loads = List.filled(sightseeingDays, 0.0);

      for (final stop in stops) {
        // Put each stop in the emptiest day that still has room; if none does,
        // the emptiest day takes it anyway and the day simply reads as full.
        var target = 0;
        for (var i = 1; i < sightseeingDays; i++) {
          if (loads[i] < loads[target]) target = i;
        }
        if (loads[target] + stop.visitHours > AppDefaults.maxSightseeingHoursPerDay &&
            loads[target] > 0) {
          for (var i = 0; i < sightseeingDays; i++) {
            if (loads[i] + stop.visitHours <= AppDefaults.maxSightseeingHoursPerDay) {
              target = i;
              break;
            }
          }
        }

        final leg = attractionRoutes[stop.id];
        final legKm = leg?.distanceKm ??
            haversineKm(config.destination.point, stop.point) * config.destination.roadFactor;
        final perPerson = stop.costPerPerson();

        buckets[target].add(ItineraryItem(
          title: stop.name,
          subtitle: [
            '${km(legKm)} from ${config.destination.name}',
            hours(stop.visitHours),
            if (perPerson > 0) '${money(perPerson)} per person',
            if (stop.requires4x4) 'jeep required',
          ].join('  ·  '),
          icon: AppColors.iconFor(stop.category),
          hours: stop.visitHours,
        ));
        loads[target] += stop.visitHours;
      }

      for (var i = 0; i < sightseeingDays; i++) {
        final items = buckets[i];
        result.add(_day(
          config,
          cursor++,
          items.isEmpty ? 'Free day in ${config.destination.name}' : 'Explore',
          items.isEmpty
              ? [
                  ItineraryItem(
                    title: 'Nothing scheduled',
                    subtitle: 'Rest day, local bazaar, or add a stop from the planner',
                    icon: Icons.self_improvement_rounded,
                    hours: 0,
                  ),
                ]
              : items,
        ));
      }
    } else if (stops.isNotEmpty) {
      // No dedicated day survived — attach the stops to the arrival day so they
      // are visible rather than silently dropped.
      final squeezed = stops
          .map((s) => ItineraryItem(
                title: s.name,
                subtitle: '${hours(s.visitHours)}  ·  no free day for this, '
                    'add days to fit it properly',
                icon: AppColors.iconFor(s.category),
                hours: s.visitHours,
              ))
          .toList();
      result.last = ItineraryDay(
        dayNumber: result.last.dayNumber,
        date: result.last.date,
        title: result.last.title,
        items: [...result.last.items, ...squeezed],
      );
    }

    // ---- Return -----------------------------------------------------------
    while (result.length < days) {
      final isLast = result.length == days - 1;
      if (splitDrive && !isLast) {
        result.add(_day(config, cursor++, 'Drive back, day 1', [
          ItineraryItem(
            title: 'Leave ${config.destination.name}',
            subtitle: 'About ${durationText(outbound.duration ~/ 2)} to the overnight stop',
            icon: Icons.logout_rounded,
            hours: (outbound.duration ~/ 2).inMinutes / 60.0,
          ),
        ]));
      } else {
        result.add(_day(config, cursor++, 'Return to ${config.originName}', [
          ItineraryItem(
            title: '${config.destination.name} to ${config.originName}',
            subtitle: '${km(outbound.distanceKm)}, about '
                '${durationText(outbound.duration)} of driving',
            icon: Icons.home_rounded,
            hours: oneWayHours,
          ),
        ]));
      }
    }

    return result.take(days).toList(growable: false);
  }

  static ItineraryItem _checkIn(TripConfig config) {
    final unit = config.stayStyle.unitLabel;
    final unitPlural = config.stayStyle.unitLabelPlural;
    final String subtitle;
    if (config.nights == 0) {
      subtitle = 'No overnight stay in this plan';
    } else if (config.stayRatePerUnitNight == 0) {
      subtitle = '${plural(config.rooms, unit, unitPlural)}, '
          '${config.stayStyle.label.toLowerCase()} — nothing to pay';
    } else {
      subtitle = '${plural(config.rooms, unit, unitPlural)} at '
          '${config.stayStyle.label.toLowerCase()} rate, '
          '${money(config.stayRatePerUnitNight)} per $unit per night';
    }

    return ItineraryItem(
      title: config.nights == 0
          ? 'Turn around same day'
          : (config.isCamping ? 'Pitch camp' : 'Check in'),
      subtitle: subtitle,
      icon: config.nights == 0
          ? Icons.u_turn_left_rounded
          : (config.isCamping ? Icons.cabin_rounded : Icons.hotel_rounded),
      hours: 0,
    );
  }

  static ItineraryDay _day(TripConfig config, int number, String title, List<ItineraryItem> items) =>
      ItineraryDay(
        dayNumber: number,
        date: config.startDate.add(Duration(days: number - 1)),
        title: title,
        items: items,
      );
}
