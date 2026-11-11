import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../api/api_client.dart';
import '../models/models.dart';
import '../state/auth_state.dart';
import '../theme.dart';
import 'comments_sheet.dart';
import 'common.dart';
import 'errors.dart';
import 'feed_media.dart';

/// Sound on or off across the whole feed. Browsers refuse to autoplay with sound, so web starts muted.
final feedMuted = ValueNotifier<bool>(kIsWeb);

/// Posts already counted as viewed in this session, so scrolling back doesn't count them again.
final _viewed = <String>{};

/// How long a post has to stay on screen to count as viewed.
const _viewDwell = Duration(milliseconds: 1500);

/// Height of the top bar holding the tabs and buttons.
const _topBarHeight = 56.0;

/// Dark look for the feed whatever the app theme: the content is photos, video and maps.
final _darkTheme = AppTheme.dark();

/// Full-screen feed: one post per page, swiped vertically. The page in view plays its video or sound;
/// those next to it are built too, so their media loads ahead of time, and the rest are disposed.
class ImmersiveFeed extends StatefulWidget {
  final List<Post> posts;

  /// Changes whenever the list starts over (refresh, other tab or filters); the feed then goes back to the top.
  final int generation;
  final bool loading;
  final bool hasMore;
  final Object? error;

  /// Whether the feed's tab is the one on screen.
  final bool visible;

  /// The user's position for "how far away" labels, if known.
  final LatLng? here;

  /// Tabs and buttons along the top.
  final Widget topBar;

  final Future<void> Function() onRefresh;
  final VoidCallback onLoadMore;
  final ValueChanged<Post> onPostChanged;
  final ValueChanged<Post> onOpen;
  final ValueChanged<Post>? onShowOnMap;

  const ImmersiveFeed({
    super.key,
    required this.posts,
    required this.generation,
    required this.loading,
    required this.hasMore,
    required this.error,
    required this.visible,
    required this.here,
    required this.topBar,
    required this.onRefresh,
    required this.onLoadMore,
    required this.onPostChanged,
    required this.onOpen,
    this.onShowOnMap,
  });

  @override
  State<ImmersiveFeed> createState() => _ImmersiveFeedState();
}

class _ImmersiveFeedState extends State<ImmersiveFeed> {
  final _pages = PageController();
  late final AppLifecycleListener _lifecycle;
  int _index = 0;
  bool _appVisible = true;
  Timer? _viewTimer;

