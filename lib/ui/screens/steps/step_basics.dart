import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/formatters.dart';
import '../../../core/theme.dart';
import '../../../services/nominatim_service.dart';
import '../../../state/app_state.dart';
import '../../../state/planner_controller.dart';
import '../../widgets/budget_panel.dart';
import '../../widgets/inputs.dart';
import '../../widgets/primitives.dart';

class StepBasics extends StatelessWidget {
  const StepBasics({super.key});

  Future<void> _pickDate(BuildContext context) async {
    final controller = context.read<PlannerController>();
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: controller.startDate,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 730)),
      helpText: 'Departure date',
    );
    if (picked != null) controller.setDates(picked);
  }

  Future<void> _searchOrigin(BuildContext context) async {
    final controller = context.read<PlannerController>();
    final repo = context.read<AppState>().repository;
    final hit = await showModalBottomSheet<PlaceHit>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _OriginSearchSheet(search: repo.searchRemote),
    );
    if (hit != null) {
      await controller.setOriginManually(hit.name, hit.point);
    }
  }

  Future<void> _changeDestination(BuildContext context) async {
    final controller = context.read<PlannerController>();
    final app = context.read<AppState>();
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _DestinationSheet(state: app),
    );
    if (picked != null) {
      final d = app.repository.byId(picked);
      if (d != null) controller.setDestination(d);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<PlannerController>();
    final theme = Theme.of(context);
    final d = controller.destination!;
    final route = controller.outbound;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        _originCard(context, controller, theme),
        const SizedBox(height: 10),
        _leg(context, theme, controller),
        const SizedBox(height: 10),
        AppCard(
          onTap: () => _changeDestination(context),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: AppColors.gradientFor(d.category)),
                  borderRadius: AppRadius.sm,
                ),
                child: Icon(AppColors.iconFor(d.category), color: Colors.white, size: 20),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Going to', style: theme.textTheme.bodySmall?.copyWith(fontSize: 12)),
                    const SizedBox(height: 2),
                    Text(d.name, style: theme.textTheme.titleMedium?.copyWith(fontSize: 16)),
                    Text(
                      d.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(fontSize: 12),
                    ),
                  ],
                ),
              ),
              Text('Change',
                  style: TextStyle(
                    color: context.palette.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                  )),
            ],
          ),
        ),
        const SizedBox(height: 22),
        const SectionHeader(title: 'When and who'),
        AppCard(
          onTap: () => _pickDate(context),
          child: Row(
            children: [
              Icon(Icons.calendar_month_rounded, size: 19, color: context.palette.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Leaving on',
                        style: theme.textTheme.bodySmall?.copyWith(fontSize: 12)),
                    const SizedBox(height: 2),
                    Text(fullDate(controller.startDate),
                        style: theme.textTheme.titleSmall?.copyWith(fontSize: 14.5)),
                  ],
                ),
              ),
              Text(
                'Back ${dayMonth(controller.startDate.add(Duration(days: controller.days - 1)))}',
                style: theme.textTheme.bodySmall?.copyWith(fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        CounterRow(
          label: 'Days',
          caption: 'Suggested ${controller.suggestedDays} for this plan',
          icon: Icons.event_rounded,
          value: controller.days,
          min: 1,
          max: 30,
          onChanged: controller.setDays,
        ),
        const SizedBox(height: 10),
        CounterRow(
          label: 'Travellers',
          caption: 'Splits every per-person figure',
          icon: Icons.group_rounded,
          value: controller.persons,
          min: 1,
          max: 40,
          onChanged: controller.setPersons,
        ),
        const SizedBox(height: 22),
        const SectionHeader(
          title: 'Budget',
          subtitle: 'Optional, but it changes the app from a calculator into advice',
        ),
        const BudgetPanel(compact: true),
        if (route != null && route.estimated) ...[
          const SizedBox(height: 16),
          const InfoNote(
            text: 'The routing service did not answer, so the distance below is a '
                'straight-line estimate corrected for terrain. Pull to refresh once you '
                'have signal for the real road distance.',
            icon: Icons.wifi_off_rounded,
          ),
        ],
      ],
    );
  }

  Widget _originCard(BuildContext context, PlannerController c, ThemeData theme) {
    if (c.locating) {
      return const AppCard(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 6),
          child: LoadingStrip(label: 'Getting your location…'),
        ),
      );
    }

    if (!c.hasOrigin) {
      return AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.my_location_rounded, size: 19, color: context.palette.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('Starting point',
                      style: theme.textTheme.titleSmall?.copyWith(fontSize: 14.5)),
                ),
              ],
            ),
            if (c.locationError != null) ...[
              const SizedBox(height: 8),
              Text(c.locationError!,
                  style: theme.textTheme.bodySmall?.copyWith(color: context.palette.danger)),
            ] else ...[
              const SizedBox(height: 6),
              Text(
                'Distance and fuel are measured from here.',
                style: theme.textTheme.bodySmall?.copyWith(fontSize: 12.5),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: c.detectLocation,
                    icon: const Icon(Icons.gps_fixed_rounded, size: 18),
                    label: const Text('Detect'),
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(46)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _searchOrigin(context),
                    icon: const Icon(Icons.search_rounded, size: 18),
                    label: const Text('Search'),
                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(46)),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return AppCard(
      child: Row(
        children: [
          Icon(Icons.trip_origin_rounded, size: 19, color: context.palette.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Starting from', style: theme.textTheme.bodySmall?.copyWith(fontSize: 12)),
                const SizedBox(height: 2),
                Text(c.originName, style: theme.textTheme.titleMedium?.copyWith(fontSize: 16)),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Use current location',
            onPressed: c.detectLocation,
            icon: const Icon(Icons.gps_fixed_rounded, size: 19),
            color: context.palette.inkSoft,
          ),
          IconButton(
            tooltip: 'Search a different city',
            onPressed: () => _searchOrigin(context),
            icon: const Icon(Icons.edit_location_alt_outlined, size: 19),
            color: context.palette.inkSoft,
          ),
        ],
      ),
    );
  }

  /// The connector between origin and destination cards, carrying the routed
  /// distance once it is known.
  Widget _leg(BuildContext context, ThemeData theme, PlannerController c) {
    final route = c.outbound;
    return Padding(
      padding: const EdgeInsets.only(left: 18),
      child: Row(
        children: [
          Container(width: 2, height: 34, color: context.palette.line),
          const SizedBox(width: 16),
          // Expanded, because the pill row wraps to two lines on a narrow phone
          // once the "Estimated" badge appears.
          Expanded(
            child: c.routing
                ? const LoadingStrip(label: 'Measuring the road distance…')
                : route == null
                    ? Text('Distance appears once both ends are set',
                        style: theme.textTheme.bodySmall?.copyWith(fontSize: 12))
                    : Wrap(
                        spacing: 7,
                        runSpacing: 6,
                        children: [
                          PillTag(
                            label: km(route.distanceKm),
                            icon: Icons.route_rounded,
                            color: context.palette.primary,
                          ),
                          PillTag(
                            label: durationText(route.duration),
                            icon: Icons.schedule_rounded,
                            color: context.palette.primary,
                          ),
                          if (route.estimated)
                            PillTag(
                              label: 'Estimated',
                              icon: Icons.help_outline_rounded,
                              color: context.palette.caution,
                            ),
                        ],
                      ),
          ),
        ],
      ),
    );
  }
}

