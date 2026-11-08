import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart' show LatLng;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mbx;

import '../models/models.dart';
import '../theme.dart';
import 'common.dart';
import 'location.dart';
import 'map_geo.dart';

const _pointsSource = 'globly-points';
const _areasSource = 'globly-areas';
const _areaFillLayer = 'globly-area-fill';
const _areaLineLayer = 'globly-area-line';
const _clusterLayer = 'globly-clusters';
const _clusterLabelLayer = 'globly-cluster-labels';
const _pinLayer = 'globly-pins';

const _emptyGeoJson = '{"type":"FeatureCollection","features":[]}';

/// Sharpness of the pin images; the map shows them at 1/[_pinScale] of their pixel size.
const _pinScale = 3.0;

/// On loading, the map starts as a globe here. If the user's location is known, it then flies down
/// to it at [_introZoom], where the map is flat; if not, it stays on the globe.
const _introStart = LatLng(35, 15);
const _introStartZoom = 2.5 - mapboxZoomOffset;
const _introZoom = 6.0;
const _introDurationMs = 3000;

/// Layers at this strength keep their own colours; otherwise the style's night lighting darkens them.
const _selfLit = 1.0;

/// World map on Mapbox, shown as a globe when zoomed out (the Standard style's default projection).
///
/// Pins and clusters are style layers rather than Flutter widgets: widgets would have to be moved
/// by hand on every camera change, and Mapbox's annotation managers aren't implemented on web.
class MapboxPostsMap extends StatefulWidget {
  final List<MapPoint> points;
  final ValueChanged<MapPoint> onPointTap;

  /// The camera moved, by a gesture or an animation.
  final VoidCallback onMoved;

  /// The style and layers are in place, so points can be shown.
  final VoidCallback onReady;

  const MapboxPostsMap({
    super.key,
    required this.points,
    required this.onPointTap,
    required this.onMoved,
    required this.onReady,
  });

  @override
  State<MapboxPostsMap> createState() => MapboxPostsMapState();
}

class MapboxPostsMapState extends State<MapboxPostsMap> {
  mbx.MapboxMap? _map;
  bool _layersReady = false;
  double? _appliedBottomInset;

  /// Looked up early, so that it's normally known by the time the intro starts.
  final _introTarget = knownLocationWithoutAsking();

  /// Built once: the map is driven through its controller, and rebuilding the widget must not
  /// send the camera back to the initial viewport.
  late final _mapWidget = mbx.MapWidget(
    viewport: mbx.CameraViewportState(
      center: mbx.Point(coordinates: mbx.Position(_introStart.longitude, _introStart.latitude)),
      zoom: _introStartZoom,
    ),
    onMapCreated: _onMapCreated,
    onStyleLoadedListener: (_) => _onStyleLoaded(),
    onCameraChangeListener: (_) => widget.onMoved(),
    onMapLoadErrorListener: (e) => debugPrint('Mapbox load error: ${e.type} ${e.message}'),
  );

  String? _language;

