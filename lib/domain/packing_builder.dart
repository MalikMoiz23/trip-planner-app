import 'package:flutter/material.dart';

import 'package:trip_planner/core/formatters.dart';
import 'package:trip_planner/data/models/trip_config.dart';
import 'package:trip_planner/data/models/weather.dart';

/// One thing to take, and why this trip needs it.
///
/// The reason is not decoration. A generic packing list gets skimmed and
/// ignored; "because you are camping at 3,300 m" is the part that makes someone
/// actually put the warm bag in the car.
class PackItem {
  const PackItem({
    required this.id,
    required this.label,
    required this.reason,
    this.quantity,
    this.critical = false,
  });

  final String id;
  final String label;

  /// The fact about *this* trip that put the item on the list.
  final String reason;

  /// Set when the count follows from the group or the length of the trip.
  final String? quantity;

  /// Forgetting this one is a trip-ruining or dangerous omission.
  final bool critical;
}

class PackSection {
  const PackSection({required this.title, required this.icon, required this.items});

  final String title;
  final IconData icon;
  final List<PackItem> items;
}

/// Builds a packing list out of the plan rather than a fixed template.
///
/// Everything here keys off something the user actually chose — the month, the
/// altitude, camping, self-cooking, a 4x4 stop, a long trek — so two different
/// trips produce genuinely different lists.
class PackingBuilder {
  const PackingBuilder._();

