import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../core/app_constants.dart';
import '../models/saved_trip.dart';

/// Local persistence. No account, no backend — everything lives in
/// shared_preferences on the device.
class StorageService {
  SharedPreferences? _prefs;

  Future<SharedPreferences> get _p async => _prefs ??= await SharedPreferences.getInstance();

  // ---- Saved trips -------------------------------------------------------

  Future<List<SavedTrip>> loadTrips() async {
    final prefs = await _p;
    final raw = prefs.getStringList(PrefKeys.savedTrips) ?? const [];
    final out = <SavedTrip>[];
    for (final item in raw) {
      try {
        out.add(SavedTrip.fromJson(jsonDecode(item) as Map<String, dynamic>));
      } on Exception {
        // A row written by an older schema — drop it rather than crash the list.
      }
    }
    out.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return out;
  }

  Future<void> saveTrips(List<SavedTrip> trips) async {
    final prefs = await _p;
    await prefs.setStringList(
      PrefKeys.savedTrips,
      trips.map((t) => jsonEncode(t.toJson())).toList(growable: false),
    );
  }

  // ---- Settings ----------------------------------------------------------

  /// Stored by enum name so the value survives a reordering of ThemeMode.
  Future<String?> themeMode() async => (await _p).getString(PrefKeys.themeMode);

  Future<void> setThemeMode(String name) async =>
      (await _p).setString(PrefKeys.themeMode, name);

  Future<double> petrolPrice() async =>
      (await _p).getDouble(PrefKeys.petrolPrice) ?? AppDefaults.petrolPricePerLitre;

  /// True once a real pump price has been entered. Pakistan reprices petrol
  /// daily, so this is what tells the planner whether it is still quoting its
  /// own bundled figure and should say so.
  Future<bool> hasCustomFuelPrice() async {
    final prefs = await _p;
    return prefs.containsKey(PrefKeys.petrolPrice) ||
        prefs.containsKey(PrefKeys.dieselPrice);
  }

  Future<double> dieselPrice() async =>
      (await _p).getDouble(PrefKeys.dieselPrice) ?? AppDefaults.dieselPricePerLitre;

  Future<double> publicRate() async =>
      (await _p).getDouble(PrefKeys.publicRate) ?? AppDefaults.publicRatePerKm;

  Future<String> lastVehicleId() async =>
      (await _p).getString(PrefKeys.lastVehicleId) ?? 'sedan';

  Future<void> setPetrolPrice(double v) async => (await _p).setDouble(PrefKeys.petrolPrice, v);
  Future<void> setDieselPrice(double v) async => (await _p).setDouble(PrefKeys.dieselPrice, v);
  Future<void> setPublicRate(double v) async => (await _p).setDouble(PrefKeys.publicRate, v);
  Future<void> setLastVehicleId(String v) async => (await _p).setString(PrefKeys.lastVehicleId, v);
}
