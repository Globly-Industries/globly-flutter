import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import '../config.dart';

/// Base map tiles: MapTiler (light/dark style following the app theme, sharp on high-DPI screens)
/// when a key is configured, otherwise OpenStreetMap's public tiles (development only).
class AppTileLayer extends StatelessWidget {
  const AppTileLayer({super.key});

  @override
  Widget build(BuildContext context) {
    if (AppConfig.mapTilerKey.isEmpty) {
      return TileLayer(urlTemplate: AppConfig.osmTileUrl, userAgentPackageName: AppConfig.userAgentPackageName);
    }
    final dark = Theme.of(context).brightness == Brightness.dark;
    final style = dark ? 'streets-v2-dark' : 'streets-v2';
    return TileLayer(
      urlTemplate: 'https://api.maptiler.com/maps/$style/256/{z}/{x}/{y}{r}.png?key=${AppConfig.mapTilerKey}',
      retinaMode: RetinaMode.isHighDensity(context),
      userAgentPackageName: AppConfig.userAgentPackageName,
      maxNativeZoom: 20,
      // Browsers send the page as Referer/Origin automatically; the Android app has to send it
      // itself, otherwise MapTiler's origin restriction on the key rejects the tiles.
      tileProvider: kIsWeb ? null : NetworkTileProvider(headers: {'Referer': AppConfig.mapTilerReferer}),
    );
  }
}

/// Required map credits ("i" button), placed bottom-left and lifted above the bottom bar.
class AppAttribution extends StatelessWidget {
  const AppAttribution({super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom),
        child: RichAttributionWidget(
          alignment: AttributionAlignment.bottomLeft,
          attributions: [
            if (AppConfig.mapTilerKey.isNotEmpty) const TextSourceAttribution('MapTiler'),
            const TextSourceAttribution('OpenStreetMap contributors'),
          ],
        ),
      );
}
