import 'package:flutter/material.dart';

import 'enums.dart';

/// A selectable vehicle with a starting mileage figure. Every number here is a
/// default the user can overwrite in the planner; nothing is fetched or fixed.
class VehiclePreset {
  const VehiclePreset({
    required this.id,
    required this.label,
    required this.blurb,
    required this.icon,
    required this.mileage,
    required this.seats,
    required this.fuel,
    required this.is4x4,
  });

  final String id;
  final String label;
  final String blurb;
  final IconData icon;

  /// Kilometres per litre on a mixed highway/hill route.
  final double mileage;
  final int seats;
  final FuelKind fuel;
  final bool is4x4;
}

class AppDefaults {
  const AppDefaults._();

  // ---- Fuel -------------------------------------------------------------
  // Pump prices move constantly. These are starting values only; the planner
  // and the settings screen both expose them as editable fields.
  static const double petrolPricePerLitre = 272.0;
  static const double dieselPricePerLitre = 278.0;

  // ---- Public transport --------------------------------------------------
  /// Intercity bus/van fare per person per kilometre.
  static const double publicRatePerKm = 5.0;

  /// Local taxi/rickshaw allowance per person per day when not self-driving.
  static const double localTransportPerPersonDay = 800.0;

  // ---- Trip shape --------------------------------------------------------
  static const int defaultDays = 3;
  static const int defaultPersons = 2;
  static const int defaultRoomOccupancy = 2;
  static const double defaultBufferPercent = 10.0;
  static const double defaultTollsAndParking = 1500.0;

  /// Used when a route has to be estimated instead of routed.
  static const double fallbackRoadFactor = 1.45;
  static const double fallbackAverageSpeedKmh = 45.0;

  /// Planning ceiling for sightseeing in a single day.
  static const double maxSightseeingHoursPerDay = 9.0;

  /// A single driving day longer than this triggers a split-the-drive warning.
  static const double longDrivingDayHours = 9.0;

  static const List<VehiclePreset> vehicles = [
    VehiclePreset(
      id: 'bike',
      label: 'Motorbike',
      blurb: '125cc class',
      icon: Icons.two_wheeler_rounded,
      mileage: 45,
      seats: 2,
      fuel: FuelKind.petrol,
      is4x4: false,
    ),
    VehiclePreset(
      id: 'hatchback',
      label: 'Small car',
      blurb: 'Alto, Cultus, Wagon R',
      icon: Icons.directions_car_filled_rounded,
      mileage: 16,
      seats: 4,
      fuel: FuelKind.petrol,
      is4x4: false,
    ),
    VehiclePreset(
      id: 'sedan',
      label: 'Sedan',
      blurb: 'Corolla, City, Civic',
      icon: Icons.directions_car_rounded,
      mileage: 12,
      seats: 5,
      fuel: FuelKind.petrol,
      is4x4: false,
    ),
    VehiclePreset(
      id: 'suv',
      label: 'SUV / 4x4',
      blurb: 'Fortuner, Prado, Vitara',
      icon: Icons.airport_shuttle_rounded,
      mileage: 9,
      seats: 6,
      fuel: FuelKind.diesel,
      is4x4: true,
    ),
    VehiclePreset(
      id: 'van',
      label: 'Hiace / Van',
      blurb: 'Group of up to 12',
      icon: Icons.local_shipping_rounded,
      mileage: 8,
      seats: 12,
      fuel: FuelKind.diesel,
      is4x4: false,
    ),
    VehiclePreset(
      id: 'coaster',
      label: 'Coaster',
      blurb: 'Large group charter',
      icon: Icons.directions_bus_filled_rounded,
      mileage: 5,
      seats: 22,
      fuel: FuelKind.diesel,
      is4x4: false,
    ),
  ];

  static VehiclePreset vehicleById(String id) =>
      vehicles.firstWhere((v) => v.id == id, orElse: () => vehicles[2]);
}

/// Network endpoints. All three are free, key-less and usage-policy bound, so
/// every request sends a descriptive User-Agent.
class Endpoints {
  const Endpoints._();

  static const String userAgent = 'TripPlanner/1.0 (Flutter; free trip cost planner)';
  static const String tileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  static const String tilePackageName = 'com.redfort360.trip_planner';
  static const String osrmBase = 'https://router.project-osrm.org/route/v1/driving';
  static const String nominatimBase = 'https://nominatim.openstreetmap.org';
  static const String overpassBase = 'https://overpass-api.de/api/interpreter';
}

class PrefKeys {
  const PrefKeys._();

  static const String savedTrips = 'saved_trips_v1';
  static const String petrolPrice = 'setting_petrol_price';
  static const String dieselPrice = 'setting_diesel_price';
  static const String publicRate = 'setting_public_rate';
  static const String lastVehicleId = 'setting_last_vehicle';
  static const String routeCache = 'route_cache_v1';
}
