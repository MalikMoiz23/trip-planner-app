import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../core/app_constants.dart';
import '../core/enums.dart';
import '../core/geo.dart';
import '../logic/budget_advisor.dart';
import '../logic/expense_calculator.dart';
import '../logic/itinerary_builder.dart';
import '../models/attraction.dart';
import '../models/destination.dart';
import '../models/expense_breakdown.dart';
import '../models/itinerary.dart';
import '../models/route_info.dart';
import '../models/weather.dart';
import '../models/saved_trip.dart';
import '../models/trip_config.dart';
import '../services/destination_repository.dart';
import '../services/location_service.dart';
import '../services/osrm_service.dart';
import 'app_state.dart';

/// Drives the four-step planner and owns everything the summary screen reads.
///
/// Routing policy: the origin-to-destination leg is routed as soon as both ends
/// are known, because every screen after that shows a running total. Attraction
/// legs are only routed when the user asks for the summary, so browsing the
/// picker does not fire a request per tap at the shared OSRM instance.
class PlannerController extends ChangeNotifier {
  PlannerController({
    required this.repo,
    required this.appState,
    OsrmService? osrm,
    LocationService? location,
  })  : _osrm = osrm ?? OsrmService(),
        _location = location ?? LocationService();

  final DestinationRepository repo;
  final AppState appState;
  final OsrmService _osrm;
  final LocationService _location;

  static const int stepCount = 4;

  // ---- Wizard position ---------------------------------------------------
  int step = 0;

  // ---- Where ------------------------------------------------------------
  Destination? _destination;

  /// Read-only: the destination is only ever set through [startFor] or
  /// [loadFrom], which also seed the curated stop list and vehicle defaults.
  /// Assigning it directly would leave those empty.
  Destination? get destination => _destination;
  LatLng? origin;
  String originName = '';
  bool locating = false;
  String? locationError;

  // ---- When and who -----------------------------------------------------
  DateTime startDate = DateTime.now().add(const Duration(days: 7));
  int days = AppDefaults.defaultDays;
  int persons = AppDefaults.defaultPersons;

  // ---- How --------------------------------------------------------------
  TravelMode mode = TravelMode.ownVehicle;
  String vehicleId = 'sedan';
  double mileage = 12;
  double fuelPrice = AppDefaults.petrolPricePerLitre;
  FuelKind fuel = FuelKind.petrol;
  double publicRatePerKm = AppDefaults.publicRatePerKm;
  double localTransportPerPersonDay = AppDefaults.localTransportPerPersonDay;
  double tollsAndParking = AppDefaults.defaultTollsAndParking;

  // ---- Comfort ----------------------------------------------------------
  int roomOccupancy = AppDefaults.defaultRoomOccupancy;
  StayStyle stayStyle = StayStyle.hotel;
  double stayRate = StayStyle.hotel.defaultRatePerUnitNight;
  FoodStyle foodStyle = FoodStyle.restaurant;
  double pricePerMeal = FoodStyle.restaurant.defaultPricePerMeal;
  int mealsPerDay = AppDefaults.defaultMealsPerDay;
  double campKitchenCost = AppDefaults.defaultCampKitchenCost;
  double bufferPercent = AppDefaults.defaultBufferPercent;

  /// What the traveller can actually spend. Zero means they have not said, and
  /// the app offers no advice rather than inventing a target.
  double budget = 0;

  /// Cleared the moment the fuel price is typed in, which stops the planner
  /// warning about a default the user has already replaced.
  bool fuelPriceIsDefault = true;

  // ---- Stops ------------------------------------------------------------
  final Set<String> _selectedIds = {};
  List<Attraction> _curated = const [];
  List<Attraction> _live = const [];
  bool loadingNearby = false;
  bool liveAttempted = false;

  // ---- Routing ----------------------------------------------------------
  RouteInfo? outbound;
  bool routing = false;
  Map<String, RouteInfo> attractionRoutes = {};
  bool finalising = false;

  // =======================================================================
  // Derived
  // =======================================================================

  bool get hasOrigin => origin != null;
  bool get hasBudget => budget > 0;
  bool get hasDestination => destination != null;

  List<Attraction> get candidates => [..._curated, ..._live];
  Set<String> get selectedIds => Set.unmodifiable(_selectedIds);

  List<Attraction> get selectedAttractions =>
      candidates.where((a) => _selectedIds.contains(a.id)).toList(growable: false);

  int get selectedCount => _selectedIds.length;

  VehiclePreset get vehicle => AppDefaults.vehicleById(vehicleId);

