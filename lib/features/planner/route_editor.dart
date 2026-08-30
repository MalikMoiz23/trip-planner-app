import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:trip_planner/core/formatters.dart';
import 'package:trip_planner/core/motion.dart';
import 'package:trip_planner/core/theme.dart';
import 'package:trip_planner/features/planner/planner_controller.dart';
import 'package:trip_planner/shared/widgets/primitives.dart';

/// The route, as an ordered list of places you sleep.
///
/// A trip used to be one town. This is the editor that makes it a journey:
/// Islamabad to Naran to Hunza to Skardu and home, each stop holding its own
/// nights. The nights are the part that has to add up — the counter at the top
/// says what is still unspoken for, because a route whose nights do not match
/// its days silently costs the wrong number of hotel rooms.
class RouteEditor extends StatelessWidget {
  const RouteEditor({super.key, required this.onAddStop});

  /// Supplied by the screen, which owns the destination picker sheet.
  final Future<void> Function(BuildContext) onAddStop;

  @override
  Widget build(BuildContext context) {
    final c = context.watch<PlannerController>();
    final theme = Theme.of(context);
    final p = context.palette;
    final spare = c.unallocatedNights;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: c.isMultiStop ? 'Your route' : 'Where you are going',
          subtitle: c.isMultiStop
              ? '${c.route.length} stops  ·  ${plural(c.days, 'day', 'days')}'
              : 'Add another stop to turn this into a route',
          actionLabel: c.isMultiStop && spare != 0 ? 'Balance' : null,
          onAction: c.balanceNights,
        ),

        // ---- Nights ledger --------------------------------------------------
        if (c.isMultiStop) ...[
          _NightsLedger(
            allocated: c.allocatedNights,
            available: c.nightsForDisplay,
          ),
          const SizedBox(height: 12),
        ],

        // ---- Origin ---------------------------------------------------------
        _Node(
          icon: Icons.trip_origin_rounded,
          colour: p.inkSoft,
          title: c.originName.isEmpty ? 'Your location' : c.originName,
          subtitle: 'Start',
        ),
        _Connector(label: _legLabel(c, 0)),

        // ---- Stops ----------------------------------------------------------
        for (var i = 0; i < c.route.length; i++) ...[
          FadeSlideIn(
            key: ValueKey(c.route[i].destination.id),
            delay: Motion.of(context).stagger(i),
            child: _StopCard(index: i),
          ),
          _Connector(label: _legLabel(c, i + 1)),
        ],

        // ---- Home -----------------------------------------------------------
        _Node(
          icon: Icons.home_rounded,
          colour: p.inkSoft,
          title: c.originName.isEmpty ? 'Home' : c.originName,
          subtitle: 'Back where you started',
        ),

        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => onAddStop(context),
          icon: const Icon(Icons.add_location_alt_rounded, size: 19),
          label: Text(c.isMultiStop ? 'Add another stop' : 'Add a second stop'),
        ),
        if (!c.isMultiStop) ...[
          const SizedBox(height: 8),
          Text(
            'Going to more than one place? Add them here and the fuel, nights and '
            'itinerary are worked out for the whole loop.',
            style: theme.textTheme.bodySmall?.copyWith(fontSize: 12.2),
          ),
        ],
      ],
    );
  }

  /// Distance of the leg once it has been routed. Null until then, so the row
  /// shows a placeholder rather than a confident zero.
  String? _legLabel(PlannerController c, int index) {
    if (index >= c.legs.length) return null;
    final leg = c.legs[index];
    if (leg == null) return c.routing ? 'measuring…' : null;
    return '${km(leg.distanceKm)}  ·  ${durationText(leg.duration)}';
  }
}

/// How many of the trip's nights the stops have claimed.
class _NightsLedger extends StatelessWidget {
  const _NightsLedger({required this.allocated, required this.available});

  final int allocated;
  final int available;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final theme = Theme.of(context);
    final spare = available - allocated;
    final tone = spare == 0 ? p.success : (spare > 0 ? p.caution : p.danger);

