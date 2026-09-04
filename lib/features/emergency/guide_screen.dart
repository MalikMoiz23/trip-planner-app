import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:trip_planner/core/launch.dart';
import 'package:trip_planner/core/motion.dart';
import 'package:trip_planner/core/theme.dart';
import 'package:trip_planner/data/sources/overpass_service.dart';
import 'package:trip_planner/domain/survival.dart';
import 'package:trip_planner/features/emergency/nearest_help_screen.dart';
import 'package:trip_planner/shared/widgets/primitives.dart';

/// One situation, as an ordered list you work down.
///
/// The single most important action is pulled out above the list and given the
/// most weight on the screen, because the failure mode here is not a person who
/// cannot find step six — it is a person who reads nothing and starts walking.
class GuideScreen extends StatelessWidget {
  const GuideScreen({super.key, required this.guide});

  final SurvivalGuide guide;

  static const Color _alarm = Color(0xFFD03B3B);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = context.palette;
    final motion = Motion.of(context);

    return Scaffold(
      backgroundColor: p.canvas,
      appBar: AppBar(
        title: Text(guide.title),
        backgroundColor: _alarm,
        foregroundColor: Colors.white,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 36),
        children: [
          // ---- Do this first ------------------------------------------------
          FadeSlideIn(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _alarm.withValues(alpha: p.isDark ? 0.16 : 0.08),
                borderRadius: AppRadius.md,
                border: Border.all(color: _alarm.withValues(alpha: 0.34)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.priority_high_rounded, size: 17, color: _alarm),
                      const SizedBox(width: 7),
                      Text(
                        'DO THIS FIRST',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: _alarm,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.7,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 9),
                  Text(
                    guide.firstThing,
                    style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
                  ),
                ],
              ),
            ),
          ),

          // ---- Fuel gets a live lookup --------------------------------------
          if (guide.kind == Emergency.fuel) ...[
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () =>
                  context.pushScreen(const NearestHelpScreen(kind: HelpKind.fuel)),
              icon: const Icon(Icons.local_gas_station_rounded, size: 19),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              label: const Text('Find the nearest petrol pump'),
            ),
          ],

          const SizedBox(height: 26),
          const SectionHeader(title: 'Then, in this order'),
          for (var i = 0; i < guide.steps.length; i++)
            FadeSlideIn(
              delay: motion.stagger(i),
              child: _Step(index: i + 1, step: guide.steps[i]),
            ),

          // ---- Never --------------------------------------------------------
          const SizedBox(height: 20),
          FadeSlideIn(
            child: Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: p.surface,
                borderRadius: AppRadius.md,
                border: Border.all(color: _alarm.withValues(alpha: 0.4), width: 1.4),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.dangerous_rounded, size: 18, color: _alarm),
                      const SizedBox(width: 7),
                      Text(
                        'NEVER',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: _alarm,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.7,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  for (final warning in guide.never)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 9),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 6, right: 9),
                            child: Container(
                              width: 5,
                              height: 5,
                              decoration: const BoxDecoration(
                                color: _alarm,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              warning,
                              style: theme.textTheme.bodySmall?.copyWith(height: 1.45),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),

          // ---- When to call -------------------------------------------------
          const SizedBox(height: 16),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('When to call for help', style: theme.textTheme.titleSmall),
                const SizedBox(height: 7),
                Text(guide.callFor, style: theme.textTheme.bodySmall?.copyWith(height: 1.45)),
                const SizedBox(height: 13),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final r in Survival.rescueNumbers.take(3))
                      OutlinedButton.icon(
                        onPressed: () => Launch.dial(r.number),
                        icon: const Icon(Icons.phone_rounded, size: 16),
                        label: Text('${r.number}  ${r.who}'),
                      ),
                  ],
                ),
              ],
            ),
          ),

          if (guide.note != null) ...[
            const SizedBox(height: 14),
            InfoNote(text: guide.note!),
          ],
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.index, required this.step});

  final int index;
  final GuideStep step;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = context.palette;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: p.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Text(
                '$index',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: p.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(step.title, style: theme.textTheme.titleSmall),
                  const SizedBox(height: 5),
                  Text(
                    step.detail,
                    style: theme.textTheme.bodySmall?.copyWith(height: 1.5),
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
