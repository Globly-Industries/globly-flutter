import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../api/api_client.dart';
import '../models/models.dart';
import '../state/auth_state.dart';
import '../state/filter_state.dart';
import '../state/settings_state.dart';
import '../widgets/common.dart';
import '../widgets/errors.dart';
import '../widgets/filter_sheet.dart';
import '../widgets/glass.dart';
import '../widgets/immersive_feed.dart';
import '../widgets/location.dart';
import '../widgets/post_card.dart';
import 'notifications_screen.dart';
import 'post_detail_screen.dart';
import 'profile_screen.dart';
import 'user_screen.dart';

/// Feed of posts in three tabs the server ranks (recent, nearby, followed people). Shown either full
/// screen, one post per page (see [ImmersiveFeed]), or as a list of cards; the choice is remembered in [SettingsState].
class FeedScreen extends StatefulWidget {
  /// Whether this tab is the one on screen; the full-screen feed only plays media while it is.
  final bool visible;

  /// Shows a post on the map tab.
  final ValueChanged<Post>? onShowOnMap;

  const FeedScreen({super.key, this.visible = true, this.onShowOnMap});

  @override
  State<FeedScreen> createState() => FeedScreenState();
}

class FeedScreenState extends State<FeedScreen> {
  final _scroll = ScrollController();
  final List<Post> _posts = [];
  FeedTab _mode = FeedTab.recent;
  int _page = 0;
  bool _hasMore = true;
  bool _loading = false;
  Object? _error;
  late final FilterState _filters;

  /// Where the user is, for distances, if known without asking.
  LatLng? _here;

  /// Incremented on refresh so responses of superseded requests are dropped.
  int _generation = 0;

  /// Where the Nearby tab ranks from; taken once per refresh so its pages agree.
  LatLng? _nearbyFrom;

  static const _nearbyRadiusKm = 50.0;

  @override
  void initState() {
    super.initState();
    _filters = context.read<FilterState>()..addListener(refresh);
    _scroll.addListener(() {
      if (_scroll.position.extentAfter < 600) _loadMore();
    });
    knownLocationWithoutAsking().then((here) {
      if (here != null && mounted && _here == null) setState(() => _here = here);
    });
    refresh();
  }

  @override
  void dispose() {
    _filters.removeListener(refresh);
    _scroll.dispose();
    super.dispose();
  }

  Future<void> refresh() async {
    _generation++;
    _page = 0;
    _hasMore = true;
    _loading = false;
    _nearbyFrom = null;
    _posts.clear();
    await _loadMore();
  }

  Future<void> _loadMore() async {
    if (_loading || !_hasMore) return;
    final gen = _generation;
    setState(() {
      _loading = true;
      _error = null;
    });
    final api = context.read<ApiClient>();
    try {
      if (_mode == FeedTab.following && !context.read<AuthState>().isSignedIn) {
        _hasMore = false;
        return;
      }
      if (_mode == FeedTab.nearby && _nearbyFrom == null) {
        final here = await currentLocation();
        if (gen != _generation) return;
        _here = _nearbyFrom = here;
      }
      final from = _mode == FeedTab.nearby ? _nearbyFrom : null;
      final page = await api.feed(
        page: _page + 1,
        tab: _mode,
        lat: from?.latitude,
        lng: from?.longitude,
        radiusKm: from == null ? null : _nearbyRadiusKm,
        filter: _filters.filter,
      );
      if (gen != _generation) return;
      // Rankings move as votes come in, so a post can turn up on two pages.
      final seen = _posts.map((p) => p.id).toSet();
      _posts.addAll(page.items.where((p) => seen.add(p.id)));
      _page++;
      _hasMore = page.hasMore;
    } catch (e) {
      if (gen != _generation) return;
      _error = e;
      _hasMore = false;
    } finally {
      if (mounted && gen == _generation) setState(() => _loading = false);
    }
  }

  void _setMode(FeedTab mode) {
    if (mode == _mode) return;
    setState(() => _mode = mode);
    refresh();
  }

  /// Puts an updated copy of a post (votes, comment count) in place of the old one.
  void _replace(Post post) {
    final i = _posts.indexWhere((p) => p.id == post.id);
    if (i >= 0 && mounted) setState(() => _posts[i] = post);
  }

