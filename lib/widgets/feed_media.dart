import 'dart:async';
import 'dart:ui' as ui;

import 'package:audioplayers/audioplayers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../models/models.dart';
import '../theme.dart';
import 'common.dart';
import 'goo.dart';
import 'static_map.dart';

/// Full-screen content of one post in the immersive feed.
///
/// The feed keeps the pages next to the visible one built, so their players load ahead of time;
/// only the page with [active] set plays, and only while [playing]. Leaving a page rewinds it.
class FeedMedia extends StatelessWidget {
  final Post post;
  final bool active;
  final bool playing;
  final ValueListenable<bool> muted;

  /// Space taken by bars and overlays at the edges, which content that must stay readable avoids.
  final EdgeInsets safe;

  /// Height of the navigation bar over the bottom edge; a video's progress line sits just above it.
  final double barBottom;

  const FeedMedia({
    super.key,
    required this.post,
    required this.active,
    required this.playing,
    required this.muted,
    required this.safe,
    this.barBottom = 0,
  });

  @override
  Widget build(BuildContext context) {
    final media = post.media;
    return switch (post.mediaType) {
      MediaType.image when media != null => FeedImage(url: media.url),
      MediaType.video when media != null => FeedVideo(
        url: media.url,
        active: active,
        playing: playing,
        muted: muted,
        barBottom: barBottom,
      ),
      MediaType.audio when media != null => FeedAudio(
        post: post,
        url: media.url,
        active: active,
        playing: playing,
        muted: muted,
        safe: safe,
      ),
      _ => FeedText(post: post, safe: safe),
    };
  }
}

/// The picture shown whole, over a blurred, enlarged copy of itself instead of black bars.
class FeedImage extends StatelessWidget {
  final String url;
  const FeedImage({super.key, required this.url});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        RepaintBoundary(
          child: ClipRect(
            child: ImageFiltered(
              imageFilter: ui.ImageFilter.blur(sigmaX: 28, sigmaY: 28),
              child: CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                placeholder: (_, _) => const ColoredBox(color: Colors.black),
                errorWidget: (_, _, _) => const ColoredBox(color: Colors.black),
              ),
            ),
          ),
        ),
        const ColoredBox(color: Color(0x40000000)),
        CachedNetworkImage(
          imageUrl: url,
          fit: BoxFit.contain,
          placeholder: (_, _) => const Center(child: CircularProgressIndicator(color: Colors.white)),
          errorWidget: (_, _, _) =>
              const Center(child: Icon(Icons.broken_image_outlined, color: Colors.white70, size: 48)),
        ),
      ],
    );
  }
}

class FeedVideo extends StatefulWidget {
  final String url;
  final bool active;
  final bool playing;
  final ValueListenable<bool> muted;
  final double barBottom;

  const FeedVideo({
    super.key,
    required this.url,
    required this.active,
    required this.playing,
    required this.muted,
    this.barBottom = 0,
  });

  @override
  State<FeedVideo> createState() => _FeedVideoState();
}

class _FeedVideoState extends State<FeedVideo> {
  late final VideoPlayerController _controller;
  Object? _error;

  @override
  void initState() {
    super.initState();
    widget.muted.addListener(_applyVolume);
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    _controller.setLooping(true);
    _controller
        .initialize()
        .then((_) {
          if (!mounted) return;
          _applyVolume();
          _sync();
          setState(() {});
        })
        .catchError((Object e) {
          if (mounted) setState(() => _error = e);
        });
  }

  @override
  void didUpdateWidget(FeedVideo old) {
    super.didUpdateWidget(old);
    if (old.muted != widget.muted) {
      old.muted.removeListener(_applyVolume);
      widget.muted.addListener(_applyVolume);
      _applyVolume();
    }
    if (old.active && !widget.active && _controller.value.isInitialized) _controller.seekTo(Duration.zero);
    if (old.playing != widget.playing) _sync();
  }