class _OriginSearchSheet extends StatefulWidget {
  const _OriginSearchSheet({required this.search});

  final Future<List<PlaceHit>> Function(String) search;

  @override
  State<_OriginSearchSheet> createState() => _OriginSearchSheetState();
}

class _OriginSearchSheetState extends State<_OriginSearchSheet> {
  final TextEditingController _field = TextEditingController();
  Timer? _debounce;
  List<PlaceHit> _hits = const [];
  bool _busy = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _field.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), () async {
      if (value.trim().length < 3) return;
      setState(() => _busy = true);
      final hits = await widget.search(value);
      if (!mounted) return;
      setState(() {
        _hits = hits;
        _busy = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Where are you starting from?', style: theme.textTheme.titleLarge?.copyWith(fontSize: 18)),
              const SizedBox(height: 4),
              Text(
                'City or town name. Searched live on OpenStreetMap.',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _field,
                autofocus: true,
                onChanged: _onChanged,
                decoration: const InputDecoration(
                  hintText: 'Lahore, Islamabad, Peshawar…',
                  prefixIcon: Icon(Icons.search_rounded, size: 20),
                ),
              ),
              const SizedBox(height: 14),
              if (_busy) const LoadingStrip(label: 'Searching…'),
              Expanded(
                child: ListView.separated(
                  itemCount: _hits.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final hit = _hits[i];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.place_outlined, color: context.palette.primary),
                      title: Text(hit.name, style: theme.textTheme.titleSmall),
                      subtitle: hit.context.isEmpty
                          ? null
                          : Text(hit.context, maxLines: 1, overflow: TextOverflow.ellipsis),
                      onTap: () => Navigator.of(context).pop(hit),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DestinationSheet extends StatelessWidget {
  const _DestinationSheet({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.72,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Change destination', style: theme.textTheme.titleLarge?.copyWith(fontSize: 18)),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.separated(
                itemCount: state.destinations.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final d = state.destinations[i];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: AppColors.gradientFor(d.category)),
                        borderRadius: AppRadius.sm,
                      ),
                      child: Icon(AppColors.iconFor(d.category), color: Colors.white, size: 19),
                    ),
                    title: Text(d.name, style: theme.textTheme.titleSmall),
                    subtitle: Text(d.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
                    onTap: () => Navigator.of(context).pop(d.id),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