  static List<PackSection> build({
    required TripConfig config,
    PlaceWeather? weather,
  }) {
    final d = config.destination;
    final month = config.startDate.month;
    final climate = weather?.forMonth(month);
    final forecast = weather?.between(config.startDate, config.endDate) ?? const [];

    final coldNights = climate?.avgMinC ?? _guessMinC(d.altitudeM, month);
    final anyFreezing = forecast.any((f) => f.freezing) || coldNights <= 0;
    final anyWet = forecast.any((f) => f.wet) || (climate?.precipMm ?? 0) > 90;
    final snowRisk = (climate?.likelySnowbound ?? false) ||
        forecast.any((f) => f.snowCm > 0);

    final high = d.altitudeM >= 3000;
    final fairlyHigh = d.altitudeM >= 2200;
    final longTrek = config.selectedAttractions.any((a) => a.visitHours >= 6);
    final anyJeep = config.requires4x4Anywhere;
    final nights = config.nights;

    final sections = <PackSection>[];

    // ---- Documents and money ----------------------------------------------
    sections.add(PackSection(
      title: 'Papers and money',
      icon: Icons.badge_rounded,
      items: [
        const PackItem(
          id: 'cnic',
          label: 'CNIC or passport for everyone',
          reason: 'Checked at security posts on every northern route.',
          critical: true,
        ),
        if (config.isSelfDriving)
          const PackItem(
            id: 'vehicle-papers',
            label: 'Licence, registration, insurance',
            reason: 'Motorway police check these and fine on the spot.',
            critical: true,
          ),
        PackItem(
          id: 'cash',
          label: 'Cash',
          reason: 'Card machines are unreliable past the main towns, and jeep '
              'drivers and campsites are cash-only.',
          quantity: 'plan around ${money(config.tollsAndParking + 5000)}',
          critical: true,
        ),
        if (d.province == 'Gilgit-Baltistan' || d.province == 'Azad Jammu & Kashmir')
          PackItem(
            id: 'permit-copies',
            label: 'Photocopies of ID',
            reason: 'Entry registration in ${d.province} still runs on paper.',
            quantity: '2 per person',
          ),
      ],
    ));

    // ---- Clothing -----------------------------------------------------------
    sections.add(PackSection(
      title: 'Clothing',
      icon: Icons.checkroom_rounded,
      items: [
        PackItem(
          id: 'layers',
          label: 'Layers you can add and remove',
          reason: climate != null
              ? 'Typically ${temp(climate.avgMaxC)} by day and '
                  '${temp(climate.avgMinC)} at night in ${monthName(month)}.'
              : 'Mountain days are warm and the nights are not.',
          quantity: '${config.days <= 3 ? config.days : 3}+ changes',
        ),
        if (anyFreezing)
          PackItem(
            id: 'warm-jacket',
            label: 'Proper insulated jacket',
            reason: 'Nights go to about ${temp(coldNights)} here in ${monthName(month)}.',
            critical: config.isCamping,
          ),
        if (anyFreezing)
          const PackItem(
            id: 'hat-gloves',
            label: 'Hat and gloves',
            reason: 'Freezing nights, and wind on the passes.',
          ),
        if (anyWet)
          const PackItem(
            id: 'rain',
            label: 'Rain shell or poncho',
            reason: 'Rain is likely for these dates.',
          ),
        if (longTrek || anyJeep)
          PackItem(
            id: 'boots',
            label: 'Boots with grip',
            reason: longTrek
                ? 'You have picked a stop that needs most of a day on foot.'
                : 'The jeep tracks end in a walk on loose ground.',
            critical: longTrek,
          ),
        if (fairlyHigh)
          const PackItem(
            id: 'sun',
            label: 'Sunglasses and high-factor sunblock',
            reason: 'UV climbs sharply with altitude, and snow doubles it by reflection.',
          ),
      ],
    ));

    // ---- Sleeping -----------------------------------------------------------
    if (config.isCamping && nights > 0) {
      sections.add(PackSection(
        title: 'Camping',
        icon: Icons.cabin_rounded,
        items: [
          if (config.stayStyle.isFree)
            PackItem(
              id: 'tent',
              label: 'Tent',
              reason: 'Your plan assumes you carry your own, which is why '
                  'accommodation costs nothing in the total.',
              quantity: '${config.rooms} for ${config.persons}',
              critical: true,
            ),
          PackItem(
            id: 'sleeping-bag',
            label: high
                ? 'Four-season sleeping bag'
                : (anyFreezing ? 'Cold-rated sleeping bag' : 'Sleeping bag'),
            reason: high
                ? 'At ${d.altitudeM} m it drops below freezing even in summer.'
                : 'Nights around ${temp(coldNights)}.',
            quantity: '${config.persons}',
            critical: true,
          ),
          const PackItem(
            id: 'mat',
            label: 'Sleeping mat',
            reason: 'The ground pulls more heat out of you than the air does.',
          ),
          const PackItem(
            id: 'headtorch',
            label: 'Head torch and spare batteries',
            reason: 'No lighting at a campsite.',
            critical: true,
          ),
        ],
      ));
    }

    // ---- Kitchen ------------------------------------------------------------
    if (config.isSelfCooking) {
      sections.add(PackSection(
        title: 'Cooking',
        icon: Icons.local_fire_department_rounded,
        items: [
          const PackItem(
            id: 'stove',
            label: 'Stove and gas',
            reason: 'Costed once in your food total.',
            critical: true,
          ),
          const PackItem(
            id: 'pots',
            label: 'Pot, pan and utensils',
            reason: 'Self-cooking is the cheapest food option you picked.',
          ),
          PackItem(
            id: 'groceries',
            label: 'Groceries bought in the last big town',
            reason: 'Village shops in the valleys are small and dearer.',
            quantity: '${config.totalMeals} meals',
          ),
          const PackItem(
            id: 'water',
            label: 'Water containers and purification',
            reason: 'Stream water is not safe without treating it.',
            critical: true,
          ),
        ],
      ));
    }

    // ---- Vehicle -------------------------------------------------------------
    if (config.isSelfDriving) {
      sections.add(PackSection(
        title: 'Vehicle',
        icon: Icons.directions_car_rounded,
        items: [
          const PackItem(
            id: 'spare',
            label: 'Spare wheel, jack and a working pump',
            reason: 'Punctures on unpaved tracks are routine, not bad luck.',
            critical: true,
          ),
          if (anyJeep || d.requires4x4)
            const PackItem(
              id: 'tow-rope',
              label: 'Tow rope',
              reason: 'This route has stretches where a 4x4 is expected.',
            ),
          if (snowRisk)
            const PackItem(
              id: 'chains',
              label: 'Snow chains',
              reason: 'Snow is plausible on these dates at this altitude.',
              critical: true,
            ),
          const PackItem(
            id: 'jerry',
            label: 'Full tank leaving the last big town',
            reason: 'Pumps thin out badly in the upper valleys.',
            critical: true,
          ),
          const PackItem(
            id: 'phone-mount',
            label: 'Offline maps downloaded',
            reason: 'Signal disappears for long stretches.',
          ),
        ],
      ));
    }

    // ---- Health ---------------------------------------------------------------
    sections.add(PackSection(
      title: 'Health and safety',
      icon: Icons.medical_services_rounded,
      items: [
        const PackItem(
          id: 'first-aid',
          label: 'First aid kit',
          reason: 'The nearest hospital can be hours away.',
          critical: true,
        ),
        const PackItem(
          id: 'meds',
          label: 'Any regular medication, plus spares',
          reason: 'Pharmacies past the main towns stock very little.',
          critical: true,
        ),
        if (high)
          PackItem(
            id: 'altitude',
            label: 'Altitude plan: ascend slowly, watch for headaches',
            reason: 'At ${d.altitudeM} m altitude sickness is a real risk. '
                'Descending is the only reliable treatment.',
            critical: true,
          ),
        const PackItem(
          id: 'powerbank',
          label: 'Power bank',
          reason: 'Load-shedding and no charging at camp.',
        ),
        if (nights > 1)
          const PackItem(
            id: 'itinerary-shared',
            label: 'Leave your route with someone at home',
            reason: 'No signal means nobody knows where you are unless you told them.',
            critical: true,
          ),
      ],
    ));

    // Drop any section that ended up empty after the conditionals.
    return sections.where((s) => s.items.isNotEmpty).toList(growable: false);
  }

  /// Rough lapse-rate guess for when climate could not be fetched: about 6.5 °C
  /// per 1,000 m off a sea-level seasonal baseline.
  static double _guessMinC(int altitudeM, int month) {
    const seaLevelMin = [8.0, 10, 15, 20, 24, 27, 28, 27, 24, 18, 12, 8];
    final base = seaLevelMin[(month - 1) % 12];
    return base - (altitudeM / 1000.0) * 6.5;
  }
}
