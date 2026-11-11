import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../api/api_client.dart';
import '../config.dart';
import '../models/models.dart';
import '../state/filter_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/errors.dart';
import '../widgets/filter_sheet.dart';
import '../widgets/glass.dart';
import '../widgets/location.dart';
import '../widgets/mapbox_posts_map.dart';
import '../widgets/post_card.dart';
import 'post_detail_screen.dart';
import 'profile_screen.dart';

/// Content visualisation module: world map with server-clustered post points.
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  /// Turned off for widget tests (see test/flutter_test_config.dart): the map is a native view.
  @visibleForTesting
  static bool showMap = AppConfig.mapboxToken.isNotEmpty;

  @override
  State<MapScreen> createState() => MapScreenState();
}

class MapScreenState extends State<MapScreen> {
  final _mapbox = GlobalKey<MapboxPostsMapState>();
  Timer? _debounce;
  CancelToken? _inFlight;
  List<MapPoint> _points = [];
  bool _loading = false;
  bool _mapReady = false;
  late final FilterState _filters;

  @override
  void initState() {
    super.initState();
    _filters = context.read<FilterState>()..addListener(refresh);
  }

  @override
  void dispose() {
    _filters.removeListener(refresh);
    _debounce?.cancel();
    _inFlight?.cancel();
    super.dispose();
  }

  void refresh() => _load();

  void _onMoved() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _load);
  }

  Future<void> _load() async {
    if (!_mapReady) return;
    _inFlight?.cancel();
    final token = _inFlight = CancelToken();
    final api = context.read<ApiClient>();
    setState(() => _loading = true);
    try {
      final queries = await _mapbox.currentState!.queries();
      if (token.isCancelled) return;
      final results = await Future.wait([
        for (final q in queries)
          api.mapPoints(
            minLat: q.minLat,
            minLng: q.minLng,
            maxLat: q.maxLat,
            maxLng: q.maxLng,
            zoom: q.zoom,
            filter: _filters.filter,
            cancelToken: token,
          ),
      ]);
      if (mounted && !token.isCancelled) setState(() => _points = [for (final r in results) ...r]);
    } on DioException {
      // Cancelled because the map moved again.
    } catch (e) {
      if (mounted) showMessage(context, e);
    } finally {
      if (mounted && identical(token, _inFlight)) setState(() => _loading = false);
    }
  }

  /// Flies to [post] and opens its preview, e.g. when it is picked from the feed.
  Future<void> showPost(Post post) async {
    await _mapbox.currentState?.goToLocation(LatLng(post.latitude, post.longitude));
    if (mounted) await _showPreview(post.id);
  }

  Future<void> _goToMyLocation() async {
    try {
      final here = await currentLocation();
      // The camera change triggers the reload.
      await _mapbox.currentState?.goToLocation(here);
    } catch (e) {
      if (mounted) showMessage(context, e);
    }
  }

  void _onPointTap(MapPoint p) {
    if (p.isCluster) {
      // The camera change triggers the reload.
      _mapbox.currentState?.zoomIntoCluster(LatLng(p.latitude, p.longitude));
    } else {
      _showPreview(p.postId!);
    }
  }

  void _toggleType(MediaType type) {
    final f = _filters.filter;
    final types = {...f.types};
    types.contains(type) ? types.remove(type) : types.add(type);
    _filters.filter = PostFilter(types: types, maxAge: f.maxAge, minScore: f.minScore);
  }

  Future<void> _showPreview(String postId) async {
    final changed = await showGlassSheet<bool>(
      context,
      builder: (sheetContext) => _PostPreview(postId: postId),
    );
    if (changed == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final filter = context.watch<FilterState>().filter;
    return Stack(
      children: [
        if (!MapScreen.showMap)
          const EmptyState(icon: Icons.map_outlined, title: 'Map unavailable: built without MAPBOX_TOKEN')
        else
          MapboxPostsMap(
            key: _mapbox,
            points: _points,
            onPointTap: _onPointTap,
            onMoved: _onMoved,
            onReady: () {
              _mapReady = true;
              _load();
            },
          ),
        if (_loading)
          const Positioned(top: 0, left: 0, right: 0, child: LinearProgressIndicator(minHeight: 3)),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _MapFilterMenu(filter: filter, onToggleType: _toggleType),
              const Spacer(),
              Column(mainAxisSize: MainAxisSize.min, children: [
                const ProfileButton(glass: true),
                const SizedBox(height: 8),
                _MapButton(
                  icon: Icons.my_location_rounded,
                  tooltip: context.l10n.useMyLocation,
                  onPressed: _goToMyLocation,
                  color: scheme.primary,
                ),
              ]),
            ]),
          ),
        ),
      ],
    );
  }
}

