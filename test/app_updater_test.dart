import 'package:flutter_test/flutter_test.dart';
import 'package:globly/update/app_updater.dart';

Map<String, dynamic> release(String tag, List<String> assetNames) => {
      'tag_name': tag,
      'assets': [
        for (final name in assetNames)
          {'name': name, 'browser_download_url': 'https://github.com/x/releases/download/$tag/$name'},
      ],
    };

void main() {
  group('compareVersions', () {
    test('compares numerically, not as text', () {
      expect(compareVersions('v0.1.10', '0.1.9'), greaterThan(0));
      expect(compareVersions('0.2.0', '0.10.0'), lessThan(0));
    });

    test('ignores the v prefix and build number', () {
      expect(compareVersions('v0.1.1', '0.1.1+7'), 0);
    });

    test('treats missing parts as zero', () {
      expect(compareVersions('1.0', '1.0.0'), 0);
      expect(compareVersions('1.0.1', '1'), greaterThan(0));
    });
  });

  group('parseRelease', () {
    test('returns the APK of a newer release', () {
      final update = parseRelease(release('v0.2.0', ['notes.txt', 'globly-v0.2.0.apk']), '0.1.0');
      expect(update, isNotNull);
      expect(update!.version, '0.2.0');
      expect(update.currentVersion, '0.1.0');
      expect(update.apkName, 'globly-v0.2.0.apk');
      expect(update.apkUrl, endsWith('/globly-v0.2.0.apk'));
    });

    test('returns null for the same or an older release', () {
      expect(parseRelease(release('v0.1.0', ['globly-v0.1.0.apk']), '0.1.0'), isNull);
      expect(parseRelease(release('v0.0.9', ['globly-v0.0.9.apk']), '0.1.0'), isNull);
    });

    test('returns null when the release has no APK', () {
      expect(parseRelease(release('v0.2.0', ['source.zip']), '0.1.0'), isNull);
    });

    test('returns null for unexpected JSON', () {
      expect(parseRelease(const {}, '0.1.0'), isNull);
      expect(parseRelease(const {'tag_name': 'v0.2.0', 'assets': 'nope'}, '0.1.0'), isNull);
    });
  });
}
