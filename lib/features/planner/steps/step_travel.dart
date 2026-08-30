import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:trip_planner/core/constants.dart';
import 'package:trip_planner/core/enums.dart';
import 'package:trip_planner/core/formatters.dart';
import 'package:trip_planner/core/theme.dart';
import 'package:trip_planner/features/planner/planner_controller.dart';
import 'package:trip_planner/shared/widgets/inputs.dart';
import 'package:trip_planner/shared/widgets/primitives.dart';

class StepTravel extends StatelessWidget {
  const StepTravel({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.watch<PlannerController>();
    final theme = Theme.of(context);
    final breakdown = c.breakdown;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        SegmentedChoice<TravelMode>(
          options: TravelMode.values,
          value: c.mode,
          onChanged: c.setMode,
          labelOf: (m) => m.label,
          iconOf: (m) => m == TravelMode.ownVehicle
              ? Icons.directions_car_rounded
              : Icons.directions_bus_rounded,
        ),
        const SizedBox(height: 20),
        if (c.mode == TravelMode.ownVehicle) ..._ownVehicle(context, c, theme)
        else ..._publicTransport(context, c, theme),
        const SizedBox(height: 20),
        if (breakdown != null) _travelSummary(theme, c),
      ],
    );
  }

  List<Widget> _ownVehicle(BuildContext context, PlannerController c, ThemeData theme) => [
        const SectionHeader(
          title: 'Vehicle',
          subtitle: 'Sets the starting mileage — override it below with your real figure',
        ),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          childAspectRatio: 2.35,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          children: AppDefaults.vehicles
              .map((v) => _VehicleCard(
                    preset: v,
                    selected: c.vehicleId == v.id,
                    onTap: () => c.setVehicle(v.id),
                  ))
              .toList(),
        ),
        const SizedBox(height: 18),
        const SectionHeader(
          title: 'Fuel',
          subtitle: 'Pump prices change constantly — put in what you are actually paying',
        ),
        Row(
          children: [
            Expanded(
              child: NumberField(
                label: 'Mileage',
                value: c.mileage,
                decimals: 1,
                suffix: 'km/L',
                onChanged: c.setMileage,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: NumberField(
                label: 'Fuel price',
                value: c.fuelPrice,
                prefix: 'Rs ',
                suffix: '/L',
                onChanged: c.setFuelPrice,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SegmentedChoice<FuelKind>(
          options: FuelKind.values,
          value: c.fuel,
          onChanged: c.setFuel,
          labelOf: (f) => f.label,
          iconOf: (_) => Icons.local_gas_station_rounded,
        ),
        const SizedBox(height: 16),
        NumberField(
          label: 'Tolls and parking, whole trip',
          value: c.tollsAndParking,
          prefix: 'Rs ',
          helper: 'Motorway tolls both ways plus parking at the stops.',
          onChanged: c.setTolls,
        ),
      ];

  List<Widget> _publicTransport(BuildContext context, PlannerController c, ThemeData theme) => [
        const SectionHeader(
          title: 'Fares',
          subtitle: 'Bus or van between cities, then taxis once you are there',
        ),
        NumberField(
          label: 'Intercity fare per person per km',
          value: c.publicRatePerKm,
          prefix: 'Rs ',
          decimals: 1,
          helper: 'A rough guide: Rs 4–6 per km on a standard coach, more on premium services.',
          onChanged: c.setPublicRate,
        ),
        const SizedBox(height: 12),
        NumberField(
          label: 'Local transport per person per day',
          value: c.localTransportPerPersonDay,
          prefix: 'Rs ',
          helper: 'Taxis and rickshaws around the base town. Jeep fares for specific stops '
              'are counted separately.',
          onChanged: c.setLocalTransportRate,
        ),
        const SizedBox(height: 16),
        const InfoNote(
          text: 'On public transport the fuel line disappears and every fare scales with '
              'the number of travellers, so a group of five costs five fares rather than '
              'one tank.',
        ),
      ];

  Widget _travelSummary(ThemeData theme, PlannerController c) {
    final b = c.breakdown!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'What that works out to'),
        Row(
          children: [
            Expanded(
              child: StatTile(
                label: 'Round trip',
                value: km(b.totalKm),
                caption: '${km(b.oneWayKm)} each way',
                icon: Icons.route_rounded,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: StatTile(
                label: 'Driving',
                value: durationText(b.totalDriveTime),
                caption: '${durationText(b.oneWayDrive)} each way',
                icon: Icons.schedule_rounded,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: StatTile(
                label: c.mode == TravelMode.ownVehicle ? 'Fuel needed' : 'Fares',
                value: c.mode == TravelMode.ownVehicle
                    ? litres(b.litres)
                    : money(b.travelCost),
                caption: c.mode == TravelMode.ownVehicle
                    ? 'at ${c.mileage.toStringAsFixed(1)} km/L'
                    : 'for ${c.persons} ${c.persons == 1 ? 'person' : 'people'}',
                icon: Icons.local_gas_station_rounded,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: StatTile(
                label: 'Travel cost',
                value: money(b.travelCost),
                caption: '${(b.travelCost / b.total * 100).round()}% of the trip',
                icon: Icons.payments_rounded,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _VehicleCard extends StatelessWidget {
  const _VehicleCard({required this.preset, required this.selected, required this.onTap});

  final VehiclePreset preset;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: selected ? context.palette.primary.withValues(alpha: 0.07) : theme.cardTheme.color,
      borderRadius: AppRadius.md,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.md,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: AppRadius.md,
            border: Border.all(
              color: selected ? context.palette.primary : (theme.dividerTheme.color ?? context.palette.line),
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(preset.icon, size: 22, color: selected ? context.palette.primary : context.palette.inkSoft),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      preset.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(fontSize: 13.5),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      '${preset.mileage.toStringAsFixed(0)} km/L · ${preset.seats} seats',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(fontSize: 11.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
