import 'package:flutter/foundation.dart';

/// App configuration, overridable at build time:
///   flutter run --dart-define=API_BASE_URL=http://192.168.1.50:5021
class AppConfig {
  /// Release builds talk to the server behind Cloudflare Tunnel; debug builds to the
  /// dev machine (10.0.2.2 is the host as seen from the Android emulator).
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: kReleaseMode
        ? 'https://api.dagnis.my.id'
        : (kIsWeb ? 'http://localhost:5021' : 'http://10.0.2.2:5021'),
  );

  /// Must match the Android applicationId; sent to the OSM tile server.
  static const userAgentPackageName = 'com.globly.globly';

  /// OpenStreetMap's public tiles are fine for development only; switch to a
  /// tile provider (MapTiler, Stadia, self-hosted...) before release.
  static const tileUrlTemplate = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
}