  /// The post whose view is being timed, so rebuilds don't restart the clock.
  String? _viewTiming;
  bool _wheelBusy = false;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onStateChange: (state) {
        final visible = state == AppLifecycleState.resumed || state == AppLifecycleState.inactive;
        if (visible != _appVisible) setState(() => _appVisible = visible);
      },
    );
  }

  @override
  void didUpdateWidget(ImmersiveFeed old) {
    super.didUpdateWidget(old);
    if (old.generation != widget.generation) {
      _index = 0;
      if (_pages.hasClients) _pages.jumpToPage(0);
    }
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _viewTimer?.cancel();
    _pages.dispose();
    super.dispose();
  }

  /// Media may play: the feed's tab is showing, nothing covers it, and the app is in front.
  bool get _canPlay => widget.visible && _appVisible && (ModalRoute.isCurrentOf(context) ?? true);

  void _onPageChanged(int index) {
    setState(() => _index = index);
    if (index >= widget.posts.length - 3) widget.onLoadMore();
  }

  /// Counts the post in view as viewed once it has stayed there a moment. The server counts a view
  /// whenever a post is fetched on its own, so this fetches it and ignores the answer.
  void _scheduleView(Post? post, bool canPlay) {
    final timing = canPlay ? post?.id : null;
    if (timing == _viewTiming) return;
    _viewTiming = timing;
    _viewTimer?.cancel();
    if (post == null || !canPlay || _viewed.contains(post.id)) return;
    final api = context.read<ApiClient>();
    _viewTimer = Timer(_viewDwell, () {
      if (_viewed.add(post.id)) api.post(post.id).ignore();
    });
  }

  Future<void> _vote(Post post, int value) async {
    if (!context.read<AuthState>().isSignedIn) {
      showMessage(context, context.l10n.signInToRate);
      return;
    }
    final newValue = post.myVote == value ? 0 : value;
    int count(int votes, int side) => votes - (post.myVote == side ? 1 : 0) + (newValue == side ? 1 : 0);
    // Shown right away; corrected by the server's counts, or undone if it fails.
    final optimistic = post.copyWith(
      myVote: newValue,
      upvotes: count(post.upvotes, 1),
      downvotes: count(post.downvotes, -1),
    );
    widget.onPostChanged(optimistic);
    try {
      final r = await context.read<ApiClient>().vote(post.id, newValue);
      widget.onPostChanged(optimistic.copyWith(upvotes: r.upvotes, downvotes: r.downvotes, isHidden: r.hidden));
    } catch (e) {
      widget.onPostChanged(post);
      if (mounted) showMessage(context, e);
    }
  }

  void _like(Post post) {
    if (post.myVote != 1) _vote(post, 1);
  }

  void _comments(Post post) => showCommentsSheet(
    context,
    post,
    onCountChanged: (count) {
      final current = widget.posts.where((p) => p.id == post.id).firstOrNull ?? post;
      widget.onPostChanged(current.copyWith(commentCount: count));
    },
  );

  /// Mouse wheel and trackpad: one notch moves one whole page, instead of scrolling part way.
  void _onPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    GestureBinding.instance.pointerSignalResolver.register(event, (event) {
      final dy = (event as PointerScrollEvent).scrollDelta.dy;
      if (_wheelBusy || dy.abs() < 4 || !_pages.hasClients) return;
      _wheelBusy = true;
      final page = dy > 0 ? _pages.nextPage : _pages.previousPage;
      page(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      ).whenComplete(() => _wheelBusy = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final canPlay = _canPlay;
    final posts = widget.posts;
    final current = _index < posts.length ? posts[_index] : null;
    _scheduleView(current, canPlay);

    final padding = MediaQuery.paddingOf(context);
    final insets = EdgeInsets.only(top: padding.top + _topBarHeight, bottom: padding.bottom);

    final Widget content;
    if (posts.isEmpty) {
      content = _emptyOrError(context, insets);
    } else {
      final extra = widget.hasMore || widget.error != null ? 1 : 0;
      content = RefreshIndicator(
        onRefresh: widget.onRefresh,
        edgeOffset: insets.top,
        child: ScrollConfiguration(
          // Lets a mouse drag the pages too, as a finger would.
          behavior: ScrollConfiguration.of(context).copyWith(dragDevices: PointerDeviceKind.values.toSet()),
          child: PageView.builder(
            controller: _pages,
            scrollDirection: Axis.vertical,
            // Keeps the pages either side of the current one built, so their media preloads.
            allowImplicitScrolling: true,
            onPageChanged: _onPageChanged,
            itemCount: posts.length + extra,
            itemBuilder: (context, i) {
              if (i >= posts.length) return _endPage(context);
              final post = posts[i];
              return Listener(
                key: ValueKey(post.id),
                onPointerSignal: _onPointerSignal,
                child: _FeedPage(
                  post: post,
                  active: i == _index,
                  canPlay: canPlay,
                  insets: insets,
                  here: widget.here,
                  onVote: (v) => _vote(post, v),
                  onLike: () => _like(post),
                  onComments: () => _comments(post),
                  onOpen: () => widget.onOpen(post),
                  onShowOnMap: widget.onShowOnMap == null ? null : () => widget.onShowOnMap!(post),
                ),
              );
            },
          ),
        ),
      );
    }

    return Theme(
      data: _darkTheme,
      child: ColoredBox(
        color: Colors.black,
        child: Stack(
          children: [
            // On wide screens the pages keep a phone's proportions, in the middle.
            LayoutBuilder(
              builder: (context, box) {
                final maxWidth = box.maxHeight * 10 / 16;
                if (box.maxWidth <= maxWidth * 1.2) return content;
                return Center(
                  child: SizedBox(width: maxWidth, child: content),
                );
              },
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: IgnorePointer(
                child: Container(
                  height: insets.top + 24,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x99000000), Color(0x00000000)],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(top: padding.top, left: 0, right: 0, height: _topBarHeight, child: widget.topBar),
          ],
        ),
      ),
    );
  }

  Widget _emptyOrError(BuildContext context, EdgeInsets insets) {
    final l = context.l10n;
    final Widget state;
    if (widget.loading) {
      state = const Padding(
        padding: EdgeInsets.all(48),
        child: Center(child: CircularProgressIndicator()),
      );
    } else if (widget.error != null) {
      state = EmptyState(
        icon: Icons.cloud_off_rounded,
        title: errorMessage(context, widget.error!),
        action: OutlinedButton(onPressed: widget.onRefresh, child: Text(l.retry)),
      );
    } else {
      state = EmptyState(icon: Icons.explore_rounded, title: l.noPostsYet, subtitle: l.noPostsHint);
    }
    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      edgeOffset: insets.top,
      child: LayoutBuilder(
        builder: (context, box) => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(minHeight: box.maxHeight),
              child: Center(child: state),
            ),
          ],
        ),
      ),
    );
  }

  /// Last page while more posts are on the way, or when loading them failed.
  Widget _endPage(BuildContext context) {
    if (widget.error != null && !widget.loading) {
      return Center(
        child: EmptyState(
          icon: Icons.cloud_off_rounded,
          title: errorMessage(context, widget.error!),
          action: OutlinedButton(onPressed: widget.onRefresh, child: Text(context.l10n.retry)),
        ),
      );
    }
    return const Center(child: CircularProgressIndicator());
  }
}

