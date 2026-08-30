import 'package:trip_planner/core/formatters.dart';

/// How far ahead a real forecast reaches, and what to say when the dates are
/// beyond it.
///
/// Two different things get shown under the same heading: an actual prediction
/// for specific days, and an average of what that month is normally like. They
/// deserve very different confidence, so which one is on screen is stated
/// rather than left to be inferred from how far off the dates are.
///
/// Lives here rather than in the widget because it is a rule, not a layout, and
/// a rule that decides what a number means is worth testing on its own.
class WeatherHorizon {
  const WeatherHorizon._();

  /// Open-Meteo publishes 16 days. The last of those is a day away from being
  /// wrong more often than not, so the useful edge is a little short of it.
  static const int forecastDays = 16;

  /// Days from today until [start], counted in whole days.
  static int daysAway(DateTime start, {DateTime? now}) {
    final today = _dateOnly(now ?? DateTime.now());
    return _dateOnly(start).difference(today).inDays;
  }

  /// True when a genuine forecast exists for [start].
  ///
  /// A date in the past is not forecastable either — it is not an error worth
  /// a message of its own, but it must not be described as a prediction.
  static bool hasForecast(DateTime start, {DateTime? now}) {
    final away = daysAway(start, now: now);
    return away >= 0 && away < forecastDays;
  }

  /// One line saying which of the two kinds of figure is on screen.
  static String describe(DateTime start, {DateTime? now}) {
    if (hasForecast(start, now: now)) {
      return 'Inside the $forecastDays-day forecast';
    }
    if (daysAway(start, now: now) < 0) {
      return 'Those dates have passed — showing ${monthName(start.month)} averages';
    }
    return 'Too far out to forecast — showing ${monthName(start.month)} averages';
  }

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
}
