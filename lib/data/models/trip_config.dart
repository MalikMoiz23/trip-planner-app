import 'package:latlong2/latlong.dart';

import 'package:trip_planner/core/enums.dart';
import 'package:trip_planner/data/models/attraction.dart';
import 'package:trip_planner/data/models/destination.dart';
import 'package:trip_planner/data/models/trip_stop.dart';

/// Every input the cost engine reads. Held immutably so a saved trip re-opens
/// with exactly the assumptions it was calculated under, even if the user has
/// since changed the app-wide fuel price.
class TripConfig {
  const TripConfig({
    required this.originName,
    required this.originLat,
    required this.originLng,
    required this.stops,
    required this.startDate,
    required this.days,
    required this.persons,
    required this.mode,
    required this.vehicleId,
    required this.mileage,
    required this.fuelPrice,
    required this.fuel,
    required this.publicRatePerKm,
    required this.localTransportPerPersonDay,
    required this.roomOccupancy,
    required this.stayStyle,
    required this.stayRatePerUnitNight,
    required this.foodStyle,
    required this.pricePerMeal,
    required this.mealsPerDay,
    required this.campKitchenCost,
    required this.fuelPriceIsDefault,
    required this.bufferPercent,
    required this.tollsAndParking,
  });

  final String originName;
  final double originLat;
  final double originLng;
  /// Where you sleep, in the order you get there. Never empty.
  ///
  /// A single-destination trip is a one-stop list, which is why the getters
  /// below still read naturally in that case and most of the app did not have
  /// to change when this became a route.
  final List<TripStop> stops;

  /// The first place you stay. Plenty of the app still speaks in terms of one
  /// destination — the hero image, the weather, the packing list — and for
  /// those the first stop is the right answer.
  Destination get destination => stops.first.destination;

  /// The last place you stay before turning for home.
  Destination get finalDestination => stops.last.destination;

  /// Everything chosen across every stop, flattened.
  List<Attraction> get selectedAttractions =>
      [for (final s in stops) ...s.selectedAttractions];

  bool get isMultiStop => stops.length > 1;

  /// Nights the stops actually account for. Should equal [nights]; when it
  /// does not the calculator says so rather than quietly costing the wrong
  /// number of hotel rooms.
  int get allocatedNights => stops.fold(0, (n, s) => n + s.nights);

  final DateTime startDate;
  final int days;
  final int persons;

  final TravelMode mode;
  final String vehicleId;

  /// Kilometres per litre, user-overridable.
  final double mileage;
  final double fuelPrice;
  final FuelKind fuel;

  /// Per person per kilometre for intercity buses/vans.
  final double publicRatePerKm;

  /// Per person per day for taxis and rickshaws once you are there.
  final double localTransportPerPersonDay;

  /// People sharing one room, or one tent when camping.
  final int roomOccupancy;
  final StayStyle stayStyle;

  /// Per room, or per tent when camping. Zero for an own tent.
  final double stayRatePerUnitNight;

  final FoodStyle foodStyle;

  /// Per person, per meal.
  final double pricePerMeal;

  /// Meals counted in a day. Drives the food bill for every style.
  final int mealsPerDay;

  /// Stove, gas and utensils, once for the trip. Only when self-cooking.
  final double campKitchenCost;

  /// False once the fuel price has been typed in rather than inherited from the
  /// bundled default, which is what lets the planner stop nagging about it.
  final bool fuelPriceIsDefault;

  final double bufferPercent;
  final double tollsAndParking;

  LatLng get origin => LatLng(originLat, originLng);

  int get nights => days > 1 ? days - 1 : 0;

  /// Rooms, or tents when camping.
  int get rooms => persons <= 0 ? 0 : (persons / roomOccupancy).ceil();

  DateTime get endDate => startDate.add(Duration(days: days - 1));

  bool get isSelfDriving => mode == TravelMode.ownVehicle;

  bool get isCamping => stayStyle.isCamping;

  bool get isSelfCooking => foodStyle.needsKitchen;

  /// Total meals bought or cooked across the whole trip.
  int get totalMeals => days * persons * mealsPerDay;

  /// True when the road in, or any chosen stop, expects a 4x4.
  bool get requires4x4Anywhere =>
      destination.requires4x4 || selectedAttractions.any((a) => a.requires4x4);

  /// The kitchen kit is only a cost if you are actually cooking.
  double get effectiveKitchenCost => isSelfCooking ? campKitchenCost : 0;

  TripConfig copyWith({
    String? originName,
    double? originLat,
    double? originLng,
    List<TripStop>? stops,
    DateTime? startDate,
    int? days,
    int? persons,
    TravelMode? mode,
    String? vehicleId,
    double? mileage,
    double? fuelPrice,
    FuelKind? fuel,
    double? publicRatePerKm,
    double? localTransportPerPersonDay,
    int? roomOccupancy,
    StayStyle? stayStyle,
    double? stayRatePerUnitNight,
    FoodStyle? foodStyle,
    double? pricePerMeal,
    int? mealsPerDay,
    double? campKitchenCost,
    bool? fuelPriceIsDefault,
    double? bufferPercent,
    double? tollsAndParking,
  }) =>
      TripConfig(
        originName: originName ?? this.originName,
        originLat: originLat ?? this.originLat,
        originLng: originLng ?? this.originLng,
        stops: stops ?? this.stops,
        startDate: startDate ?? this.startDate,
        days: days ?? this.days,
        persons: persons ?? this.persons,
        mode: mode ?? this.mode,
        vehicleId: vehicleId ?? this.vehicleId,
        mileage: mileage ?? this.mileage,
        fuelPrice: fuelPrice ?? this.fuelPrice,
        fuel: fuel ?? this.fuel,
        publicRatePerKm: publicRatePerKm ?? this.publicRatePerKm,
        localTransportPerPersonDay:
            localTransportPerPersonDay ?? this.localTransportPerPersonDay,
        roomOccupancy: roomOccupancy ?? this.roomOccupancy,
        stayStyle: stayStyle ?? this.stayStyle,
        stayRatePerUnitNight: stayRatePerUnitNight ?? this.stayRatePerUnitNight,
        foodStyle: foodStyle ?? this.foodStyle,
        pricePerMeal: pricePerMeal ?? this.pricePerMeal,
        mealsPerDay: mealsPerDay ?? this.mealsPerDay,
        campKitchenCost: campKitchenCost ?? this.campKitchenCost,
        fuelPriceIsDefault: fuelPriceIsDefault ?? this.fuelPriceIsDefault,
        bufferPercent: bufferPercent ?? this.bufferPercent,
        tollsAndParking: tollsAndParking ?? this.tollsAndParking,
      );

