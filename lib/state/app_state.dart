import 'package:flutter/foundation.dart';

import '../core/app_constants.dart';
import '../core/enums.dart';
import '../models/destination.dart';
import '../models/saved_trip.dart';
import '../services/destination_repository.dart';
import '../services/storage_service.dart';

/// App-wide, long-lived state: the catalogue, the saved trips, and the price
/// settings that seed every new plan.
class AppState extends ChangeNotifier {
  AppState({DestinationRepository? repository, StorageService? storage})
      : repository = repository ?? DestinationRepository(),
        storage = storage ?? StorageService();

  final DestinationRepository repository;
  final StorageService storage;

  bool _ready = false;
  String? _error;
  List<SavedTrip> _savedTrips = const [];

  double petrolPrice = AppDefaults.petrolPricePerLitre;
  double dieselPrice = AppDefaults.dieselPricePerLitre;
  double publicRatePerKm = AppDefaults.publicRatePerKm;
  String lastVehicleId = 'sedan';

  /// False while fuel is still whatever the app shipped with. Pakistan reprices
  /// petrol daily, so a plan built on the bundled figure gets an advisory.
  bool fuelPriceIsCustom = false;

  bool get isReady => _ready;
  String? get error => _error;
  List<SavedTrip> get savedTrips => _savedTrips;
  List<Destination> get destinations => repository.all;
  List<Destination> get featured => repository.featured;
  List<String> get categories => repository.categories;
  String get dataNote => repository.dataNote;

  Future<void> init() async {
    try {
      await repository.load();
      petrolPrice = await storage.petrolPrice();
      dieselPrice = await storage.dieselPrice();
      publicRatePerKm = await storage.publicRate();
      lastVehicleId = await storage.lastVehicleId();
      fuelPriceIsCustom = await storage.hasCustomFuelPrice();
      _savedTrips = await storage.loadTrips();
      _ready = true;
      _error = null;
    } on Exception catch (e) {
      _error = 'Could not load the destination catalogue: $e';
      _ready = false;
    }
    notifyListeners();
  }

  double priceFor(FuelKind fuel) =>
      fuel == FuelKind.diesel ? dieselPrice : petrolPrice;

  Future<void> setPetrolPrice(double v) async {
    petrolPrice = v;
    fuelPriceIsCustom = true;
    await storage.setPetrolPrice(v);
    notifyListeners();
  }

  Future<void> setDieselPrice(double v) async {
    dieselPrice = v;
    fuelPriceIsCustom = true;
    await storage.setDieselPrice(v);
    notifyListeners();
  }

  Future<void> setPublicRate(double v) async {
    publicRatePerKm = v;
    await storage.setPublicRate(v);
    notifyListeners();
  }

  Future<void> rememberVehicle(String id) async {
    lastVehicleId = id;
    await storage.setLastVehicleId(id);
  }

  Future<void> addTrip(SavedTrip trip) async {
    _savedTrips = [trip, ..._savedTrips];
    await storage.saveTrips(_savedTrips);
    notifyListeners();
  }

  Future<void> deleteTrip(String id) async {
    _savedTrips = _savedTrips.where((t) => t.id != id).toList(growable: false);
    await storage.saveTrips(_savedTrips);
    notifyListeners();
  }

  Future<void> clearTrips() async {
    _savedTrips = const [];
    await storage.saveTrips(const []);
    notifyListeners();
  }
}
