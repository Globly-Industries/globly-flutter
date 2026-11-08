import 'dart:convert';

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:globly/models/models.dart';
import 'package:globly/widgets/map_geo.dart';

void main() {
  List<MapQuery> queries(double west, double east, {double zoom = 8, bool infinite = false}) =>
      mapQueries(south: 10, west: west, north: 20, east: east, zoom: zoom, infinite: infinite);

  group('mapQueries', () {
    test('a normal view is one box with the same zoom', () {
      final q = queries(5, 15).single;
      expect([q.minLat, q.minLng, q.maxLat, q.maxLng, q.zoom], [10, 5, 20, 15, 8]);
    });

    test('a view crossing the 180° meridian becomes one box on each side', () {
      final q = queries(170, -170);
      expect(q, hasLength(2));
      expect([q[0].minLng, q[0].maxLng], [170, 180]);
      expect([q[1].minLng, q[1].maxLng], [-180, -170]);
      expect(q.every((b) => b.minLat == 10 && b.maxLat == 20), isTrue);
    });

    test('unwrapped longitudes past 180° also split at the meridian', () {
      final q = queries(170, 190);
      expect(q, hasLength(2));
      expect([q[0].minLng, q[0].maxLng], [170, 180]);
      expect([q[1].minLng, q[1].maxLng], [-180, -170]);
    });

    test('exactly 180° stays on its own side', () {
      final q = queries(170, 180).single;
      expect([q.minLng, q.maxLng], [170, 180]);
    });

    test('a view wider than the world covers all longitudes but keeps its latitudes', () {
      final q = queries(-200, 200).single;
      expect([q.minLat, q.minLng, q.maxLat, q.maxLng], [10, -180, 20, 180]);
    });

    test('a zoomed out globe or infinite bounds ask for the whole world', () {
      for (final q in [queries(5, 15, zoom: 3).single, queries(5, 15, infinite: true).single]) {
        expect([q.minLat, q.minLng, q.maxLat, q.maxLng], [-90, -180, 90, 180]);
      }
    });
  });

  group('GeoJSON', () {
    const cluster = MapPoint(1, 2, 1500, null, null, null);
    const pin = MapPoint(3, 4, 1, 'post-1', MediaType.video, 'Title');
    const approximate = MapPoint(5, 6, 1, 'post-2', MediaType.image, 'Title', 1000);

    List<dynamic> pointFeatures(List<MapPoint> points) => (jsonDecode(
          pointsGeoJson(points, clusterColor: const Color(0xFF102030), clusterTextColor: const Color(0xFFFFFFFF)),
        ) as Map)['features'];

    test('coordinates are longitude first', () {
      expect(pointFeatures([pin]).single['geometry']['coordinates'], [4, 3]);
    });

    test('clusters carry their label, size and colours', () {
      final p = pointFeatures([cluster]).single['properties'];
      expect(p['kind'], 'cluster');
      expect(p['label'], '1.5k');
      expect(p['radius'], clusterDiameter(1500) / 2);
      expect(p['color'], 'rgb(16,32,48)');
      expect(p['textColor'], 'rgb(255,255,255)');
    });

    test('exact posts get a tipped pin anchored at the tip, approximate ones a round centred pin', () {
      final features = pointFeatures([pin, approximate]);
      expect(features[0]['properties']['icon'], 'globly-pin-video');
      expect(features[0]['properties']['anchor'], 'bottom');
      expect(features[1]['properties']['icon'], 'globly-pin-image-round');
      expect(features[1]['properties']['anchor'], 'center');
    });

    test('tap keys identify posts and clusters', () {
      expect(mapPointKey(pin), 'post-1');
      expect(mapPointKey(cluster), 'cluster:1.0,2.0');
    });

    test('only approximate posts get an area, as a closed ring of about the right size', () {
      final features = (jsonDecode(areasGeoJson([cluster, pin, approximate])) as Map)['features'] as List;
      final ring = features.single['geometry']['coordinates'][0] as List;

      expect(ring.first, ring.last);
      final lats = ring.map((c) => c[1] as double);
      // 1000 m is about 0.009° of latitude each way.
      expect(lats.reduce((a, b) => a > b ? a : b), closeTo(5.009, 0.001));
      expect(lats.reduce((a, b) => a < b ? a : b), closeTo(4.991, 0.001));
    });

    test('areas near a pole keep valid latitudes', () {
      const polar = MapPoint(89.999, 0, 1, 'post-3', MediaType.text, 'Title', 5000);
      final features = (jsonDecode(areasGeoJson([polar])) as Map)['features'] as List;
      final ring = features.single['geometry']['coordinates'][0] as List;
      expect(ring.every((c) => (c[1] as double) <= 90), isTrue);
    });
  });
}
