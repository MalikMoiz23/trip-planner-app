import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../core/app_constants.dart';
import '../models/weather.dart';

/// Weather from Open-Meteo: free, no key, no account, no attribution required
/// beyond good manners.
///
/// Two endpoints, because they answer different questions:
///  - the forecast covers roughly 16 days, which only helps someone leaving
///    soon;
///  - the archive gives real daily records, which this aggregates into monthly
///    normals so the app can answer "when should I go" for a trip in March.
///
/// The monthly figures matter for a second reason. A landmark promoted out of a
/// town inherits that town's season, which is wrong when the landmark is two
/// thousand metres higher up. Climate is derived from the spot's own
/// coordinates, so it corrects the inherited guess with something measured.
class WeatherService {
  WeatherService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  /// Keyed on coordinates rounded to ~1 km. Two stops in the same valley share
  /// an entry rather than each hitting the network.
  final Map<String, PlaceWeather> _cache = {};
  final Map<String, Future<PlaceWeather>> _inFlight = {};

  static const Duration _timeout = Duration(seconds: 12);

  String _key(LatLng p) =>
      '${p.latitude.toStringAsFixed(2)},${p.longitude.toStringAsFixed(2)}';

  PlaceWeather? cached(LatLng point) => _cache[_key(point)];

  /// Never throws. A failed lookup yields whatever did load, possibly nothing,
  /// and the UI simply omits the section.
  Future<PlaceWeather> load(LatLng point) {
    final key = _key(point);
    final hit = _cache[key];
    if (hit != null) return Future.value(hit);

    // Collapse duplicate requests — the detail screen and the summary both ask
    // for the same place at once.
    return _inFlight[key] ??= _load(point).whenComplete(() => _inFlight.remove(key));
  }

  Future<PlaceWeather> _load(LatLng point) async {
    final results = await Future.wait([
      _forecast(point),
      _climate(point),
    ]);

    final weather = PlaceWeather(
      forecast: results[0] as List<DailyForecast>,
      climate: results[1] as List<MonthClimate>,
    );
    // Cache even a partial result; retrying on every rebuild would hammer a
    // free service for a failure that is usually not transient.
    _cache[_key(point)] = weather;
    return weather;
  }

  Future<List<DailyForecast>> _forecast(LatLng p) async {
    final uri = Uri.parse('${Endpoints.openMeteoForecast}?'
        'latitude=${p.latitude.toStringAsFixed(4)}'
        '&longitude=${p.longitude.toStringAsFixed(4)}'
        '&daily=weather_code,temperature_2m_max,temperature_2m_min,'
        'precipitation_sum,snowfall_sum'
        '&forecast_days=16&timezone=auto');

    try {
      final res = await _client
          .get(uri, headers: {'User-Agent': Endpoints.userAgent}).timeout(_timeout);
      if (res.statusCode != 200) return const [];

      final daily = (jsonDecode(res.body) as Map<String, dynamic>)['daily'];
      if (daily is! Map<String, dynamic>) return const [];

      final times = (daily['time'] as List?) ?? const [];
      final out = <DailyForecast>[];
      for (var i = 0; i < times.length; i++) {
        final date = DateTime.tryParse(times[i] as String);
        if (date == null) continue;
        out.add(DailyForecast(
          date: date,
          maxC: _num(daily['temperature_2m_max'], i),
          minC: _num(daily['temperature_2m_min'], i),
          precipMm: _num(daily['precipitation_sum'], i),
          snowCm: _num(daily['snowfall_sum'], i),
          sky: Sky.fromWmo(_num(daily['weather_code'], i).round()),
        ));
      }
      return out;
    } on Exception {
      return const [];
    }
  }

  /// Two complete calendar years of daily records, folded into twelve months.
  ///
  /// Two years rather than one because a single year can be freakish, and not
  /// more because this is one request on a shared free service and the marginal
  /// accuracy does not justify the payload.
  Future<List<MonthClimate>> _climate(LatLng p) async {
    final lastComplete = DateTime.now().year - 1;
    final firstYear = lastComplete - 1;

    final uri = Uri.parse('${Endpoints.openMeteoArchive}?'
        'latitude=${p.latitude.toStringAsFixed(4)}'
        '&longitude=${p.longitude.toStringAsFixed(4)}'
        '&start_date=$firstYear-01-01&end_date=$lastComplete-12-31'
        '&daily=temperature_2m_max,temperature_2m_min,precipitation_sum,snowfall_sum'
        '&timezone=auto');

    try {
      final res = await _client
          .get(uri, headers: {'User-Agent': Endpoints.userAgent}).timeout(_timeout);
      if (res.statusCode != 200) return const [];

      final daily = (jsonDecode(res.body) as Map<String, dynamic>)['daily'];
      if (daily is! Map<String, dynamic>) return const [];

      final times = (daily['time'] as List?) ?? const [];
      if (times.length < 300) return const [];

      final maxSum = List<double>.filled(13, 0);
      final minSum = List<double>.filled(13, 0);
      final precipSum = List<double>.filled(13, 0);
      final snowSum = List<double>.filled(13, 0);
      final days = List<int>.filled(13, 0);
      final years = <int>{};

      for (var i = 0; i < times.length; i++) {
        final date = DateTime.tryParse(times[i] as String);
        if (date == null) continue;
        final m = date.month;
        years.add(date.year);
        maxSum[m] += _num(daily['temperature_2m_max'], i);
        minSum[m] += _num(daily['temperature_2m_min'], i);
        precipSum[m] += _num(daily['precipitation_sum'], i);
        snowSum[m] += _num(daily['snowfall_sum'], i);
        days[m]++;
      }

      final yearCount = years.isEmpty ? 1 : years.length;
      final out = <MonthClimate>[];
      for (var m = 1; m <= 12; m++) {
        if (days[m] == 0) return const []; // a gap makes the set untrustworthy
        out.add(MonthClimate(
          month: m,
          avgMaxC: maxSum[m] / days[m],
          avgMinC: minSum[m] / days[m],
          // Totals are per-year, so divide the multi-year sum by the years seen.
          precipMm: precipSum[m] / yearCount,
          snowCm: snowSum[m] / yearCount,
        ));
      }
      return out;
    } on Exception {
      return const [];
    }
  }

  static double _num(dynamic list, int i) {
    if (list is! List || i >= list.length) return 0;
    final v = list[i];
    return v is num ? v.toDouble() : 0;
  }

  void dispose() => _client.close();
}