  /// Distance from the base town to a stop. Uses the routed leg when one has
  /// been fetched, otherwise a terrain-corrected straight line.
  double distanceToStop(Attraction a) {
    final routed = attractionRoutes[a.id];
    if (routed != null && routed.distanceKm > 0) return routed.distanceKm;
    final d = destination;
    if (d == null) return 0;
    return haversineKm(d.point, a.point) * d.roadFactor;
  }

  bool isSelected(String id) => _selectedIds.contains(id);

  double get sightseeingHours =>
      selectedAttractions.fold(0.0, (sum, a) => sum + a.visitHours);

  int get nightsForDisplay => days > 1 ? days - 1 : 0;

  int get roomsForDisplay =>
      persons <= 0 ? 0 : (persons / math.max(1, roomOccupancy)).ceil();

  /// Running total. Null until the outbound leg is known.
  ExpenseBreakdown? get breakdown {
    final route = outbound;
    if (route == null || destination == null) return null;
    return ExpenseCalculator.compute(
      config: buildConfig(),
      outbound: route,
      attractionRoutes: attractionRoutes,
    );
  }

  List<ItineraryDay> get itinerary {
    final route = outbound;
    if (route == null || destination == null) return const [];
    return ItineraryBuilder.build(
      config: buildConfig(),
      outbound: route,
      attractionRoutes: attractionRoutes,
    );
  }

  int get suggestedDays {
    final route = outbound;
    if (route == null || destination == null) return destination?.recommendedDays ?? 3;
    return math.max(
      destination!.recommendedDays,
      ExpenseCalculator.requiredDays(
        config: buildConfig(),
        outbound: route,
        sightseeingHours: sightseeingHours,
      ),
    );
  }

  TripConfig buildConfig() => TripConfig(
        originName: originName.isEmpty ? 'Your location' : originName,
        originLat: origin?.latitude ?? 0,
        originLng: origin?.longitude ?? 0,
        destination: destination!,
        startDate: startDate,
        days: days,
        persons: persons,
        mode: mode,
        vehicleId: vehicleId,
        mileage: mileage,
        fuelPrice: fuelPrice,
        fuel: fuel,
        publicRatePerKm: publicRatePerKm,
        localTransportPerPersonDay: localTransportPerPersonDay,
        roomOccupancy: roomOccupancy,
        stayStyle: stayStyle,
        stayRatePerUnitNight: stayRate,
        foodStyle: foodStyle,
        pricePerMeal: pricePerMeal,
        mealsPerDay: mealsPerDay,
        campKitchenCost: campKitchenCost,
        fuelPriceIsDefault: fuelPriceIsDefault,
        selectedAttractions: selectedAttractions,
        bufferPercent: bufferPercent,
        tollsAndParking: tollsAndParking,
      );

  /// Blocks Next when the current step is incomplete; the message is shown as
  /// a snack bar rather than a silently disabled button.
  String? blockingReason() {
    switch (step) {
      case 0:
        if (destination == null) return 'Pick a destination first.';
        if (origin == null) return 'Set your starting point — detect it or search for a city.';
        if (days < 1) return 'A trip needs at least one day.';
        if (persons < 1) return 'A trip needs at least one traveller.';
        return null;
      case 1:
        if (mode == TravelMode.ownVehicle && mileage <= 0) {
          return 'Mileage must be greater than zero.';
        }
        if (mode == TravelMode.ownVehicle && fuelPrice <= 0) {
          return 'Enter the fuel price you are paying.';
        }
        if (mode == TravelMode.publicTransport && publicRatePerKm <= 0) {
          return 'Enter a per-kilometre fare.';
        }
        return null;
      default:
        return null;
    }
  }

  // =======================================================================
  // Mutations
  // =======================================================================

  void startFor(Destination d) {
    _destination = d;
    days = d.recommendedDays;
    _selectedIds.clear();
    _curated = d.attractions;
    _live = const [];
    liveAttempted = false;
    attractionRoutes = {};
    outbound = null;
    step = 0;

    vehicleId = appState.lastVehicleId;
    final preset = AppDefaults.vehicleById(vehicleId);
    mileage = preset.mileage;
    fuel = preset.fuel;
    fuelPrice = appState.priceFor(preset.fuel);
    fuelPriceIsDefault = !appState.fuelPriceIsCustom;
    publicRatePerKm = appState.publicRatePerKm;

    notifyListeners();
    if (origin != null) {
      unawaited(_routeOutbound());
    } else {
      unawaited(detectLocation());
    }
  }

  // ---- Budget -------------------------------------------------------------

  /// Advice on fitting the trip inside [budget], recomputed from the live
  /// breakdown. Null until both a route and a budget exist.
  BudgetAdvice? get budgetAdvice {
    final d = _destination;
    final route = outbound;
    if (d == null || route == null || !hasBudget) return null;
    return BudgetAdvisor.advise(
      config: buildConfig(),
      outbound: route,
      attractionRoutes: attractionRoutes,
      budget: budget,
    );
  }

