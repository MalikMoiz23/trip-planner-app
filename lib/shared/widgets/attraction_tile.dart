import 'package:flutter/material.dart';

import 'package:trip_planner/core/formatters.dart';
import 'package:trip_planner/core/theme.dart';
import 'package:trip_planner/data/models/attraction.dart';
import 'package:trip_planner/shared/widgets/primitives.dart';

/// Selectable row in the stop picker. Shows the two things that decide whether
/// a stop makes the cut: how far the detour is and what it costs per head.
class AttractionTile extends StatelessWidget {
  const AttractionTile({
    super.key,
    required this.attraction,
    required this.distanceKm,
    required this.selected,
    required this.onToggle,
    this.onEditCost,
    this.persons = 1,
  });

  final Attraction attraction;
  final double distanceKm;
  final bool selected;
  final VoidCallback onToggle;
  final VoidCallback? onEditCost;
  final int persons;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final a = attraction;
    final perPerson = a.costPerPerson();
    final groupCost = perPerson * persons;

    return Material(
      color: selected ? context.palette.primary.withValues(alpha: 0.06) : theme.cardTheme.color,
      borderRadius: AppRadius.md,
      child: InkWell(
        onTap: onToggle,
        borderRadius: AppRadius.md,
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            borderRadius: AppRadius.md,
            border: Border.all(
              color: selected ? context.palette.primary : (theme.dividerTheme.color ?? context.palette.line),
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: AppColors.gradientFor(a.category),
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: AppRadius.sm,
                ),
                child: Icon(AppColors.iconFor(a.category), color: Colors.white, size: 21),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(a.name, style: theme.textTheme.titleSmall?.copyWith(fontSize: 14.5)),
                    const SizedBox(height: 3),
                    Text(
                      a.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        PillTag(
                          label: km(distanceKm),
                          icon: Icons.route_rounded,
                          color: context.palette.primary,
                        ),
                        PillTag(label: hours(a.visitHours), icon: Icons.schedule_rounded),
                        // An estimated figure is labelled as one. A curated
                        // figure is shown plain, because it is a real price.
                        if (perPerson > 0 && a.ratesEstimated)
                          PillTag(
                            label: 'Est. ${money(perPerson)}/person',
                            icon: Icons.help_outline_rounded,
                            color: context.palette.caution,
                          )
                        else if (perPerson > 0)
                          PillTag(
                            label: '${money(perPerson)}/person',
                            icon: Icons.payments_rounded,
                            color: context.palette.primary,
                          )
                        else
                          PillTag(
                            label: 'Free entry',
                            icon: Icons.check_rounded,
                            color: context.palette.success,
                          ),
                        if (a.requires4x4)
                          PillTag(
                            label: 'Jeep only',
                            icon: Icons.airport_shuttle_rounded,
                            color: context.palette.caution,
                          ),
                      ],
                    ),
                    if (selected && groupCost > 0) ...[
                      const SizedBox(height: 9),
                      Text(
                        'Adds ${money(groupCost)} for $persons '
                        '${persons == 1 ? 'person' : 'people'}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: context.palette.primary,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                children: [
                  _Check(selected: selected, onTap: onToggle),
                  if (onEditCost != null) ...[
                    const SizedBox(height: 6),
                    IconButton(
                      onPressed: onEditCost,
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                      icon: const Icon(Icons.edit_outlined, size: 17),
                      color: context.palette.inkSoft,
                      tooltip: 'Edit cost',
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Check extends StatelessWidget {
  const _Check({required this.selected, required this.onTap});

  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: selected ? context.palette.primary : Colors.transparent,
          borderRadius: AppRadius.sm,
          border: Border.all(
            color: selected ? context.palette.primary : context.palette.line,
            width: 1.6,
          ),
        ),
        child: selected
            ? const Icon(Icons.check_rounded, size: 17, color: Colors.white)
            : null,
      ),
    );
  }
}
