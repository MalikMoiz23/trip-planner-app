import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:trip_planner/core/formatters.dart';
import 'package:trip_planner/data/models/attraction.dart';
import 'package:trip_planner/features/planner/planner_controller.dart';
import 'package:trip_planner/shared/widgets/attraction_tile.dart';
import 'package:trip_planner/shared/widgets/primitives.dart';

class StepStops extends StatelessWidget {
  const StepStops({super.key});

  Future<void> _editCost(BuildContext context, Attraction a) async {
    final controller = context.read<PlannerController>();
    final result = await showModalBottomSheet<({double entry, double transport})>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _CostSheet(attraction: a),
    );
    if (result != null) {
      controller.updateAttractionCost(
        a.id,
        entryFee: result.entry,
        localTransport: result.transport,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<PlannerController>();
    final theme = Theme.of(context);
    final d = c.destination!;

    final curated = c.candidates.where((a) => !a.isLive).toList();
    final live = c.candidates.where((a) => a.isLive).toList();

    final stopsCost = c.selectedAttractions
            .fold<double>(0, (sum, a) => sum + a.costPerPerson()) *
        c.persons;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        Row(
          children: [
            Expanded(
              child: StatTile(
                label: 'Stops chosen',
                value: '${c.selectedCount}',
                caption: c.selectedCount == 0
                    ? 'nothing picked yet'
                    : '${hours(c.sightseeingHours)} of sightseeing',
                icon: Icons.place_rounded,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: StatTile(
                label: 'Adds to the trip',
                value: money(stopsCost),
                caption: 'tickets and local fares',
                icon: Icons.confirmation_number_rounded,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        if (curated.isNotEmpty) ...[
          SectionHeader(
            title: 'Around ${d.name}',
            subtitle: 'Curated stops with known fees and visit times',
            actionLabel: c.selectedCount == 0 ? 'Select all' : 'Clear',
            onAction: c.selectedCount == 0 ? c.selectAllCurated : c.clearAttractions,
          ),
          ...curated.map((a) => Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: AttractionTile(
                  attraction: a,
                  distanceKm: c.distanceToStop(a),
                  selected: c.isSelected(a.id),
                  persons: c.persons,
                  onToggle: () => c.toggleAttraction(a.id),
                  onEditCost: () => _editCost(context, a),
                ),
              )),
          const SizedBox(height: 12),
        ],
        const SectionHeader(
          title: 'More from OpenStreetMap',
          subtitle: 'Live lookup within 35 km. It carries no prices, so these are costed '
              'at typical rates and marked "Est."',
        ),
        if (c.loadingNearby)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: LoadingStrip(label: 'Looking up what else is nearby…'),
          )
        else if (!c.liveAttempted)
          OutlinedButton.icon(
            onPressed: () => c.loadNearby(),
            icon: const Icon(Icons.travel_explore_rounded, size: 19),
            label: const Text('Find more places nearby'),
          )
        else if (live.isEmpty)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Nothing extra came back. Either the area has no tagged places or the '
                'Overpass server was busy.',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => c.loadNearby(force: true),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Try again'),
              ),
            ],
          )
        else
          ...live.map((a) => Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: AttractionTile(
                  attraction: a,
                  distanceKm: c.distanceToStop(a),
                  selected: c.isSelected(a.id),
                  persons: c.persons,
                  onToggle: () => c.toggleAttraction(a.id),
                  onEditCost: () => _editCost(context, a),
                ),
              )),
        const SizedBox(height: 16),
        InfoNote(
          text: 'Each stop is costed as a return day trip from ${d.name}, so its distance '
              'is counted twice in the fuel figure. Tap the pencil on any stop to correct '
              'its ticket or jeep fare.',
        ),
      ],
    );
  }
}

/// Cost editor. Holds its own controllers so the value is read on Save even if
/// the field never lost focus.
class _CostSheet extends StatefulWidget {
  const _CostSheet({required this.attraction});

  final Attraction attraction;

  @override
  State<_CostSheet> createState() => _CostSheetState();
}

class _CostSheetState extends State<_CostSheet> {
  late final TextEditingController _entry =
      TextEditingController(text: widget.attraction.entryFee.round().toString());
  late final TextEditingController _transport =
      TextEditingController(text: widget.attraction.localTransport.round().toString());

  @override
  void dispose() {
    _entry.dispose();
    _transport.dispose();
    super.dispose();
  }

  double _read(TextEditingController c) =>
      double.tryParse(c.text.replaceAll(',', '').trim())?.clamp(0, 1000000).toDouble() ?? 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.attraction.name,
                style: theme.textTheme.titleLarge?.copyWith(fontSize: 18)),
            const SizedBox(height: 4),
            Text('Both figures are per person.', style: theme.textTheme.bodySmall),
            const SizedBox(height: 16),
            TextField(
              controller: _entry,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Entry ticket', prefixText: 'Rs '),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _transport,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Jeep, boat or chairlift fare',
                prefixText: 'Rs ',
              ),
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(
                (entry: _read(_entry), transport: _read(_transport)),
              ),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