  void setBudget(double value) {
    budget = value < 0 ? 0 : value;
    notifyListeners();
  }

  /// Swaps the plan for the cheaper variant the advisor worked out, so taking a
  /// suggestion is one tap rather than a list of edits to reproduce by hand.
  void applyLever(BudgetLever lever) {
    _adopt(lever.apply(buildConfig()));
    notifyListeners();
  }

  // ---- Weather ------------------------------------------------------------

  PlaceWeather? weather;
  bool loadingWeather = false;

  /// Climate and forecast for wherever the trip is going. Never throws; on
  /// failure [weather] stays null and the UI omits those sections.
  Future<void> loadWeather() async {
    final d = _destination;
    if (d == null || loadingWeather) return;

    final hit = appState.weatherService.cached(d.point);
    if (hit != null) {
      weather = hit;
      notifyListeners();
      return;
    }

    loadingWeather = true;
    notifyListeners();
    weather = await appState.weatherService.load(d.point);
    loadingWeather = false;
    notifyListeners();
  }

  void setDestination(Destination d) {
    if (destination?.id == d.id) return;
    startFor(d);
  }

  void goTo(int index) {
    step = index.clamp(0, stepCount - 1);
    notifyListeners();
  }

  void next() {
    if (step < stepCount - 1) {
      step++;
      notifyListeners();
    }
  }

  void back() {
    if (step > 0) {
      step--;
      notifyListeners();
    }
  }

  Future<void> detectLocation() async {
    locating = true;
    locationError = null;
    notifyListeners();
    try {
      final fix = await _location.current();
      origin = fix.point;
      originName = await repo.reverseName(fix.point);
      locationError = null;
    } on LocationFailure catch (e) {
      locationError = e.message;
    } on Exception catch (e) {
      locationError = 'Location lookup failed: $e';
    }
    locating = false;
    notifyListeners();
    if (origin != null) await _routeOutbound();
  }

  Future<void> setOriginManually(String name, LatLng point) async {
    origin = point;
    originName = name;
    locationError = null;
    notifyListeners();
    await _routeOutbound();
  }

  void setDates(DateTime start) {
    startDate = start;
    notifyListeners();
  }

  void setDays(int value) {
    days = value.clamp(1, 30);
    notifyListeners();
  }

  void setPersons(int value) {
    persons = value.clamp(1, 40);
    notifyListeners();
  }

  void setMode(TravelMode value) {
    mode = value;
    notifyListeners();
  }

  void setVehicle(String id) {
    vehicleId = id;
    final preset = AppDefaults.vehicleById(id);
    mileage = preset.mileage;
    fuel = preset.fuel;
    fuelPrice = appState.priceFor(preset.fuel);
    unawaited(appState.rememberVehicle(id));
    notifyListeners();
  }

  void setMileage(double v) {
    mileage = v;
    notifyListeners();
  }

  void setFuel(FuelKind v) {
    fuel = v;
    fuelPrice = appState.priceFor(v);
    notifyListeners();
  }

  void setFuelPrice(double v) {
    fuelPrice = v;
    fuelPriceIsDefault = false;
    notifyListeners();
  }

  void setPublicRate(double v) {
    publicRatePerKm = v;
    notifyListeners();
  }

  void setLocalTransportRate(double v) {
    localTransportPerPersonDay = v;
    notifyListeners();
  }

  void setTolls(double v) {
    tollsAndParking = v;
    notifyListeners();
  }

  void setStayStyle(StayStyle style) {
    stayStyle = style;
    stayRate = style.defaultRatePerUnitNight;
    // Tents and rooms hold different numbers of people, so the occupancy moves
    // with the choice rather than stranding a stale value.
    roomOccupancy = style.defaultOccupancy;
    notifyListeners();
  }

  void setStayRate(double v) {
    stayRate = v;
    notifyListeners();
  }

  void setFoodStyle(FoodStyle style) {
    foodStyle = style;
    pricePerMeal = style.defaultPricePerMeal;
    notifyListeners();
  }

  void setMealsPerDay(int value) {
    mealsPerDay = value.clamp(AppDefaults.minMealsPerDay, AppDefaults.maxMealsPerDay);
    notifyListeners();
  }

  void setCampKitchenCost(double v) {
    campKitchenCost = v;
    notifyListeners();
  }

  void setPricePerMeal(double v) {
    pricePerMeal = v;
    notifyListeners();
  }

  void setRoomOccupancy(int v) {
    roomOccupancy = v.clamp(1, 6);
    notifyListeners();
  }

  void setBuffer(double v) {
    bufferPercent = v;
    notifyListeners();
  }

