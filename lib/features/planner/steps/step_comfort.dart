import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:trip_planner/core/constants.dart';
import 'package:trip_planner/core/enums.dart';
import 'package:trip_planner/core/motion.dart';
import 'package:trip_planner/core/theme.dart';
import 'package:trip_planner/data/models/meal_plan.dart';
import 'package:trip_planner/core/formatters.dart';
import 'package:trip_planner/features/planner/planner_controller.dart';
import 'package:trip_planner/shared/widgets/inputs.dart';
import 'package:trip_planner/shared/widgets/primitives.dart';

class StepComfort extends StatelessWidget {
  const StepComfort({super.key});

  static IconData _stayIcon(StayStyle s) => switch (s) {
        StayStyle.ownTent => Icons.cabin_rounded,
        StayStyle.rentedTent => Icons.holiday_village_rounded,
        StayStyle.guestHouse => Icons.night_shelter_rounded,
        StayStyle.hotel => Icons.hotel_rounded,
        StayStyle.resort => Icons.apartment_rounded,
      };

  static IconData _foodIcon(FoodStyle f) => switch (f) {
        FoodStyle.selfCooking => Icons.local_fire_department_rounded,
        FoodStyle.dhaba => Icons.lunch_dining_rounded,
        FoodStyle.restaurant => Icons.restaurant_rounded,
        FoodStyle.hotelDining => Icons.restaurant_menu_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final c = context.watch<PlannerController>();
    final theme = Theme.of(context);
    final b = c.breakdown;
    final unit = c.stayStyle.unitLabel;
    final unitPlural = c.stayStyle.unitLabelPlural;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        // ---- Where you sleep ------------------------------------------------
        SectionHeader(
          title: 'Where you sleep',
          subtitle: c.days > 1
              ? '${plural(c.nightsForDisplay, 'night', 'nights')} · '
                  '${plural(c.roomsForDisplay, unit, unitPlural)} for ${c.persons} '
                  '${c.persons == 1 ? 'person' : 'people'}'
              : 'Day trip — nowhere to sleep needed',
        ),
        ...StayStyle.values.map((style) => Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: TierOption(
                title: style.label,
                blurb: style.blurb,
                price: style.isFree
                    ? 'Free'
                    : '${money(style.defaultRatePerUnitNight)}/night',
                icon: _stayIcon(style),
                selected: c.stayStyle == style,
                onTap: () => c.setStayStyle(style),
              ),
            )),
        const SizedBox(height: 6),
        if (c.stayStyle.isFree)
          const InfoNote(
            icon: Icons.check_circle_outline_rounded,
            text: 'Your own tent costs nothing per night, so accommodation drops out '
                'of the total entirely. Check the destination allows camping and that '
                'you are equipped for the altitude.',
          )
        else
          NumberField(
            label: 'Your $unit rate',
            value: c.stayRate,
            prefix: 'Rs ',
            suffix: '/night',
            onChanged: c.setStayRate,
          ),
        const SizedBox(height: 10),
        CounterRow(
          label: 'People per $unit',
          caption: 'Decides how many $unitPlural you need',
          icon: c.stayStyle.isCamping ? Icons.cabin_rounded : Icons.bed_rounded,
          value: c.roomOccupancy,
          min: 1,
          max: 6,
          onChanged: c.setRoomOccupancy,
        ),

