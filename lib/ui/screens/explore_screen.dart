import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../models/destination.dart';
import '../../services/nominatim_service.dart';
import '../../state/app_state.dart';
import '../widgets/destination_card.dart';
import '../widgets/primitives.dart';
import 'destination_detail_screen.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final TextEditingController _search = TextEditingController();
  Timer? _debounce;

  String _query = '';
  String? _category;
  List<PlaceHit> _remoteHits = const [];
  bool _searchingRemote = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    setState(() {
      _query = value;
      _remoteHits = const [];
    });
    _debounce?.cancel();
    // Nominatim's public instance asks for roughly one request per second, so
    // typing never fires a lookup directly.
    _debounce = Timer(const Duration(milliseconds: 700), () => _searchRemote(value));
  }

  Future<void> _searchRemote(String value) async {
    final app = context.read<AppState>();
    // Only reach for the network when fuzzy matching over the built-in guide
    // found nothing — most misspellings are resolved locally and instantly.
    if (value.trim().length < 3 || app.repository.hasLocalMatch(value)) return;
    setState(() => _searchingRemote = true);
    final hits = await app.repository.searchRemote(value);
    if (!mounted) return;
    setState(() {
      _remoteHits = hits;
      _searchingRemote = false;
    });
  }

  void _openDestination(Destination d) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => DestinationDetailScreen(destination: d)),
    );
  }

  void _openRemote(PlaceHit hit) {
    _openDestination(Destination.fromGeocode(
      id: hit.id,
      name: hit.name,
      region: hit.context,
      lat: hit.point.latitude,
      lng: hit.point.longitude,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final theme = Theme.of(context);

    var results = app.repository.searchRanked(_query);
    if (_category != null) {
      results = results
          .where((h) => h.destination.category == _category)
          .toList(growable: false);
    }
    final approximate = _query.trim().isNotEmpty &&
        results.isNotEmpty &&
        results.first.isApproximate;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _header(theme)),
            SliverToBoxAdapter(child: _searchBar()),
            if (_query.isEmpty) ...[
              SliverToBoxAdapter(child: _categoryChips(app)),
              if (_category == null)
                SliverToBoxAdapter(child: _featured(app)),
            ],
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              sliver: SliverToBoxAdapter(
                child: SectionHeader(
                  title: _query.isEmpty
                      ? (_category ?? 'All destinations')
                      : 'Results for "$_query"',
                  subtitle: approximate
                      ? 'Nothing spelled exactly like that — closest matches first'
                      : '${results.length} '
                          '${results.length == 1 ? 'place' : 'places'} in the built-in guide',
                  actionLabel: _category != null ? 'Clear' : null,
                  onAction: () => setState(() => _category = null),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              sliver: SliverList.separated(
                itemCount: results.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  final hit = results[i];
                  return DestinationRow(
                    destination: hit.destination,
                    matchNote: hit.matchedStop == null
                        ? null
                        : 'has ${hit.matchedStop}',
                    onTap: () => _openDestination(hit.destination),
                  );
                },
              ),
            ),
            if (_query.trim().length >= 3)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                sliver: SliverToBoxAdapter(child: _remoteSection(theme, results.isEmpty)),
              ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
              sliver: SliverToBoxAdapter(child: InfoNote(text: app.dataNote)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(ThemeData theme) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Plan the whole trip', style: theme.textTheme.headlineMedium?.copyWith(fontSize: 27)),
            const SizedBox(height: 5),
            Text(
              'Distance, fuel, hotel, food and tickets — costed per person before you go.',
              style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.inkSoft, fontSize: 14),
            ),
          ],
        ),
      );

  Widget _searchBar() => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
        child: TextField(
          controller: _search,
          onChanged: _onQueryChanged,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: 'Search Naran, Hunza, Kalash, a lake, a fort…',
            prefixIcon: const Icon(Icons.search_rounded, size: 21),
            suffixIcon: _query.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close_rounded, size: 19),
                    onPressed: () {
                      _search.clear();
                      _onQueryChanged('');
                    },
                  ),
          ),
        ),
      );

  Widget _categoryChips(AppState app) => SizedBox(
        height: 40,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: app.categories.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (context, i) {
            final category = app.categories[i];
            final selected = _category == category;
            return FilterChip(
              selected: selected,
              showCheckmark: false,
              avatar: Icon(
                AppColors.iconFor(category),
                size: 16,
                color: selected ? Colors.white : AppColors.inkSoft,
              ),
              label: Text(category),
              labelStyle: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : AppColors.ink,
              ),
              backgroundColor: Theme.of(context).cardTheme.color,
              selectedColor: AppColors.primary,
              side: BorderSide(color: selected ? AppColors.primary : AppColors.line),
              onSelected: (v) => setState(() => _category = v ? category : null),
            );
          },
        ),
      );

  Widget _featured(AppState app) => Padding(
        padding: const EdgeInsets.only(top: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 0),
              child: SectionHeader(
                title: 'Most detailed guides',
                subtitle: 'The places with the most curated stops and costs',
              ),
            ),
            SizedBox(
              height: 176,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: app.featured.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (context, i) => DestinationCard(
                  destination: app.featured[i],
                  onTap: () => _openDestination(app.featured[i]),
                ),
              ),
            ),
            const SizedBox(height: 22),
          ],
        ),
      );

  Widget _remoteSection(ThemeData theme, bool noLocalResults) {
    if (_searchingRemote) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: LoadingStrip(label: 'Searching OpenStreetMap…'),
      );
    }
    if (_remoteHits.isEmpty) {
      return noLocalResults
          ? Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Nothing in the built-in guide matches that. Live search found nothing '
                'either — try a town name.',
                style: theme.textTheme.bodySmall,
              ),
            )
          : const SizedBox.shrink();
    }

    // If the query had to be rewritten to get any hits at all, say what was
    // actually searched. Silently answering a different question is worse than
    // returning nothing.
    final via = _remoteHits.first.viaQuery;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'From OpenStreetMap',
          subtitle: via == null
              ? 'Not in the guide, so stops are priced at typical rates you can edit'
              : 'Nothing matched "$_query", so this searched for "$via" instead',
        ),
        ...(_remoteHits.map((hit) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: AppCard(
                onTap: () => _openRemote(hit),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                child: Row(
                  children: [
                    const Icon(Icons.travel_explore_rounded, size: 20, color: AppColors.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(hit.name, style: theme.textTheme.titleSmall?.copyWith(fontSize: 14)),
                          if (hit.context.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              hit.context,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(fontSize: 12),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded, color: AppColors.inkSoft),
                  ],
                ),
              ),
            ))),
      ],
    );
  }
}