  Map<String, dynamic> toJson() => {
        'originName': originName,
        'originLat': originLat,
        'originLng': originLng,
        'stops': stops.map((s) => s.toJson()).toList(),
        'startDate': startDate.toIso8601String(),
        'days': days,
        'persons': persons,
        'mode': mode.name,
        'vehicleId': vehicleId,
        'mileage': mileage,
        'fuelPrice': fuelPrice,
        'fuel': fuel.name,
        'publicRatePerKm': publicRatePerKm,
        'localTransportPerPersonDay': localTransportPerPersonDay,
        'roomOccupancy': roomOccupancy,
        'stayStyle': stayStyle.name,
        'stayRatePerUnitNight': stayRatePerUnitNight,
        'foodStyle': foodStyle.name,
        'pricePerMeal': pricePerMeal,
        'mealsPerDay': mealsPerDay,
        'campKitchenCost': campKitchenCost,
        'fuelPriceIsDefault': fuelPriceIsDefault,
        'bufferPercent': bufferPercent,
        'tollsAndParking': tollsAndParking,
      };

  factory TripConfig.fromJson(Map<String, dynamic> j) => TripConfig(
        originName: (j['originName'] as String?) ?? 'Your location',
        originLat: (j['originLat'] as num).toDouble(),
        originLng: (j['originLng'] as num).toDouble(),
        stops: _stopsFromJson(j),
        startDate: DateTime.parse(j['startDate'] as String),
        days: (j['days'] as num).toInt(),
        persons: (j['persons'] as num).toInt(),
        mode: TravelMode.byName(j['mode'] as String?),
        vehicleId: (j['vehicleId'] as String?) ?? 'sedan',
        mileage: (j['mileage'] as num).toDouble(),
        fuelPrice: (j['fuelPrice'] as num).toDouble(),
        fuel: FuelKind.byName(j['fuel'] as String?),
        publicRatePerKm: (j['publicRatePerKm'] as num?)?.toDouble() ?? 5,
        localTransportPerPersonDay:
            (j['localTransportPerPersonDay'] as num?)?.toDouble() ?? 800,
        roomOccupancy: (j['roomOccupancy'] as num?)?.toInt() ?? 2,

        // Stay and food were three-step tiers before tents and cooking existed.
        // A trip saved under that schema has to keep opening, so the old keys
        // are read when the new ones are absent.
        stayStyle: j['stayStyle'] != null
            ? StayStyle.byName(j['stayStyle'] as String?)
            : StayStyle.fromLegacyTier(j['stayTier'] as String?),
        stayRatePerUnitNight: (j['stayRatePerUnitNight'] as num?)?.toDouble() ??
            (j['stayRatePerRoomNight'] as num?)?.toDouble() ??
            StayStyle.hotel.defaultRatePerUnitNight,
        foodStyle: j['foodStyle'] != null
            ? FoodStyle.byName(j['foodStyle'] as String?)
            : FoodStyle.fromLegacyTier(j['mealTier'] as String?),
        mealsPerDay: (j['mealsPerDay'] as num?)?.toInt() ?? 3,
        // The old schema stored a daily food figure. Three meals a day is the
        // assumption it was written under, so dividing by three recovers a
        // per-meal price that reproduces the same total.
        pricePerMeal: (j['pricePerMeal'] as num?)?.toDouble() ??
            ((j['mealRatePerPersonDay'] as num?)?.toDouble() ?? 2800) / 3,
        campKitchenCost: (j['campKitchenCost'] as num?)?.toDouble() ?? 0,
        fuelPriceIsDefault: (j['fuelPriceIsDefault'] as bool?) ?? false,

        bufferPercent: (j['bufferPercent'] as num?)?.toDouble() ?? 10,
        tollsAndParking: (j['tollsAndParking'] as num?)?.toDouble() ?? 0,
      );

  /// Reads the stop list, falling back to the single-destination schema.
  ///
  /// Trips saved before a trip could have more than one stop wrote a lone
  /// `destination` with a flat `selectedAttractions`. Those become a one-stop
  /// route holding every night, which costs out to exactly what it did before.
  static List<TripStop> _stopsFromJson(Map<String, dynamic> j) {
    final raw = j['stops'] as List?;
    if (raw != null && raw.isNotEmpty) {
      return raw
          .map((e) => TripStop.fromJson(e as Map<String, dynamic>))
          .toList(growable: false);
    }

    final days = (j['days'] as num?)?.toInt() ?? 1;
    return [
      TripStop(
        destination: Destination.fromJson(j['destination'] as Map<String, dynamic>),
        nights: days > 1 ? days - 1 : 0,
        selectedAttractions: ((j['selectedAttractions'] as List?) ?? const [])
            .map((e) => Attraction.fromJson(e as Map<String, dynamic>))
            .toList(growable: false),
      ),
    ];
  }
}
