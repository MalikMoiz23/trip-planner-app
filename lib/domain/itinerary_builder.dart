import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:trip_planner/core/constants.dart';
import 'package:trip_planner/core/formatters.dart';
import 'package:trip_planner/core/geo.dart';
import 'package:trip_planner/core/theme.dart';
import 'package:trip_planner/data/models/itinerary.dart';
import 'package:trip_planner/data/models/route_info.dart';
import 'package:trip_planner/data/models/trip_config.dart';
import 'package:trip_planner/data/models/trip_stop.dart';

/// Turns a costed trip into a day-by-day plan.
///
/// Walks the route: drive to a stop, sleep there for its nights filling the days
/// with what you chose to see from that base, drive on to the next, and finally
/// drive home. A single-destination trip is the one-stop case of that same walk,
/// which is why there is no separate code path for it.
///
/// A leg longer than a sane driving day is split across two days with a night
/// en route, because pretending you can drive fourteen hours and still check in
/// is how a plan stops being useful.
class ItineraryBuilder {
  const ItineraryBuilder._();

  /// [legs] runs home → stop 1 → … → stop n → home.
  static List<ItineraryDay> build({
    required TripConfig config,
    required List<RouteInfo> legs,
    Map<String, RouteInfo> attractionRoutes = const {},
  }) {
    final days = math.max(1, config.days);
    final result = <ItineraryDay>[];
    var cursor = 1;

    RouteInfo legAt(int i) =>
        i < legs.length ? legs[i] : const RouteInfo(distanceKm: 0, duration: Duration.zero);

    var from = config.originName;

    for (var i = 0; i < config.stops.length; i++) {
      final stop = config.stops[i];
      final leg = legAt(i);
      final hoursOnRoad = leg.duration.inMinutes / 60.0;
      final split = hoursOnRoad > AppDefaults.longDrivingDayHours && days >= 3;
      final to = stop.destination.name;

      // ---- Getting there --------------------------------------------------
      if (split) {
        final half = leg.duration ~/ 2;
        result.add(_day(config, cursor++, 'Drive to $to, day 1', [
          ItineraryItem(
            title: 'Leave $from',
            subtitle: 'About ${durationText(half)} on the road, roughly '
                '${km(leg.distanceKm / 2)}',
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
        result.add(_day(config, cursor++, 'Arrive $to', [
          ItineraryItem(
            title: 'Finish the drive',
            subtitle: 'Remaining ${durationText(half)} to $to',
            icon: Icons.directions_car_filled_rounded,
            hours: half.inMinutes / 60.0,
          ),
          _checkIn(config, stop),
        ]));
      } else {
        result.add(_day(config, cursor++, 'Travel to $to', [
          ItineraryItem(
            title: '$from to $to',
            subtitle: '${km(leg.distanceKm)}, about '
                '${durationText(leg.duration)} of driving',
            icon: config.isSelfDriving
                ? Icons.directions_car_filled_rounded
                : Icons.directions_bus_filled_rounded,
            hours: hoursOnRoad,
          ),
          _checkIn(config, stop),
        ]));
      }

      // ---- Days based here -------------------------------------------------
      // The arrival day already carries the check-in, so the free days are the
      // nights minus the one you arrive on.
      final baseDays = math.max(0, stop.nights - (split ? 0 : 1) + (split ? -1 : 0));
      _addSightseeing(
        config: config,
        stop: stop,
        attractionRoutes: attractionRoutes,
        dayCount: baseDays,
        result: result,
        nextDay: () => cursor++,
      );

      from = to;
    }

    // ---- Home ---------------------------------------------------------------
    final homeLeg = legAt(config.stops.length);
    final homeHours = homeLeg.duration.inMinutes / 60.0;
    if (homeHours > AppDefaults.longDrivingDayHours && days >= 3) {
      result.add(_day(config, cursor++, 'Drive back, day 1', [
        ItineraryItem(
          title: 'Leave $from',
          subtitle: 'About ${durationText(homeLeg.duration ~/ 2)} to the overnight stop',
          icon: Icons.logout_rounded,
          hours: (homeLeg.duration ~/ 2).inMinutes / 60.0,
        ),
      ]));
    }

    final goHome = ItineraryItem(
      title: '$from to ${config.originName}',
      subtitle: '${km(homeLeg.distanceKm)}, about '
          '${durationText(homeLeg.duration)} of driving',
      icon: Icons.home_rounded,
      hours: homeHours,
    );

    // A trip with no nights is a day trip: you drive out, look at it and drive
    // back between one sunrise and the next. Giving the return its own day
    // would invent a night nobody is spending.
    if (config.allocatedNights == 0 && result.isNotEmpty) {
      final last = result.last;
      result[result.length - 1] = ItineraryDay(
        dayNumber: last.dayNumber,
        date: last.date,
        title: 'Day trip to ${config.stops.last.destination.name}',
        items: [...last.items, goHome],
      );
    } else {
      result.add(_day(config, cursor++, 'Return to ${config.originName}', [goHome]));
    }

    // The walk can produce more days than were budgeted, which is exactly what
    // the "too tight" advisory is for. Trimming here would hide it.
    return result;
  }

  /// Packs a stop's chosen places into the days spent at that base.
  static void _addSightseeing({
    required TripConfig config,
    required TripStop stop,
    required Map<String, RouteInfo> attractionRoutes,
    required int dayCount,
    required List<ItineraryDay> result,
    required int Function() nextDay,
  }) {
    final places = [...stop.selectedAttractions]
      ..sort((a, b) => b.visitHours.compareTo(a.visitHours));

    if (dayCount <= 0) {
      if (places.isEmpty) return;
      // No free day survived here — attach them to the arrival day so they are
      // visible rather than silently dropped.
      final squeezed = places
          .map((s) => ItineraryItem(
                title: s.name,
                subtitle: '${hours(s.visitHours)}  ·  no free day for this, '
                    'add a night at ${stop.destination.name} to fit it',
                icon: AppColors.iconFor(s.category),
                hours: s.visitHours,
              ))
          .toList();
      final last = result.last;
      result[result.length - 1] = ItineraryDay(
        dayNumber: last.dayNumber,
        date: last.date,
        title: last.title,
        items: [...last.items, ...squeezed],
      );
      return;
    }

    final buckets = List.generate(dayCount, (_) => <ItineraryItem>[]);
    final loads = List.filled(dayCount, 0.0);

    for (final place in places) {
      // Emptiest day that still has room; if none does, the emptiest takes it
      // anyway and that day simply reads as full.
      var target = 0;
      for (var i = 1; i < dayCount; i++) {
        if (loads[i] < loads[target]) target = i;
      }
      if (loads[target] + place.visitHours > AppDefaults.maxSightseeingHoursPerDay &&
          loads[target] > 0) {
        for (var i = 0; i < dayCount; i++) {
          if (loads[i] + place.visitHours <= AppDefaults.maxSightseeingHoursPerDay) {
            target = i;
            break;
          }
        }
      }

      final leg = attractionRoutes[place.id];
      final legKm = leg?.distanceKm ??
          haversineKm(stop.destination.point, place.point) *
              stop.destination.roadFactor;
      final perPerson = place.costPerPerson();

      buckets[target].add(ItineraryItem(
        title: place.name,
        subtitle: [
          '${km(legKm)} from ${stop.destination.name}',
          hours(place.visitHours),
          if (perPerson > 0) '${money(perPerson)} per person',
          if (place.requires4x4) 'jeep required',
        ].join('  ·  '),
        icon: AppColors.iconFor(place.category),
        hours: place.visitHours,
      ));
      loads[target] += place.visitHours;
    }

    for (var i = 0; i < dayCount; i++) {
      final items = buckets[i];
      result.add(_day(
        config,
        nextDay(),
        items.isEmpty ? 'Free day in ${stop.destination.name}' : 'Explore ${stop.destination.name}',
        items.isEmpty
            ? const [
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
  }

  static ItineraryItem _checkIn(TripConfig config, TripStop stop) {
    final unit = config.stayStyle.unitLabel;
    final unitPlural = config.stayStyle.unitLabelPlural;
    final rate = stop.stayRatePerUnitNight ?? config.stayRatePerUnitNight;

    if (stop.nights == 0) {
      return ItineraryItem(
        title: 'Passing through ${stop.destination.name}',
        subtitle: 'No night here — carry on the same day',
        icon: Icons.u_turn_left_rounded,
        hours: 0,
      );
    }

    final String subtitle;
    if (rate == 0) {
      subtitle = '${plural(config.rooms, unit, unitPlural)} for '
          '${plural(stop.nights, 'night', 'nights')}, '
          '${config.stayStyle.label.toLowerCase()} — nothing to pay';
    } else {
      subtitle = '${plural(config.rooms, unit, unitPlural)} for '
          '${plural(stop.nights, 'night', 'nights')} at '
          '${money(rate)} per $unit per night';
    }

    return ItineraryItem(
      title: config.isCamping ? 'Pitch camp' : 'Check in',
      subtitle: subtitle,
      icon: config.isCamping ? Icons.cabin_rounded : Icons.hotel_rounded,
      hours: 0,
    );
  }

  static ItineraryDay _day(
    TripConfig config,
    int number,
    String title,
    List<ItineraryItem> items,
  ) =>
      ItineraryDay(
        dayNumber: number,
        date: config.startDate.add(Duration(days: number - 1)),
        title: title,
        items: items,
      );
}
