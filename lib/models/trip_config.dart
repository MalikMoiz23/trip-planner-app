import 'package:latlong2/latlong.dart';

import '../core/enums.dart';
import 'attraction.dart';
import 'destination.dart';

/// Every input the cost engine reads. Held immutably so a saved trip re-opens
/// with exactly the assumptions it was calculated under, even if the user has
/// since changed the app-wide fuel price.
class TripConfig {
  const TripConfig({
    required this.originName,
    required this.originLat,
    required this.originLng,
    required this.destination,
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
    required this.stayTier,
    required this.stayRatePerRoomNight,
    required this.mealTier,
    required this.mealRatePerPersonDay,
    required this.selectedAttractions,
    required this.bufferPercent,
    required this.tollsAndParking,
  });

  final String originName;
  final double originLat;
  final double originLng;
  final Destination destination;

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

  final int roomOccupancy;
  final StayTier stayTier;
  final double stayRatePerRoomNight;
  final MealTier mealTier;
  final double mealRatePerPersonDay;

  final List<Attraction> selectedAttractions;
  final double bufferPercent;
  final double tollsAndParking;

  LatLng get origin => LatLng(originLat, originLng);

  int get nights => days > 1 ? days - 1 : 0;

  int get rooms => persons <= 0 ? 0 : (persons / roomOccupancy).ceil();

  DateTime get endDate => startDate.add(Duration(days: days - 1));

  bool get isSelfDriving => mode == TravelMode.ownVehicle;

  TripConfig copyWith({
    String? originName,
    double? originLat,
    double? originLng,
    Destination? destination,
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
    StayTier? stayTier,
    double? stayRatePerRoomNight,
    MealTier? mealTier,
    double? mealRatePerPersonDay,
    List<Attraction>? selectedAttractions,
    double? bufferPercent,
    double? tollsAndParking,
  }) =>
      TripConfig(
        originName: originName ?? this.originName,
        originLat: originLat ?? this.originLat,
        originLng: originLng ?? this.originLng,
        destination: destination ?? this.destination,
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
        stayTier: stayTier ?? this.stayTier,
        stayRatePerRoomNight: stayRatePerRoomNight ?? this.stayRatePerRoomNight,
        mealTier: mealTier ?? this.mealTier,
        mealRatePerPersonDay: mealRatePerPersonDay ?? this.mealRatePerPersonDay,
        selectedAttractions: selectedAttractions ?? this.selectedAttractions,
        bufferPercent: bufferPercent ?? this.bufferPercent,
        tollsAndParking: tollsAndParking ?? this.tollsAndParking,
      );

  Map<String, dynamic> toJson() => {
        'originName': originName,
        'originLat': originLat,
        'originLng': originLng,
        'destination': destination.toJson(),
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
        'stayTier': stayTier.name,
        'stayRatePerRoomNight': stayRatePerRoomNight,
        'mealTier': mealTier.name,
        'mealRatePerPersonDay': mealRatePerPersonDay,
        'selectedAttractions': selectedAttractions.map((a) => a.toJson()).toList(),
        'bufferPercent': bufferPercent,
        'tollsAndParking': tollsAndParking,
      };

  factory TripConfig.fromJson(Map<String, dynamic> j) => TripConfig(
        originName: (j['originName'] as String?) ?? 'Your location',
        originLat: (j['originLat'] as num).toDouble(),
        originLng: (j['originLng'] as num).toDouble(),
        destination: Destination.fromJson(j['destination'] as Map<String, dynamic>),
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
        stayTier: StayTier.byName(j['stayTier'] as String?),
        stayRatePerRoomNight: (j['stayRatePerRoomNight'] as num).toDouble(),
        mealTier: MealTier.byName(j['mealTier'] as String?),
        mealRatePerPersonDay: (j['mealRatePerPersonDay'] as num).toDouble(),
        selectedAttractions: ((j['selectedAttractions'] as List?) ?? const [])
            .map((e) => Attraction.fromJson(e as Map<String, dynamic>))
            .toList(growable: false),
        bufferPercent: (j['bufferPercent'] as num?)?.toDouble() ?? 10,
        tollsAndParking: (j['tollsAndParking'] as num?)?.toDouble() ?? 0,
      );
}
