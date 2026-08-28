import 'package:latlong2/latlong.dart';

/// A place you can bolt onto a trip. `entryFee` and `localTransport` are both
/// per person; `localTransport` covers the jeep, boat or chairlift that the
/// site needs on top of your own vehicle.
class Attraction {
  const Attraction({
    required this.id,
    required this.name,
    required this.category,
    required this.lat,
    required this.lng,
    this.description = '',
    this.entryFee = 0,
    this.localTransport = 0,
    this.visitHours = 2,
    this.requires4x4 = false,
    this.isLive = false,
  });

  final String id;
  final String name;
  final String category;
  final String description;
  final double lat;
  final double lng;
  final double entryFee;
  final double localTransport;
  final double visitHours;
  final bool requires4x4;

  /// True when the row came from a live Overpass lookup rather than the bundled
  /// dataset, which means its cost fields are placeholders.
  final bool isLive;

  LatLng get point => LatLng(lat, lng);

  double costPerPerson() => entryFee + localTransport;

  factory Attraction.fromJson(Map<String, dynamic> j) => Attraction(
        id: j['id'] as String,
        name: j['name'] as String,
        category: (j['category'] as String?) ?? 'Attraction',
        description: (j['description'] as String?) ?? '',
        lat: (j['lat'] as num).toDouble(),
        lng: (j['lng'] as num).toDouble(),
        entryFee: (j['entryFee'] as num?)?.toDouble() ?? 0,
        localTransport: (j['localTransport'] as num?)?.toDouble() ?? 0,
        visitHours: (j['visitHours'] as num?)?.toDouble() ?? 2,
        requires4x4: (j['requires4x4'] as bool?) ?? false,
        isLive: (j['isLive'] as bool?) ?? false,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'category': category,
        'description': description,
        'lat': lat,
        'lng': lng,
        'entryFee': entryFee,
        'localTransport': localTransport,
        'visitHours': visitHours,
        'requires4x4': requires4x4,
        'isLive': isLive,
      };

  Attraction copyWith({double? entryFee, double? localTransport, double? visitHours}) => Attraction(
        id: id,
        name: name,
        category: category,
        description: description,
        lat: lat,
        lng: lng,
        entryFee: entryFee ?? this.entryFee,
        localTransport: localTransport ?? this.localTransport,
        visitHours: visitHours ?? this.visitHours,
        requires4x4: requires4x4,
        isLive: isLive,
      );
}