/// One post filling the screen, with its details and buttons over it.
class _FeedPage extends StatefulWidget {
  final Post post;
  final bool active;
  final bool canPlay;

  /// Space the top bar and the bottom navigation take.
  final EdgeInsets insets;
  final LatLng? here;
  final ValueChanged<int> onVote;
  final VoidCallback onLike;
  final VoidCallback onComments;
  final VoidCallback onOpen;
  final VoidCallback? onShowOnMap;

  const _FeedPage({
    required this.post,
    required this.active,
    required this.canPlay,
    required this.insets,
    required this.here,
    required this.onVote,
    required this.onLike,
    required this.onComments,
    required this.onOpen,
    required this.onShowOnMap,
  });

  @override
  State<_FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends State<_FeedPage> {
  /// Paused by a tap; cleared when the page is left.
  bool _paused = false;
  bool _expanded = false;
  final _bursts = <({Offset at, Key key})>[];
  int _burstCount = 0;

  bool get _playable => widget.post.mediaType == MediaType.video || widget.post.mediaType == MediaType.audio;

  @override
  void didUpdateWidget(_FeedPage old) {
    super.didUpdateWidget(old);
    if (old.active && !widget.active) {
      _paused = false;
      _expanded = false;
    }
  }

  void _onTap() {
    if (_playable) {
      setState(() => _paused = !_paused);
    } else {
      widget.onOpen();
    }
  }

  void _onDoubleTap(Offset at) {
    setState(() => _bursts.add((at: at, key: ValueKey(_burstCount++))));
    widget.onLike();
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final l = context.l10n;
    final insets = widget.insets;
    final playing = widget.active && widget.canPlay && !_paused;
    // What the content keeps clear of: the top bar, the buttons on the right, and the
    // details at the bottom.
    final contentSafe = EdgeInsets.fromLTRB(0, insets.top + 16, 64, insets.bottom + 150);
    Offset? doubleTapAt;

    return Stack(
      fit: StackFit.expand,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _onTap,
          onDoubleTapDown: (d) => doubleTapAt = d.localPosition,
          onDoubleTap: () => _onDoubleTap(doubleTapAt ?? Offset.zero),
          child: FeedMedia(
            post: post,
            active: widget.active,
            playing: playing,
            muted: feedMuted,
            safe: contentSafe,
            barBottom: insets.bottom,
          ),
        ),

        // Shade under the details so white text reads on any picture.
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: insets.bottom + 260,
          child: const IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Color(0xB3000000), Color(0x00000000)],
                ),
              ),
            ),
          ),
        ),

        for (final burst in _bursts)
          Positioned(
            key: burst.key,
            left: burst.at.dx - 56,
            top: burst.at.dy - 56,
            child: _LikeBurst(onDone: () => setState(() => _bursts.remove(burst))),
          ),

        // Details.
        Positioned(
          left: 16,
          right: 84,
          bottom: insets.bottom + 20,
          child: _Details(
            post: post,
            here: widget.here,
            expanded: _expanded,
            onToggle: () => setState(() => _expanded = !_expanded),
            onShowOnMap: widget.onShowOnMap,
          ),
        ),

        // Buttons.
        Positioned(
          right: 6,
          bottom: insets.bottom + 12,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _RailButton(
                icon: post.myVote == 1 ? Icons.thumb_up_rounded : Icons.thumb_up_outlined,
                color: post.myVote == 1 ? AppTheme.brandLight : Colors.white,
                label: '${post.score}',
                onPressed: () => widget.onVote(1),
              ),
              _RailButton(
                icon: post.myVote == -1 ? Icons.thumb_down_rounded : Icons.thumb_down_outlined,
                color: post.myVote == -1 ? const Color(0xFFFF6B6B) : Colors.white,
                onPressed: () => widget.onVote(-1),
              ),
              _RailButton(
                icon: Icons.chat_bubble_outline_rounded,
                label: '${post.commentCount}',
                tooltip: l.comments,
                onPressed: widget.onComments,
              ),
              if (widget.onShowOnMap != null)
                _RailButton(icon: Icons.map_outlined, tooltip: l.showOnMap, onPressed: widget.onShowOnMap!),
              if (_playable)
                ValueListenableBuilder(
                  valueListenable: feedMuted,
                  builder: (context, muted, _) => _RailButton(
                    icon: muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                    tooltip: muted ? l.soundOn : l.soundOff,
                    onPressed: () => feedMuted.value = !muted,
                  ),
                ),
              _RailButton(icon: Icons.more_horiz_rounded, tooltip: l.postDetails, onPressed: widget.onOpen),
            ],
          ),
        ),
      ],
    );
  }
}

