import 'package:flutter/material.dart';

import '../../core/enums.dart';
import '../../core/theme.dart';
import '../../models/expense_breakdown.dart';

/// Advisories use the reserved status palette, never a series hue, and always
/// pair the colour with an icon and a written level so meaning is never carried
/// by colour alone.
class WarningCard extends StatelessWidget {
  const WarningCard({super.key, required this.warning});

  final TripWarning warning;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (color, icon, level) = switch (warning.level) {
      WarningLevel.blocker => (AppColors.danger, Icons.error_outline_rounded, 'Fix this'),
      WarningLevel.caution => (AppColors.serious, Icons.warning_amber_rounded, 'Check this'),
      WarningLevel.info => (AppColors.primary, Icons.info_outline_rounded, 'Note'),
    };

    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: AppRadius.md,
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 19, color: color),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        warning.title,
                        style: theme.textTheme.titleSmall?.copyWith(fontSize: 14),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.14),
                        borderRadius: AppRadius.pill,
                      ),
                      child: Text(
                        level,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: color,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  warning.detail,
                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 12.4, height: 1.45),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
