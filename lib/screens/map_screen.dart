import 'dart:async';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../api/api_client.dart';
import '../config.dart';
import '../models/models.dart';
import '../state/filter_state.dart';
import '../widgets/common.dart';
import '../widgets/filter_sheet.dart';
import '../widgets/location.dart';
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
    final at = LatLng(p.latitude, p.longitude);
    if (p.isCluster) {
      _map.move(at, math.min(_map.camera.zoom + 2, 18));
      _load();
    } else {
      Navigator.push(context, MaterialPageRoute(builder: (_) => PostDetailScreen(postId: p.postId!)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final filterActive = context.watch<FilterState>().filter.isActive;

    return Stack(
      children: [
        FlutterMap(
          mapController: _map,
          options: MapOptions(
            initialCenter: const LatLng(30, 10),
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
            TileLayer(
              urlTemplate: AppConfig.tileUrlTemplate,
              userAgentPackageName: AppConfig.userAgentPackageName,
            ),
            MarkerLayer(
              markers: [
                for (final p in _points)
                  Marker(
                    point: LatLng(p.latitude, p.longitude),
                    width: p.isCluster ? 48 : 40,
                    height: p.isCluster ? 48 : 40,
                    child: GestureDetector(
                      onTap: () => _onPointTap(p),
                      child: p.isCluster ? _ClusterBubble(count: p.count) : _PostPin(type: p.mediaType),
                    ),
                  ),
              ],
            ),
            RichAttributionWidget(
              attributions: [TextSourceAttribution('OpenStreetMap contributors')],
            ),
          ],
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                FloatingActionButton.small(
                  heroTag: 'filter',
                  onPressed: () => showFilterSheet(context),
                  backgroundColor: filterActive ? scheme.primaryContainer : null,
                  child: Icon(filterActive ? Icons.filter_alt : Icons.filter_alt_outlined),
                ),
                const Spacer(),
                if (_loading) const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                const SizedBox(width: 12),
                FloatingActionButton.small(
                  heroTag: 'locate',
                  onPressed: _goToMyLocation,
                  child: const Icon(Icons.my_location),
                ),
              ],
            ),
          ),
        ),
      ],
    );
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
        color: scheme.primary.withValues(alpha: 0.85),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: Text(
        count > 999 ? '${count ~/ 1000}k' : '$count',
        style: TextStyle(color: scheme.onPrimary, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _PostPin extends StatelessWidget {
  final MediaType? type;
  const _PostPin({required this.type});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        shape: BoxShape.circle,
        border: Border.all(color: scheme.primary, width: 2),
        boxShadow: const [BoxShadow(blurRadius: 4, color: Colors.black26)],
      ),
      child: Icon(mediaIcon(type), color: scheme.primary, size: 20),
    );
  }
}
