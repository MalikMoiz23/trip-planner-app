import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:trip_planner/data/sources/weather_service.dart';
import 'package:trip_planner/domain/weather_horizon.dart';

/// Answers both Open-Meteo endpoints from canned data, and counts the requests
/// so the de-duplication can be checked without a network.
class _StubClient extends http.BaseClient {
  _StubClient({this.delay = Duration.zero});

  final Duration delay;
  int forecastCalls = 0;
  int archiveCalls = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (delay != Duration.zero) await Future<void>.delayed(delay);
    final isArchive = request.url.host.contains('archive');
    if (isArchive) {
      archiveCalls++;
    } else {
      forecastCalls++;
    }
    final body = utf8.encode(isArchive ? _archiveJson() : _forecastJson());
    return http.StreamedResponse(Stream.value(body), 200);
  }
}

String _forecastJson() {
  final start = DateTime.now();
  final times = [
    for (var i = 0; i < 16; i++)
      DateTime(start.year, start.month, start.day + i).toIso8601String().split('T').first,
  ];
  return jsonEncode({
    'daily': {
      'time': times,
      'weather_code': List.filled(16, 1),
      'temperature_2m_max': List.filled(16, 24.0),
      'temperature_2m_min': List.filled(16, 11.0),
      'precipitation_sum': List.filled(16, 0.4),
      'snowfall_sum': List.filled(16, 0.0),
    },
  });
}

/// Two full calendar years, which is what the service asks for and what its
/// "a gap makes the set untrustworthy" check requires.
String _archiveJson() {
  final times = <String>[];
  for (final year in [2024, 2025]) {
    for (var m = 1; m <= 12; m++) {
      for (var d = 1; d <= 28; d++) {
        times.add('$year-${m.toString().padLeft(2, '0')}-${d.toString().padLeft(2, '0')}');
      }
    }
  }
  final n = times.length;
  return jsonEncode({
    'daily': {
      'time': times,
      'temperature_2m_max': List.filled(n, 20.0),
      'temperature_2m_min': List.filled(n, 8.0),
      'precipitation_sum': List.filled(n, 1.0),
      'snowfall_sum': List.filled(n, 0.0),
    },
  });
}

void main() {
  _horizonTests();

  const naran = LatLng(34.9086, 73.6503);

  test('the first call completes', () async {
    // The regression this file exists for. `whenComplete`'s callback was
    // written as an arrow returning `_inFlight.remove(key)` — the very future
    // being completed — so it waited on itself and never finished. The request
    // succeeded and the cache filled; only the caller hung, on a screen that
    // sat on "checking the weather" forever.
    //
    // A timeout is the assertion: a deadlocked future fails no expectation, it
    // simply never arrives.
    final service = WeatherService(client: _StubClient());
    final weather = await service.load(naran).timeout(
          const Duration(seconds: 5),
          onTimeout: () => fail('load() never completed — the in-flight future '
              'is waiting on itself'),
        );

    expect(weather.forecast, hasLength(16));
    expect(weather.climate, hasLength(12));
    expect(weather.hasForecast, isTrue);
    expect(weather.hasClimate, isTrue);
  });

  test('a second call is served from cache without another request', () async {
    final stub = _StubClient();
    final service = WeatherService(client: stub);

    await service.load(naran).timeout(const Duration(seconds: 5));
    await service.load(naran).timeout(const Duration(seconds: 5));

    expect(stub.forecastCalls, 1);
    expect(stub.archiveCalls, 1);
    expect(service.cached(naran), isNotNull);
  });

  test('two callers at once share one request and both get an answer', () async {
    // The detail screen and the summary ask for the same place at the same
    // moment. Both must be answered, and it must cost one round trip.
    final stub = _StubClient(delay: const Duration(milliseconds: 40));
    final service = WeatherService(client: stub);

    final results = await Future.wait([
      service.load(naran),
      service.load(naran),
    ]).timeout(const Duration(seconds: 5));

    expect(results, hasLength(2));
    expect(results[0].forecast, hasLength(16));
    expect(results[1].forecast, hasLength(16));
    expect(stub.forecastCalls, 1, reason: 'the second caller should not refetch');
  });

  test('nearby coordinates share a cache entry', () async {
    final stub = _StubClient();
    final service = WeatherService(client: stub);

    await service.load(naran);
    // ~100 m away: the key rounds to two decimals, so this is the same entry.
    await service.load(const LatLng(34.9088, 73.6501));

    expect(stub.forecastCalls, 1);
  });

  test('a dead network yields an empty result rather than throwing', () async {
    final service = WeatherService(client: _DeadClient());
    final weather = await service.load(naran).timeout(const Duration(seconds: 5));

    expect(weather.hasForecast, isFalse);
    expect(weather.hasClimate, isFalse);
  });

  test('a failed lookup does not wedge the next one', () async {
    // The in-flight entry has to be cleared on failure too, or every later
    // caller joins a future that already failed.
    final service = WeatherService(client: _DeadClient());
    await service.load(naran).timeout(const Duration(seconds: 5));
    final second = await service.load(naran).timeout(
          const Duration(seconds: 5),
          onTimeout: () => fail('a failed lookup left the in-flight entry behind'),
        );
    expect(second.hasForecast, isFalse);
  });
}

class _DeadClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      Future.error(const SocketException('offline in tests'));
}

/// The rule that decides whether the figures on screen are a prediction or a
/// monthly average. Tested directly rather than through the widget, because it
/// is a rule and the widget only renders what it returns.
void _horizonTests() {
  group('WeatherHorizon', () {
    final now = DateTime(2026, 6, 10);

    test('today and the days just ahead are forecastable', () {
      expect(WeatherHorizon.hasForecast(DateTime(2026, 6, 10), now: now), isTrue);
      expect(WeatherHorizon.hasForecast(DateTime(2026, 6, 20), now: now), isTrue);
      expect(WeatherHorizon.describe(DateTime(2026, 6, 12), now: now),
          'Inside the 16-day forecast');
    });

    test('the horizon ends where the provider stops publishing', () {
      // Day 15 is the last inside a 16-day window that starts at day 0.
      expect(WeatherHorizon.daysAway(DateTime(2026, 6, 25), now: now), 15);
      expect(WeatherHorizon.hasForecast(DateTime(2026, 6, 25), now: now), isTrue);
      expect(WeatherHorizon.hasForecast(DateTime(2026, 6, 26), now: now), isFalse);
    });

    test('further out falls back to the month, and names it', () {
      final far = DateTime(2026, 9, 3);
      expect(WeatherHorizon.hasForecast(far, now: now), isFalse);
      expect(WeatherHorizon.describe(far, now: now),
          'Too far out to forecast — showing September averages');
    });

    test('a past date is not described as a prediction', () {
      final past = DateTime(2026, 3, 1);
      expect(WeatherHorizon.hasForecast(past, now: now), isFalse);
      expect(WeatherHorizon.describe(past, now: now), contains('have passed'));
      expect(WeatherHorizon.describe(past, now: now), contains('March'));
    });

    test('the time of day does not move the boundary', () {
      // Whole days only: 11pm today and 1am today are the same day away.
      expect(
        WeatherHorizon.daysAway(DateTime(2026, 6, 20, 23, 59), now: DateTime(2026, 6, 10, 0, 1)),
        10,
      );
    });
  });
}
