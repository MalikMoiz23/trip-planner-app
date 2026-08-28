import 'package:latlong2/latlong.dart';

import 'attraction.dart';

class Destination {
  const Destination({
    required this.id,
    required this.name,
    required this.region,
    required this.province,
    required this.category,
    required this.lat,
    required this.lng,
    required this.altitudeM,
    required this.recommendedDays,
    required this.roadFactor,
    required this.requires4x4,
    required this.difficulty,
    required this.bestMonths,
    required this.tagline,
    required this.description,
    required this.highlights,
    required this.attractions,
    this.aliases = const [],
  });

  final String id;
  final String name;
  final String region;
  final String province;
  final String category;
  final double lat;
  final double lng;
  final int altitudeM;
  final int recommendedDays;

  /// Straight-line to road multiplier for this terrain, used only when the
  /// routing service is unreachable.
  final double roadFactor;
  final bool requires4x4;
  final String difficulty;
  final List<int> bestMonths;
  final String tagline;
  final String description;
  final List<String> highlights;
  final List<Attraction> attractions;

  /// Alternate romanisations, so search finds the place however it is spelled.
  final List<String> aliases;

  /// Name plus every alternate spelling — what fuzzy search scores against.
  List<String> get searchLabels => [name, ...aliases];

  LatLng get point => LatLng(lat, lng);

  String get subtitle => '$region, $province';

  bool inSeason(DateTime when) => bestMonths.contains(when.month);

  factory Destination.fromJson(Map<String, dynamic> j) => Destination(
        id: j['id'] as String,
        name: j['name'] as String,
        region: (j['region'] as String?) ?? '',
        province: (j['province'] as String?) ?? '',
        category: (j['category'] as String?) ?? 'Mountains',
        lat: (j['lat'] as num).toDouble(),
        lng: (j['lng'] as num).toDouble(),
        altitudeM: (j['altitudeM'] as num?)?.toInt() ?? 0,
        recommendedDays: (j['recommendedDays'] as num?)?.toInt() ?? 3,
        roadFactor: (j['roadFactor'] as num?)?.toDouble() ?? 1.45,
        requires4x4: (j['requires4x4'] as bool?) ?? false,
        difficulty: (j['difficulty'] as String?) ?? 'Easy',
        bestMonths: ((j['bestMonths'] as List?) ?? const [])
            .map((e) => (e as num).toInt())
            .toList(growable: false),
        tagline: (j['tagline'] as String?) ?? '',
        description: (j['description'] as String?) ?? '',
        highlights: ((j['highlights'] as List?) ?? const [])
            .map((e) => e as String)
            .toList(growable: false),
        attractions: ((j['attractions'] as List?) ?? const [])
            .map((e) => Attraction.fromJson(e as Map<String, dynamic>))
            .toList(growable: false),
        aliases: ((j['aliases'] as List?) ?? const [])
            .map((e) => e as String)
            .toList(growable: false),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'region': region,
        'province': province,
        'category': category,
        'lat': lat,
        'lng': lng,
        'altitudeM': altitudeM,
        'recommendedDays': recommendedDays,
        'roadFactor': roadFactor,
        'requires4x4': requires4x4,
        'difficulty': difficulty,
        'bestMonths': bestMonths,
        'tagline': tagline,
        'description': description,
        'highlights': highlights,
        'attractions': attractions.map((a) => a.toJson()).toList(),
        'aliases': aliases,
      };

  /// Builds a destination out of a free-text geocoder hit, so a place that is
  /// not in the bundled dataset can still be planned for.
  factory Destination.fromGeocode({
    required String id,
    required String name,
    required String region,
    required double lat,
    required double lng,
  }) =>
      Destination(
        id: id,
        name: name,
        region: region,
        province: '',
        category: 'City',
        lat: lat,
        lng: lng,
        altitudeM: 0,
        recommendedDays: 3,
        roadFactor: 1.45,
        requires4x4: false,
        difficulty: 'Unknown',
        bestMonths: const [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12],
        tagline: 'Searched location',
        description:
            'This place came from a live search rather than the built-in guide, so it '
            'carries no curated notes. Nearby stops are pulled from OpenStreetMap and '
            'priced from typical rates for that kind of place — the plan is complete, '
            'but check the figures against what you are actually quoted.',
        highlights: const [],
        attractions: const [],
      );

  Destination withAttractions(List<Attraction> list) => Destination(
        id: id,
        name: name,
        region: region,
        province: province,
        category: category,
        lat: lat,
        lng: lng,
        altitudeM: altitudeM,
        recommendedDays: recommendedDays,
        roadFactor: roadFactor,
        requires4x4: requires4x4,
        difficulty: difficulty,
        bestMonths: bestMonths,
        tagline: tagline,
        description: description,
        highlights: highlights,
        attractions: list,
        aliases: aliases,
      );
}