  @override
  void dispose() {
    widget.muted.removeListener(_applyVolume);
    _controller.dispose();
    super.dispose();
  }

  void _applyVolume() {
    if (_controller.value.isInitialized) _controller.setVolume(widget.muted.value ? 0 : 1);
  }

  void _sync() {
    if (!_controller.value.isInitialized) return;
    widget.playing ? _controller.play() : _controller.pause();
    setState(() {}); // Show or hide the play icon.
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Center(
        child: Text(context.l10n.couldNotLoadVideo, style: const TextStyle(color: Colors.white70)),
      );
    }
    final value = _controller.value;
    if (!value.isInitialized) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }
    final size = value.size;
    // Upright videos fill the screen like the camera saw it; wide ones are shown whole.
    final upright = size.height >= size.width;
    return Stack(
      fit: StackFit.expand,
      children: [
        FittedBox(
          fit: upright ? BoxFit.cover : BoxFit.contain,
          clipBehavior: Clip.hardEdge,
          child: SizedBox(width: size.width, height: size.height, child: VideoPlayer(_controller)),
        ),
        // Over the video, so taps reach the page's gesture handling rather than the video: on web the
        // video is a platform view, which would otherwise win them.
        const ColoredBox(color: Colors.transparent),
        if (!widget.playing && widget.active)
          const Center(child: Icon(Icons.play_arrow_rounded, size: 84, color: Colors.white70)),
        Positioned(
          left: 0,
          right: 0,
          bottom: widget.barBottom,
          child: VideoProgressIndicator(
            _controller,
            allowScrubbing: false,
            padding: EdgeInsets.zero,
            colors: VideoProgressColors(
              playedColor: Colors.white,
              bufferedColor: Colors.white.withValues(alpha: 0.3),
              backgroundColor: Colors.white.withValues(alpha: 0.12),
            ),
          ),
        ),
      ],
    );
  }
}

/// A sound recording as "the sound of this place": the map around where it was recorded, with a
/// drop of liquid in the middle that comes alive while it plays.
class FeedAudio extends StatefulWidget {
  final Post post;
  final String url;
  final bool active;
  final bool playing;
  final ValueListenable<bool> muted;
  final EdgeInsets safe;

  const FeedAudio({
    super.key,
    required this.post,
    required this.url,
    required this.active,
    required this.playing,
    required this.muted,
    required this.safe,
  });

  @override
  State<FeedAudio> createState() => _FeedAudioState();
}

class _FeedAudioState extends State<FeedAudio> {
  final _player = AudioPlayer();
  final _subs = <StreamSubscription>[];
  bool _ready = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  @override
  void initState() {
    super.initState();
    widget.muted.addListener(_applyVolume);
    _subs.addAll([
      _player.onPositionChanged.listen((p) {
        if (mounted) setState(() => _position = p);
      }),
      _player.onDurationChanged.listen((d) {
        if (mounted) setState(() => _duration = d);
      }),
    ]);
    _load();
  }

  Future<void> _load() async {
    try {
      await _player.setReleaseMode(ReleaseMode.loop);
      await _player.setSourceUrl(widget.url);
      if (!mounted) return;
      _ready = true;
      _applyVolume();
      _sync();
    } catch (_) {
      // Stays silent; the page still shows the place.
    }
  }

  @override
  void didUpdateWidget(FeedAudio old) {
    super.didUpdateWidget(old);
    if (old.muted != widget.muted) {
      old.muted.removeListener(_applyVolume);
      widget.muted.addListener(_applyVolume);
      _applyVolume();
    }
    if (old.active && !widget.active && _ready) _player.seek(Duration.zero);
    if (old.playing != widget.playing) _sync();
  }

  @override
  void dispose() {
    widget.muted.removeListener(_applyVolume);
    for (final s in _subs) {
      s.cancel();
    }
    _player.dispose();
    super.dispose();
  }

