import 'package:flutter/material.dart';

import '../../core/formatters.dart';
import '../../core/theme.dart';
import '../../models/destination.dart';
import 'primitives.dart';

/// The gradient plate every destination visual is built on.
///
/// The app ships no photography, so identity comes from a per-category
/// gradient plus an oversized watermark glyph. It renders identically offline
/// and never shows a broken image box.
class DestinationPlate extends StatelessWidget {
  const DestinationPlate({
    super.key,
    required this.category,
    this.borderRadius = AppRadius.md,
    this.child,
    this.watermarkSize = 150,
  });

  final String category;
  final BorderRadius borderRadius;
  final Widget? child;
  final double watermarkSize;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.gradientFor(category);
    return ClipRRect(
      borderRadius: borderRadius,
      child: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: colors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          Positioned(
            right: -watermarkSize * 0.18,
            bottom: -watermarkSize * 0.22,
            child: Icon(
              AppColors.iconFor(category),
              size: watermarkSize,
              color: Colors.white.withValues(alpha: 0.10),
            ),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Color(0x99000000)],
                stops: [0.35, 1.0],
              ),
            ),
          ),
          ?child,
        ],
      ),
    );
  }
}

/// Wide card for the featured carousel.
class DestinationCard extends StatelessWidget {
  const DestinationCard({
    super.key,
    required this.destination,
    required this.onTap,
    this.width = 232,
  });

  final Destination destination;
  final VoidCallback onTap;
  final double width;

  @override
  Widget build(BuildContext context) {
    final d = destination;
    return SizedBox(
      width: width,
      child: GestureDetector(
        onTap: onTap,
        child: DestinationPlate(
          category: d.category,
          borderRadius: AppRadius.lg,
          watermarkSize: 168,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    PillTag(label: d.category, onSurface: true),
                    const Spacer(),
                    PillTag(
                      label: '${d.recommendedDays}d',
                      icon: Icons.event_rounded,
                      onSurface: true,
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  d.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  d.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70, fontSize: 12.5),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.place_rounded, size: 13, color: Colors.white70),
                    const SizedBox(width: 4),
                    Text(
                      '${d.attractions.length} nearby spots',
                      style: const TextStyle(color: Colors.white70, fontSize: 11.5),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Row used in the explore list — plate thumbnail plus the facts that decide
/// whether a place is even feasible right now.
class DestinationRow extends StatelessWidget {
  const DestinationRow({
    super.key,
    required this.destination,
    required this.onTap,
    this.trailing,
  });

  final Destination destination;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final d = destination;
    final inSeason = d.inSeason(DateTime.now());

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(10),
      child: Row(
        children: [
          SizedBox(
            width: 84,
            height: 84,
            child: DestinationPlate(
              category: d.category,
              watermarkSize: 74,
              child: Align(
                alignment: Alignment.bottomLeft,
                child: Padding(
                  padding: const EdgeInsets.all(7),
                  child: Text(
                    d.province.isEmpty ? d.category : _shortProvince(d.province),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        d.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                    ?trailing,
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  d.tagline,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 12.3),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    PillTag(
                      label: inSeason ? 'In season' : 'Off season',
                      icon: inSeason ? Icons.check_circle_rounded : Icons.ac_unit_rounded,
                      color: inSeason ? AppColors.success : AppColors.caution,
                    ),
                    PillTag(label: '${d.recommendedDays} days', icon: Icons.event_rounded),
                    if (d.altitudeM > 0)
                      PillTag(label: '${d.altitudeM} m', icon: Icons.terrain_rounded),
                    if (d.requires4x4)
                      const PillTag(
                        label: '4x4',
                        icon: Icons.airport_shuttle_rounded,
                        color: AppColors.caution,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _shortProvince(String province) {
    switch (province) {
      case 'Khyber Pakhtunkhwa':
        return 'KP';
      case 'Gilgit-Baltistan':
        return 'GB';
      case 'Azad Jammu & Kashmir':
        return 'AJK';
      default:
        return province;
    }
  }
}

/// Compact chip strip for "best months".
class MonthStrip extends StatelessWidget {
  const MonthStrip({super.key, required this.months});

  final List<int> months;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now().month;
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: List.generate(12, (i) {
        final m = i + 1;
        final good = months.contains(m);
        final isNow = m == now;
        return Container(
          width: 40,
          padding: const EdgeInsets.symmetric(vertical: 6),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: good ? AppColors.primary.withValues(alpha: 0.12) : AppColors.canvas,
            borderRadius: AppRadius.sm,
            border: Border.all(
              color: isNow ? AppColors.primary : AppColors.line,
              width: isNow ? 1.6 : 1,
            ),
          ),
          child: Text(
            shortMonthName(m),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: good ? AppColors.primary : AppColors.inkSoft,
            ),
          ),
        );
      }),
    );
  }
}
