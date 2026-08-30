import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:trip_planner/core/enums.dart';
import 'package:trip_planner/core/formatters.dart';
import 'package:trip_planner/core/theme.dart';
import 'package:trip_planner/data/models/expense_breakdown.dart';
import 'package:trip_planner/data/models/itinerary.dart';
import 'package:trip_planner/app/app_state.dart';
import 'package:trip_planner/features/planner/planner_controller.dart';
import 'package:trip_planner/shared/widgets/cost_chart.dart';
import 'package:trip_planner/shared/widgets/primitives.dart';
import 'package:trip_planner/shared/widgets/trip_map.dart';
import 'package:trip_planner/shared/widgets/warning_card.dart';
import 'package:trip_planner/core/motion.dart';
import 'package:trip_planner/shared/widgets/budget_panel.dart';
import 'package:trip_planner/shared/widgets/weather_card.dart';
import 'package:trip_planner/features/summary/expense_detail_screen.dart';
import 'package:trip_planner/features/trips/packing_screen.dart';
import 'package:trip_planner/features/summary/map_screen.dart';

class SummaryScreen extends StatelessWidget {
  const SummaryScreen({super.key});

  Future<void> _save(BuildContext context) async {
    final controller = context.read<PlannerController>();
    final app = context.read<AppState>();
    final messenger = ScaffoldMessenger.of(context);
    await app.addTrip(controller.toSavedTrip());
    messenger.showSnackBar(
      const SnackBar(content: Text('Saved. Find it under My trips.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<PlannerController>();
    final theme = Theme.of(context);
    final b = c.breakdown;
    final d = c.destination;

    if (b == null || d == null) {
      return const Scaffold(
        body: Center(child: Text('Nothing to show — the route has not been worked out.')),
      );
    }

    final blockers = b.warnings.where((w) => w.level == WarningLevel.blocker).toList();
    final others = b.warnings.where((w) => w.level != WarningLevel.blocker).toList();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(d.name, style: theme.textTheme.titleLarge?.copyWith(fontSize: 18)),
            Text(
              '${dayMonth(c.startDate)} – ${dayMonth(c.startDate.add(Duration(days: c.days - 1)))}'
              '  ·  ${plural(c.days, 'day', 'days')}  ·  '
              '${plural(c.persons, 'person', 'people')}',
              style: theme.textTheme.bodySmall?.copyWith(fontSize: 12),
            ),
          ],
        ),
        toolbarHeight: 64,
        actions: [
          IconButton(
            tooltip: 'Save this trip',
            onPressed: () => _save(context),
            icon: const Icon(Icons.bookmark_add_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          _hero(context, b),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: StatTile(
                  label: 'Per day',
                  value: money(b.perDay),
                  caption: 'whole group',
                  icon: Icons.today_rounded,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: StatTile(
                  label: 'Each per day',
                  value: money(b.perPersonPerDay),
                  caption: 'per person, per day',
                  icon: Icons.person_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),

          // ---- Route -------------------------------------------------------
          const SectionHeader(title: 'The route'),
          _mapCard(context, c),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: StatTile(
                  label: 'Total distance',
                  value: km(b.totalKm),
                  caption: '${km(b.oneWayKm)} each way'
                      '${b.attractionsKm > 0 ? ' + ${km(b.attractionsKm)} detours' : ''}',
                  icon: Icons.route_rounded,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: StatTile(
                  label: 'Time driving',
                  value: durationText(b.totalDriveTime),
                  caption: '${durationText(b.oneWayDrive)} each way',
                  icon: Icons.schedule_rounded,
                ),
              ),
            ],
          ),
          if (c.mode == TravelMode.ownVehicle) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: StatTile(
                    label: 'Fuel needed',
                    value: litres(b.litres),
                    caption: 'at ${c.mileage.toStringAsFixed(1)} km/L',
                    icon: Icons.local_gas_station_rounded,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: StatTile(
                    label: 'Fuel cost',
                    value: money(b.travelCost),
                    caption: '${moneyExact(c.fuelPrice)} per litre',
                    icon: Icons.payments_rounded,
                  ),
                ),
              ],
            ),
          ],
          if (b.routeEstimated) ...[
            const SizedBox(height: 12),
            const InfoNote(
              icon: Icons.wifi_off_rounded,
              text: 'At least one leg could not be routed, so its distance is a '
                  'terrain-corrected straight line rather than a measured road.',
            ),
          ],
          const SizedBox(height: 24),

          // ---- Money -------------------------------------------------------
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.cardTheme.color,
              borderRadius: AppRadius.md,
              border: Border.all(color: theme.dividerTheme.color ?? context.palette.line),
            ),
            child: CostBreakdownChart(breakdown: b),
          ),
          const SizedBox(height: 24),

          // ---- Advisories --------------------------------------------------
          if (blockers.isNotEmpty) ...[
            const SectionHeader(title: 'Fix before you go'),
            ...blockers.map((w) => Padding(
                  padding: const EdgeInsets.only(bottom: 9),
                  child: WarningCard(warning: w),
                )),
            const SizedBox(height: 14),
          ],
          if (others.isNotEmpty) ...[
            SectionHeader(
              title: 'Worth knowing',
              subtitle: '${others.length} '
                  '${others.length == 1 ? 'thing' : 'things'} this plan assumes',
            ),
            ...others.map((w) => Padding(
                  padding: const EdgeInsets.only(bottom: 9),
                  child: WarningCard(warning: w),
                )),
            const SizedBox(height: 14),
          ],

          // ---- Itinerary ---------------------------------------------------
          const SizedBox(height: 8),
          SectionHeader(
            title: 'Day by day',
            subtitle: 'Stops packed to a ceiling of 9 hours of sightseeing a day',
          ),
          ...c.itinerary.map((day) => _DayCard(day: day)),

          // ---- Weather -------------------------------------------------------
          const SizedBox(height: 22),
          const SectionHeader(
            title: 'Weather',
            subtitle: 'Measured at these coordinates, not inherited from the region',
          ),
          WeatherPanel(
            weather: c.weather,
            start: c.startDate,
            end: c.startDate.add(Duration(days: c.days - 1)),
            loading: c.loadingWeather,
            altitudeM: d.altitudeM,
            guideMonths: d.bestMonths,
          ),

          // ---- Budget --------------------------------------------------------
          const SizedBox(height: 22),
          const SectionHeader(
            title: 'Against your budget',
            subtitle: 'Say what you can spend and the app works out how to fit it',
          ),
          BudgetPanel(
            budget: c.budget,
            onBudgetChanged: c.setBudget,
            advice: c.budgetAdvice,
            onApplyLever: c.applyLever,
          ),

          const SizedBox(height: 22),
          FilledButton.icon(
            onPressed: () => context.pushScreen(const ExpenseDetailScreen()),
            icon: const Icon(Icons.receipt_long_rounded, size: 20),
            label: const Text('See every rupee'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => context.pushScreen(const PackingScreen()),
            icon: const Icon(Icons.checklist_rounded, size: 19),
            label: const Text('Packing list'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => _save(context),
            icon: const Icon(Icons.bookmark_add_rounded, size: 19),
            label: const Text('Save this trip'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.tune_rounded, size: 19),
            label: const Text('Adjust the plan'),
          ),
        ],
      ),
    );
  }

  Widget _hero(BuildContext context, ExpenseBreakdown b) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primaryDark, context.palette.primary],
        ),
        borderRadius: AppRadius.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Estimated total',
            style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              money(b.total),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 40,
                fontWeight: FontWeight.w800,
                height: 1.05,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: AppRadius.md,
            ),
            child: Row(
              children: [
                const Icon(Icons.group_rounded, size: 18, color: Colors.white70),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Each person pays',
                    style: TextStyle(color: Colors.white70, fontSize: 13.5),
                  ),
                ),
                Text(
                  money(b.perPerson),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _mapCard(BuildContext context, PlannerController c) {
    final d = c.destination!;
    return ClipRRect(
      borderRadius: AppRadius.md,
      child: SizedBox(
        height: 190,
        child: Stack(
          children: [
            TripMap(
              origin: c.origin,
              originLabel: c.originName,
              destination: d.point,
              destinationLabel: d.name,
              category: d.category,
              routePoints: [for (final l in c.legs) ...?l?.geometry],
              stops: c.selectedAttractions,
              interactive: false,
              showAttribution: false,
            ),
            Positioned.fill(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const MapScreen()),
                  ),
                ),
              ),
            ),
            Positioned(
              right: 10,
              bottom: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: AppRadius.pill,
                  boxShadow: context.palette.shadowCard,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.open_in_full_rounded, size: 14, color: context.palette.ink),
                    SizedBox(width: 6),
                    Text(
                      'Open map',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: context.palette.ink,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 8,
              bottom: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                color: Colors.white70,
                child: Text(
                  '© OpenStreetMap contributors',
                  style: TextStyle(fontSize: 9, color: context.palette.ink),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DayCard extends StatelessWidget {
  const _DayCard({required this.day});

  final ItineraryDay day;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: context.palette.primary.withValues(alpha: 0.10),
                    borderRadius: AppRadius.sm,
                  ),
                  child: Text(
                    '${day.dayNumber}',
                    style: TextStyle(
                      color: context.palette.primary,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(day.title, style: theme.textTheme.titleSmall?.copyWith(fontSize: 14.5)),
                      Text(
                        dayMonth(day.date),
                        style: theme.textTheme.bodySmall?.copyWith(fontSize: 12),
                      ),
                    ],
                  ),
                ),
                if (day.totalHours > 0)
                  PillTag(label: hours(day.totalHours), icon: Icons.schedule_rounded),
              ],
            ),
            const SizedBox(height: 12),
            ...day.items.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(item.icon, size: 17, color: context.palette.inkSoft),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.title,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontSize: 13.8,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              item.subtitle,
                              style: theme.textTheme.bodySmall?.copyWith(fontSize: 12.2),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }
}
