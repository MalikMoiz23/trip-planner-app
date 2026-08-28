import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/enums.dart';
import '../../../core/formatters.dart';
import '../../../state/planner_controller.dart';
import '../../widgets/inputs.dart';
import '../../widgets/primitives.dart';

class StepComfort extends StatelessWidget {
  const StepComfort({super.key});

  static IconData _stayIcon(StayTier t) => switch (t) {
        StayTier.budget => Icons.night_shelter_rounded,
        StayTier.standard => Icons.hotel_rounded,
        StayTier.premium => Icons.apartment_rounded,
      };

  static IconData _mealIcon(MealTier t) => switch (t) {
        MealTier.basic => Icons.lunch_dining_rounded,
        MealTier.standard => Icons.restaurant_rounded,
        MealTier.premium => Icons.restaurant_menu_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final c = context.watch<PlannerController>();
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        SectionHeader(
          title: 'Rooms',
          subtitle: c.days > 1
              ? '${plural(c.nightsForDisplay, 'night', 'nights')} · '
                  '${plural(c.roomsForDisplay, 'room', 'rooms')} for ${c.persons} '
                  '${c.persons == 1 ? 'person' : 'people'}'
              : 'Day trip — no rooms needed',
        ),
        ...StayTier.values.map((tier) => Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: TierOption(
                title: tier.label,
                blurb: tier.blurb,
                price: '${money(tier.defaultRatePerRoomNight)}/night',
                icon: _stayIcon(tier),
                selected: c.stayTier == tier,
                onTap: () => c.setStayTier(tier),
              ),
            )),
        const SizedBox(height: 6),
        NumberField(
          label: 'Your room rate',
          value: c.stayRate,
          prefix: 'Rs ',
          suffix: '/night',
          onChanged: c.setStayRate,
        ),
        const SizedBox(height: 10),
        CounterRow(
          label: 'People per room',
          caption: 'Decides how many rooms you book',
          icon: Icons.bed_rounded,
          value: c.roomOccupancy,
          min: 1,
          max: 6,
          onChanged: c.setRoomOccupancy,
        ),
        const SizedBox(height: 24),
        const SectionHeader(
          title: 'Food',
          subtitle: 'Per person per day, covering all meals and tea stops',
        ),
        ...MealTier.values.map((tier) => Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: TierOption(
                title: tier.label,
                blurb: tier.blurb,
                price: '${money(tier.defaultRatePerPersonDay)}/day',
                icon: _mealIcon(tier),
                selected: c.mealTier == tier,
                onTap: () => c.setMealTier(tier),
              ),
            )),
        const SizedBox(height: 6),
        NumberField(
          label: 'Your food budget per person per day',
          value: c.mealRate,
          prefix: 'Rs ',
          onChanged: c.setMealRate,
        ),
        const SizedBox(height: 24),
        const SectionHeader(
          title: 'Contingency',
          subtitle: 'Slack for weather, breakdowns and prices moving under you',
        ),
        AppCard(
          child: SliderRow(
            label: 'Buffer on top of everything',
            valueLabel: '${c.bufferPercent.round()}%',
            value: c.bufferPercent,
            min: 0,
            max: 30,
            divisions: 30,
            onChanged: c.setBuffer,
            helper: 'Mountain roads close, jeeps get hired at short notice and fuel moves. '
                '10% is the sensible floor; 15–20% if you are going far north.',
          ),
        ),
        const SizedBox(height: 20),
        if (c.breakdown != null)
          Row(
            children: [
              Expanded(
                child: StatTile(
                  label: 'Rooms',
                  value: money(c.breakdown!.stayCost),
                  caption: c.breakdown!.nights == 0
                      ? 'day trip'
                      : '${c.breakdown!.nights} x ${c.breakdown!.rooms}',
                  icon: Icons.hotel_rounded,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: StatTile(
                  label: 'Food',
                  value: money(c.breakdown!.mealCost),
                  caption: '${c.days} days x ${c.persons}',
                  icon: Icons.restaurant_rounded,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: StatTile(
                  label: 'Buffer',
                  value: money(c.breakdown!.bufferCost),
                  caption: '${c.bufferPercent.round()}%',
                  icon: Icons.savings_rounded,
                ),
              ),
            ],
          ),
        const SizedBox(height: 16),
        Text(
          'Every rate on this screen is an editable estimate. Nothing here is fetched '
          'from a booking service, so treat the total as a planning figure and confirm '
          'prices before you commit.',
          style: theme.textTheme.bodySmall?.copyWith(fontSize: 12.2),
        ),
      ],
    );
  }
}
