import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../config.dart';
import '../models/models.dart';
import '../theme.dart';

/// Share of the picture's width that an approximate post's area spans.
const _areaShare = 0.7;

/// Zoom at which a precise post is shown: a few streets around it.
const _preciseZoom = 13.5;

/// Zoom for a map [width] logical pixels wide around [post]: close in for a precise location, and for
/// an approximate one far enough out that its whole area fits in [_areaShare] of the width.
double staticMapZoom(Post post, double width) {
  final radius = post.locationRadiusMeters;
  if (radius == null) return _preciseZoom;
  // Static Images API tiles are 512 px: one pixel spans this many metres at zoom 0, on the equator.
  const metersPerPixelAtZoom0 = 78271.517;
  final latFactor = math.cos(post.latitude * math.pi / 180).abs().clamp(0.01, 1.0);
  final zoom = math.log(metersPerPixelAtZoom0 * latFactor * width * _areaShare / (2 * radius)) / math.ln2;
  return zoom.clamp(1.0, _preciseZoom);
}

/// URL of a still map picture centred on [post] from Mapbox's Static Images API, or null without a
/// token. One plain image per post is cheap enough for every page of the feed, unlike a live map view.
/// The marker is drawn in Flutter on top (see [StaticPostMap]), so the URL needs no overlay.
String? staticMapUrl(Post post, {required int width, required int height, double? zoom}) {
  if (AppConfig.mapboxToken.isEmpty) return null;
  final z = (zoom ?? staticMapZoom(post, width.toDouble())).toStringAsFixed(2);
  final lng = post.longitude.toStringAsFixed(5);
  final lat = post.latitude.toStringAsFixed(5);
  return 'https://api.mapbox.com/styles/v1/mapbox/dark-v11/static/$lng,$lat,$z,0/${width}x$height@2x'
      '?attribution=false&logo=false&access_token=${AppConfig.mapboxToken}';
}

/// Still map of a post's surroundings, filling its constraints, with its spot marked: a dot for a
/// precise location, the circle it lies somewhere in for an approximate one.
class StaticPostMap extends StatelessWidget {
  final Post post;

  /// Requested picture size; the API caps each side at 1280.
  final int width;
  final int height;
  final bool marker;

  const StaticPostMap({super.key, required this.post, required this.width, required this.height, this.marker = true});

  @override
  Widget build(BuildContext context) {
    final url = staticMapUrl(post, width: width, height: height);
    final color = AppTheme.mediaColor(post.mediaType);
    final fallback = ColoredBox(color: const Color(0xFF1B1F1D), child: const SizedBox.expand());
    return Stack(
      fit: StackFit.expand,
      children: [
        if (url == null)
          fallback
        else
          CachedNetworkImage(
            imageUrl: url,
            fit: BoxFit.cover,
            fadeInDuration: const Duration(milliseconds: 200),
            placeholder: (_, _) => fallback,
            errorWidget: (_, _, _) => fallback,
          ),
        if (marker)
          LayoutBuilder(
            builder: (context, box) {
              if (post.locationRadiusMeters != null) {
                // The picture's zoom was chosen so the area spans _areaShare of the requested width;
                // BoxFit.cover scales it by the larger of the two ratios.
                final scale = math.max(box.maxWidth / width, box.maxHeight / height);
                final diameter = width * _areaShare * scale;
                return Center(
                  child: Container(
                    width: diameter,
                    height: diameter,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color.withValues(alpha: 0.25),
                      border: Border.all(color: color, width: 2),
                    ),
                  ),
                );
              }
              return Center(
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color,
                    border: Border.all(color: Colors.white, width: 2.5),
                    boxShadow: [BoxShadow(color: color.withValues(alpha: 0.7), blurRadius: 10, spreadRadius: 2)],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}
