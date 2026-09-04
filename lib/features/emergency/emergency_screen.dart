import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:trip_planner/core/launch.dart';
import 'package:trip_planner/core/motion.dart';
import 'package:trip_planner/core/theme.dart';
import 'package:trip_planner/data/sources/overpass_service.dart';
import 'package:trip_planner/domain/survival.dart';
import 'package:trip_planner/features/emergency/guide_screen.dart';
import 'package:trip_planner/features/emergency/nearest_help_screen.dart';
import 'package:trip_planner/shared/widgets/primitives.dart';

/// The red screen. Everything on it works with no signal.
///
/// Laid out for someone who is cold, in the dark, or frightened: the rescue
/// numbers first because dialling beats reading, then the situations as big
/// targets. No search box — typing is the first thing to go.
class EmergencyScreen extends StatelessWidget {
  const EmergencyScreen({super.key});

  static const Color _alarm = Color(0xFFD03B3B);

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: p.canvas,
      appBar: AppBar(
        title: const Text('Emergency'),
        backgroundColor: _alarm,
        foregroundColor: Colors.white,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          FadeSlideIn(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _alarm.withValues(alpha: p.isDark ? 0.16 : 0.08),
                borderRadius: AppRadius.md,
                border: Border.all(color: _alarm.withValues(alpha: 0.34)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.wifi_off_rounded, size: 19, color: _alarm),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Every step on this screen is stored in the app. It all '
                      'works with no signal and no data. Only "nearest petrol '
                      'pump" needs a connection, and it says so if it cannot '
                      'get one.',
                      style: theme.textTheme.bodySmall?.copyWith(height: 1.45),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 22),

          const SectionHeader(
            title: 'Call for help',
            subtitle: 'Tap to put the number in your dialler',
          ),
          for (var i = 0; i < Survival.rescueNumbers.length; i++) ...[
            FadeSlideIn(
              delay: Motion.of(context).stagger(i),
              child: _RescueRow(number: Survival.rescueNumbers[i]),
            ),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 6),
          InfoNote(text: Survival.coverageNote, icon: Icons.cell_tower_rounded),

          const SizedBox(height: 26),
          const SectionHeader(
            title: 'Find what you need',
            subtitle: 'Uses your GPS and OpenStreetMap',
          ),
          Row(
            children: [
              Expanded(
                child: _FindButton(
                  icon: Icons.local_gas_station_rounded,
                  label: 'Petrol pump',
                  kind: HelpKind.fuel,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _FindButton(
                  icon: Icons.local_hospital_rounded,
                  label: 'Hospital',
                  kind: HelpKind.hospital,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _FindButton(
                  icon: Icons.local_police_rounded,
                  label: 'Police',
                  kind: HelpKind.police,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _FindButton(
                  icon: Icons.build_rounded,
                  label: 'Mechanic',
                  kind: HelpKind.workshop,
                ),
              ),
            ],
          ),

          const SizedBox(height: 26),
          const SectionHeader(
            title: 'What has happened?',
            subtitle: 'Step by step, in the order to do them',
          ),
          for (var i = 0; i < Survival.guides.length; i++) ...[
            FadeSlideIn(
              delay: Motion.of(context).stagger(i),
              child: _SituationRow(guide: Survival.guides[i]),
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _RescueRow extends StatelessWidget {
  const _RescueRow({required this.number});

  final RescueNumber number;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = context.palette;

    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      onTap: () async {
        final ok = await Launch.dial(number.number);
        if (!ok && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not open the dialler. Call ${number.number}.')),
          );
        }
      },
      child: Row(
        children: [
          Container(
            width: 54,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: EmergencyScreen._alarm.withValues(alpha: p.isDark ? 0.2 : 0.1),
              borderRadius: AppRadius.sm,
            ),
            child: Text(
              number.number,
              style: theme.textTheme.titleMedium?.copyWith(
                color: EmergencyScreen._alarm,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(number.who, style: theme.textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(number.what, style: theme.textTheme.bodySmall?.copyWith(height: 1.35)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(Icons.phone_rounded, size: 19, color: p.primary),
        ],
      ),
    );
  }
}

class _FindButton extends StatelessWidget {
  const _FindButton({required this.icon, required this.label, required this.kind});

  final IconData icon;
  final String label;
  final HelpKind kind;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      onTap: () => context.pushScreen(NearestHelpScreen(kind: kind)),
      child: Row(
        children: [
          Icon(icon, size: 19, color: p.primary),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.titleSmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _SituationRow extends StatelessWidget {
  const _SituationRow({required this.guide});

  final SurvivalGuide guide;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = context.palette;

    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      onTap: () => context.pushScreen(GuideScreen(guide: guide)),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: p.surfaceAlt,
              borderRadius: AppRadius.sm,
            ),
            child: Icon(guide.icon, size: 19, color: p.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(guide.title, style: theme.textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(guide.subtitle, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, size: 20, color: p.inkFaint),
        ],
      ),
    );
  }
}
