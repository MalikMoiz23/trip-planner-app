import 'package:flutter/material.dart';

/// WMO weather interpretation codes, collapsed to the handful of states worth
/// showing a traveller.
enum Sky {
  clear('Clear', Icons.wb_sunny_rounded),
  partly('Partly cloudy', Icons.wb_cloudy_outlined),
  cloudy('Overcast', Icons.cloud_rounded),
  fog('Fog', Icons.foggy),
  drizzle('Drizzle', Icons.grain_rounded),
  rain('Rain', Icons.water_drop_rounded),
  heavyRain('Heavy rain', Icons.thunderstorm_outlined),
  snow('Snow', Icons.ac_unit_rounded),
  storm('Thunderstorm', Icons.thunderstorm_rounded);

  const Sky(this.label, this.icon);
  final String label;
  final IconData icon;

  /// https://open-meteo.com/en/docs — WMO code table.
  static Sky fromWmo(int? code) {
    if (code == null) return Sky.cloudy;
    if (code == 0) return Sky.clear;
    if (code <= 2) return Sky.partly;
    if (code == 3) return Sky.cloudy;
    if (code == 45 || code == 48) return Sky.fog;
    if (code >= 51 && code <= 57) return Sky.drizzle;
    if (code >= 61 && code <= 65) return Sky.rain;
    if (code >= 66 && code <= 67) return Sky.rain;
    if (code >= 71 && code <= 77) return Sky.snow;
    if (code >= 80 && code <= 82) return Sky.heavyRain;
    if (code >= 85 && code <= 86) return Sky.snow;
    if (code >= 95) return Sky.storm;
    return Sky.cloudy;
  }
}

/// One day of the actual forecast. Only available inside the provider's 16-day
/// horizon; beyond that the app falls back to climate.
class DailyForecast {
  const DailyForecast({
    required this.date,
    required this.maxC,
    required this.minC,
    required this.precipMm,
    required this.snowCm,
    required this.sky,
  });

  final DateTime date;
  final double maxC;
  final double minC;
  final double precipMm;
  final double snowCm;
  final Sky sky;

  bool get freezing => minC <= 0;
  bool get wet => precipMm >= 2;
}

/// Averaged climate for one calendar month, computed from two complete past
/// years of daily records.
class MonthClimate {
  const MonthClimate({
    required this.month,
    required this.avgMaxC,
    required this.avgMinC,
    required this.precipMm,
    required this.snowCm,
  });

  /// 1–12.
  final int month;
  final double avgMaxC;
  final double avgMinC;

  /// Typical total for the month.
  final double precipMm;
  final double snowCm;

  /// How good this month is for visiting, 0 to 1.
  ///
  /// Comfort is the dominant term, then rain, then snow. This is a travel
  /// heuristic, not a climatology: it answers "would I enjoy standing outside
  /// here", which is what someone choosing a month actually wants to know.
  double get score {
    // Ideal daytime high around 22 °C, tolerable from 10 to 32.
    final warmth = 1 - ((avgMaxC - 22).abs() / 18).clamp(0.0, 1.0);
    // Nights below freezing matter for camping and for road closures.
    final nights = avgMinC >= 5
        ? 1.0
        : avgMinC >= 0
            ? 0.7
            : avgMinC >= -8
                ? 0.35
                : 0.05;
    final dry = 1 - (precipMm / 220).clamp(0.0, 1.0);
    final clear = snowCm <= 1
        ? 1.0
        : snowCm <= 15
            ? 0.5
            : 0.1;
    return warmth * 0.42 + nights * 0.24 + dry * 0.22 + clear * 0.12;
  }

  /// True when the month is plausibly snow-closed for a high road.
  bool get likelySnowbound => snowCm >= 12 || avgMaxC <= 1;
}

/// Everything known about the weather at one place.
class PlaceWeather {
  const PlaceWeather({this.forecast = const [], this.climate = const []});

  /// Empty beyond the 16-day horizon, or when the lookup failed.
  final List<DailyForecast> forecast;

  /// Twelve entries when loaded, empty when unavailable.
  final List<MonthClimate> climate;

  bool get hasForecast => forecast.isNotEmpty;
  bool get hasClimate => climate.length == 12;

  MonthClimate? forMonth(int month) {
    for (final m in climate) {
      if (m.month == month) return m;
    }
    return null;
  }

  /// The months worth travelling in, best first, keeping only those that clear
  /// a usable bar rather than always returning a top three.
  List<MonthClimate> get bestMonths {
    if (!hasClimate) return const [];
    final sorted = [...climate]..sort((a, b) => b.score.compareTo(a.score));
    final top = sorted.first.score;
    return sorted.where((m) => m.score >= top - 0.14).toList();
  }

  /// Forecast entries covering a trip, which may be none.
  List<DailyForecast> between(DateTime start, DateTime end) {
    final from = DateTime(start.year, start.month, start.day);
    final to = DateTime(end.year, end.month, end.day);
    return forecast
        .where((d) => !d.date.isBefore(from) && !d.date.isAfter(to))
        .toList(growable: false);
  }
}
