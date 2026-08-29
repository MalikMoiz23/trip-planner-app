import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_constants.dart';
import '../../core/formatters.dart';
import '../../core/theme.dart';
import '../../models/expense_breakdown.dart';
import '../../models/trip_config.dart';
import '../../state/planner_controller.dart';
import '../widgets/primitives.dart';

/// Every rupee, and the arithmetic behind it.
///
/// The summary answers "what does this cost". This answers "why", line by line,
/// with the inputs beside each figure so any number can be checked by hand.
class ExpenseDetailScreen extends StatelessWidget {
  const ExpenseDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.watch<PlannerController>();
    final b = c.breakdown;
    final config = c.hasDestination ? c.buildConfig() : null;

    if (b == null || config == null) {
      return const Scaffold(
        body: Center(child: Text('Nothing to itemise yet.')),
      );
    }

    final theme = Theme.of(context);
    final persons = config.persons;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Every expense', style: theme.textTheme.titleLarge?.copyWith(fontSize: 18)),
            Text(
              '${config.destination.name} · ${plural(config.days, 'day', 'days')} · '
              '${plural(persons, 'person', 'people')}',
              style: theme.textTheme.bodySmall?.copyWith(fontSize: 12),
            ),
          ],
        ),
        toolbarHeight: 64,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          _assumptions(context, config, b),
          const SizedBox(height: 20),
          ..._sections(context, config, b),
          const SizedBox(height: 8),
          _grandTotal(context, b, persons),
          const SizedBox(height: 20),
          const InfoNote(
            text: 'Every figure here comes from the inputs shown beside it. Nothing is '
                'fetched from a booking service, so this is a planning estimate — check '
                'the rates that matter most before you commit money to them.',
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------

  Widget _assumptions(BuildContext context, TripConfig config, ExpenseBreakdown b) {
    final vehicle = AppDefaults.vehicleById(config.vehicleId);
    final rows = <(String, String)>[
      ('From', config.originName),
      ('To', config.destination.name),
      ('Leaving', fullDate(config.startDate)),
      ('Length', '${plural(config.days, 'day', 'days')}, '
          '${plural(b.nights, 'night', 'nights')}'),
      ('Travellers', '${config.persons}'),
      ('Travelling by',
          config.isSelfDriving ? '${vehicle.label} (${config.fuel.label})' : 'Public transport'),
      if (config.isSelfDriving)
        ('Vehicle average', '${config.mileage.toStringAsFixed(1)} km per litre'),
      if (config.isSelfDriving)
        ('Fuel price', '${moneyExact(config.fuelPrice)} per litre'
            '${config.fuelPriceIsDefault ? ' (app default)' : ' (yours)'}'),
      ('Sleeping in', '${config.stayStyle.label}, '
          '${config.roomOccupancy} per ${config.stayStyle.unitLabel}'),
      ('Eating', '${config.foodStyle.label}, ${config.mealsPerDay} '
          '${config.mealsPerDay == 1 ? 'meal' : 'meals'} a day'),
      ('Stops chosen', '${config.selectedAttractions.length}'),
      ('Contingency', '${config.bufferPercent.toStringAsFixed(0)}%'),
    ];

    return _Panel(
      title: 'What this is based on',
      subtitle: 'Change any of these in the planner and every figure below moves',
      child: Column(
        children: [
          for (final row in rows) _KeyValue(label: row.$1, value: row.$2),
        ],
      ),
    );
  }

  List<Widget> _sections(BuildContext context, TripConfig config, ExpenseBreakdown b) {
    final persons = config.persons;
    final vehicle = AppDefaults.vehicleById(config.vehicleId);

    return [
      // ---- Travel ---------------------------------------------------------
      _CostPanel(
        slot: 0,
        title: config.isSelfDriving ? 'Fuel' : 'Intercity travel',
        total: b.travelCost,
        persons: persons,
        rows: config.isSelfDriving
            ? [
                ('Out', km(b.oneWayKm)),
                ('Back', km(b.returnKm)),
                if (b.attractionsKm > 0)
                  ('Day trips to your stops', km(b.attractionsKm)),
                ('Distance driven', km(b.totalKm)),
                ('${vehicle.label} average', '${config.mileage.toStringAsFixed(1)} km/L'),
                ('Fuel needed', '${km(b.totalKm)} ÷ '
                    '${config.mileage.toStringAsFixed(1)} = ${litres(b.litres)}'),
                ('${config.fuel.label} price', '${moneyExact(config.fuelPrice)} per litre'),
                ('Cost per kilometre', money(b.costPerKm)),
              ]
            : [
                ('Out and back', km(b.oneWayKm * 2)),
                ('Fare', '${money(config.publicRatePerKm)} per km per person'),
                ('Travellers', '$persons'),
                ('Cost per kilometre', money(b.costPerKm)),
              ],
        formula: config.isSelfDriving
            ? '${litres(b.litres)} × ${money(config.fuelPrice)}'
            : '${km(b.oneWayKm * 2)} × ${money(config.publicRatePerKm)} × $persons',
      ),

      // ---- Stay -----------------------------------------------------------
      _CostPanel(
        slot: 1,
        title: config.isCamping ? 'Camping' : 'Accommodation',
        total: b.stayCost,
        persons: persons,
        rows: [
          ('Style', config.stayStyle.label),
          ('Nights', '${b.nights}'),
          ('People per ${b.unitLabel}', '${config.roomOccupancy}'),
          ('${b.unitLabel[0].toUpperCase()}${b.unitLabel.substring(1)}s needed',
              '$persons ÷ ${config.roomOccupancy}, rounded up = ${b.rooms}'),
          ('Rate', config.stayRatePerUnitNight == 0
              ? 'Free — you carry your own'
              : '${money(config.stayRatePerUnitNight)} per ${b.unitLabel} per night'),
        ],
        formula: b.nights == 0
            ? 'Day trip, nothing to pay'
            : '${b.nights} × ${b.rooms} × ${money(config.stayRatePerUnitNight)}',
      ),

      // ---- Food -----------------------------------------------------------
      _CostPanel(
        slot: 2,
        title: 'Food',
        total: b.mealCost,
        persons: persons,
        rows: [
          ('Style', config.foodStyle.label),
          ('Meals a day', '${config.mealsPerDay}'),
          ('Meals in total', '${config.days} × $persons × ${config.mealsPerDay} '
              '= ${b.mealCount}'),
          ('Cost per meal', '${money(config.pricePerMeal)} per person'),
          ('Meals subtotal', money(b.mealsCost)),
          if (b.kitchenCost > 0)
            ('Stove, gas and utensils', '${money(b.kitchenCost)}, once for the trip'),
        ],
        formula: b.kitchenCost > 0
            ? '${b.mealCount} × ${money(config.pricePerMeal)} + ${money(b.kitchenCost)}'
            : '${b.mealCount} × ${money(config.pricePerMeal)}',
      ),

      // ---- Tickets --------------------------------------------------------
      _CostPanel(
        slot: 3,
        title: 'Entry tickets',
        total: b.entryCost,
        persons: persons,
        rows: config.selectedAttractions.isEmpty
            ? [('Stops chosen', 'none')]
            : [
                for (final a in config.selectedAttractions)
                  (a.name, a.entryFee == 0
                      ? 'free'
                      : '${money(a.entryFee)} pp${a.ratesEstimated ? ' (est.)' : ''}'),
                ('Travellers', '× $persons'),
              ],
        formula: config.selectedAttractions.isEmpty ? '—' : 'sum of tickets × $persons',
      ),

      // ---- Local transport ------------------------------------------------
      _CostPanel(
        slot: 4,
        title: 'Local transport',
        total: b.localTransportCost,
        persons: persons,
        rows: [
          for (final a in config.selectedAttractions.where((a) => a.localTransport > 0))
            ('${a.name} jeep or boat', '${money(a.localTransport)} pp'),
          if (!config.isSelfDriving)
            ('Taxis around town', '${money(config.localTransportPerPersonDay)} pp per day '
                '× ${config.days} days'),
          if (b.localTransportCost == 0) ('Nothing needed', '—'),
        ],
        formula: b.localTransportCost == 0 ? '—' : 'fares × $persons',
      ),

      // ---- Tolls ----------------------------------------------------------
      _CostPanel(
        slot: 5,
        title: 'Tolls and parking',
        total: b.tollsCost,
        persons: persons,
        rows: [
          config.isSelfDriving
              ? ('Whole trip', money(config.tollsAndParking))
              : ('Not applicable', 'you are not driving'),
        ],
        formula: config.isSelfDriving ? 'flat, both ways' : '—',
      ),

      // ---- Buffer ---------------------------------------------------------
      _CostPanel(
        slot: 6,
        title: 'Contingency',
        total: b.bufferCost,
        persons: persons,
        rows: [
          ('Everything above', money(b.subtotal)),
          ('Buffer', '${config.bufferPercent.toStringAsFixed(0)}%'),
        ],
        formula: '${money(b.subtotal)} × ${config.bufferPercent.toStringAsFixed(0)}%',
      ),
    ];
  }

  Widget _grandTotal(BuildContext context, ExpenseBreakdown b, int persons) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primaryDark, context.palette.primary],
        ),
        borderRadius: AppRadius.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _WhiteRow(label: 'Subtotal', value: money(b.subtotal)),
          _WhiteRow(label: 'Contingency', value: money(b.bufferCost)),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Divider(color: Colors.white24, height: 1),
          ),
          _WhiteRow(label: 'Total', value: money(b.total), big: true),
          const SizedBox(height: 10),
          _WhiteRow(label: 'Per person', value: money(b.perPerson)),
          _WhiteRow(label: 'Per day', value: money(b.perDay)),
          _WhiteRow(label: 'Per person per day', value: money(b.perPersonPerDay)),
          const SizedBox(height: 6),
          Text(
            'Split $persons ways.',
            style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.child, this.subtitle});

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleMedium?.copyWith(fontSize: 15.5)),
          if (subtitle != null) ...[
            const SizedBox(height: 3),
            Text(subtitle!, style: theme.textTheme.bodySmall?.copyWith(fontSize: 12.2)),
          ],
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

