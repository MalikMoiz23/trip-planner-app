import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/formatters.dart';
import '../../core/motion.dart';
import '../../core/theme.dart';
import '../../logic/budget_advisor.dart';
import '../../state/planner_controller.dart';
import 'ambient.dart';
import 'inputs.dart';
import 'primitives.dart';

/// Set a budget, see whether the trip fits, and get costed ways to close the
/// gap if it does not.
class BudgetPanel extends StatelessWidget {
  const BudgetPanel({super.key, this.compact = false});

  /// In the planner the levers are hidden; the summary shows the lot.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final c = context.watch<PlannerController>();
    final p = context.palette;
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        NumberField(
          label: 'What can you spend in total?',
          value: c.budget,
          prefix: 'Rs ',
          helper: 'Leave it at zero to skip this. The whole group, not per person.',
          onChanged: c.setBudget,
        ),
        if (c.hasBudget) ...[
          const SizedBox(height: 14),
          Builder(builder: (context) {
            final advice = c.budgetAdvice;
            if (advice == null) {
              return Text(
                'The verdict appears once the route has been measured.',
                style: theme.textTheme.bodySmall?.copyWith(fontSize: 12.5, color: p.inkFaint),
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Verdict(advice: advice),
                if (!compact && !advice.fits) ...[
                  const SizedBox(height: 16),
                  _Levers(advice: advice),
                ],
              ],
            );
          }),
        ],
      ],
    );
  }

}

class _Verdict extends StatelessWidget {
  const _Verdict({required this.advice});

  final BudgetAdvice advice;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final theme = Theme.of(context);
    final fits = advice.fits;
    final tone = fits ? p.success : (advice.reachable ? p.caution : p.danger);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                fits ? Icons.check_circle_rounded : Icons.report_problem_rounded,
                size: 20,
                color: tone,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: SwapIn(
                  child: Text(
                    fits
                        ? 'Fits, with ${money(advice.headroom)} to spare'
                        : '${money(advice.gap)} over budget',
                    key: ValueKey(fits ? advice.headroom.round() : advice.gap.round()),
                    style: theme.textTheme.titleMedium?.copyWith(fontSize: 15.5, color: tone),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _Meter(ratio: advice.ratio, tone: tone),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _Figure(label: 'Trip costs', value: advice.total),
              ),
              Expanded(
                child: _Figure(label: 'You have', value: advice.budget, align: TextAlign.right),
              ),
            ],
          ),
          if (!fits) ...[
            const SizedBox(height: 10),
            Text(
              advice.reachable
                  ? 'The changes below can bring it down. They overlap, so taking two '
                      'saves less than adding their two figures together.'
                  : 'Even taking every suggestion below, this trip does not reach '
                      '${money(advice.budget)}. Something bigger has to give — fewer '
                      'people, or a nearer destination.',
              style: theme.textTheme.bodySmall?.copyWith(fontSize: 12.3),
            ),
          ],
        ],
      ),
    );
  }
}

/// Fill bar that overshoots visibly when the trip is over budget.
class _Meter extends StatelessWidget {
  const _Meter({required this.ratio, required this.tone});

  final double ratio;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final motion = Motion.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final full = constraints.maxWidth;
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: ratio.clamp(0.0, 1.35)),
          duration: motion.d(Motion.lazy),
          curve: Motion.enter,
          builder: (context, t, _) => Stack(
            children: [
              Container(
                height: 12,
                decoration: BoxDecoration(color: p.line, borderRadius: AppRadius.pill),
              ),
              Container(
                height: 12,
                width: (full * t).clamp(0.0, full),
                decoration: BoxDecoration(color: tone, borderRadius: AppRadius.pill),
              ),
              // The budget line stays visible when the bar runs past it.
              if (t > 1)
                Positioned(
                  left: full / t.clamp(1.0, 1.35) * 1 - 1,
                  child: Container(height: 12, width: 2, color: p.surface),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({required this.label, required this.value, this.align = TextAlign.left});

  final String label;
  final double value;
  final TextAlign align;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment:
          align == TextAlign.right ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.bodySmall?.copyWith(fontSize: 11.5)),
        AnimatedNumber(
          value: value,
          format: money,
          textAlign: align,
          style: theme.textTheme.titleMedium?.copyWith(fontSize: 15),
        ),
      ],
    );
  }
}

class _Levers extends StatelessWidget {
  const _Levers({required this.advice});

  final BudgetAdvice advice;

  @override
  Widget build(BuildContext context) {
    final c = context.read<PlannerController>();
    final theme = Theme.of(context);
    final p = context.palette;
    // Only a change that closes the whole gap by itself earns the badge.
    final sufficient = advice.levers
        .where((l) => l.saving >= advice.gap)
        .map((l) => l.id)
        .toSet();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Ways to close the gap',
          subtitle: '${advice.levers.length} '
              '${advice.levers.length == 1 ? 'change' : 'changes'}, each re-costed '
              'against this exact trip',
        ),
        for (var i = 0; i < advice.levers.length; i++)
          FadeSlideIn(
            delay: Motion.of(context).stagger(i),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: PressableScale(
                onTap: () {
                  c.applyLever(advice.levers[i]);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Applied: ${advice.levers[i].title}')),
                  );
                },
                child: AppCard(
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: p.primary.withValues(alpha: 0.12),
                          borderRadius: AppRadius.sm,
                        ),
                        child: Icon(advice.levers[i].icon, size: 19, color: p.primary),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    advice.levers[i].title,
                                    style: theme.textTheme.titleSmall?.copyWith(fontSize: 13.5),
                                  ),
                                ),
                                if (sufficient.contains(advice.levers[i].id)) ...[
                                  const SizedBox(width: 6),
                                  PillTag(
                                    label: 'enough on its own',
                                    color: p.success,
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              advice.levers[i].detail,
                              style: theme.textTheme.bodySmall?.copyWith(fontSize: 12.2),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '−${money(advice.levers[i].saving)}',
                            style: theme.textTheme.titleSmall
                                ?.copyWith(fontSize: 14, color: p.success),
                          ),
                          Text('tap to apply',
                              style: theme.textTheme.bodySmall
                                  ?.copyWith(fontSize: 10.5, color: p.inkFaint)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
