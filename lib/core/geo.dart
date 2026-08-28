import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

const double _earthRadiusKm = 6371.0088;

/// Great-circle distance in kilometres.
double haversineKm(LatLng a, LatLng b) {
  final dLat = _rad(b.latitude - a.latitude);
  final dLng = _rad(b.longitude - a.longitude);
  final lat1 = _rad(a.latitude);
  final lat2 = _rad(b.latitude);

  final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.sin(dLng / 2) * math.sin(dLng / 2) * math.cos(lat1) * math.cos(lat2);
  return 2 * _earthRadiusKm * math.asin(math.min(1, math.sqrt(h)));
}

double _rad(double deg) => deg * math.pi / 180.0;

/// Decodes an OSRM `geometries=polyline` string (precision 5) into points.
/// Used as a compact alternative to GeoJSON when the response is large.
List<LatLng> decodePolyline(String encoded, {int precision = 5}) {
  final factor = math.pow(10, precision).toDouble();
  final points = <LatLng>[];
  int index = 0, lat = 0, lng = 0;

  while (index < encoded.length) {
    int result = 0, shift = 0, b;
    do {
      b = encoded.codeUnitAt(index++) - 63;
      result |= (b & 0x1f) << shift;
      shift += 5;
    } while (b >= 0x20);
    lat += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);

    result = 0;
    shift = 0;
    do {
      b = encoded.codeUnitAt(index++) - 63;
      result |= (b & 0x1f) << shift;
      shift += 5;
    } while (b >= 0x20);
    lng += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);

    points.add(LatLng(lat / factor, lng / factor));
  }
  return points;
}

/// Keeps every nth point so a long route polyline stays cheap to paint.
List<LatLng> simplify(List<LatLng> points, {int maxPoints = 400}) {
  if (points.length <= maxPoints) return points;
  final step = (points.length / maxPoints).ceil();
  final out = <LatLng>[];
  for (var i = 0; i < points.length; i += step) {
    out.add(points[i]);
  }
  if (out.last != points.last) out.add(points.last);
  return out;
}

/// Midpoint of a set of coordinates, used to centre the map before a fit.
LatLng centroid(List<LatLng> points) {
  if (points.isEmpty) return const LatLng(30.3753, 69.3451); // Pakistan centroid
  var lat = 0.0, lng = 0.0;
  for (final p in points) {
    lat += p.latitude;
    lng += p.longitude;
  }
  return LatLng(lat / points.length, lng / points.length);
}
