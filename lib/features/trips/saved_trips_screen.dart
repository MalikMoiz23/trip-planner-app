import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:trip_planner/core/formatters.dart';
import 'package:trip_planner/core/theme.dart';
import 'package:trip_planner/data/models/saved_trip.dart';
import 'package:trip_planner/app/app_state.dart';
import 'package:trip_planner/features/planner/planner_controller.dart';
import 'package:trip_planner/shared/widgets/primitives.dart';
import 'package:trip_planner/features/planner/planner_screen.dart';
import 'package:trip_planner/features/summary/summary_screen.dart';

class SavedTripsScreen extends StatelessWidget {
  const SavedTripsScreen({super.key});

  Future<void> _reopen(BuildContext context, SavedTrip trip, {required bool toSummary}) async {
    final controller = context.read<PlannerController>();
    final navigator = Navigator.of(context);
    controller.loadFrom(trip);
    if (toSummary) {
      await controller.finalise();
      await navigator.push(MaterialPageRoute(builder: (_) => const SummaryScreen()));
    } else {
      await navigator.push(MaterialPageRoute(builder: (_) => const PlannerScreen()));
    }
  }

  Future<void> _confirmDelete(BuildContext context, SavedTrip trip) async {
    final app = context.read<AppState>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this trip?'),
        content: Text('${trip.config.destination.name}, saved ${dayMonth(trip.createdAt)}.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Keep')),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Delete', style: TextStyle(color: context.palette.danger)),
          ),
        ],
      ),
    );
    if (ok == true) await app.deleteTrip(trip.id);
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final theme = Theme.of(context);
    final trips = app.savedTrips;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: trips.isEmpty
            ? const EmptyState(
                icon: Icons.bookmark_border_rounded,
                title: 'No saved trips yet',
                message: 'Plan a trip from the Explore tab and hit Save on the breakdown. '
                    'Saved trips keep the exact rates they were costed with.',
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                children: [
                  Text('My trips', style: theme.textTheme.headlineMedium?.copyWith(fontSize: 26)),
                  const SizedBox(height: 4),
                  Text(
                    '${trips.length} saved on this device. Nothing leaves your phone.',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 18),
                  ...trips.map((trip) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _TripCard(
                          trip: trip,
                          onOpen: () => _reopen(context, trip, toSummary: true),
                          onEdit: () => _reopen(context, trip, toSummary: false),
                          onDelete: () => _confirmDelete(context, trip),
                        ),
                      )),
                ],
              ),
      ),
    );
  }
}

class _TripCard extends StatelessWidget {
  const _TripCard({
    required this.trip,
    required this.onOpen,
    required this.onEdit,
    required this.onDelete,
  });

  final SavedTrip trip;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = trip.config;
    final d = c.destination;

    return AppCard(
      onTap: onOpen,
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: AppColors.gradientFor(d.category),
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        d.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${c.originName} → ${d.name}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white70, fontSize: 12.5),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      money(trip.total),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      '${money(trip.perPerson)} each',
                      style: const TextStyle(color: Colors.white70, fontSize: 11.5),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(15, 12, 15, 12),
            child: Column(
              children: [
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: [
                    PillTag(label: dayMonth(c.startDate), icon: Icons.event_rounded),
                    PillTag(
                      label: plural(c.days, 'day', 'days'),
                      icon: Icons.schedule_rounded,
                    ),
                    PillTag(
                      label: plural(c.persons, 'person', 'people'),
                      icon: Icons.group_rounded,
                    ),
                    PillTag(label: km(trip.totalKm), icon: Icons.route_rounded),
                    PillTag(
                      label: plural(c.selectedAttractions.length, 'stop', 'stops'),
                      icon: Icons.place_rounded,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onEdit,
                        icon: const Icon(Icons.tune_rounded, size: 17),
                        label: const Text('Adjust'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(42),
                        ),
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: onOpen,
                        icon: const Icon(Icons.receipt_long_rounded, size: 17),
                        label: const Text('Breakdown'),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(42),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      onPressed: onDelete,
                      icon: const Icon(Icons.delete_outline_rounded, size: 20),
                      color: context.palette.inkSoft,
                      tooltip: 'Delete',
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Costed on ${fullDate(trip.createdAt)} at '
                    '${money(c.fuelPrice)}/L fuel',
                    style: theme.textTheme.bodySmall?.copyWith(fontSize: 11.5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
