import 'package:latlong2/latlong.dart';

import 'package:trip_planner/data/models/attraction.dart';

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
    this.parentId,
    this.parentName,
    String? iconCategory,
  }) : _iconCategory = iconCategory;

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

  /// Set when this place is a single spot promoted out of a base town, rather
  /// than a town in its own right. Panj Peer Rocks is somewhere you can go on
  /// its own, so it has to be plannable on its own — but it is still worth
  /// knowing it sits near Murree.
  final String? parentId;
  final String? parentName;

  /// The stop's own category, kept for the icon. [category] is flattened to one
  /// of the canonical set so the filter chips stay a short list.
  final String? _iconCategory;

  String get iconCategory => _iconCategory ?? category;

  bool get isSpot => parentId != null;

  /// Name plus every alternate spelling — what fuzzy search scores against.
  List<String> get searchLabels => [name, ...aliases];

  LatLng get point => LatLng(lat, lng);

  String get subtitle =>
      province.isEmpty ? region : (region.isEmpty ? province : '$region, $province');

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
        parentId: j['parentId'] as String?,
        parentName: j['parentName'] as String?,
        iconCategory: j['iconCategory'] as String?,
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
        'parentId': parentId,
        'parentName': parentName,
        'iconCategory': _iconCategory,
      };

  /// Promotes a single stop to a place you can plan a trip to directly.
  ///
  /// A landmark is not only a side trip from a town: someone may drive out to
  /// Panj Peer Rocks and go nowhere else. So every stop becomes a destination
  /// whose base is the landmark itself, with the town it belongs to and that
  /// town's other stops offered as its nearby options.
  ///
  /// Derived rather than duplicated in the JSON, so there is one place to edit
  /// a fee and no chance of the two copies drifting apart.
  factory Destination.fromStop(Attraction stop, Destination parent) {
    final siblings = parent.attractions.where((a) => a.id != stop.id).toList();

    // The town itself becomes one of the options, since anyone standing at the
    // landmark is within reach of it.
    final town = Attraction(
      id: 'town-${parent.id}',
      name: parent.name,
      category: parent.category,
      lat: parent.lat,
      lng: parent.lng,
      description: parent.tagline.isEmpty
          ? 'The main town for this area.'
          : parent.tagline,
      visitHours: 3,
      aliases: parent.aliases,
    );

    return Destination(
      // Namespaced: stop ids are only unique inside their own town.
      id: '${parent.id}.${stop.id}',
      name: stop.name,
      region: 'Near ${parent.name}',
      province: parent.province,
      category: _canonicalCategory(stop.category, parent.category),
      iconCategory: stop.category,
      lat: stop.lat,
      lng: stop.lng,
      altitudeM: 0, // not recorded per stop
      // A long day out needs two days once the drive is added; the planner's
      // own suggestion refines this from the routed distance.
      recommendedDays: stop.visitHours >= 8 ? 2 : 1,
      roadFactor: parent.roadFactor,
      requires4x4: stop.requires4x4,
      difficulty: stop.requires4x4 ? 'Moderate' : parent.difficulty,
      bestMonths: parent.bestMonths,
      tagline: '${stop.category} near ${parent.name}',
      description: stop.description,
      highlights: const [],
      attractions: [town, ...siblings],
      aliases: stop.aliases,
      parentId: parent.id,
      parentName: parent.name,
    );
  }

  /// Flattens a stop's category onto the canonical set the filter chips and the
  /// gradients use, falling back to whatever the parent town is.
  static String _canonicalCategory(String stopCategory, String parentCategory) {
    switch (stopCategory) {
      case 'Lake':
      case 'Spring':
      case 'River':
      case 'Waterfall':
        return 'Lakes';
      case 'Beach':
      case 'Island':
        return 'Beaches';
      case 'Historical':
      case 'Culture':
      case 'Bazaar':
      case 'Food':
        return 'Historical';
      case 'Desert':
        return 'Desert';
      case 'Valley':
        return 'Valleys';
      default:
        return parentCategory;
    }
  }

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
        parentId: parentId,
        parentName: parentName,
        iconCategory: _iconCategory,
      );
}
