import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:trip_planner/core/formatters.dart';
import 'package:trip_planner/core/motion.dart';
import 'package:trip_planner/core/theme.dart';
import 'package:trip_planner/data/models/weather.dart';
import 'package:trip_planner/shared/widgets/primitives.dart';

/// Forecast for the trip dates when they are close enough to have one, and the
/// month-by-month climate either way.
class WeatherPanel extends StatelessWidget {
  const WeatherPanel({
    super.key,
    required this.weather,
    required this.start,
    required this.end,
    required this.loading,
    this.altitudeM = 0,
    this.guideMonths = const [],
  });

  final PlaceWeather? weather;
  final DateTime start;
  final DateTime end;
  final bool loading;
  final int altitudeM;

  /// What the bundled catalogue claims, so the two can be compared.
  final List<int> guideMonths;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const AppCard(child: LoadingStrip(label: 'Checking the weather…'));
    }

    final w = weather;
    if (w == null || (!w.hasForecast && !w.hasClimate)) {
      return const InfoNote(
        icon: Icons.cloud_off_rounded,
        text: 'Weather could not be fetched. Everything else on this plan works '
            'offline, so this section simply sits out.',
      );
    }

    final days = w.between(start, end);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (days.isNotEmpty) ...[
          _ForecastStrip(days: days),
          const SizedBox(height: 12),
        ] else if (w.hasClimate) ...[
          InfoNote(
            icon: Icons.calendar_month_rounded,
            text: 'Your dates are beyond the 16-day forecast, so the figures below '
                'are what ${monthName(start.month)} is normally like here, averaged '
                'from two years of records at these exact coordinates.',
          ),
          const SizedBox(height: 12),
        ],
        if (w.hasClimate) _ClimateStrip(weather: w, selected: start.month),
        if (w.hasClimate) ...[
          const SizedBox(height: 12),
          _Verdict(weather: w, month: start.month, altitudeM: altitudeM, guideMonths: guideMonths),
        ],
      ],
    );
  }
}

class _ForecastStrip extends StatelessWidget {
  const _ForecastStrip({required this.days});

  final List<DailyForecast> days;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.event_available_rounded, size: 17, color: p.primary),
              const SizedBox(width: 7),
              Text('Forecast for your dates',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(fontSize: 14)),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 108,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: days.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, i) => FadeSlideIn(
                delay: Motion.of(context).stagger(i, step: const Duration(milliseconds: 40)),
                offset: const Offset(0.25, 0),
                child: _DayChip(day: days[i]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip({required this.day});

  final DailyForecast day;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final theme = Theme.of(context);
    final alarming = day.freezing || day.snowCm > 0;

    return Container(
      width: 76,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: p.surfaceAlt,
        borderRadius: AppRadius.sm,
        border: Border.all(color: alarming ? p.caution.withValues(alpha: 0.5) : p.line),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(dayMonth(day.date),
              style: theme.textTheme.bodySmall?.copyWith(fontSize: 11.5)),
          const SizedBox(height: 6),
          Icon(day.sky.icon, size: 22, color: alarming ? p.caution : p.primary),
          const SizedBox(height: 6),
          Text(temp(day.maxC),
              style: theme.textTheme.titleSmall?.copyWith(fontSize: 14)),
          Text(temp(day.minC),
              style: theme.textTheme.bodySmall?.copyWith(fontSize: 11.5)),
          if (day.precipMm >= 1)
            Text('${day.precipMm.round()} mm',
                style: theme.textTheme.bodySmall?.copyWith(fontSize: 10, color: p.inkFaint)),
        ],
      ),
    );
  }
}

/// Twelve bars, one per month, height by how good the month is.
class _ClimateStrip extends StatelessWidget {
  const _ClimateStrip({required this.weather, required this.selected});