    final String message;
    if (spare == 0) {
      message = 'Every night is accounted for';
    } else if (spare > 0) {
      message = '${plural(spare, 'night', 'nights')} still to place';
    } else {
      message = '${plural(-spare, 'night', 'nights')} more than the trip is long';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.10),
        borderRadius: AppRadius.sm,
        border: Border.all(color: tone.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(
            spare == 0 ? Icons.check_circle_rounded : Icons.info_rounded,
            size: 18,
            color: tone,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 12.6,
                color: tone,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            '$allocated / $available',
            style: theme.textTheme.titleSmall?.copyWith(fontSize: 13, color: tone),
          ),
        ],
      ),
    );
  }
}

/// A fixed end of the route — where you set off from and come back to.
class _Node extends StatelessWidget {
  const _Node({
    required this.icon,
    required this.colour,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final Color colour;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 20, color: colour),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.textTheme.titleSmall?.copyWith(fontSize: 14)),
              Text(subtitle, style: theme.textTheme.bodySmall?.copyWith(fontSize: 11.5)),
            ],
          ),
        ),
      ],
    );
  }
}

/// The dashed run between two nodes, labelled with the leg once it is known.
class _Connector extends StatelessWidget {
  const _Connector({this.label});

  final String? label;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 9),
      child: Row(
        children: [
          Container(width: 2, height: 30, color: p.line),
          const SizedBox(width: 16),
          if (label != null)
            Text(
              label!,
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 11.5,
                color: p.inkFaint,
              ),
            ),
        ],
      ),
    );
  }
}

/// One stop: its nights, and the controls to move or drop it.
class _StopCard extends StatelessWidget {
  const _StopCard({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    final c = context.watch<PlannerController>();
    final theme = Theme.of(context);
    final p = context.palette;
    final stop = c.route[index];
    final d = stop.destination;
    final canRemove = c.route.length > 1;

    return AppCard(
      padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: AppColors.gradientFor(d.category)),
                  borderRadius: AppRadius.sm,
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      d.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(fontSize: 14.5),
                    ),
                    Text(
                      stop.selectedIds.isEmpty
                          ? d.subtitle
                          : '${plural(stop.selectedIds.length, 'place', 'places')} to see',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(fontSize: 11.8),
                    ),
                  ],
                ),
              ),
              if (c.isMultiStop)
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert_rounded, size: 19, color: p.inkSoft),
                  onSelected: (value) {
                    switch (value) {
                      case 'up':
                        c.moveStop(index, index - 1);
                      case 'down':
                        c.moveStop(index, index + 1);
                      case 'remove':
                        c.removeStop(index);
                    }
                  },
                  itemBuilder: (_) => [
                    if (index > 0)
                      const PopupMenuItem(value: 'up', child: Text('Move earlier')),
                    if (index < c.route.length - 1)
                      const PopupMenuItem(value: 'down', child: Text('Move later')),
                    if (canRemove)
                      const PopupMenuItem(value: 'remove', child: Text('Remove stop')),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                stop.nights == 0 ? Icons.fast_forward_rounded : Icons.bedtime_rounded,
                size: 16,
                color: stop.nights == 0 ? p.inkFaint : p.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  stop.nights == 0
                      ? 'Passing through, no night here'
                      : plural(stop.nights, 'night', 'nights'),
                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 12.4),
                ),
              ),
              _Stepper(
                value: stop.nights,
                onChanged: (v) => c.setStopNights(index, v),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Round(
          icon: Icons.remove_rounded,
          enabled: value > 0,
          onTap: () => onChanged(value - 1),
        ),
        SizedBox(
          width: 30,
          child: Text(
            '$value',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: p.ink),
          ),
        ),
        _Round(
          icon: Icons.add_rounded,
          enabled: true,
          onTap: () => onChanged(value + 1),
        ),
      ],
    );
  }
}

class _Round extends StatelessWidget {
  const _Round({required this.icon, required this.enabled, required this.onTap});

  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return PressableScale(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: enabled ? p.surfaceAlt : p.surfaceAlt.withValues(alpha: 0.5),
          borderRadius: AppRadius.sm,
          border: Border.all(color: p.line),
        ),
        child: Icon(icon, size: 16, color: enabled ? p.ink : p.inkFaint),
      ),
    );
  }
}
