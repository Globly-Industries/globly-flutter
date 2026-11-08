import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/painting.dart';

import '../models/models.dart';
import '../theme.dart';

/// Mapbox zoom levels are one lower than the server's for the same scale: the server's clustering
/// assumes 256px tiles, and Mapbox uses 512px. The app's zoom limits use the server's scale too.
const mapboxZoomOffset = 1.0;

/// Below this zoom (server scale) the globe shows so much of the world, possibly including a pole,
/// that a lat/lng box can't describe the view; ask for everything instead.
const _wholeWorldBelowZoom = 4.0;

/// One area to request from the server.
class MapQuery {
  final double minLat;
  final double minLng;
  final double maxLat;
  final double maxLng;
  final double zoom;

  const MapQuery({
    required this.minLat,
    required this.minLng,
    required this.maxLat,
    required this.maxLng,
    required this.zoom,
  });
}

/// Turns a visible area into server requests. [zoom] is on the server's scale.
///
/// The server only understands plain min/max boxes, so a view crossing the 180° meridian becomes
/// two requests, one on each side of it.
List<MapQuery> mapQueries({
  required double south,
  required double west,
  required double north,
  required double east,
  required double zoom,
  bool infinite = false,
}) {
  MapQuery box(double s, double w, double n, double e) =>
      MapQuery(minLat: s, minLng: w, maxLat: n, maxLng: e, zoom: zoom);

  if (infinite || zoom < _wholeWorldBelowZoom) return [box(-90, -180, 90, 180)];
  if (east - west >= 360) return [box(south, -180, north, 180)];

  final w = _wrapLongitude(west);
  final e = _wrapLongitude(east);
  if (w <= e) return [box(south, w, north, e)];
  return [box(south, w, north, 180), box(south, -180, north, e)];
}

double _wrapLongitude(double lng) {
  if (lng >= -180 && lng <= 180) return lng;
  return (lng + 180) % 360 - 180;
}

/// Identifies a point in the map's features, so a tap can be traced back to it.
String mapPointKey(MapPoint p) => p.postId ?? 'cluster:${p.latitude},${p.longitude}';

/// The name of the map image for a post pin. Pins without a tip mark the middle of an area.
String pinImageId(MediaType? type, {required bool tip}) => 'globly-pin-${(type ?? MediaType.text).name}${tip ? '' : '-round'}';

double clusterDiameter(int count) => 40 + math.min(28, math.log(count) * 6);

String clusterLabel(int count) => count > 999 ? '${(count / 1000).toStringAsFixed(count < 10000 ? 1 : 0)}k' : '$count';

String _cssColor(Color c) => 'rgb(${(c.r * 255).round()},${(c.g * 255).round()},${(c.b * 255).round()})';

/// GeoJSON for the clusters and pins.
String pointsGeoJson(List<MapPoint> points, {required Color clusterColor, required Color clusterTextColor}) => jsonEncode({
      'type': 'FeatureCollection',
      'features': [
        for (final p in points)
          {
            'type': 'Feature',
            'geometry': {
              'type': 'Point',
              'coordinates': [p.longitude, p.latitude],
            },
            'properties': p.isCluster
                ? {
                    'kind': 'cluster',
                    'key': mapPointKey(p),
                    'label': clusterLabel(p.count),
                    'radius': clusterDiameter(p.count) / 2,
                    'color': _cssColor(clusterColor),
                    'textColor': _cssColor(clusterTextColor),
                  }
                : {
                    'kind': 'pin',
                    'key': mapPointKey(p),
                    'icon': pinImageId(p.mediaType, tip: p.locationRadiusMeters == null),
                    'anchor': p.locationRadiusMeters == null ? 'bottom' : 'center',
                  },
          },
      ],
    });

/// GeoJSON for the areas of posts that only have an approximate location.
String areasGeoJson(List<MapPoint> points) => jsonEncode({
      'type': 'FeatureCollection',
      'features': [
        for (final p in points)
          if (!p.isCluster && p.locationRadiusMeters != null)
            {
              'type': 'Feature',
              'geometry': {
                'type': 'Polygon',
                'coordinates': [_circleRing(p.latitude, p.longitude, p.locationRadiusMeters!.toDouble())],
              },
              'properties': {'color': _cssColor(AppTheme.mediaColor(p.mediaType))},
            },
      ],
    });

/// A closed ring approximating a circle on the ground; plenty accurate at location-radius sizes.
List<List<double>> _circleRing(double lat, double lng, double meters) {
  const earthRadius = 6371000.0;
  const steps = 48;
  final dLat = (meters / earthRadius) * 180 / math.pi;
  // Avoids dividing by almost nothing right at the poles.
  final dLng = dLat / math.max(math.cos(lat * math.pi / 180), 0.01);
  return [
    for (var i = 0; i <= steps; i++)
      [
        lng + dLng * math.sin(2 * math.pi * (i % steps) / steps),
        (lat + dLat * math.cos(2 * math.pi * (i % steps) / steps)).clamp(-90.0, 90.0),
      ],
  ];
}
