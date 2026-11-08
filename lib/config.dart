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

  /// On Android the Turnstile widget runs in a WebView that pretends to be this page; the
  /// hostname must be listed in the Turnstile widget's domains in the Cloudflare dashboard.
  static const turnstileBaseUrl = 'https://globly.dagnis.my.id/';

  /// Must match the Android applicationId; sent to the OSM tile server.
  static const userAgentPackageName = 'com.globly.globly';

  /// MapTiler API key for map tiles. Map keys are always visible to app users; this one is
  /// restricted to *.dagnis.my.id in the MapTiler dashboard (Allowed HTTP origins), and the
  /// Android app sends globly.dagnis.my.id as Referer (see widgets/map_tiles.dart).
  /// Override with --dart-define=MAPTILER_KEY=... ; empty = fall back to OpenStreetMap tiles.
  static const mapTilerKey = String.fromEnvironment('MAPTILER_KEY', defaultValue: 'YYYNnzxWYFehPRSPcF8R');

  /// Sent as Referer by the Android app; must match the key's allowed origins (*.dagnis.my.id).
  static const mapTilerReferer = 'https://globly.dagnis.my.id/';

  /// OpenStreetMap's public tiles: fallback for development only (not allowed for production traffic).
  static const osmTileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
}