        // ---- Food -----------------------------------------------------------
        const SizedBox(height: 24),
        const SectionHeader(
          title: 'Food',
          subtitle: 'Where you eat, what each sitting costs, and which meals '
              'you take on each day',
        ),
        ...FoodStyle.values.map((style) => Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: TierOption(
                title: style.label,
                blurb: style.blurb,
                price: '${money(style.defaultPricePerMeal)}/meal',
                icon: _foodIcon(style),
                selected: c.foodStyle == style,
                onTap: () => c.setFoodStyle(style),
              ),
            )),

        // ---- Price per sitting ----------------------------------------------
        const SizedBox(height: 16),
        SectionHeader(
          title: 'What each sitting costs',
          subtitle: 'Per person. Breakfast is usually a fraction of dinner, so '
              'they are priced separately.',
        ),
        ...MealSlot.values.map((slot) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: NumberField(
                label: '${slot.label}  ·  ${slot.timeHint}',
                value: c.mealPlan.priceOf(slot),
                prefix: 'Rs ',
                helper: slot.blurb,
                onChanged: (v) => c.setMealPrice(slot, v),
              ),
            )),

        if (c.foodStyle.needsKitchen) ...[
          const SizedBox(height: 2),
          NumberField(
            label: 'Stove, gas and utensils',
            value: c.campKitchenCost,
            prefix: 'Rs ',
            helper: 'Counted once for the trip, not per meal. Set it to zero if you '
                'already own the kit.',
            onChanged: c.setCampKitchenCost,
          ),
        ],

        // ---- Which meals, day by day ----------------------------------------
        const SizedBox(height: 20),
        SectionHeader(
          title: 'Which meals, day by day',
          subtitle: 'A driving day is often two meals, or one late one. Tap to '
              'add or remove.',
        ),
        _MealGrid(controller: c),

        const SizedBox(height: 12),
        _foodMath(context, c),

        // ---- Contingency ----------------------------------------------------
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
        if (b != null)
          Row(
            children: [
              Expanded(
                child: StatTile(
                  label: c.stayStyle.isCamping ? 'Camping' : 'Rooms',
                  value: money(b.stayCost),
                  caption: b.nights == 0
                      ? 'day trip'
                      : '${b.nights} × ${b.rooms} ${b.unitLabel}',
                  icon: _stayIcon(c.stayStyle),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: StatTile(
                  label: 'Food',
                  value: money(b.mealCost),
                  caption: '${b.mealCount} meals',
                  icon: _foodIcon(c.foodStyle),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: StatTile(
                  label: 'Buffer',
                  value: money(b.bufferCost),
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

  /// Spells the food arithmetic out on the screen where it is chosen, so the
  /// number on the summary is never a surprise.
  Widget _foodMath(BuildContext context, PlannerController c) {
    final theme = Theme.of(context);
    final plan = c.mealPlan;
    final bySlot = plan.countBySlot();
    final kitchen = c.foodStyle.needsKitchen ? c.campKitchenCost : 0.0;
    final mealsCost = plan.cost(c.persons);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'How this food bill is worked out',
            style: theme.textTheme.titleSmall?.copyWith(fontSize: 14),
          ),
          const SizedBox(height: 10),
          if (bySlot.isEmpty)
            _MathRow(label: 'No meals selected on any day', value: money(0))
          else
            // One row per kind of sitting, because that is how the total is
            // actually built up — an average would hide that breakfast is
            // a third of the price of dinner.
            ...MealSlot.values.where(bySlot.containsKey).map((slot) {
              final count = bySlot[slot]!;
              return _MathRow(
                label: '$count × ${slot.label.toLowerCase()} × ${c.persons} '
                    '${c.persons == 1 ? 'person' : 'people'} '
                    'at ${money(plan.priceOf(slot))}',
                value: money(count * c.persons * plan.priceOf(slot)),
              );
            }),
          if (kitchen > 0)
            _MathRow(label: 'Stove, gas and utensils, once', value: money(kitchen)),
          const Divider(height: 18),
          _MathRow(
            label: 'Food total  ·  ${plan.sittings(c.persons)} sittings',
            value: money(mealsCost + kitchen),
            bold: true,
          ),
        ],
      ),
    );
  }
}

/// One row per day, with a chip for each sitting.
///
/// A grid rather than a single number because that is the thing being decided:
/// two meals on the day you drive out, three in the middle, one on the way home.
class _MealGrid extends StatelessWidget {
  const _MealGrid({required this.controller});

  final PlannerController controller;

  static IconData _slotIcon(MealSlot slot) => switch (slot) {
        MealSlot.breakfast => Icons.free_breakfast_rounded,
        MealSlot.lunch => Icons.lunch_dining_rounded,
        MealSlot.dinner => Icons.dinner_dining_rounded,
        MealSlot.lunchDinner => Icons.brunch_dining_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final theme = Theme.of(context);
    final p = context.palette;
    final plan = c.mealPlan;

    return Column(
      children: [
        for (var day = 0; day < plan.days.length; day++)
          Padding(
            padding: const EdgeInsets.only(bottom: 9),
            child: AppCard(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Day ${day + 1}',
                        style: theme.textTheme.titleSmall?.copyWith(fontSize: 13.5),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        dayMonth(c.startDate.add(Duration(days: day))),
                        style: theme.textTheme.bodySmall?.copyWith(fontSize: 11.5),
                      ),
                      const Spacer(),
                      Text(
                        money(_dayCost(plan, day, c.persons)),
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontSize: 13,
                          color: p.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 9),
                  Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: [
                      for (final slot in MealSlot.values)
                        _MealChip(
                          label: slot == MealSlot.lunchDinner
                              ? 'Lunch + dinner'
                              : slot.label,
                          icon: _slotIcon(slot),
                          selected: plan.days[day].contains(slot),
                          onTap: () => c.toggleMeal(day, slot),
                        ),
                    ],
                  ),
                  if (plan.days.length > 1) ...[
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: () => c.applyMealsToAllDays(day),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          minimumSize: const Size(0, 30),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text('Use this for every day',
                            style: TextStyle(fontSize: 12)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }

  static double _dayCost(MealPlan plan, int day, int persons) {
    var total = 0.0;
    for (final slot in plan.days[day]) {
      total += plan.priceOf(slot) * persons;
    }
    return total;
  }
}

class _MealChip extends StatelessWidget {
  const _MealChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final motion = Motion.of(context);

    return PressableScale(
      onTap: onTap,
      child: AnimatedContainer(
        duration: motion.d(Motion.quick),
        curve: Motion.standard,
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? p.primary : p.surfaceAlt,
          borderRadius: AppRadius.pill,
          border: Border.all(color: selected ? p.primary : p.line),
        ),
        // Sized to its label, so the Wrap can fit two or three to a row rather
        // than giving each chip a line of its own.
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              selected ? Icons.check_rounded : icon,
              size: 15,
              color: selected ? Colors.white : p.inkSoft,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : p.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MathRow extends StatelessWidget {
  const _MathRow({required this.label, required this.value, this.bold = false});

  final String label;
  final String value;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = bold
        ? theme.textTheme.titleSmall?.copyWith(fontSize: 13.5)
        : theme.textTheme.bodySmall?.copyWith(fontSize: 12.5);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label, style: style)),
          const SizedBox(width: 12),
          Text(value, style: style),
        ],
      ),
    );
  }
}
