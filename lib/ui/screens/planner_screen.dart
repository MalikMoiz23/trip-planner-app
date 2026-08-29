import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/formatters.dart';
import '../../core/theme.dart';
import '../../state/planner_controller.dart';
import 'steps/step_basics.dart';
import 'steps/step_comfort.dart';
import 'steps/step_stops.dart';
import 'steps/step_travel.dart';
import 'summary_screen.dart';

class PlannerScreen extends StatelessWidget {
  const PlannerScreen({super.key});

  static const _titles = ['Trip basics', 'Getting there', 'Stops', 'Comfort'];
  static const _subtitles = [
    'Where from, where to, how long, how many',
    'Vehicle and fuel, or public transport',
    'What you want to see around the base town',
    'Rooms, meals and how much slack to keep',
  ];

  Future<void> _openSummary(BuildContext context) async {
    final controller = context.read<PlannerController>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    final blocker = controller.blockingReason();
    if (blocker != null) {
      messenger.showSnackBar(SnackBar(content: Text(blocker)));
      return;
    }

    await controller.finalise();
    if (controller.breakdown == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not work out the route. Check your connection.')),
      );
      return;
    }
    await navigator.push(MaterialPageRoute(builder: (_) => const SummaryScreen()));
  }

  void _next(BuildContext context) {
    final controller = context.read<PlannerController>();
    final blocker = controller.blockingReason();
    if (blocker != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(blocker)));
      return;
    }
    controller.next();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<PlannerController>();
    final theme = Theme.of(context);

    if (!controller.hasDestination) {
      return const Scaffold(body: Center(child: Text('No destination selected.')));
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_titles[controller.step], style: theme.textTheme.titleLarge?.copyWith(fontSize: 18)),
            Text(
              'Step ${controller.step + 1} of ${PlannerController.stepCount}  ·  '
              '${controller.destination!.name}',
              style: theme.textTheme.bodySmall?.copyWith(fontSize: 12),
            ),
          ],
        ),
        toolbarHeight: 64,
      ),
      body: Column(
        children: [
          _StepBar(step: controller.step, onTap: (i) => controller.goTo(i)),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _subtitles[controller.step],
                style: theme.textTheme.bodySmall?.copyWith(fontSize: 13),
              ),
            ),
          ),
          Expanded(
            child: IndexedStack(
              index: controller.step,
              children: const [
                StepBasics(),
                StepTravel(),
                StepStops(),
                StepComfort(),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _Footer(
        onNext: () => _next(context),
        onBack: controller.back,
        onFinish: () => _openSummary(context),
      ),
    );
  }
}

class _StepBar extends StatelessWidget {
  const _StepBar({required this.step, required this.onTap});

  final int step;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: List.generate(PlannerController.stepCount, (i) {
          final done = i <= step;
          return Expanded(
            child: GestureDetector(
              // Backwards navigation only — jumping ahead would skip validation.
              onTap: i < step ? () => onTap(i) : null,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: EdgeInsets.only(right: i == PlannerController.stepCount - 1 ? 0 : 6),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 4,
                  decoration: BoxDecoration(
                    color: done ? context.palette.primary : context.palette.line,
                    borderRadius: AppRadius.pill,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

/// Persistent running total. The point of the app is that the number moves as
/// you change inputs, so it is visible on every step rather than only at the end.
class _Footer extends StatelessWidget {
  const _Footer({required this.onNext, required this.onBack, required this.onFinish});

  final VoidCallback onNext;
  final VoidCallback onBack;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<PlannerController>();
    final theme = Theme.of(context);
    final breakdown = controller.breakdown;
    final isLast = controller.step == PlannerController.stepCount - 1;
    final busy = controller.routing || controller.finalising;

    return Container(
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        border: Border(top: BorderSide(color: theme.dividerTheme.color ?? context.palette.line)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          busy
                              ? 'Working out the route…'
                              : breakdown == null
                                  ? 'Set your starting point to see the total'
                                  : 'Estimated total',
                          style: theme.textTheme.bodySmall?.copyWith(fontSize: 12),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          breakdown == null ? '—' : money(breakdown.total),
                          style: theme.textTheme.headlineSmall?.copyWith(fontSize: 23),
                        ),
                      ],
                    ),
                  ),
                  if (breakdown != null)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'per person',
                          style: theme.textTheme.bodySmall?.copyWith(fontSize: 12),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          money(breakdown.perPerson),
                          style: theme.textTheme.titleMedium?.copyWith(fontSize: 17),
                        ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  if (controller.step > 0) ...[
                    Expanded(
                      child: OutlinedButton(onPressed: onBack, child: const Text('Back')),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: busy ? null : (isLast ? onFinish : onNext),
                      child: busy
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation(Colors.white),
                              ),
                            )
                          : Text(isLast ? 'See full breakdown' : 'Continue'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