  @override
  Widget build(BuildContext context) => _mapWidget;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The map's labels follow the app's language. Set before the map is first built, too.
    final language = Localizations.localeOf(context).languageCode;
    if (language != _language) {
      _language = language;
      mbx.MapboxMapsOptions.setLanguage(language);
    }
    // Also subscribes this state to theme and padding changes.
    final brightness = Theme.of(context).brightness;
    if (_layersReady) {
      _applyLightPreset(brightness);
      _pushPoints();
    }
    _applyOrnamentInsets();
  }

  @override
  void didUpdateWidget(MapboxPostsMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_layersReady && !identical(oldWidget.points, widget.points)) _pushPoints();
  }

  /// The server requests that cover the current view.
  Future<List<MapQuery>> queries() async {
    final map = _map!;
    final camera = await map.getCameraState();
    final bounds = await map.coordinateBoundsForCamera(camera.toCameraOptions());
    return mapQueries(
      south: bounds.southwest.coordinates.lat.toDouble(),
      west: bounds.southwest.coordinates.lng.toDouble(),
      north: bounds.northeast.coordinates.lat.toDouble(),
      east: bounds.northeast.coordinates.lng.toDouble(),
      zoom: camera.zoom + mapboxZoomOffset,
      infinite: bounds.infiniteBounds,
    );
  }

  /// Flies to [point], zooming in to at least a neighbourhood's scale.
  Future<void> goToLocation(LatLng point) async {
    final camera = await _map?.getCameraState();
    if (camera != null) await _flyTo(point, math.max(camera.zoom, 13 - mapboxZoomOffset));
  }

  /// Zooms in far enough that the server splits the cluster at [point].
  Future<void> zoomIntoCluster(LatLng point) async {
    final camera = await _map?.getCameraState();
    if (camera != null) await _flyTo(point, math.min(camera.zoom + 2, _maxZoom));
  }

  Future<void> _flyTo(LatLng point, double zoom, {int durationMs = 800}) async {
    await _map?.flyTo(
      mbx.CameraOptions(center: mbx.Point(coordinates: mbx.Position(point.longitude, point.latitude)), zoom: zoom),
      mbx.MapAnimationOptions(duration: durationMs),
    );
  }

  /// Flies from the globe down to the user's location, if known and the map hasn't been moved yet.
  Future<void> _playIntro() async {
    final target = await _introTarget;
    if (target == null) return;
    final camera = await _map?.getCameraState();
    if (camera == null || !mounted) return;

    final center = camera.center.coordinates;
    final untouched = (camera.zoom - _introStartZoom).abs() < 0.01 &&
        (center.lat - _introStart.latitude).abs() < 0.01 &&
        (center.lng - _introStart.longitude).abs() < 0.01;
    if (!untouched) return;

    await _flyTo(target, _introZoom, durationMs: MediaQuery.disableAnimationsOf(context) ? 0 : _introDurationMs);
  }

  static const _maxZoom = 18 - mapboxZoomOffset;

  Future<void> _onMapCreated(mbx.MapboxMap map) async {
    _map = map;
    _appliedBottomInset = null;
    _applyOrnamentInsets();
    await Future.wait([
      // A north-up map you can't tilt.
      map.gestures.updateSettings(mbx.GesturesSettings(rotateEnabled: false, pitchEnabled: false)),
      map.setBounds(mbx.CameraBoundsOptions(minZoom: 2 - mapboxZoomOffset, maxZoom: _maxZoom)),
      map.scaleBar.updateSettings(mbx.ScaleBarSettings(enabled: false)),
      map.compass.updateSettings(mbx.CompassSettings(enabled: false)),
    ]);
  }

  /// Keeps the required Mapbox logo and attribution above the bottom bar.
  void _applyOrnamentInsets() {
    final map = _map;
    if (map == null) return;
    final inset = MediaQuery.paddingOf(context).bottom;
    if (inset == _appliedBottomInset) return;
    _appliedBottomInset = inset;
    map.logo.updateSettings(mbx.LogoSettings(marginBottom: inset + 8));
    map.attribution.updateSettings(mbx.AttributionSettings(marginBottom: inset + 8));
  }

  Future<void> _onStyleLoaded() async {
    final map = _map;
    if (map == null || _layersReady) return;

    await _applyLightPreset(Theme.of(context).brightness);
    await _addPinImages(map);
    await map.addSource(mbx.GeoJsonSource(id: _areasSource, data: _emptyGeoJson));
    await map.addSource(mbx.GeoJsonSource(id: _pointsSource, data: _emptyGeoJson));

    final isCluster = <Object>['==', ['get', 'kind'], 'cluster'];
    final isPin = <Object>['==', ['get', 'kind'], 'pin'];

    await map.addLayer(mbx.FillLayer(
      id: _areaFillLayer,
      sourceId: _areasSource,
      fillColorExpression: const ['get', 'color'],
      fillOpacity: 0.16,
      fillEmissiveStrength: _selfLit,
    ));
    await map.addLayer(mbx.LineLayer(
      id: _areaLineLayer,
      sourceId: _areasSource,
      lineColorExpression: const ['get', 'color'],
      lineOpacity: 0.55,
      lineWidth: 1.5,
      lineEmissiveStrength: _selfLit,
    ));
    await map.addLayer(mbx.CircleLayer(
      id: _clusterLayer,
      sourceId: _pointsSource,
      filter: isCluster,
      circleRadiusExpression: const ['get', 'radius'],
      circleColorExpression: const ['get', 'color'],
      circleStrokeColor: Colors.white.toARGB32(),
      circleStrokeWidth: 3,
      circleEmissiveStrength: _selfLit,
    ));
    await map.addLayer(mbx.SymbolLayer(
      id: _clusterLabelLayer,
      sourceId: _pointsSource,
      filter: isCluster,
      textFieldExpression: const ['get', 'label'],
      textColorExpression: const ['get', 'textColor'],
      textFont: const ['Open Sans Bold', 'Arial Unicode MS Bold'],
      textSize: 14,
      textAllowOverlap: true,
      textIgnorePlacement: true,
      textEmissiveStrength: _selfLit,
    ));
    await map.addLayer(mbx.SymbolLayer(
      id: _pinLayer,
      sourceId: _pointsSource,
      filter: isPin,
      iconImageExpression: const ['get', 'icon'],
      iconAnchorExpression: const ['get', 'anchor'],
      iconAllowOverlap: true,
      iconIgnorePlacement: true,
      iconEmissiveStrength: _selfLit,
    ));

    for (final layerId in [_clusterLayer, _pinLayer]) {
      map.addInteraction(
        mbx.TapInteraction(mbx.FeaturesetDescriptor(layerId: layerId), (feature, _) => _onFeatureTap(feature.properties)),
        interactionID: 'tap-$layerId',
      );
    }

    if (!mounted) return;
    _layersReady = true;
    await _pushPoints();
    widget.onReady();
    await _playIntro();
  }

  void _onFeatureTap(Map<String?, Object?> properties) {
    final key = properties['key'];
    for (final point in widget.points) {
      if (mapPointKey(point) == key) {
        widget.onPointTap(point);
        return;
      }
    }
  }

  Future<void> _pushPoints() async {
    final map = _map;
    if (map == null) return;
    final scheme = Theme.of(context).colorScheme;
    final points = widget.points;
    await map.setStyleSourceProperty(_areasSource, 'data', areasGeoJson(points));
    await map.setStyleSourceProperty(
      _pointsSource,
      'data',
      pointsGeoJson(points, clusterColor: scheme.primary, clusterTextColor: scheme.onPrimary),
    );
  }

  Future<void> _applyLightPreset(Brightness brightness) async {
    await _map?.setStyleImportConfigProperty(
      'basemap',
      'lightPreset',
      brightness == Brightness.dark ? 'night' : 'day',
    );
  }

  Future<void> _addPinImages(mbx.MapboxMap map) async {
    for (final type in MediaType.values) {
      for (final tip in [true, false]) {
        await map.addImage(pinImageId(type, tip: tip), _pinScale, await _renderPin(type, tip: tip));
      }
    }
  }
}

