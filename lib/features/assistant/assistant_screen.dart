import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:trip_planner/app/app_state.dart';
import 'package:trip_planner/core/constants.dart';
import 'package:trip_planner/core/enums.dart';
import 'package:trip_planner/core/formatters.dart';
import 'package:trip_planner/core/motion.dart';
import 'package:trip_planner/core/theme.dart';
import 'package:trip_planner/data/models/meal_plan.dart';
import 'package:trip_planner/data/models/trip_config.dart';
import 'package:trip_planner/data/models/trip_stop.dart';
import 'package:trip_planner/domain/assistant.dart';
import 'package:trip_planner/features/explore/destination_detail_screen.dart';
import 'package:trip_planner/shared/widgets/destination_card.dart';
import 'package:trip_planner/shared/widgets/primitives.dart';

/// One turn in the conversation.
class _Turn {
  _Turn.you(this.text)
      : reply = null,
        fromUser = true;
  _Turn.app(this.reply)
      : text = null,
        fromUser = false;

  final String? text;
  final AssistantReply? reply;
  final bool fromUser;
}

/// A trip assistant that answers from the app's own data.
///
/// No model and no network: the catalogue, the cost engine, the packing builder
/// and the season data are all already here, and they are the things a question
/// about a trip to Naran actually needs. That also means it answers instantly
/// with no signal, and cannot invent a fuel price.
class AssistantScreen extends StatefulWidget {
  const AssistantScreen({super.key});

  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends State<AssistantScreen> {
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final List<_Turn> _turns = [];

  static const _openers = [
    'Where can I go for a weekend?',
    'Somewhere with lakes in June',
    'How much for Hunza for 4 people?',
    'Where can I go without a jeep?',
    'Cheapest places under 60k',
    'What should I pack for Skardu in December?',
  ];

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// The assumptions the assistant costs against: whatever the user has set as
  /// their own rates, so its figures agree with the rest of the app.
  TripConfig _defaults(AppState app) {
    final anywhere = app.repository.towns.first;
    return TripConfig(
      originName: 'your location',
      originLat: 33.6844,
      originLng: 73.0479,
      stops: [TripStop(destination: anywhere, nights: 2)],
      startDate: DateTime.now().add(const Duration(days: 14)),
      days: 3,
      persons: AppDefaults.defaultPersons,
      mode: TravelMode.ownVehicle,
      vehicleId: app.lastVehicleId,
      mileage: AppDefaults.vehicleById(app.lastVehicleId).mileage,
      fuelPrice: app.priceFor(AppDefaults.vehicleById(app.lastVehicleId).fuel),
      fuel: AppDefaults.vehicleById(app.lastVehicleId).fuel,
      publicRatePerKm: app.publicRatePerKm,
      localTransportPerPersonDay: AppDefaults.localTransportPerPersonDay,
      roomOccupancy: AppDefaults.defaultRoomOccupancy,
      stayStyle: StayStyle.hotel,
      stayRatePerUnitNight: StayStyle.hotel.defaultRatePerUnitNight,
      foodStyle: FoodStyle.restaurant,
      mealPlan: MealPlan.standard(
        dayCount: 3,
        basePrice: FoodStyle.restaurant.defaultPricePerMeal,
      ),
      campKitchenCost: AppDefaults.defaultCampKitchenCost,
      fuelPriceIsDefault: !app.fuelPriceIsCustom,
      bufferPercent: AppDefaults.defaultBufferPercent,
      tollsAndParking: AppDefaults.defaultTollsAndParking,
    );
  }

  void _send(String raw) {
    final question = raw.trim();
    if (question.isEmpty) return;

    final app = context.read<AppState>();
    final reply = TripAssistant.answer(
      question,
      places: app.repository.all,
      defaults: _defaults(app),
    );

    setState(() {
      _turns
        ..add(_Turn.you(question))
        ..add(_Turn.app(reply));
    });
    _input.clear();

    // After the frame, so the new turns are laid out and the extent is real.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: Motion.of(context).d(Motion.base),
        curve: Motion.standard,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = context.palette;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _header(theme, p),
            Expanded(
              child: _turns.isEmpty
                  ? _empty(theme)
                  : ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                      itemCount: _turns.length,
                      itemBuilder: (context, i) => FadeSlideIn(
                        key: ValueKey(i),
                        child: _bubble(_turns[i], theme, p),
                      ),
                    ),
            ),
            _composer(p),
          ],
        ),
      ),
    );
  }

  Widget _header(ThemeData theme, AppPalette p) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: p.primary.withValues(alpha: 0.14),
                borderRadius: AppRadius.sm,
              ),
              child: Icon(Icons.auto_awesome_rounded, size: 20, color: p.primary),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Ask about your trip',
                      style: theme.textTheme.titleLarge?.copyWith(fontSize: 19)),
                  Text(
                    'Answers from this app\'s data — works with no signal',
                    style: theme.textTheme.bodySmall?.copyWith(fontSize: 11.8),
                  ),
                ],
              ),
            ),
            if (_turns.isNotEmpty)
              IconButton(
                tooltip: 'Start again',
                onPressed: () => setState(_turns.clear),
                icon: const Icon(Icons.refresh_rounded, size: 20),
              ),
          ],
        ),
      );

  Widget _empty(ThemeData theme) => ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
        children: [
          const InfoNote(
            icon: Icons.lightbulb_outline_rounded,
            text: 'I work from the 176 places, the cost engine and the season data '
                'already in the app, so every figure I quote is one you can check. '
                'I cannot answer things outside trip planning.',
          ),
          const SizedBox(height: 18),
          const SectionHeader(title: 'Try one of these'),
          for (var i = 0; i < _openers.length; i++)
            FadeSlideIn(
              delay: Motion.of(context).stagger(i),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: _suggestionChip(_openers[i]),
              ),
            ),
        ],
      );

  Widget _suggestionChip(String text) {
    final p = context.palette;
    return PressableScale(
      onTap: () => _send(text),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: AppRadius.md,
          border: Border.all(color: p.line),
        ),
        child: Row(
          children: [
            Icon(Icons.north_east_rounded, size: 16, color: p.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(text, style: TextStyle(fontSize: 13.5, color: p.ink)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bubble(_Turn turn, ThemeData theme, AppPalette p) {
    if (turn.fromUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12, left: 40),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: p.primary,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(4),
            ),
          ),
          child: Text(
            turn.text!,
            style: const TextStyle(color: Colors.white, fontSize: 13.5, height: 1.4),
          ),
        ),
      );
    }

    final reply = turn.reply!;
    return Container(
      margin: const EdgeInsets.only(bottom: 16, right: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: p.surface,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomLeft: Radius.circular(4),
                bottomRight: Radius.circular(16),
              ),
              border: Border.all(color: p.line),
            ),
            child: Text(
              reply.text,
              style: TextStyle(fontSize: 13.5, height: 1.5, color: p.ink),
            ),
          ),

          // Places come back as real cards, so a recommendation is one tap from
          // being planned rather than a name to go and search for.
          if (reply.suggestions.isNotEmpty) ...[
            const SizedBox(height: 10),
            for (final s in reply.suggestions)
              Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: _suggestionCard(s, theme, p),
              ),
          ],

          if (reply.followUps.isNotEmpty) ...[
            const SizedBox(height: 4),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                for (final f in reply.followUps) _followUp(f, p),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _suggestionCard(PlaceSuggestion s, ThemeData theme, AppPalette p) {
    final d = s.destination;
    return AppCard(
      padding: const EdgeInsets.all(10),
      onTap: () => context.pushScreen(DestinationDetailScreen(destination: d)),
      child: Row(
        children: [
          SizedBox(
            width: 54,
            height: 54,
            child: DestinationPlate(
              category: d.category,
              iconCategory: d.iconCategory,
              watermarkSize: 48,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(d.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(fontSize: 14)),
                const SizedBox(height: 2),
                Text(
                  s.reason,
                  maxLines: 2,
                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 11.5),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(moneyCompact(s.estimatedTotal),
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontSize: 14, color: p.primary)),
              Text(km(s.distanceKm),
                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _followUp(String text, AppPalette p) => PressableScale(
        onTap: () => _send(text),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
          decoration: BoxDecoration(
            color: p.primary.withValues(alpha: 0.10),
            borderRadius: AppRadius.pill,
            border: Border.all(color: p.primary.withValues(alpha: 0.28)),
          ),
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: p.primary,
            ),
          ),
        ),
      );

  Widget _composer(AppPalette p) => Container(
        padding: EdgeInsets.fromLTRB(
          16,
          10,
          16,
          10 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        decoration: BoxDecoration(
          color: p.surface,
          border: Border(top: BorderSide(color: p.line)),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _input,
                textInputAction: TextInputAction.send,
                onSubmitted: _send,
                minLines: 1,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: 'Ask about a place, a budget, a month…',
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 9),
            SizedBox(
              width: 46,
              height: 46,
              child: FilledButton(
                onPressed: () => _send(_input.text),
                style: FilledButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(46, 46),
                  shape: const RoundedRectangleBorder(borderRadius: AppRadius.md),
                ),
                child: const Icon(Icons.arrow_upward_rounded, size: 20),
              ),
            ),
          ],
        ),
      );
}