/// One expense category: its inputs, the formula, the amount, and what that is
/// per person.
class _CostPanel extends StatelessWidget {
  const _CostPanel({
    required this.slot,
    required this.title,
    required this.total,
    required this.persons,
    required this.rows,
    required this.formula,
  });

  final int slot;
  final String title;
  final double total;
  final int persons;
  final List<(String, String)> rows;
  final String formula;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      // Stable per-category key, so tests can scroll to a panel without
      // depending on a label that also appears in the assumptions list.
      key: ValueKey('cost-panel-$title'),
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 11,
                  height: 11,
                  decoration: BoxDecoration(
                    color: AppColors.seriesOf(context, slot),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(title,
                      style: theme.textTheme.titleMedium?.copyWith(fontSize: 15.5)),
                ),
                Text(money(total),
                    style: theme.textTheme.titleMedium?.copyWith(fontSize: 15.5)),
              ],
            ),
            const SizedBox(height: 12),
            for (final row in rows) _KeyValue(label: row.$1, value: row.$2),
            const Divider(height: 20),
            Row(
              children: [
                Expanded(
                  child: Text(
                    formula,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 12.2,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  persons > 0 ? '${money(total / persons)} each' : '—',
                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 12.2),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _KeyValue extends StatelessWidget {
  const _KeyValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 5,
            child: Text(label, style: theme.textTheme.bodySmall?.copyWith(fontSize: 12.6)),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 4,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 12.6,
                fontWeight: FontWeight.w700,
                color: context.palette.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WhiteRow extends StatelessWidget {
  const _WhiteRow({required this.label, required this.value, this.big = false});

  final String label;
  final String value;
  final bool big;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: big ? Colors.white : Colors.white70,
                fontSize: big ? 16 : 13.5,
                fontWeight: big ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontSize: big ? 24 : 14.5,
              fontWeight: big ? FontWeight.w800 : FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