/// Draws a post pin as an image the map can use.
Future<mbx.StyleImage> _renderPin(MediaType type, {required bool tip}) async {
  const size = 44.0;
  const tipHeight = 8.0;
  const tipWidth = 12.0;
  const center = Offset(size / 2, size / 2);
  final color = AppTheme.mediaColor(type);
  final height = tip ? size + tipHeight : size;

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder)..scale(_pinScale);

  canvas.drawCircle(
    center + const Offset(0, 1),
    20,
    Paint()
      ..color = Colors.black38
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
  );
  if (tip) {
    canvas.drawPath(
      Path()
        ..moveTo(size / 2 - tipWidth / 2, size - 3)
        ..lineTo(size / 2 + tipWidth / 2, size - 3)
        ..lineTo(size / 2, size + tipHeight - 1)
        ..close(),
      Paint()..color = color,
    );
  }
  canvas.drawCircle(center, 20, Paint()..color = Colors.white);
  canvas.drawCircle(center, 17, Paint()..color = color);

  final icon = mediaIcon(type);
  final glyph = TextPainter(
    textDirection: TextDirection.ltr,
    text: TextSpan(
      text: String.fromCharCode(icon.codePoint),
      style: TextStyle(fontFamily: icon.fontFamily, package: icon.fontPackage, fontSize: 20, color: Colors.white),
    ),
  )..layout();
  glyph.paint(canvas, center - Offset(glyph.width / 2, glyph.height / 2));
  glyph.dispose();

  final picture = recorder.endRecording();
  final image = await picture.toImage((size * _pinScale).ceil(), (height * _pinScale).ceil());
  picture.dispose();
  try {
    return await mbx.StyleImage.fromImage(image);
  } finally {
    image.dispose();
  }
}
