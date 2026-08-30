import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:trip_planner/core/formatters.dart';
import 'package:trip_planner/core/theme.dart';
import 'package:trip_planner/features/planner/planner_controller.dart';
import 'package:trip_planner/shared/widgets/primitives.dart';
import 'package:trip_planner/shared/widgets/trip_map.dart';

class MapScreen extends StatelessWidget {
  const MapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.watch<PlannerController>();
    final d = c.destination;
    if (d == null) {
      return const Scaffold(body: Center(child: Text('No trip loaded.')));
    }

    final route = c.legs.isEmpty ? null : c.legs.first;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: TripMap(
              origin: c.origin,
              originLabel: c.originName,
              destination: d.point,
              destinationLabel: d.name,
              category: d.category,
              routePoints: route?.geometry ?? const [],
              stops: c.selectedAttractions,
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  _RoundIcon(
                    icon: Icons.arrow_back_rounded,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${c.originName} → ${d.name}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(fontSize: 14.5),
                            ),
                          ),
                          if (route != null && route.estimated)
                            PillTag(
                              label: 'Estimated',
                              icon: Icons.help_outline_rounded,
                              color: context.palette.caution,
                            ),
                        ],
                      ),
                      const SizedBox(height: 9),
                      Wrap(
                        spacing: 7,
                        runSpacing: 7,
                        children: [
                          if (route != null)
                            PillTag(
                              label: km(route.distanceKm),
                              icon: Icons.route_rounded,
                              color: context.palette.primary,
                            ),
                          if (route != null)
                            PillTag(
                              label: durationText(route.duration),
                              icon: Icons.schedule_rounded,
                              color: context.palette.primary,
                            ),
                          PillTag(
                            label: '${c.selectedCount} stops pinned',
                            icon: Icons.place_rounded,
                            color: AppColors.accent,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundIcon extends StatelessWidget {
  const _RoundIcon({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 2,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(width: 42, height: 42, child: Icon(icon, size: 20, color: context.palette.ink)),
      ),
    );
  }
}
