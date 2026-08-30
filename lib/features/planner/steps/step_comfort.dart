import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:trip_planner/core/constants.dart';
import 'package:trip_planner/core/enums.dart';
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
          subtitle: 'How you eat, and how many times a day',
        ),
        CounterRow(
          label: 'Meals a day',
          caption: c.mealsPerDay >= 3
              ? 'Breakfast, lunch and dinner'
              : 'Fewer sit-down meals, more snacking',
          icon: Icons.schedule_rounded,
          value: c.mealsPerDay,
          min: AppDefaults.minMealsPerDay,
          max: AppDefaults.maxMealsPerDay,
          onChanged: c.setMealsPerDay,
        ),
        const SizedBox(height: 12),
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
        const SizedBox(height: 6),
        NumberField(
          label: 'Your cost per person per meal',
          value: c.pricePerMeal,
          prefix: 'Rs ',
          helper: c.foodStyle.needsKitchen
              ? 'What the ingredients for one person\'s meal cost.'
              : 'What one person\'s meal costs where you plan to eat.',
          onChanged: c.setPricePerMeal,
        ),
        if (c.foodStyle.needsKitchen) ...[
          const SizedBox(height: 12),
          NumberField(
            label: 'Stove, gas and utensils',
            value: c.campKitchenCost,
            prefix: 'Rs ',
            helper: 'Counted once for the trip, not per meal. Set it to zero if you '
                'already own the kit.',
            onChanged: c.setCampKitchenCost,
          ),
        ],
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
    final meals = c.days * c.persons * c.mealsPerDay;
    final mealsCost = meals * c.pricePerMeal;
    final kitchen = c.foodStyle.needsKitchen ? c.campKitchenCost : 0.0;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'How this food bill is worked out',
            style: theme.textTheme.titleSmall?.copyWith(fontSize: 14),
          ),
          const SizedBox(height: 10),
          _MathRow(
            label: '${c.days} ${c.days == 1 ? 'day' : 'days'} × ${c.persons} '
                '${c.persons == 1 ? 'person' : 'people'} × ${c.mealsPerDay} '
                '${c.mealsPerDay == 1 ? 'meal' : 'meals'}',
            value: '$meals meals',
          ),
          _MathRow(
            label: '$meals × ${money(c.pricePerMeal)} per meal',
            value: money(mealsCost),
          ),
          if (kitchen > 0)
            _MathRow(label: 'Stove, gas and utensils, once', value: money(kitchen)),
          const Divider(height: 18),
          _MathRow(label: 'Food total', value: money(mealsCost + kitchen), bold: true),
        ],
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