  final PlaceWeather weather;
  final int selected;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final theme = Theme.of(context);
    final months = weather.climate;
    final best = months.map((m) => m.score).fold<double>(0, math.max);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.insights_rounded, size: 17, color: p.primary),
              const SizedBox(width: 7),
              Expanded(
                child: Text('When to come',
                    style: theme.textTheme.titleSmall?.copyWith(fontSize: 14)),
              ),
              Text('taller is better',
                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 11, color: p.inkFaint)),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 96,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final m in months)
                  Expanded(
                    child: _MonthBar(
                      climate: m,
                      relative: best <= 0 ? 0 : m.score / best,
                      isSelected: m.month == selected,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthBar extends StatelessWidget {
  const _MonthBar({
    required this.climate,
    required this.relative,
    required this.isSelected,
  });

  final MonthClimate climate;
  final double relative;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final motion = Motion.of(context);
    final color = climate.likelySnowbound
        ? p.inkFaint
        : (isSelected ? p.primary : p.primary.withValues(alpha: 0.42));

    return Tooltip(
      message: '${monthName(climate.month)}: '
          '${temp(climate.avgMaxC)} / ${temp(climate.avgMinC)}, '
          '${climate.precipMm.round()} mm rain'
          '${climate.snowCm >= 1 ? ', ${climate.snowCm.round()} cm snow' : ''}',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            // Grows from nothing on first paint, so the shape of the year reads
            // as information arriving rather than as a static block.
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: relative.clamp(0.06, 1.0)),
              duration: motion.d(Motion.lazy),
              curve: Motion.enter,
              builder: (context, t, _) => Container(
                height: 62 * t,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
                ),
              ),
            ),
            const SizedBox(height: 5),
            Text(
              shortMonthName(climate.month).substring(0, 1),
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                color: isSelected ? p.ink : p.inkFaint,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The plain-language answer: is the chosen month a good one, and what does the
/// bundled guide say by comparison.
class _Verdict extends StatelessWidget {
  const _Verdict({
    required this.weather,
    required this.month,
    required this.altitudeM,
    required this.guideMonths,
  });

  final PlaceWeather weather;
  final int month;
  final int altitudeM;
  final List<int> guideMonths;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final theme = Theme.of(context);
    final chosen = weather.forMonth(month);
    if (chosen == null) return const SizedBox.shrink();

    final best = weather.bestMonths;
    final bestLabel = best.isEmpty
        ? '—'
        : (best.map((m) => m.month).toList()..sort())
            .map(shortMonthName)
            .join(', ');

    final isGood = best.any((m) => m.month == month);
    final snowbound = chosen.likelySnowbound;

    final Color tone;
    final IconData icon;
    final String headline;
    if (snowbound) {
      tone = p.serious;
      icon = Icons.ac_unit_rounded;
      headline = '${monthName(month)} is likely snowbound here';
    } else if (isGood) {
      tone = p.success;
      icon = Icons.check_circle_rounded;
      headline = '${monthName(month)} is one of the better months';
    } else {
      tone = p.caution;
      icon = Icons.error_outline_rounded;
      headline = '${monthName(month)} is not the ideal month';
    }

    // The guide's months are inherited from the parent town for a promoted
    // landmark, which is exactly the case measured climate should override.
    final guideLabel = guideMonths.isEmpty
        ? null
        : (guideMonths.toList()..sort()).map(shortMonthName).join(', ');
    final disagrees = guideLabel != null && guideMonths.contains(month) != isGood;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 19, color: tone),
              const SizedBox(width: 9),
              Expanded(
                child: Text(headline,
                    style: theme.textTheme.titleSmall?.copyWith(fontSize: 14, color: tone)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Typically ${temp(chosen.avgMaxC)} by day and ${temp(chosen.avgMinC)} at '
            'night, with about ${chosen.precipMm.round()} mm of rain'
            '${chosen.snowCm >= 1 ? ' and ${chosen.snowCm.round()} cm of snow' : ''}.',
            style: theme.textTheme.bodySmall?.copyWith(fontSize: 12.5),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 7,
            runSpacing: 6,
            children: [
              PillTag(label: 'Best: $bestLabel', icon: Icons.star_rounded, color: p.primary),
              if (altitudeM > 0)
                PillTag(label: '$altitudeM m', icon: Icons.terrain_rounded),
              if (guideLabel != null)
                PillTag(label: 'Guide says $guideLabel', icon: Icons.menu_book_rounded),
            ],
          ),
          if (disagrees) ...[
            const SizedBox(height: 10),
            Text(
              'The built-in guide and the measured record disagree for this month. '
              'The record is taken at this exact spot; the guide describes the wider '
              'area, so trust the record where they differ.',
              style: theme.textTheme.bodySmall?.copyWith(fontSize: 12, color: p.inkFaint),
            ),
          ],
        ],
      ),
    );
  }
}
