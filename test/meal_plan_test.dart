import 'package:flutter_test/flutter_test.dart';
import 'package:trip_planner/core/enums.dart';
import 'package:trip_planner/data/models/meal_plan.dart';

void main() {
  group('MealPlan', () {
    test('a standard plan is lighter on the travel days', () {
      final plan = MealPlan.standard(dayCount: 4, basePrice: 1000);

      expect(plan.days.length, 4);
      // Drive out: breakfast then one meal on the road.
      expect(plan.days.first, {MealSlot.breakfast, MealSlot.lunchDinner});
      // Middle: a full day.
      expect(plan.days[1], {MealSlot.breakfast, MealSlot.lunch, MealSlot.dinner});
      // Drive home: breakfast and lunch, then you are back.
      expect(plan.days.last, {MealSlot.breakfast, MealSlot.lunch});
    });

    test('a day trip is one combined meal', () {
      final plan = MealPlan.standard(dayCount: 1, basePrice: 1000);
      expect(plan.days.single, {MealSlot.lunchDinner});
    });

    test('breakfast is priced below a main meal', () {
      final plan = MealPlan.standard(dayCount: 3, basePrice: 1000);
      expect(plan.priceOf(MealSlot.breakfast), lessThan(plan.priceOf(MealSlot.lunch)));
      expect(plan.priceOf(MealSlot.breakfast), closeTo(550, 0.001));
      expect(plan.priceOf(MealSlot.lunch), 1000);
      expect(plan.priceOf(MealSlot.dinner), 1000);
    });

    test('one combined meal costs more than one meal but less than two', () {
      final plan = MealPlan.standard(dayCount: 3, basePrice: 1000);
      final combined = plan.priceOf(MealSlot.lunchDinner);
      expect(combined, greaterThan(plan.priceOf(MealSlot.lunch)));
      expect(
        combined,
        lessThan(plan.priceOf(MealSlot.lunch) + plan.priceOf(MealSlot.dinner)),
        reason: 'eating once should be cheaper than eating twice',
      );
    });

    test('the cost is summed sitting by sitting, not averaged', () {
      final plan = MealPlan(
        days: [
          {MealSlot.breakfast, MealSlot.lunch},
          {MealSlot.lunchDinner},
        ],
        prices: const {
          MealSlot.breakfast: 400,
          MealSlot.lunch: 1000,
          MealSlot.dinner: 1200,
          MealSlot.lunchDinner: 1500,
        },
      );

      // Day one: 400 + 1000. Day two: 1500. Times two people.
      expect(plan.cost(2), 2 * (400 + 1000 + 1500));
      expect(plan.sittingsPerPerson, 3);
      expect(plan.sittings(2), 6);
    });

    test('different days can hold different meals', () {
      // The whole point of the feature: two on the first day, one on the second.
      var plan = MealPlan(
        days: [{}, {}],
        prices: const {
          MealSlot.breakfast: 400,
          MealSlot.lunch: 1000,
          MealSlot.dinner: 1000,
          MealSlot.lunchDinner: 1400,
        },
      );
      plan = plan.toggled(0, MealSlot.breakfast).toggled(0, MealSlot.dinner);
      plan = plan.toggled(1, MealSlot.lunchDinner);

      expect(plan.days[0].length, 2);
      expect(plan.days[1].length, 1);
      expect(plan.cost(1), 400 + 1000 + 1400);
    });

    test('a combined meal clears the two it replaces', () {
      var plan = MealPlan.standard(dayCount: 2, basePrice: 1000);
      plan = MealPlan(days: [
        {MealSlot.breakfast, MealSlot.lunch, MealSlot.dinner},
        {},
      ], prices: plan.prices);

      plan = plan.toggled(0, MealSlot.lunchDinner);
      expect(plan.days[0], {MealSlot.breakfast, MealSlot.lunchDinner},
          reason: 'holding lunch, dinner and a combined meal at once is nonsense');
    });

    test('picking lunch again clears the combined meal', () {
      var plan = MealPlan(
        days: [{MealSlot.lunchDinner}],
        prices: const {
          MealSlot.breakfast: 1,
          MealSlot.lunch: 1,
          MealSlot.dinner: 1,
          MealSlot.lunchDinner: 1,
        },
      );
      plan = plan.toggled(0, MealSlot.lunch);
      expect(plan.days[0], {MealSlot.lunch});
    });

    test('toggling twice returns to where it started', () {
      final plan = MealPlan.standard(dayCount: 3, basePrice: 900);
      final there = plan.toggled(1, MealSlot.breakfast);
      final back = there.toggled(1, MealSlot.breakfast);
      expect(back.days[1], plan.days[1]);
    });

    test('resizing keeps the days already chosen', () {
      var plan = MealPlan.standard(dayCount: 3, basePrice: 1000);
      plan = plan.toggled(0, MealSlot.dinner); // a deliberate change on day one

      final longer = plan.resized(5);
      expect(longer.days.length, 5);
      expect(longer.days[0], plan.days[0], reason: 'a chosen day must survive');

      final shorter = plan.resized(2);
      expect(shorter.days.length, 2);
      expect(shorter.days[0], plan.days[0]);
    });

    test('rebasing moves every price and keeps the pattern', () {
      final plan = MealPlan.standard(dayCount: 3, basePrice: 1000);
      final cheaper = plan.rebased(400);

      expect(cheaper.priceOf(MealSlot.lunch), 400);
      expect(cheaper.priceOf(MealSlot.breakfast), closeTo(220, 0.001));
      expect(cheaper.days, plan.days, reason: 'changing where you eat is not changing when');
      expect(cheaper.cost(2), lessThan(plan.cost(2)));
    });

    test('one day can be copied onto the rest', () {
      var plan = MealPlan.standard(dayCount: 4, basePrice: 1000);
      plan = plan.appliedToAll(1);
      for (final day in plan.days) {
        expect(day, {MealSlot.breakfast, MealSlot.lunch, MealSlot.dinner});
      }
    });

    test('counts by sitting add up to the total', () {
      final plan = MealPlan.standard(dayCount: 5, basePrice: 1000);
      final counted = plan.countBySlot().values.fold<int>(0, (a, b) => a + b);
      expect(counted, plan.sittingsPerPerson);
    });

    test('survives a JSON round trip', () {
      final plan = MealPlan.standard(dayCount: 4, basePrice: 1234)
          .toggled(2, MealSlot.lunchDinner)
          .withPrice(MealSlot.breakfast, 275);

      final back = MealPlan.fromJson(plan.toJson());
      expect(back.days, plan.days);
      expect(back.prices, plan.prices);
      expect(back.cost(3), plan.cost(3));
    });

    test('the old flat schema costs exactly what it used to', () {
      // 3 days, 3 meals a day, Rs 1,200 each, 4 people = Rs 43,200.
      final plan = MealPlan.fromLegacy(dayCount: 3, mealsPerDay: 3, pricePerMeal: 1200);
      expect(plan.cost(4), 43200);
      expect(plan.sittings(4), 36);
    });

    test('an empty day costs nothing rather than throwing', () {
      final plan = MealPlan(days: [{}, {}], prices: const {});
      expect(plan.cost(4), 0);
      expect(plan.sittingsPerPerson, 0);
      expect(plan.countBySlot(), isEmpty);
    });

    test('a toggle on a day that does not exist is ignored', () {
      final plan = MealPlan.standard(dayCount: 2, basePrice: 1000);
      expect(plan.toggled(9, MealSlot.lunch).days, plan.days);
      expect(plan.toggled(-1, MealSlot.lunch).days, plan.days);
    });
  });
}
