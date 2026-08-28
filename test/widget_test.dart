import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trip_planner/models/destination.dart';

/// Guards the bundled catalogue: a malformed or half-filled entry would only
/// surface as a runtime crash on the explore screen otherwise.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the bundled catalogue parses and every entry is usable', () async {
    final raw = await rootBundle.loadString('assets/data/destinations.json');
    final map = jsonDecode(raw) as Map<String, dynamic>;
    final list = (map['destinations'] as List)
        .map((e) => Destination.fromJson(e as Map<String, dynamic>))
        .toList();

    expect(list, isNotEmpty);

    final ids = <String>{};
    for (final d in list) {
      expect(ids.add(d.id), isTrue, reason: 'duplicate destination id ${d.id}');
      expect(d.name, isNotEmpty);
      expect(d.lat, inInclusiveRange(-90, 90));
      expect(d.lng, inInclusiveRange(-180, 180));
      expect(d.recommendedDays, greaterThan(0));
      expect(d.roadFactor, greaterThanOrEqualTo(1.0));
      expect(d.bestMonths, isNotEmpty);
      expect(d.bestMonths.every((m) => m >= 1 && m <= 12), isTrue,
          reason: '${d.id} has a month outside 1-12');

      final stopIds = <String>{};
      for (final a in d.attractions) {
        expect(stopIds.add(a.id), isTrue, reason: 'duplicate stop ${a.id} in ${d.id}');
        expect(a.name, isNotEmpty);
        expect(a.lat, inInclusiveRange(-90, 90));
        expect(a.lng, inInclusiveRange(-180, 180));
        expect(a.entryFee, greaterThanOrEqualTo(0));
        expect(a.localTransport, greaterThanOrEqualTo(0));
        expect(a.visitHours, greaterThan(0));
      }
    }
  });
}
