import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:globly/l10n/app_localizations.dart';
import 'package:globly/models/models.dart';
import 'package:globly/widgets/media_view.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

class _FakePlayer extends VideoPlayerPlatform with MockPlatformInterfaceMixin {
  final calls = <String>[];
  final _events = StreamController<VideoEvent>();

  @override
  Future<void> init() async {}

  @override
  Future<void> dispose(int playerId) async {}

  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async {
    _events.add(VideoEvent(
      eventType: VideoEventType.initialized,
      duration: const Duration(seconds: 10),
      size: const Size(160, 90),
    ));
    return 1;
  }

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) => _events.stream;

  @override
  Future<void> setLooping(int playerId, bool looping) async {}

  @override
  Future<void> play(int playerId) async => calls.add('play');

  @override
  Future<void> pause(int playerId) async => calls.add('pause');

  @override
  Future<void> setVolume(int playerId, double volume) async {}

  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {}

  @override
  Future<void> seekTo(int playerId, Duration position) async {}

  @override
  Future<Duration> getPosition(int playerId) async => Duration.zero;

  @override
  Future<void> setMixWithOthers(bool mixWithOthers) async {}

  @override
  // A real platform view, as on web: it enters the gesture arena and takes touches.
  Widget buildViewWithOptions(VideoViewOptions options) => PlatformViewSurface(
        controller: _FakePlatformViewController(),
        hitTestBehavior: PlatformViewHitTestBehavior.opaque,
        gestureRecognizers: const {},
      );
}

class _FakePlatformViewController extends PlatformViewController {
  @override
  int get viewId => 0;

  @override
  Future<void> clearFocus() async {}

  @override
  Future<void> dispatchPointerEvent(PointerEvent event) async {}

  @override
  Future<void> dispose() async {}
}

void main() {
  testWidgets('tapping the play icon starts the video, and tapping the video pauses it', (tester) async {
    final player = _FakePlayer();
    VideoPlayerPlatform.instance = player;

    final post = Post(
      id: '1',
      author: const Author('a', 'liga'),
      title: 'Video',
      description: null,
      mediaType: MediaType.video,
      media: const Media('https://example.com/video.mp4', 'video/mp4', 1),
      latitude: 0,
      longitude: 0,
      views: 0,
      upvotes: 0,
      downvotes: 0,
      commentCount: 0,
      myVote: 0,
      reportCount: 0,
      isHidden: false,
      hiddenReason: HiddenReason.none,
      createdAt: DateTime(2026),
      updatedAt: null,
    );

    await tester.pumpWidget(MaterialApp(
      locale: const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Scaffold(body: Center(child: SizedBox(width: 320, child: MediaView(post: post)))),
    ));
    await tester.pump();
    await tester.pump();
    await tester.pump();

    final icon = find.byIcon(Icons.play_circle_fill);
    expect(icon, findsOneWidget);
    player.calls.clear(); // The player sends a "pause" of its own while starting up.

    await tester.tapAt(tester.getCenter(icon));
    await tester.pump();
    expect(player.calls, ['play']);
    expect(icon, findsNothing);

    // Same spot, now playing.
    await tester.tapAt(tester.getCenter(find.byType(MediaView)));
    await tester.pump();
    expect(player.calls, ['play', 'pause']);
    expect(icon, findsOneWidget);
  });
}
