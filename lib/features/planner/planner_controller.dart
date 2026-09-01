import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import 'package:trip_planner/core/constants.dart';
import 'package:trip_planner/core/enums.dart';
import 'package:trip_planner/core/geo.dart';
import 'package:trip_planner/domain/budget_advisor.dart';
import 'package:trip_planner/domain/expense_calculator.dart';
import 'package:trip_planner/domain/itinerary_builder.dart';
import 'package:trip_planner/data/models/attraction.dart';
import 'package:trip_planner/data/models/destination.dart';
import 'package:trip_planner/features/planner/planned_stop.dart';
import 'package:trip_planner/data/models/expense_breakdown.dart';
import 'package:trip_planner/data/models/itinerary.dart';
import 'package:trip_planner/data/models/route_info.dart';
import 'package:trip_planner/data/models/weather.dart';
import 'package:trip_planner/data/models/saved_trip.dart';
import 'package:trip_planner/data/models/trip_config.dart';
import 'package:trip_planner/data/models/meal_plan.dart';
import 'package:trip_planner/data/models/trip_stop.dart';
import 'package:trip_planner/data/repositories/destination_repository.dart';
import 'package:trip_planner/data/sources/location_service.dart';
import 'package:trip_planner/data/sources/osrm_service.dart';
import 'package:trip_planner/app/app_state.dart';

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
  /// The first place you sleep. Derived from [route] rather than stored, so the
  /// two can never disagree.
  ///
  /// Plenty of the app is still single-destination shaped — the hero, the
  /// weather, the packing list — and for those the first stop is the answer.
  Destination? get destination => route.isEmpty ? null : route.first.destination;

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
  /// Which sittings happen on each day, and what each costs.
  MealPlan mealPlan = MealPlan.standard(
    dayCount: AppDefaults.defaultDays,
    basePrice: FoodStyle.restaurant.defaultPricePerMeal,
  );
  double campKitchenCost = AppDefaults.defaultCampKitchenCost;
  double bufferPercent = AppDefaults.defaultBufferPercent;

  /// What the traveller can actually spend. Zero means they have not said, and
  /// the app offers no advice rather than inventing a target.
  double budget = 0;

  /// Cleared the moment the fuel price is typed in, which stops the planner
  /// warning about a default the user has already replaced.
  bool fuelPriceIsDefault = true;

  // ---- The route ----------------------------------------------------------
  /// Every place you sleep, in order. A single-destination trip is one entry.
  final List<PlannedStop> route = [];

  /// Which stop the "what to see" step is currently editing.
  int activeStopIndex = 0;

  bool loadingNearby = false;

  // ---- Routing ------------------------------------------------------------
  /// One per leg: home → stop 1 → … → stop n → home, so `route.length + 1`
  /// entries. A null means that leg has not been fetched yet; the calculator
  /// estimates any it is not given.
  final List<RouteInfo?> legs = [];

  bool routing = false;
  Map<String, RouteInfo> attractionRoutes = {};
  bool finalising = false;

  // =======================================================================
  // Derived
  // =======================================================================

  bool get hasOrigin => origin != null;
  bool get hasBudget => budget > 0;
  bool get hasDestination => destination != null;

  /// The stop being edited on the "what to see" step.
  PlannedStop? get activeStop =>
      route.isEmpty ? null : route[activeStopIndex.clamp(0, route.length - 1)];

  bool get isMultiStop => route.length > 1;

  /// Nights the route accounts for, which should match [nightsForDisplay].
  int get allocatedNights => route.fold(0, (n, s) => n + s.nights);

  int get unallocatedNights => nightsForDisplay - allocatedNights;

  /// Candidates and selection belong to the active stop — a place you can see
  /// from Hunza is not on the menu while you are based in Naran.
  List<Attraction> get candidates => activeStop?.candidates ?? const [];

  Set<String> get selectedIds => Set.unmodifiable(activeStop?.selectedIds ?? const {});

  bool get liveAttempted => activeStop?.liveAttempted ?? false;

  /// Everything chosen across the whole route.
  List<Attraction> get selectedAttractions =>
      [for (final s in route) ...s.selected];

  int get selectedCount => selectedAttractions.length;

  VehiclePreset get vehicle => AppDefaults.vehicleById(vehicleId);

  /// Distance from the base you would be staying at to a stop. Uses the routed
  /// leg when one has been fetched, otherwise a terrain-corrected straight line.
  double distanceToStop(Attraction a) {
    final routed = attractionRoutes[a.id];
    if (routed != null && routed.distanceKm > 0) return routed.distanceKm;
    final base = activeStop?.destination ?? destination;
    if (base == null) return 0;
    return haversineKm(base.point, a.point) * base.roadFactor;
  }

  bool isSelected(String id) => activeStop?.selectedIds.contains(id) ?? false;

  double get sightseeingHours =>
      selectedAttractions.fold(0.0, (sum, a) => sum + a.visitHours);

  /// Legs with the gaps filled in as nulls removed — what the domain wants.
  List<RouteInfo> get resolvedLegs => [
        for (final l in legs)
          if (l != null) l else const RouteInfo(distanceKm: 0, duration: Duration.zero),
      ];

  /// True once at least the first leg is known, which is when a total becomes
  /// worth showing.
  bool get hasAnyRoute => legs.any((l) => l != null);

  int get nightsForDisplay => days > 1 ? days - 1 : 0;

  int get roomsForDisplay =>
      persons <= 0 ? 0 : (persons / math.max(1, roomOccupancy)).ceil();

  /// Running total. Null until at least one leg is known.
  ExpenseBreakdown? get breakdown {
    if (!hasAnyRoute || route.isEmpty) return null;
    return ExpenseCalculator.compute(
      config: buildConfig(),
      legs: resolvedLegs,
      attractionRoutes: attractionRoutes,
    );
  }

  List<ItineraryDay> get itinerary {
    if (!hasAnyRoute || route.isEmpty) return const [];
    return ItineraryBuilder.build(
      config: buildConfig(),
      legs: resolvedLegs,
      attractionRoutes: attractionRoutes,
    );
  }

  int get suggestedDays {
    if (route.isEmpty) return 3;
    final floor = route.fold(0, (sum, s) => sum + s.destination.recommendedDays);
    if (!hasAnyRoute) return floor;
    return math.max(
      floor,
      ExpenseCalculator.requiredDays(
        config: buildConfig(),
        legs: resolvedLegs,
        sightseeingHours: sightseeingHours,
      ),
    );
  }

  TripConfig buildConfig() => TripConfig(
        originName: originName.isEmpty ? 'Your location' : originName,
        originLat: origin?.latitude ?? 0,
        originLng: origin?.longitude ?? 0,
        stops: [for (final s in route) s.toTripStop()],
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
        mealPlan: mealPlan,
        campKitchenCost: campKitchenCost,
        fuelPriceIsDefault: fuelPriceIsDefault,
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
    days = d.recommendedDays;
    route
      ..clear()
      ..add(PlannedStop(destination: d, nights: days > 1 ? days - 1 : 0));
    activeStopIndex = 0;
    attractionRoutes = {};
    _resetLegs();
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
    if (route.isEmpty || !hasAnyRoute || !hasBudget) return null;
    return BudgetAdvisor.advise(
      config: buildConfig(),
      legs: resolvedLegs,
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
    final d = destination;
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
    // With one stop the nights are simply the days minus one, so keeping them
    // in step means a single-destination trip never has to think about nights
    // at all. On a route the split is the user's, so it is left alone and the
    // ledger reports any mismatch instead.
    if (route.length == 1) {
      route.first.nights = nightsForDisplay;
    }
    // The meal plan is one entry per day, so it has to grow and shrink with the
    // trip. Days already chosen keep their meals; new ones get the default
    // pattern for that position.
    mealPlan = mealPlan.resized(days);
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
    // Rebases every sitting at once, keeping which meals are taken on which
    // day. Switching from dhaba to hotel dining should move the prices, not
    // undo a day-by-day plan someone has just set up.
    mealPlan = mealPlan.rebased(style.defaultPricePerMeal);
    notifyListeners();
  }

  /// Adds or removes one sitting on one day.
  void toggleMeal(int dayIndex, MealSlot slot) {
    mealPlan = mealPlan.toggled(dayIndex, slot);
    notifyListeners();
  }

  /// Copies one day's meals onto every other day.
  void applyMealsToAllDays(int dayIndex) {
    mealPlan = mealPlan.appliedToAll(dayIndex);
    notifyListeners();
  }

  void setMealPrice(MealSlot slot, double value) {
    mealPlan = mealPlan.withPrice(slot, value);
    notifyListeners();
  }

  void setCampKitchenCost(double v) {
    campKitchenCost = v;
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
    final stop = activeStop;
    if (stop == null) return;
    if (!stop.selectedIds.remove(id)) stop.selectedIds.add(id);
    notifyListeners();
  }

  // =======================================================================
  // Building the route
  // =======================================================================

  /// Adds a place to sleep at, after the ones already chosen.
  ///
  /// Nights come out of whatever the day count has not spoken for; when there
  /// is nothing spare the stop is added with none, which the summary then flags
  /// rather than quietly stretching the trip.
  void addStop(Destination d) {
    if (route.any((s) => s.destination.id == d.id)) return;
    final spare = math.max(0, unallocatedNights);
    route.add(PlannedStop(destination: d, nights: math.min(spare, d.recommendedDays)));
    activeStopIndex = route.length - 1;
    _resetLegs();
    notifyListeners();
    unawaited(_routeAllLegs());
  }

  void removeStop(int index) {
    if (index < 0 || index >= route.length || route.length == 1) return;
    route.removeAt(index);
    activeStopIndex = activeStopIndex.clamp(0, route.length - 1);
    _resetLegs();
    notifyListeners();
    unawaited(_routeAllLegs());
  }

  /// Reorders the route. The legs all change, so they are refetched.
  void moveStop(int from, int to) {
    if (from < 0 || from >= route.length) return;
    final target = to.clamp(0, route.length - 1);
    if (from == target) return;
    final moved = route.removeAt(from);
    route.insert(target, moved);
    activeStopIndex = target;
    _resetLegs();
    notifyListeners();
    unawaited(_routeAllLegs());
  }

  void setStopNights(int index, int nights) {
    if (index < 0 || index >= route.length) return;
    route[index].nights = math.max(0, nights);
    notifyListeners();
  }

  void setActiveStop(int index) {
    activeStopIndex = index.clamp(0, math.max(0, route.length - 1));
    notifyListeners();
  }

  /// Spreads the trip's nights over the stops as evenly as they divide, with
  /// any remainder going to the earlier stops.
  void balanceNights() {
    if (route.isEmpty) return;
    final total = nightsForDisplay;
    final each = total ~/ route.length;
    var left = total - each * route.length;
    for (final s in route) {
      s.nights = each + (left-- > 0 ? 1 : 0);
    }
    notifyListeners();
  }

  void selectAllCurated() {
    final stop = activeStop;
    if (stop == null) return;
    stop.selectedIds.addAll(stop.curated.map((a) => a.id));
    notifyListeners();
  }

  void clearAttractions() {
    activeStop?.selectedIds.clear();
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
    for (final stop in route) {
      stop.curated = patch(stop.curated);
      stop.live = patch(stop.live);
    }
    notifyListeners();
  }

  Future<void> loadNearby({bool force = false}) async {
    final stop = activeStop;
    if (stop == null) return;
    if (stop.liveAttempted && !force) return;
    loadingNearby = true;
    stop.liveAttempted = true;
    notifyListeners();
    stop.live = await repo.liveNearby(stop.destination);
    loadingNearby = false;
    notifyListeners();
  }

  /// Clears the leg cache and sizes it to the current route.
  ///
  /// Called whenever the shape of the route changes. Reordering Naran and Hunza
  /// changes every leg, not just the two that moved, so keeping any of them
  /// would leave the total quietly wrong.
  void _resetLegs() {
    legs
      ..clear()
      ..addAll(List<RouteInfo?>.filled(route.length + 1, null));
  }

  /// Fetches every leg of the loop: home to the first stop, between each pair,
  /// and back home from the last.
  Future<void> _routeAllLegs() async {
    final o = origin;
    if (o == null || route.isEmpty) return;

    if (legs.length != route.length + 1) _resetLegs();

    routing = true;
    notifyListeners();

    final points = [o, for (final s in route) s.destination.point, o];
    for (var i = 0; i < points.length - 1; i++) {
      if (legs[i] != null) continue;
      final factor = route[math.min(i, route.length - 1)].destination.roadFactor;
      // pairRoute, not route: the way out and the way home are the same road and
      // have to carry the same number. On a single-destination trip this costs
      // no extra requests, because the two legs share one cache entry.
      legs[i] = await _osrm.pairRoute(points[i], points[i + 1], roadFactor: factor);
      // Publish each leg as it lands: on a four-stop route the total should
      // firm up progressively rather than sitting empty until the last request
      // comes back.
      notifyListeners();
    }

    routing = false;
    notifyListeners();
  }

  Future<void> _routeOutbound() => _routeAllLegs();

  Future<void> refreshRoute() => _routeOutbound();

  /// Routes the chosen stops before the summary is shown, so the fuel figure
  /// reflects real detours rather than straight lines.
  Future<void> finalise() async {
    final d = destination;
    if (d == null) return;
    finalising = true;
    notifyListeners();

    if (!hasAnyRoute) await _routeAllLegs();

    // Day trips are measured from the stop they belong to, so each base gets
    // its own batch rather than everything being measured from the first one.
    for (final stop in route) {
      final base = stop.destination;
      final pending = <String, LatLng>{
        for (final a in stop.selected)
          if (!attractionRoutes.containsKey(a.id)) a.id: a.point,
      };
      if (pending.isEmpty) continue;
      final routed =
          await _osrm.routeMany(base.point, pending, roadFactor: base.roadFactor);
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
      outboundRoute: legs.isNotEmpty && legs.first != null ? legs.first! : RouteInfo.zero,
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
    _resetLegs();
    if (legs.isNotEmpty) legs[0] = trip.outboundRoute;
    step = 0;
    unawaited(_routeAllLegs());
    notifyListeners();
  }

  /// Copies every field of a config into this controller.
  ///
  /// Shared by [loadFrom] and by the budget advisor, which hands back a whole
  /// modified config rather than a diff — keeping one adoption path means a new
  /// field cannot be wired into saving but forgotten in the advice flow.
  void _adopt(TripConfig c) {
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
    mealPlan = c.mealPlan;
    campKitchenCost = c.campKitchenCost;
    fuelPriceIsDefault = c.fuelPriceIsDefault;
    bufferPercent = c.bufferPercent;
    tollsAndParking = c.tollsAndParking;

    route
      ..clear()
      ..addAll([
        for (final s in c.stops) _plannedFrom(s),
      ]);
    activeStopIndex = 0;
    _resetLegs();
  }

  /// Rebuilds the editable stop from a saved one.
  ///
  /// Anything selected that is not in the catalogue for that place came from a
  /// live lookup, so it is put back in the live list — otherwise reopening a
  /// trip would show the selection ticked against a candidate that no longer
  /// appears in the picker.
  static PlannedStop _plannedFrom(TripStop s) {
    final curatedIds = s.destination.attractions.map((a) => a.id).toSet();
    final stop = PlannedStop(destination: s.destination, nights: s.nights)
      ..live = s.selectedAttractions
          .where((a) => !curatedIds.contains(a.id))
          .toList(growable: false);
    stop.selectedIds.addAll(s.selectedAttractions.map((a) => a.id));
    return stop;
  }
}
