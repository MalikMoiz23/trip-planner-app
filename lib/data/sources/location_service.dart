import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

class LocationFailure implements Exception {
  LocationFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

class LocationFix {
  const LocationFix({required this.point, required this.accuracyM});
  final LatLng point;
  final double accuracyM;
}

/// Thin wrapper over geolocator that turns every failure path into a message
/// the UI can show verbatim, instead of a raw platform exception.
class LocationService {
  Future<LocationFix> current({Duration timeout = const Duration(seconds: 25)}) async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw LocationFailure('Location services are turned off. Enable GPS and try again.');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw LocationFailure('Location permission was denied.');
    }
    if (permission == LocationPermission.deniedForever) {
      throw LocationFailure(
        'Location permission is permanently denied. Allow it in system settings.',
      );
    }

    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: timeout,
        ),
      );
      return LocationFix(
        point: LatLng(pos.latitude, pos.longitude),
        accuracyM: pos.accuracy,
      );
    } on Exception {
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) {
        return LocationFix(
          point: LatLng(last.latitude, last.longitude),
          accuracyM: last.accuracy,
        );
      }
      throw LocationFailure('Could not get a GPS fix. Move to open sky or set the origin manually.');
    }
  }
}
