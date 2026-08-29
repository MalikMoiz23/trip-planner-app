import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../core/app_constants.dart';
import '../../core/geo.dart';
import '../../core/theme.dart';
import '../../models/attraction.dart';

/// OpenStreetMap view of the trip: the routed line out to the base town, the
/// base itself, and a pin per chosen stop.
///
/// Tiles come from the public OSM tile servers, which are free but require
/// attribution and a real User-Agent — both are set here.
class TripMap extends StatefulWidget {
  const TripMap({
    super.key,
    required this.origin,
    required this.originLabel,
    required this.destination,
    required this.destinationLabel,
    required this.category,
    this.routePoints = const [],
    this.stops = const [],
    this.interactive = true,
    this.showAttribution = true,
  });

  final LatLng? origin;
  final String originLabel;
  final LatLng destination;
  final String destinationLabel;
  final String category;
  final List<LatLng> routePoints;
  final List<Attraction> stops;
  final bool interactive;
  final bool showAttribution;

  @override
  State<TripMap> createState() => _TripMapState();
}

class _TripMapState extends State<TripMap> {
  final MapController _controller = MapController();
  bool _ready = false;

  List<LatLng> get _allPoints => [
        if (widget.origin != null) widget.origin!,
        widget.destination,
        ...widget.routePoints,
        ...widget.stops.map((s) => s.point),
      ];

  void _fit() {
    final points = _allPoints;
    if (points.length < 2) return;
    _controller.fitCamera(
      CameraFit.coordinates(
        coordinates: points,
        padding: const EdgeInsets.all(44),
        maxZoom: 12,
      ),
    );
  }

  @override
  void didUpdateWidget(covariant TripMap old) {
    super.didUpdateWidget(old);
    if (_ready &&
        (old.routePoints.length != widget.routePoints.length ||
            old.stops.length != widget.stops.length ||
            old.destination != widget.destination)) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _fit());
    }
  }

  @override
  Widget build(BuildContext context) {
    final line = widget.routePoints.isNotEmpty
        ? widget.routePoints
        : (widget.origin == null ? const <LatLng>[] : [widget.origin!, widget.destination]);

    return FlutterMap(
      mapController: _controller,
      options: MapOptions(
        initialCenter: centroid(_allPoints),
        initialZoom: 7,
        minZoom: 3,
        maxZoom: 17,
        backgroundColor: context.palette.canvas,
        interactionOptions: InteractionOptions(
          flags: widget.interactive
              ? InteractiveFlag.all & ~InteractiveFlag.rotate
              : InteractiveFlag.none,
        ),
        onMapReady: () {
          _ready = true;
          _fit();
        },
      ),
      children: [
        TileLayer(
          urlTemplate: Endpoints.tileUrl,
          userAgentPackageName: Endpoints.tilePackageName,
          maxNativeZoom: 19,
        ),
        if (line.length >= 2)
          PolylineLayer(
            polylines: [
              // A white casing under the route keeps it readable over both the
              // pale plains and the dark hill shading in the OSM raster.
              Polyline(points: line, strokeWidth: 7, color: Colors.white.withValues(alpha: 0.9)),
              Polyline(points: line, strokeWidth: 3.5, color: context.palette.series[0]),
            ],
          ),
        MarkerLayer(
          markers: [
            if (widget.origin != null)
              Marker(
                point: widget.origin!,
                width: 132,
                height: 54,
                alignment: Alignment.topCenter,
                child: _Pin(
                  label: widget.originLabel,
                  icon: Icons.trip_origin_rounded,
                  color: context.palette.ink,
                ),
              ),
            // Stop names are suppressed on the non-interactive preview: half a
            // dozen day trips out of one base town pile their labels on top of
            // each other at that zoom. The full-screen map keeps them.
            for (final stop in widget.stops)
              Marker(
                point: stop.point,
                width: widget.interactive ? 132 : 30,
                height: widget.interactive ? 54 : 30,
                alignment: widget.interactive ? Alignment.topCenter : Alignment.center,
                child: _Pin(
                  label: widget.interactive ? stop.name : null,
                  icon: AppColors.iconFor(stop.category),
                  color: AppColors.accent,
                  small: true,
                ),
              ),
            Marker(
              point: widget.destination,
              width: 150,
              height: 54,
              alignment: Alignment.topCenter,
              child: _Pin(
                label: widget.destinationLabel,
                icon: AppColors.iconFor(widget.category),
                color: context.palette.primary,
              ),
            ),
          ],
        ),
        if (widget.showAttribution)
          const RichAttributionWidget(
            alignment: AttributionAlignment.bottomLeft,
            showFlutterMapAttribution: false,
            attributions: [
              TextSourceAttribution('OpenStreetMap contributors', prependCopyright: true),
            ],
          ),
      ],
    );
  }
}

class _Pin extends StatelessWidget {
  const _Pin({
    required this.label,
    required this.icon,
    required this.color,
    this.small = false,
  });

  /// Null renders the dot on its own, for zoom levels where a caption would
  /// collide with its neighbours.
  final String? label;
  final IconData icon;
  final Color color;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final size = small ? 26.0 : 32.0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: context.palette.shadowCard,
          ),
          child: Icon(icon, size: small ? 13 : 16, color: Colors.white),
        ),
        if (label != null) ...[
          const SizedBox(height: 3),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: AppRadius.sm,
                boxShadow: context.palette.shadowCard,
              ),
              child: Text(
                label!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: small ? 10 : 11,
                  fontWeight: FontWeight.w700,
                  color: context.palette.ink,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
