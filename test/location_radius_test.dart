import 'package:flutter_test/flutter_test.dart';
import 'package:globly/models/models.dart';
import 'package:globly/widgets/common.dart';
import 'package:globly/widgets/location.dart';

void main() {
  group('approximateRadiusMeters', () {
    test('is never below the 2 km Android blurs by', () {
      expect(approximateRadiusMeters(5), 2000);
    });

    test('follows a larger reported accuracy', () {
      expect(approximateRadiusMeters(3200.4), 3200);
    });

    test('stays within what the API accepts', () {
      expect(approximateRadiusMeters(900000), 50000);
    });
  });

  test('formatRadius', () {
    expect(formatRadius(800), '800 m');
    expect(formatRadius(2000), '2 km');
    expect(formatRadius(2500), '2.5 km');
  });

  group('API parsing', () {
    const point = {'latitude': 56.95, 'longitude': 24.1, 'count': 1, 'postId': 'p', 'mediaType': 'Image', 'title': 'T'};

    test('map points carry the radius when there is one', () {
      expect(MapPoint.fromJson({...point, 'locationRadiusMeters': 2000}).locationRadiusMeters, 2000);
    });

    test('map points are precise when the field is null or missing', () {
      expect(MapPoint.fromJson({...point, 'locationRadiusMeters': null}).locationRadiusMeters, isNull);
      expect(MapPoint.fromJson(point).locationRadiusMeters, isNull); // An API not yet updated.
    });
  });
}
