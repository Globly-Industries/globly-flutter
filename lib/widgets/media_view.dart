import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../models/models.dart';
import 'common.dart';
import 'glass.dart';

/// Plays/streams a post's media directly from Cloudflare R2.
class MediaView extends StatelessWidget {
  final Post post;
  const MediaView({super.key, required this.post});

  @override
  Widget build(BuildContext context) {
    final media = post.media;
    if (media == null) return const SizedBox.shrink();
    return switch (post.mediaType) {
      MediaType.image => InteractiveViewer(
          child: CachedNetworkImage(
            imageUrl: media.url,
            fit: BoxFit.contain,
            placeholder: (_, _) => const AspectRatio(aspectRatio: 4 / 3, child: Center(child: CircularProgressIndicator())),
            errorWidget: (_, _, _) => const AspectRatio(aspectRatio: 4 / 3, child: Center(child: Icon(Icons.broken_image))),
          ),
        ),
      MediaType.video => _VideoView(url: media.url),
      MediaType.audio => _AudioView(url: media.url),
      MediaType.text => const SizedBox.shrink(),
    };
  }
}

class _VideoView extends StatefulWidget {
  final String url;
  const _VideoView({required this.url});

  @override
  State<_VideoView> createState() => _VideoViewState();
}

class _VideoViewState extends State<_VideoView> {
  late final VideoPlayerController _controller;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..setLooping(true)
      ..initialize().then((_) {
        if (mounted) setState(() {});
      }).catchError((Object e) {
        if (mounted) setState(() => _error = e);
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _togglePlaying() {
    _controller.value.isPlaying ? _controller.pause() : _controller.play();
    setState(() {}); // The playing state changes right away; show or hide the play icon to match.
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return AspectRatio(aspectRatio: 16 / 9, child: Center(child: Text(context.l10n.couldNotLoadVideo)));
    }
    if (!_controller.value.isInitialized) {
      return const AspectRatio(aspectRatio: 16 / 9, child: Center(child: CircularProgressIndicator()));
    }
    return AspectRatio(
      aspectRatio: _controller.value.aspectRatio,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          GestureDetector(
            onTap: _togglePlaying,
            child: VideoPlayer(_controller),
          ),
          if (!_controller.value.isPlaying)
            // Only an indicator: taps on it must reach the video underneath.
            const IgnorePointer(child: Center(child: Icon(Icons.play_circle_fill, size: 64, color: Colors.white70))),
          VideoProgressIndicator(_controller, allowScrubbing: true),
        ],
      ),
    );
  }
}

class _AudioView extends StatefulWidget {
  final String url;
  const _AudioView({required this.url});

  @override
  State<_AudioView> createState() => _AudioViewState();
}

class _AudioViewState extends State<_AudioView> {
  final _player = AudioPlayer();
  final _subs = <StreamSubscription>[];
  PlayerState _state = PlayerState.stopped;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _subs.addAll([
      _player.onPlayerStateChanged.listen((s) => setState(() => _state = s)),
      _player.onPositionChanged.listen((p) => setState(() => _position = p)),
      _player.onDurationChanged.listen((d) => setState(() => _duration = d)),
    ]);
    _player.setSourceUrl(widget.url);
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _player.dispose();
    super.dispose();
  }

  String _fmt(Duration d) => '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final playing = _state == PlayerState.playing;
    final max = _duration.inMilliseconds.toDouble();
    return Container(
      color: glassTint(context),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
      child: Row(
        children: [
          IconButton.filled(
            iconSize: 32,
            icon: Icon(playing ? Icons.pause : Icons.play_arrow),
            onPressed: () => playing ? _player.pause() : _player.resume(),
          ),
          Expanded(
            child: Slider(
              value: _position.inMilliseconds.clamp(0, max <= 0 ? 0 : max).toDouble(),
              max: max <= 0 ? 1 : max,
              onChanged: max <= 0 ? null : (v) => _player.seek(Duration(milliseconds: v.round())),
            ),
          ),
          Text('${_fmt(_position)} / ${_fmt(_duration)}'),
        ],
      ),
    );
  }
}