  Future<void> _open(Post post) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => PostDetailScreen(postId: post.id, initial: post),
      ),
    );
    if (changed == true) refresh();
  }

  Widget _viewToggle(bool immersive) {
    final l = context.l10n;
    return IconButton(
      tooltip: immersive ? l.feedViewList : l.feedViewImmersive,
      icon: Icon(immersive ? Icons.view_agenda_outlined : Icons.fullscreen_rounded),
      onPressed: () => context.read<SettingsState>().setImmersiveFeed(!immersive),
    );
  }

  Widget _filterButton(bool active) => IconButton(
    tooltip: context.l10n.filters,
    icon: Badge(isLabelVisible: active, smallSize: 8, child: const Icon(Icons.tune_rounded)),
    onPressed: () => showFilterSheet(context),
  );

  @override
  Widget build(BuildContext context) {
    final immersive = context.select<SettingsState, bool>((s) => s.immersiveFeed);
    final filterActive = context.watch<FilterState>().filter.isActive;
    return GestureDetector(
      // Swipe left for the next tab, right for the previous one.
      onHorizontalDragEnd: (d) {
        final v = d.primaryVelocity ?? 0;
        if (v.abs() < 300) return;
        final next = _mode.index + (v < 0 ? 1 : -1);
        if (next >= 0 && next < FeedTab.values.length) _setMode(FeedTab.values[next]);
      },
      child: immersive ? _buildImmersive(filterActive) : _buildList(filterActive),
    );
  }

  Widget _buildImmersive(bool filterActive) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: ImmersiveFeed(
        posts: _posts,
        generation: _generation,
        loading: _loading,
        hasMore: _hasMore,
        error: _error,
        visible: widget.visible,
        here: _here,
        onRefresh: refresh,
        onLoadMore: _loadMore,
        onPostChanged: _replace,
        onOpen: _open,
        onShowOnMap: widget.onShowOnMap,
        onOpenAuthor: (a) => openUserProfile(context, a),
        empty: _emptyState(),
        topBar: _ImmersiveTopBar(
          mode: _mode,
          onMode: _setMode,
          actions: [_viewToggle(true), _filterButton(filterActive), const NotificationsButton(), const ProfileButton(), const SizedBox(width: 4)],
        ),
      ),
    );
  }

  Widget _buildList(bool filterActive) {
    final l = context.l10n;
    return GlassScaffold(
      behindBar: true,
      appBar: GlassAppBar(
        title: Text(l.navFeed),
        actions: [_viewToggle(false), _filterButton(filterActive), const NotificationsButton(), const ProfileButton(), const SizedBox(width: 4)],
      ),
      // Builder: only below the scaffold does MediaQuery include the app and bottom bars.
      body: Builder(
        builder: (context) {
          final insets = MediaQuery.paddingOf(context);
          return RefreshIndicator(
            onRefresh: refresh,
            edgeOffset: insets.top,
            child: ListView.builder(
              controller: _scroll,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.only(top: insets.top + 8, bottom: insets.bottom + 24),
              itemCount: _posts.length + 2,
              itemBuilder: (context, i) {
                if (i == 0) {
                  return ContentWidth(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                      child: SegmentedButton<FeedTab>(
                        segments: [
                          ButtonSegment(
                            value: FeedTab.recent,
                            label: Text(l.newest),
                            icon: const Icon(Icons.schedule_rounded),
                          ),
                          ButtonSegment(
                            value: FeedTab.nearby,
                            label: Text(l.nearby),
                            icon: const Icon(Icons.near_me_rounded),
                          ),
                          ButtonSegment(
                            value: FeedTab.following,
                            label: Text(l.following),
                            icon: const Icon(Icons.people_alt_rounded),
                          ),
                        ],
                        selected: {_mode},
                        onSelectionChanged: (s) => _setMode(s.first),
                      ),
                    ),
                  );
                }
                final index = i - 1;
                if (index < _posts.length) {
                  final post = _posts[index];
                  return ContentWidth(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      child: PostCard(
                        post: post,
                        onTap: () => _open(post),
                        onAuthorTap: () => openUserProfile(context, post.author),
                      ),
                    ),
                  );
                }
                if (_loading) {
                  return const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (_error != null) {
                  return EmptyState(
                    icon: Icons.cloud_off_rounded,
                    title: errorMessage(context, _error!),
                    action: OutlinedButton(onPressed: refresh, child: Text(l.retry)),
                  );
                }
                if (_posts.isEmpty) return _emptyState();
                return const SizedBox.shrink();
              },
            ),
          );
        },
      ),
    );
  }

  /// What an empty tab shows once loading is done.
  Widget _emptyState() {
    final l = context.l10n;
    if (_mode != FeedTab.following) {
      return EmptyState(icon: Icons.explore_rounded, title: l.noPostsYet, subtitle: l.noPostsHint);
    }
    final auth = context.read<AuthState>();
    if (!auth.isSignedIn) {
      return EmptyState(
        icon: Icons.people_alt_rounded,
        title: l.followingSignIn,
        action: FilledButton(onPressed: auth.requestSignIn, child: Text(l.signInOrRegister)),
      );
    }
    return EmptyState(icon: Icons.people_alt_rounded, title: l.followingEmpty, subtitle: l.followingEmptyHint);
  }
}

/// "Recent | Nearby | Following" as text tabs in the middle, buttons on the right, over the full-screen feed.
class _ImmersiveTopBar extends StatelessWidget {
  final FeedTab mode;
  final ValueChanged<FeedTab> onMode;
  final List<Widget> actions;

  const _ImmersiveTopBar({required this.mode, required this.onMode, required this.actions});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    Widget tab(FeedTab value, String label) {
      final selected = value == mode;
      return TextButton(
        onPressed: () => onMode(value),
        style: TextButton.styleFrom(
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          minimumSize: const Size(0, 40),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 17,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                color: selected ? Colors.white : Colors.white70,
                shadows: const [Shadow(color: Color(0x99000000), blurRadius: 6)],
              ),
            ),
            const SizedBox(height: 3),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: selected ? 22 : 0,
              height: 3,
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(2)),
            ),
          ],
        ),
      );
    }

    return IconTheme(
      data: const IconThemeData(
        color: Colors.white,
        shadows: [Shadow(color: Color(0x99000000), blurRadius: 6)],
      ),
      child: Row(
        children: [
          const SizedBox(width: 4),
          // Shrinks the tabs rather than overflowing on narrow phones.
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Row(children: [
                tab(FeedTab.recent, l.newest),
                tab(FeedTab.nearby, l.nearby),
                tab(FeedTab.following, l.following),
              ]),
            ),
          ),
          ...actions,
        ],
      ),
    );
  }
}
