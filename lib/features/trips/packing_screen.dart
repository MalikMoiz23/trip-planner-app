import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:trip_planner/core/formatters.dart';
import 'package:trip_planner/core/motion.dart';
import 'package:trip_planner/core/theme.dart';
import 'package:trip_planner/domain/packing_builder.dart';
import 'package:trip_planner/app/app_state.dart';
import 'package:trip_planner/features/planner/planner_controller.dart';
import 'package:trip_planner/shared/widgets/primitives.dart';

/// A packing list built from this trip rather than from a template.
///
/// Ticks are kept in memory for an unsaved plan and written through to storage
/// once the trip has been saved, so the list is still ticked the next morning
/// when it is actually being used.
class PackingScreen extends StatefulWidget {
  const PackingScreen({super.key, this.savedTripId});

  /// When set, ticks persist against that trip.
  final String? savedTripId;

  @override
  State<PackingScreen> createState() => _PackingScreenState();
}

class _PackingScreenState extends State<PackingScreen> {
  Set<String> _packed = {};
  bool _seeded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_seeded) return;
    _seeded = true;
    final id = widget.savedTripId;
    if (id == null) return;
    final trip = context.read<AppState>().tripById(id);
    if (trip != null) _packed = {...trip.packedItemIds};
  }

  Future<void> _toggle(String id) async {
    setState(() {
      if (!_packed.remove(id)) _packed.add(id);
    });
    final tripId = widget.savedTripId;
    if (tripId != null) {
      await context.read<AppState>().setPackedItems(tripId, _packed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<PlannerController>();
    final p = context.palette;
    final theme = Theme.of(context);

    if (!c.hasDestination) {
      return const Scaffold(body: Center(child: Text('No trip to pack for yet.')));
    }

    final config = c.buildConfig();
    final sections = PackingBuilder.build(config: config, weather: c.weather);
    final all = sections.expand((s) => s.items).toList();
    final done = all.where((i) => _packed.contains(i.id)).length;
    final criticalLeft =
        all.where((i) => i.critical && !_packed.contains(i.id)).length;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 64,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Packing list', style: theme.textTheme.titleLarge?.copyWith(fontSize: 18)),
            Text(
              '${config.destination.name} · ${plural(config.days, 'day', 'days')} · '
              '${monthName(config.startDate.month)}',
              style: theme.textTheme.bodySmall?.copyWith(fontSize: 12),
            ),
          ],
        ),
        actions: [
          if (_packed.isNotEmpty)
            TextButton(
              onPressed: () async {
                setState(_packed.clear);
                final tripId = widget.savedTripId;
                if (tripId != null) {
                  await context.read<AppState>().setPackedItems(tripId, _packed);
                }
              },
              child: const Text('Reset'),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
        children: [
          _Progress(done: done, total: all.length, criticalLeft: criticalLeft),
          const SizedBox(height: 18),
          for (var s = 0; s < sections.length; s++)
            FadeSlideIn(
              delay: Motion.of(context).stagger(s, step: const Duration(milliseconds: 70)),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(sections[s].icon, size: 18, color: p.primary),
                        const SizedBox(width: 8),
                        Text(sections[s].title,
                            style: theme.textTheme.titleMedium?.copyWith(fontSize: 15.5)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    for (final item in sections[s].items)
                      _ItemRow(
                        item: item,
                        checked: _packed.contains(item.id),
                        onTap: () => _toggle(item.id),
                      ),
                  ],
                ),
              ),
            ),
          if (widget.savedTripId == null)
            const InfoNote(
              icon: Icons.bookmark_add_outlined,
              text: 'Save this trip and the ticks will still be here next time. '
                  'Until then they last only as long as this screen.',
            ),
        ],
      ),
    );
  }
}

class _Progress extends StatelessWidget {
  const _Progress({required this.done, required this.total, required this.criticalLeft});

  final int done;
  final int total;
  final int criticalLeft;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final theme = Theme.of(context);
    final motion = Motion.of(context);
    final ratio = total == 0 ? 0.0 : done / total;
    final complete = done == total && total > 0;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  complete ? 'Everything packed' : '$done of $total packed',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontSize: 16,
                    color: complete ? p.success : p.ink,
                  ),
                ),
              ),
              if (criticalLeft > 0)
                PillTag(
                  label: '$criticalLeft essential left',
                  icon: Icons.priority_high_rounded,
                  color: p.serious,
                ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: AppRadius.pill,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: ratio),
              duration: motion.d(Motion.slow),
              curve: Motion.standard,
              builder: (context, t, _) => LinearProgressIndicator(
                value: t,
                minHeight: 10,
                backgroundColor: p.line,
                valueColor: AlwaysStoppedAnimation(complete ? p.success : p.primary),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.item, required this.checked, required this.onTap});

  final PackItem item;
  final bool checked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final theme = Theme.of(context);
    final motion = Motion.of(context);

    return PressableScale(
      onTap: onTap,
      pressedScale: 0.985,
      child: AnimatedContainer(
        duration: motion.d(Motion.quick),
        curve: Motion.standard,
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: checked ? p.surfaceAlt : p.surface,
          borderRadius: AppRadius.md,
          border: Border.all(
            color: checked
                ? p.success.withValues(alpha: 0.45)
                : (item.critical ? p.serious.withValues(alpha: 0.35) : p.line),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedContainer(
              duration: motion.d(Motion.quick),
              curve: Motion.spring,
              width: 22,
              height: 22,
              margin: const EdgeInsets.only(top: 1),
              decoration: BoxDecoration(
                color: checked ? p.success : Colors.transparent,
                borderRadius: BorderRadius.circular(7),
                border: Border.all(color: checked ? p.success : p.line, width: 1.6),
              ),
              child: checked
                  ? const Icon(Icons.check_rounded, size: 15, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: AnimatedDefaultTextStyle(
                          duration: motion.d(Motion.quick),
                          style: (theme.textTheme.titleSmall ?? const TextStyle()).copyWith(
                            fontSize: 13.8,
                            color: checked ? p.inkFaint : p.ink,
                            decoration:
                                checked ? TextDecoration.lineThrough : TextDecoration.none,
                            decorationColor: p.inkFaint,
                          ),
                          child: Text(item.label),
                        ),
                      ),
                      if (item.quantity != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          item.quantity!,
                          style: theme.textTheme.bodySmall
                              ?.copyWith(fontSize: 11.5, color: p.inkFaint),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    item.reason,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 12,
                      color: checked ? p.inkFaint : p.inkSoft,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
