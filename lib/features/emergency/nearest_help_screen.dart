import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import 'package:trip_planner/app/app_state.dart';
import 'package:trip_planner/core/formatters.dart';
import 'package:trip_planner/core/launch.dart';
import 'package:trip_planner/core/motion.dart';
import 'package:trip_planner/core/theme.dart';
import 'package:trip_planner/data/models/help_place.dart';
import 'package:trip_planner/data/repositories/emergency_repository.dart';
import 'package:trip_planner/data/sources/location_service.dart';
import 'package:trip_planner/data/sources/overpass_service.dart';
import 'package:trip_planner/shared/widgets/primitives.dart';

/// Nearest pump, hospital, police station or workshop.
///
/// The one part of the emergency feature that needs a signal, and it is honest
/// about that at every step: which figures are road distances and which are
/// straight lines, and when the list came from the app's own towns because
/// OpenStreetMap could not be reached.
class NearestHelpScreen extends StatefulWidget {
  const NearestHelpScreen({super.key, required this.kind});

  final HelpKind kind;

  @override
  State<NearestHelpScreen> createState() => _NearestHelpScreenState();
}

class _NearestHelpScreenState extends State<NearestHelpScreen> {
  final LocationService _location = LocationService();
  final EmergencyRepository _repo = EmergencyRepository();

  LatLng? _me;
  List<HelpPlace> _results = const [];
  String _status = 'Getting your location…';
  String? _error;
  bool _busy = true;

  @override
  void initState() {
    super.initState();
    _find();
  }

  Future<void> _find() async {
    setState(() {
      _busy = true;
      _error = null;
      _status = 'Getting your location…';
    });

    LatLng here;
    try {
      here = (await _location.current()).point;
    } on LocationFailure catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.message;
      });
      return;
    }

    if (!mounted) return;
    setState(() {
      _me = here;
      _status = 'Looking for the nearest ${widget.kind.label.toLowerCase()}…';
    });

    final catalogue = context.read<AppState>().repository.towns;
    final found = await _repo.nearest(here, widget.kind, catalogue: catalogue);

    if (!mounted) return;
    setState(() {
      _busy = false;
      _results = found;
    });
  }

  String get _coords => _me == null
      ? ''
      : '${_me!.latitude.toStringAsFixed(5)}, ${_me!.longitude.toStringAsFixed(5)}';

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final theme = Theme.of(context);
    final offline = _results.isNotEmpty && _results.first.fromCatalogue;

    return Scaffold(
      backgroundColor: p.canvas,
      appBar: AppBar(
        title: Text('Nearest ${widget.kind.label.toLowerCase()}'),
        backgroundColor: const Color(0xFFD03B3B),
        foregroundColor: Colors.white,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _busy ? null : _find,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Search again',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          // ---- Where you are -------------------------------------------------
          if (_me != null) ...[
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('You are here', style: theme.textTheme.titleSmall),
                  const SizedBox(height: 6),
                  SelectableText(
                    _coords,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'GPS works with no signal. Read this out to Rescue 1122, or '
                    'send it — a text gets through where a call will not.',
                    style: theme.textTheme.bodySmall?.copyWith(height: 1.4),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => Launch.sms(
                          'I need help. My position is $_coords. '
                          'Sent from Triplyst.',
                        ),
                        icon: const Icon(Icons.sms_rounded, size: 16),
                        label: const Text('Text my position'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () async {
                          await Clipboard.setData(ClipboardData(text: _coords));
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Position copied')),
                            );
                          }
                        },
                        icon: const Icon(Icons.copy_rounded, size: 16),
                        label: const Text('Copy'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
          ],

          // ---- States ---------------------------------------------------------
          if (_busy)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: LoadingStrip(label: _status),
            )
          else if (_error != null)
            EmptyState(
              icon: Icons.location_disabled_rounded,
              title: 'No position yet',
              message: _error!,
              action: FilledButton(onPressed: _find, child: const Text('Try again')),
            )
          else if (_results.isEmpty)
            EmptyState(
              icon: Icons.search_off_rounded,
              title: 'Nothing found nearby',
              message: 'No ${widget.kind.label.toLowerCase()} is mapped within '
                  '40 km of you, and there was no signal to look further. '
                  'Call 130 on a highway, or 1122 anywhere.',
              action: FilledButton.icon(
                onPressed: () => Launch.dial('1122'),
                icon: const Icon(Icons.phone_rounded, size: 18),
                label: const Text('Call 1122'),
              ),
            )
          else ...[
            if (offline)
              const InfoNote(
                icon: Icons.wifi_off_rounded,
                text: 'No connection, so this is the app\'s own list of towns '
                    'rather than a live map of pumps. These are real '
                    'settlements on real roads and the nearest is a good bet, '
                    'but none of them is confirmed to have one.',
              )
            else
              const InfoNote(
                icon: Icons.map_rounded,
                text: 'From OpenStreetMap. The first few carry a real road '
                    'distance; the rest are straight-line, which always '
                    'understates a mountain road.',
              ),
            const SizedBox(height: 14),
            for (var i = 0; i < _results.length; i++)
              FadeSlideIn(
                delay: Motion.of(context).stagger(i),
                child: _HelpRow(place: _results[i]),
              ),
          ],
        ],
      ),
    );
  }
}

class _HelpRow extends StatelessWidget {
  const _HelpRow({required this.place});

  final HelpPlace place;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = context.palette;

    final distance = place.isRouted
        ? '${km(place.roadKm!)} by road'
        : '${km(place.straightKm)} straight line';
    final time = place.driveTime == null ? null : durationText(place.driveTime!);

    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        onTap: () => Launch.map(
          place.point.latitude,
          place.point.longitude,
          label: place.name,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(place.name, style: theme.textTheme.titleSmall),
                  const SizedBox(height: 3),
                  Text(
                    time == null ? '$distance  ·  ${place.kind}' : '$distance  ·  $time',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Icon(Icons.directions_rounded, size: 20, color: p.primary),
          ],
        ),
      ),
    );
  }
}