class _MapButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool highlighted;
  final Color? color;
  const _MapButton({required this.icon, required this.tooltip, required this.onPressed, this.highlighted = false, this.color});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GlassPanel(
      borderRadius: BorderRadius.circular(16),
      shadow: false,
      tint: highlighted ? scheme.primaryContainer.withValues(alpha: 0.6) : glassButtonTint(context),
      child: IconButton(
        tooltip: tooltip,
        icon: Icon(icon, color: color ?? scheme.onSurface),
        onPressed: onPressed,
      ),
    );
  }
}

/// The filter button, with a dropdown: quick on/off for content types, and the full filter sheet.
class _MapFilterMenu extends StatefulWidget {
  final PostFilter filter;
  final ValueChanged<MediaType> onToggleType;
  const _MapFilterMenu({required this.filter, required this.onToggleType});

  @override
  State<_MapFilterMenu> createState() => _MapFilterMenuState();
}

class _MapFilterMenuState extends State<_MapFilterMenu> {
  bool _open = false;

  void _setOpen(bool open) => setState(() => _open = open);

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final filter = widget.filter;

    return PopScope(
      // The back button closes the dropdown before it does anything else.
      canPop: !_open,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _setOpen(false);
      },
      child: TapRegion(
        onTapOutside: (_) {
          if (_open) _setOpen(false);
        },
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          _MapButton(
            icon: _open
                ? Icons.close_rounded
                : (filter.isActive ? Icons.filter_alt_rounded : Icons.tune_rounded),
            highlighted: filter.isActive,
            tooltip: l.filters,
            onPressed: () => _setOpen(!_open),
          ),
          Flexible(
            child: AnimatedSize(
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOut,
              alignment: Alignment.topLeft,
              child: !_open
                  ? const SizedBox(width: 48)
                  : Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: SizedBox(
                        width: 210,
                        child: GlassPanel(
                          borderRadius: BorderRadius.circular(20),
                          strong: true,
                          shadow: false,
                          // Scrolls on very short screens, like a phone held sideways.
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Column(mainAxisSize: MainAxisSize.min, children: [
                              for (final type in MediaType.values)
                                _FilterRow(
                                  icon: mediaIcon(type),
                                  color: AppTheme.mediaColor(type),
                                  label: mediaLabel(context, type),
                                  selected: filter.types.contains(type),
                                  onTap: () => widget.onToggleType(type),
                                ),
                              const Divider(height: 9, indent: 14, endIndent: 14),
                              _FilterRow(
                                icon: Icons.tune_rounded,
                                label: l.moreFilters,
                                trailing: Icons.chevron_right_rounded,
                                onTap: () {
                                  _setOpen(false);
                                  showFilterSheet(context);
                                },
                              ),
                            ]),
                          ),
                        ),
                      ),
                    ),
            ),
          ),
        ]),
      ),
    );
  }
}

class _FilterRow extends StatelessWidget {
  final IconData icon;
  final Color? color;
  final String label;
  final bool selected;
  final IconData? trailing;
  final VoidCallback onTap;

  const _FilterRow({
    required this.icon,
    this.color,
    required this.label,
    this.selected = false,
    this.trailing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      selected: selected,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 46,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(children: [
              Icon(icon, size: 22, color: color ?? scheme.onSurface),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: selected ? FontWeight.w700 : FontWeight.w500, color: scheme.onSurface),
                ),
              ),
              if (selected) Icon(Icons.check_rounded, size: 20, color: scheme.primary),
              if (trailing != null) Icon(trailing, size: 20, color: scheme.onSurfaceVariant),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Bottom-sheet preview of a post tapped on the map.
class _PostPreview extends StatefulWidget {
  final String postId;
  const _PostPreview({required this.postId});

  @override
  State<_PostPreview> createState() => _PostPreviewState();
}

class _PostPreviewState extends State<_PostPreview> {
  late final Future<Post> _post = context.read<ApiClient>().post(widget.postId);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: FutureBuilder<Post>(
          future: _post,
          builder: (context, snap) {
            if (snap.hasError) {
              return EmptyState(icon: Icons.error_outline_rounded, title: errorMessage(context, snap.error!));
            }
            if (!snap.hasData) {
              return const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()));
            }
            final post = snap.data!;
            return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              PostCard(post: post, compact: true),
              const SizedBox(height: 12),
              FilledButton.icon(
                icon: const Icon(Icons.open_in_full_rounded),
                label: Text(context.l10n.open),
                onPressed: () async {
                  final nav = Navigator.of(context);
                  final changed = await nav.push<bool>(
                    MaterialPageRoute(builder: (_) => PostDetailScreen(postId: post.id, initial: post)),
                  );
                  if (mounted) nav.pop(changed);
                },
              ),
            ]);
          },
        ),
      ),
    );
  }
}