  void _applyVolume() {
    if (_ready) _player.setVolume(widget.muted.value ? 0 : 1);
  }

  void _sync() {
    if (!_ready) return;
    widget.playing ? _player.resume() : _player.pause();
  }

  String _fmt(Duration d) => '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.mediaColor(MediaType.audio);
    final total = _duration.inMilliseconds;
    final progress = total <= 0 ? 0.0 : (_position.inMilliseconds / total).clamp(0.0, 1.0);

    return Stack(
      fit: StackFit.expand,
      children: [
        StaticPostMap(post: widget.post, width: 400, height: 720, marker: false),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [color.withValues(alpha: 0.35), Colors.black.withValues(alpha: 0.55)],
            ),
          ),
        ),
        Padding(
          padding: widget.safe,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GooBlob(
                  size: 150,
                  lively: widget.playing,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color.lerp(color, Colors.white, 0.25)!, color],
                  ),
                  shadowColor: color.withValues(alpha: 0.6),
                  child: Icon(
                    widget.playing ? Icons.graphic_eq_rounded : Icons.play_arrow_rounded,
                    size: 64,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: 200,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 3,
                      color: Colors.white,
                      backgroundColor: Colors.white.withValues(alpha: 0.2),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${_fmt(_position)} / ${_fmt(_duration)}',
                  style: const TextStyle(color: Colors.white70, fontFeatures: [ui.FontFeature.tabularFigures()]),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// A text post as a card of large type on a colourful background, the colour picked from the post's
/// id so it stays the same every time. Text that doesn't fit ends with "…" and a "Read more" hint.
class FeedText extends StatelessWidget {
  final Post post;
  final EdgeInsets safe;
  const FeedText({super.key, required this.post, required this.safe});

  static List<Color> _colors(String id) {
    final hue = (id.hashCode & 0x7fffffff) % 360.0;
    return [
      HSLColor.fromAHSL(1, hue, 0.55, 0.40).toColor(),
      HSLColor.fromAHSL(1, (hue + 50) % 360, 0.60, 0.24).toColor(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final body = post.description?.trim() ?? '';
    final length = post.title.length + body.length;
    final bodySize = length < 80
        ? 30.0
        : length < 200
        ? 25.0
        : length < 500
        ? 20.0
        : 17.0;
    const lineHeight = 1.3;
    final titleStyle = TextStyle(
      color: Colors.white,
      fontSize: bodySize + (body.isEmpty ? 8 : 4),
      fontWeight: FontWeight.w800,
      height: 1.2,
    );
    final bodyStyle = TextStyle(color: Colors.white.withValues(alpha: 0.92), fontSize: bodySize, height: lineHeight);

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: _colors(post.id)),
      ),
      child: Padding(
        padding: safe + const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
        child: LayoutBuilder(
          builder: (context, box) {
            final direction = Directionality.of(context);
            final title = TextPainter(
              text: TextSpan(text: post.title, style: titleStyle),
              textDirection: direction,
              maxLines: 4,
            )..layout(maxWidth: box.maxWidth);
            final titleHeight = title.height;
            title.dispose();
            // Room left for the body below the title, less the "Read more" line.
            final room = box.maxHeight - titleHeight - 16 - 32;
            final maxLines = room <= 0 ? 1 : (room / (bodySize * lineHeight)).floor().clamp(1, 1000);
            final painter = TextPainter(
              text: TextSpan(text: body, style: bodyStyle),
              textDirection: direction,
              maxLines: maxLines,
            )..layout(maxWidth: box.maxWidth);
            final cut = painter.didExceedMaxLines;
            painter.dispose();

            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(post.title, style: titleStyle, maxLines: 4, overflow: TextOverflow.ellipsis),
                  if (body.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(body, style: bodyStyle, maxLines: maxLines, overflow: TextOverflow.ellipsis),
                  ],
                  if (cut) ...[
                    const SizedBox(height: 10),
                    Text(
                      context.l10n.readMore,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
