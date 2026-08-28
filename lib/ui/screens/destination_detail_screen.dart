import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/geo.dart';
import '../../core/theme.dart';
import '../../models/attraction.dart';
import '../../models/destination.dart';
import '../../state/planner_controller.dart';
import '../widgets/attraction_tile.dart';
import '../widgets/destination_card.dart';
import '../widgets/primitives.dart';
import 'planner_screen.dart';

class DestinationDetailScreen extends StatelessWidget {
  const DestinationDetailScreen({super.key, required this.destination});

  final Destination destination;

  void _plan(BuildContext context) {
    context.read<PlannerController>().startFor(destination);
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const PlannerScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final d = destination;
    final inSeason = d.inSeason(DateTime.now());

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 268,
            pinned: true,
            backgroundColor: AppColors.gradientFor(d.category).last,
            foregroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              background: DestinationPlate(
                category: d.category,
                borderRadius: BorderRadius.zero,
                watermarkSize: 250,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Wrap(
                          spacing: 7,
                          runSpacing: 7,
                          children: [
                            PillTag(label: d.category, onSurface: true),
                            PillTag(
                              label: inSeason ? 'In season now' : 'Off season now',
                              icon: inSeason
                                  ? Icons.check_circle_rounded
                                  : Icons.ac_unit_rounded,
                              onSurface: true,
                            ),
                            if (d.requires4x4)
                              const PillTag(
                                label: '4x4 country',
                                icon: Icons.airport_shuttle_rounded,
                                onSurface: true,
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          d.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            height: 1.05,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          d.subtitle,
                          style: const TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
            sliver: SliverList.list(
              children: [
                Text(d.tagline, style: theme.textTheme.titleMedium?.copyWith(fontSize: 16.5)),
                const SizedBox(height: 10),
                Text(d.description, style: theme.textTheme.bodyMedium?.copyWith(fontSize: 14.3)),
                const SizedBox(height: 20),
                _facts(context),
                const SizedBox(height: 24),
                const SectionHeader(
                  title: 'When to go',
                  subtitle: 'Months this place is normally open and worth the drive',
                ),
                MonthStrip(months: d.bestMonths),
                if (d.highlights.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  const SectionHeader(title: 'Known for'),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: d.highlights
                        .map((h) => PillTag(
                              label: h,
                              icon: Icons.star_rounded,
                              color: AppColors.accent,
                            ))
                        .toList(),
                  ),
                ],
                const SizedBox(height: 24),
                SectionHeader(
                  title: 'Nearby stops',
                  subtitle: d.attractions.isEmpty
                      ? 'None curated — the planner will pull live ones from OpenStreetMap'
                      : 'Pick which of these to include when you plan',
                ),
                if (d.attractions.isEmpty)
                  const InfoNote(
                    text: 'This place came from live search, so it has no curated stops. '
                        'Open the planner and the app will look up what is around it.',
                  )
                else
                  ...d.attractions.map((a) => Padding(
                        padding: const EdgeInsets.only(bottom: 9),
                        child: AttractionTile(
                          attraction: a,
                          distanceKm: _approxKm(a),
                          selected: false,
                          onToggle: () => _plan(context),
                        ),
                      )),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
          child: FilledButton.icon(
            onPressed: () => _plan(context),
            icon: const Icon(Icons.calculate_rounded, size: 20),
            label: Text('Plan a trip to ${d.name}'),
          ),
        ),
      ),
    );
  }

  /// Straight-line, terrain-corrected. The real routed figure is fetched in the
  /// planner, where it actually feeds a cost.
  double _approxKm(Attraction a) =>
      haversineKm(destination.point, a.point) * destination.roadFactor;

  Widget _facts(BuildContext context) {
    final d = destination;
    return Row(
      children: [
        // Labels are kept to eight characters or so: at three tiles across a
        // 360 dp screen there is no room for more before they ellipsise.
        Expanded(
          child: StatTile(
            label: 'Days',
            value: '${d.recommendedDays}',
            caption: 'recommended',
            icon: Icons.event_rounded,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: StatTile(
            label: 'Altitude',
            value: d.altitudeM > 0 ? '${d.altitudeM} m' : 'n/a',
            caption: 'above sea level',
            icon: Icons.terrain_rounded,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: StatTile(
            label: 'Terrain',
            value: d.difficulty,
            caption: 'roads and trails',
            icon: Icons.hiking_rounded,
          ),
        ),
      ],
    );
  }
}
