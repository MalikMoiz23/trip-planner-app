import 'package:flutter/material.dart';

import 'package:trip_planner/core/enums.dart';

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
  // OGRA ex-depot rates effective 28 August 2026. Pakistan moved to daily
  // petroleum pricing in August 2026, so these are stale within a day and the
  // app treats them as a starting point that needs confirming, never as fact.
  // Retail pump prices also vary by city.
  static const double petrolPricePerLitre = 342.60;
  static const double dieselPricePerLitre = 371.61;

  /// When the two figures above were correct.
  static final DateTime fuelPriceAsOf = DateTime(2026, 8, 28);

  /// Past this, the planner stops trusting its own default and asks.
  static const int fuelPriceStaleAfterDays = 3;

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

  // ---- Food --------------------------------------------------------------
  /// Breakfast, lunch and dinner. Tea and snacks are what the contingency is for.
  static const int defaultMealsPerDay = 3;
  static const int minMealsPerDay = 1;
  static const int maxMealsPerDay = 6;

  /// One-off cost of cooking for yourself: stove, a gas cylinder and utensils,
  /// counted once for the whole trip rather than per meal.
  static const double defaultCampKitchenCost = 3000.0;

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

  // Photon: free, no key, built for type-ahead. Complements Nominatim, which
  // matches near-exactly and returns nothing for a misspelling.
  static const String photonBase = 'https://photon.komoot.io/api/';

  // Open-Meteo: free for non-commercial use, no key and no account.
  static const String openMeteoForecast = 'https://api.open-meteo.com/v1/forecast';
  static const String openMeteoArchive = 'https://archive-api.open-meteo.com/v1/archive';
}

class PrefKeys {
  const PrefKeys._();

  static const String savedTrips = 'saved_trips_v1';
  static const String petrolPrice = 'setting_petrol_price';
  static const String dieselPrice = 'setting_diesel_price';
  static const String publicRate = 'setting_public_rate';
  static const String lastVehicleId = 'setting_last_vehicle';
  static const String routeCache = 'route_cache_v1';
  static const String themeMode = 'setting_theme_mode';
}