/// Author, time, distance, title and description at the bottom of a page.
class _Details extends StatelessWidget {
  final Post post;
  final LatLng? here;
  final bool expanded;
  final VoidCallback onToggle;

  /// Tapping the distance shows the post on the map.
  final VoidCallback? onShowOnMap;

  const _Details({
    required this.post,
    required this.here,
    required this.expanded,
    required this.onToggle,
    this.onShowOnMap,
  });

  static const _shadow = [Shadow(color: Color(0x99000000), blurRadius: 6)];

  /// "2.4 km", or "~2.4 km" when the post's location is only approximate.
  String? _distance() {
    final from = here;
    if (from == null) return null;
    final meters = const Distance().as(LengthUnit.Meter, from, LatLng(post.latitude, post.longitude)).round();
    final rounded = meters >= 10000 ? (meters / 1000).round() * 1000 : meters;
    return '${post.locationRadiusMeters != null ? '~' : ''}${formatRadius(rounded)}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final distance = _distance();
    final description = post.description?.trim() ?? '';
    final isText = post.mediaType == MediaType.text;
    const white = TextStyle(color: Colors.white, shadows: _shadow);

    return GestureDetector(
      onTap: onToggle,
      child: AnimatedSize(
        duration: const Duration(milliseconds: 200),
        alignment: Alignment.bottomLeft,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                UserAvatar(post.author.userName, radius: 16),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    post.author.userName,
                    overflow: TextOverflow.ellipsis,
                    style: white.copyWith(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                ),
                Text(
                  '  ·  ${timeAgo(context, post.createdAt)}',
                  style: white.copyWith(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
            if (distance != null || post.isHidden) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  if (distance != null) _Chip(icon: Icons.place_rounded, label: distance, onTap: onShowOnMap),
                  if (post.isHidden) _Chip(icon: Icons.visibility_off_rounded, label: context.l10n.hidden),
                ],
              ),
            ],
            // A text post's title and text are the page itself.
            if (!isText) ...[
              const SizedBox(height: 8),
              Text(
                post.title,
                maxLines: expanded ? 4 : 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.merge(white).copyWith(fontWeight: FontWeight.w800),
              ),
              if (description.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  description,
                  maxLines: expanded ? 10 : 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.merge(white).copyWith(color: Colors.white.withValues(alpha: 0.9)),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  const _Chip({required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.35), borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
    if (onTap == null) return chip;
    return GestureDetector(onTap: onTap, child: chip);
  }
}

class _RailButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String? label;
  final String? tooltip;
  final VoidCallback onPressed;

  const _RailButton({required this.icon, required this.onPressed, this.color = Colors.white, this.label, this.tooltip});

  @override
  Widget build(BuildContext context) {
    const shadow = [Shadow(color: Color(0x99000000), blurRadius: 8)];
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: tooltip,
            iconSize: 30,
            onPressed: onPressed,
            icon: Icon(icon, color: color, shadows: shadow),
          ),
          if (label != null)
            Text(
              label!,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13, shadows: shadow),
            ),
        ],
      ),
    );
  }
}

/// The thumb that pops up where a page was double-tapped.
class _LikeBurst extends StatelessWidget {
  final VoidCallback onDone;
  const _LikeBurst({required this.onDone});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 750),
        onEnd: onDone,
        builder: (context, t, child) {
          final scale = t < 0.25 ? 0.6 + t / 0.25 * 0.6 : 1.2 - (t - 0.25) * 0.2;
          final opacity = t < 0.6 ? 1.0 : 1 - (t - 0.6) / 0.4;
          return Opacity(
            opacity: opacity.clamp(0, 1),
            child: Transform.scale(scale: scale, child: child),
          );
        },
        child: const Icon(
          Icons.thumb_up_rounded,
          size: 112,
          color: AppTheme.brandLight,
          shadows: [Shadow(color: Color(0x66000000), blurRadius: 16)],
        ),
      ),
    );
  }
}
