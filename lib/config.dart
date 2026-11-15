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

  /// Public Mapbox tokens. These are made to be visible to app users, so they live in the repo.
  /// The web one is URL-restricted, the mobile one can't be.
  /// Override with --dart-define=MAPBOX_TOKEN=... ; empty = no map, only a message.
  static const mapboxToken = String.fromEnvironment(
    'MAPBOX_TOKEN',
    defaultValue: kIsWeb
        ? 'pk.eyJ1IjoiZHJyZW1lc2lzIiwiYSI6ImNtd2hsdng4NTB3azUyeHIyejFzd3V1YWwifQ.vYmtTyljgTZVsoy9fjAS2g'
        : 'pk.eyJ1IjoiZHJyZW1lc2lzIiwiYSI6ImNtd2hsdW81dzE3NzkzMHM2aG9sMDVveTAifQ.OgywCTHeOm0CVdGDNyoyeQ',
  );
}