  void toggleAttraction(String id) {
    if (!_selectedIds.remove(id)) _selectedIds.add(id);
    notifyListeners();
  }

  void selectAllCurated() {
    _selectedIds.addAll(_curated.map((a) => a.id));
    notifyListeners();
  }

  void clearAttractions() {
    _selectedIds.clear();
    notifyListeners();
  }

  /// Lets the user put a real number on an OpenStreetMap stop that ships with
  /// zeros, or correct a curated one.
  void updateAttractionCost(String id, {double? entryFee, double? localTransport}) {
    List<Attraction> patch(List<Attraction> list) => list
        .map((a) => a.id == id
            ? a.copyWith(entryFee: entryFee, localTransport: localTransport)
            : a)
        .toList(growable: false);
    _curated = patch(_curated);
    _live = patch(_live);
    notifyListeners();
  }

  Future<void> loadNearby({bool force = false}) async {
    final d = destination;
    if (d == null) return;
    if (liveAttempted && !force) return;
    loadingNearby = true;
    liveAttempted = true;
    notifyListeners();
    _live = await repo.liveNearby(d);
    loadingNearby = false;
    notifyListeners();
  }

  Future<void> _routeOutbound() async {
    final d = destination;
    final o = origin;
    if (d == null || o == null) return;
    routing = true;
    notifyListeners();
    outbound = await _osrm.route(o, d.point, roadFactor: d.roadFactor);
    routing = false;
    notifyListeners();
  }

  Future<void> refreshRoute() => _routeOutbound();

  /// Routes the chosen stops before the summary is shown, so the fuel figure
  /// reflects real detours rather than straight lines.
  Future<void> finalise() async {
    final d = destination;
    if (d == null) return;
    finalising = true;
    notifyListeners();

    if (outbound == null) await _routeOutbound();

    final pending = <String, LatLng>{
      for (final a in selectedAttractions)
        if (!attractionRoutes.containsKey(a.id)) a.id: a.point,
    };
    if (pending.isNotEmpty) {
      final routed = await _osrm.routeMany(d.point, pending, roadFactor: d.roadFactor);
      attractionRoutes = {...attractionRoutes, ...routed};
    }

    finalising = false;
    notifyListeners();

    // Deliberately not awaited: the summary is worth showing the instant the
    // costing is done, and the weather section fills itself in a moment later
    // rather than holding up the whole screen behind a third-party service.
    unawaited(loadWeather());
  }

  SavedTrip toSavedTrip() {
    final b = breakdown!;
    return SavedTrip(
      id: '${DateTime.now().microsecondsSinceEpoch}',
      createdAt: DateTime.now(),
      config: buildConfig(),
      outboundRoute: outbound ?? RouteInfo.zero,
      total: b.total,
      perPerson: b.perPerson,
      totalKm: b.totalKm,
      budget: budget,
    );
  }

  /// Reopens a saved trip in the planner so it can be adjusted and re-costed.
  void loadFrom(SavedTrip trip) {
    _adopt(trip.config);
    budget = trip.budget;
    weather = null;
    attractionRoutes = {};
    outbound = trip.outboundRoute;
    step = 0;
    notifyListeners();
  }

  /// Copies every field of a config into this controller.
  ///
  /// Shared by [loadFrom] and by the budget advisor, which hands back a whole
  /// modified config rather than a diff — keeping one adoption path means a new
  /// field cannot be wired into saving but forgotten in the advice flow.
  void _adopt(TripConfig c) {
    _destination = c.destination;
    origin = c.origin;
    originName = c.originName;
    startDate = c.startDate;
    days = c.days;
    persons = c.persons;
    mode = c.mode;
    vehicleId = c.vehicleId;
    mileage = c.mileage;
    fuelPrice = c.fuelPrice;
    fuel = c.fuel;
    publicRatePerKm = c.publicRatePerKm;
    localTransportPerPersonDay = c.localTransportPerPersonDay;
    roomOccupancy = c.roomOccupancy;
    stayStyle = c.stayStyle;
    stayRate = c.stayRatePerUnitNight;
    foodStyle = c.foodStyle;
    pricePerMeal = c.pricePerMeal;
    mealsPerDay = c.mealsPerDay;
    campKitchenCost = c.campKitchenCost;
    fuelPriceIsDefault = c.fuelPriceIsDefault;
    bufferPercent = c.bufferPercent;
    tollsAndParking = c.tollsAndParking;

    final curatedIds = c.destination.attractions.map((a) => a.id).toSet();
    _curated = c.destination.attractions;
    _live = c.selectedAttractions.where((a) => !curatedIds.contains(a.id)).toList();
    _selectedIds
      ..clear()
      ..addAll(c.selectedAttractions.map((a) => a.id));
    liveAttempted = false;
  }
}
