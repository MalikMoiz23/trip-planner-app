import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:trip_planner/core/constants.dart';
import 'package:trip_planner/core/formatters.dart';
import 'package:trip_planner/core/theme.dart';
import 'package:trip_planner/app/app_state.dart';
import 'package:trip_planner/shared/widgets/inputs.dart';
import 'package:trip_planner/shared/widgets/primitives.dart';

/// Default rates. These seed every new plan; a saved trip keeps whatever rates
/// it was costed with, so changing a price here never rewrites history.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          children: [
            Text('Settings', style: theme.textTheme.headlineMedium?.copyWith(fontSize: 26)),
            const SizedBox(height: 4),
            Text(
              'How the app looks, and the rates that seed every new plan.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 20),
            const SectionHeader(
              title: 'Appearance',
              subtitle: 'Follow the device, or pin it',
            ),
            SegmentedChoice<ThemeMode>(
              options: const [ThemeMode.system, ThemeMode.light, ThemeMode.dark],
              value: app.themeMode,
              onChanged: app.setThemeMode,
              labelOf: (m) => switch (m) {
                ThemeMode.system => 'System',
                ThemeMode.light => 'Light',
                ThemeMode.dark => 'Dark',
              },
              iconOf: (m) => switch (m) {
                ThemeMode.system => Icons.brightness_auto_rounded,
                ThemeMode.light => Icons.light_mode_rounded,
                ThemeMode.dark => Icons.dark_mode_rounded,
              },
            ),
            const SizedBox(height: 26),
            SectionHeader(
              title: 'Fuel',
              subtitle: app.fuelPriceIsCustom
                  ? 'Your own figures — the planner will not second-guess them'
                  : 'Still the rates this app shipped with, from '
                      '${fullDate(AppDefaults.fuelPriceAsOf)}',
            ),
            if (!app.fuelPriceIsCustom) ...[
              const InfoNote(
                icon: Icons.local_gas_station_rounded,
                text: 'Pakistan reprices petrol daily under the OGRA mechanism, so these '
                    'go out of date within a day of release. Fuel is usually the largest '
                    'single line in a road trip, so putting in the price you actually '
                    'paid changes the total more than anything else on this screen.',
              ),
              const SizedBox(height: 14),
            ],
            NumberField(
              label: 'Petrol',
              value: app.petrolPrice,
              prefix: 'Rs ',
              suffix: '/L',
              decimals: 2,
              onChanged: app.setPetrolPrice,
            ),
            const SizedBox(height: 12),
            NumberField(
              label: 'High-speed diesel',
              value: app.dieselPrice,
              prefix: 'Rs ',
              suffix: '/L',
              decimals: 2,
              onChanged: app.setDieselPrice,
            ),
            const SizedBox(height: 22),
            const SectionHeader(title: 'Public transport'),
            NumberField(
              label: 'Intercity fare per person per km',
              value: app.publicRatePerKm,
              prefix: 'Rs ',
              decimals: 1,
              onChanged: app.setPublicRate,
            ),
            const SizedBox(height: 22),
            const SectionHeader(
              title: 'Vehicle mileage defaults',
              subtitle: 'Applied when you pick a vehicle, overridable per trip',
            ),
            ...AppDefaults.vehicles.map((v) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: AppCard(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Row(
                      children: [
                        Icon(v.icon, size: 20, color: context.palette.inkSoft),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(v.label,
                                  style: theme.textTheme.titleSmall?.copyWith(fontSize: 14)),
                              Text(v.blurb,
                                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 12)),
                            ],
                          ),
                        ),
                        Text(
                          '${v.mileage.toStringAsFixed(0)} km/L',
                          style: theme.textTheme.titleSmall?.copyWith(fontSize: 13.5),
                        ),
                      ],
                    ),
                  ),
                )),
            const SizedBox(height: 20),
            const InfoNote(
              text: 'Nothing in this app is a live price. Fuel, hotel, food and ticket '
                  'figures are your own assumptions — the app only does the arithmetic on '
                  'top of them. Distances and maps come from OpenStreetMap and OSRM, which '
                  'are free and need no account.',
            ),
            const SizedBox(height: 18),
            const SectionHeader(title: 'Data'),
            AppCard(
              onTap: app.savedTrips.isEmpty
                  ? null
                  : () async {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Delete all saved trips?'),
                          content: Text('${app.savedTrips.length} saved plans will be removed '
                              'from this device. This cannot be undone.'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(ctx).pop(false),
                              child: const Text('Keep'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.of(ctx).pop(true),
                              child: Text('Delete all',
                                  style: TextStyle(color: context.palette.danger)),
                            ),
                          ],
                        ),
                      );
                      if (ok == true) await app.clearTrips();
                    },
              child: Row(
                children: [
                  Icon(Icons.delete_sweep_outlined, size: 20, color: context.palette.inkSoft),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Clear saved trips',
                            style: theme.textTheme.titleSmall?.copyWith(fontSize: 14)),
                        Text(
                          app.savedTrips.isEmpty
                              ? 'Nothing saved'
                              : '${app.savedTrips.length} stored on this device',
                          style: theme.textTheme.bodySmall?.copyWith(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            Text(
              'Map data © OpenStreetMap contributors. Routing by the public OSRM demo '
              'server. Search and nearby lookups by Nominatim and Overpass. All free, '
              'no keys, no accounts.',
              style: theme.textTheme.bodySmall?.copyWith(fontSize: 11.8),
            ),
          ],
        ),
      ),
    );
  }
}
