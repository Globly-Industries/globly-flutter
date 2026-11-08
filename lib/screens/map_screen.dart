import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../api/api_client.dart';
import '../models/models.dart';
import '../state/filter_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/errors.dart';
import '../widgets/filter_sheet.dart';
import '../widgets/location.dart';
import '../widgets/map_tiles.dart';
import '../widgets/post_card.dart';
import 'post_detail_screen.dart';

/// Content visualisation module: world map with server-clustered post points.
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => MapScreenState();
}

class MapScreenState extends State<MapScreen> {
  final _map = MapController();
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
    _map.dispose();
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
    final camera = _map.camera;
    final b = camera.visibleBounds;
    setState(() => _loading = true);
    try {
      final points = await context.read<ApiClient>().mapPoints(
            minLat: b.south,
            minLng: b.west,
            maxLat: b.north,
            maxLng: b.east,
            zoom: camera.zoom,
            filter: _filters.filter,
            cancelToken: token,
          );
      if (mounted && !token.isCancelled) setState(() => _points = points);
    } on DioException {
      // Cancelled because the map moved again.
    } catch (e) {
      if (mounted) showMessage(context, e);
    } finally {
      if (mounted && identical(token, _inFlight)) setState(() => _loading = false);
    }
  }

  Future<void> _goToMyLocation() async {
    try {
      final here = await currentLocation();
      _map.move(here, math.max(_map.camera.zoom, 13));
      _load();
    } catch (e) {
      if (mounted) showMessage(context, e);
    }
  }

  void _onPointTap(MapPoint p) {
    if (p.isCluster) {
      _map.move(LatLng(p.latitude, p.longitude), math.min(_map.camera.zoom + 2, 18));
      _load();
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
    final changed = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: 560),
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
        FlutterMap(
          mapController: _map,
          options: MapOptions(
            initialCenter: const LatLng(35, 15),
            initialZoom: 2.5,
            minZoom: 2,
            maxZoom: 18,
            interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
            onMapReady: () {
              _mapReady = true;
              _load();
            },
            onPositionChanged: (_, hasGesture) {
              if (hasGesture) _onMoved();
            },
          ),
          children: [
            const AppTileLayer(),
            MarkerLayer(
              markers: [
                for (final p in _points)
                  if (p.isCluster)
                    Marker(
                      point: LatLng(p.latitude, p.longitude),
                      width: _clusterSize(p.count),
                      height: _clusterSize(p.count),
                      child: GestureDetector(onTap: () => _onPointTap(p), child: _ClusterBubble(count: p.count)),
                    )
                  else
                    Marker(
                      point: LatLng(p.latitude, p.longitude),
                      width: 44,
                      height: 52,
                      alignment: Alignment.topCenter,
                      child: GestureDetector(onTap: () => _onPointTap(p), child: _PostPin(type: p.mediaType)),
                    ),
              ],
            ),
            const AppAttribution(),
          ],
        ),
        if (_loading)
          const Positioned(top: 0, left: 0, right: 0, child: LinearProgressIndicator(minHeight: 3)),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: [
                    _MapButton(
                      icon: filter.isActive ? Icons.filter_alt_rounded : Icons.tune_rounded,
                      highlighted: filter.isActive,
                      tooltip: context.l10n.filters,
                      onPressed: () => showFilterSheet(context),
                    ),
                    const SizedBox(width: 8),
                    for (final t in MediaType.values) ...[
                      _TypeChip(
                        type: t,
                        selected: filter.types.contains(t),
                        showLabel: MediaQuery.sizeOf(context).width >= 600,
                        onTap: () => _toggleType(t),
                      ),
                      const SizedBox(width: 6),
                    ],
                  ]),
                ),
              ),
              const SizedBox(width: 8),
              _MapButton(
                icon: Icons.my_location_rounded,
                tooltip: context.l10n.useMyLocation,
                onPressed: _goToMyLocation,
                color: scheme.primary,
              ),
            ]),
          ),
        ),
      ],
    );
  }

  static double _clusterSize(int count) => 40 + math.min(28, math.log(count) * 6);
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
    return Material(
      color: highlighted ? scheme.primaryContainer : scheme.surface,
      elevation: 3,
      shadowColor: Colors.black38,
      borderRadius: BorderRadius.circular(14),
      child: IconButton(
        tooltip: tooltip,
        icon: Icon(icon, color: color ?? scheme.onSurface),
        onPressed: onPressed,
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  final MediaType type;
  final bool selected;
  final bool showLabel;
  final VoidCallback onTap;
  const _TypeChip({required this.type, required this.selected, required this.showLabel, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = AppTheme.mediaColor(type);
    final label = mediaLabel(context, type);
    return Tooltip(message: label, child: Material(
      color: selected ? color : scheme.surface,
      elevation: 3,
      shadowColor: Colors.black38,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: showLabel ? 12 : 13, vertical: showLabel ? 10 : 13),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(mediaIcon(type), size: 20, color: selected ? Colors.white : color),
            if (showLabel) ...[
              const SizedBox(width: 6),
              Text(label, style: TextStyle(fontWeight: FontWeight.w600, color: selected ? Colors.white : scheme.onSurface)),
            ],
          ]),
        ),
      ),
    ));
  }
}

class _ClusterBubble extends StatelessWidget {
  final int count;
  const _ClusterBubble({required this.count});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: scheme.primary,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [BoxShadow(color: scheme.primary.withValues(alpha: 0.35), blurRadius: 10, spreadRadius: 4)],
      ),
      child: Text(
        count > 999 ? '${(count / 1000).toStringAsFixed(count < 10000 ? 1 : 0)}k' : '$count',
        style: TextStyle(color: scheme.onPrimary, fontWeight: FontWeight.w800),
      ),
    );
  }
}

/// Teardrop-style pin coloured by content type; the tip points at the location.
class _PostPin extends StatelessWidget {
  final MediaType? type;
  const _PostPin({required this.type});

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.mediaColor(type);
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: const [BoxShadow(blurRadius: 6, color: Colors.black38, offset: Offset(0, 2))],
        ),
        child: Icon(mediaIcon(type), color: Colors.white, size: 20),
      ),
      CustomPaint(size: const Size(12, 8), painter: _PinTip(color)),
    ]);
  }
}

class _PinTip extends CustomPainter {
  final Color color;
  _PinTip(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final path = ui.Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_PinTip old) => old.color != color;
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
