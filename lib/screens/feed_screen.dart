import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../api/api_client.dart';
import '../models/models.dart';
import '../state/filter_state.dart';
import '../state/settings_state.dart';
import '../widgets/common.dart';
import '../widgets/errors.dart';
import '../widgets/filter_sheet.dart';
import '../widgets/glass.dart';
import '../widgets/immersive_feed.dart';
import '../widgets/location.dart';
import '../widgets/post_card.dart';
import 'post_detail_screen.dart';
import 'profile_screen.dart';

enum FeedMode { newest, nearby }

/// Feed of posts: newest first (paged) or nearest to the user. Shown either full screen, one post
/// per page (see [ImmersiveFeed]), or as a list of cards; the choice is remembered in [SettingsState].
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
  FeedMode _mode = FeedMode.newest;
  int _page = 0;
  bool _hasMore = true;
  bool _loading = false;
  Object? _error;
  late final FilterState _filters;

  /// Where the user is, for distances, if known without asking.
  LatLng? _here;

  /// Incremented on refresh so responses of superseded requests are dropped.
  int _generation = 0;

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
      if (_mode == FeedMode.nearby) {
        final here = await currentLocation();
        if (gen != _generation) return;
        _here = here;
        final items = await api.nearby(here.latitude, here.longitude, radiusKm: 50, filter: _filters.filter);
        if (gen != _generation) return;
        _posts
          ..clear()
          ..addAll(items);
        _hasMore = false;
      } else {
        final page = await api.feed(page: _page + 1, filter: _filters.filter);
        if (gen != _generation) return;
        _posts.addAll(page.items);
        _page++;
        _hasMore = page.hasMore;
      }
    } catch (e) {
      if (gen != _generation) return;
      _error = e;
      _hasMore = false;
    } finally {
      if (mounted && gen == _generation) setState(() => _loading = false);
    }
  }

  void _setMode(FeedMode mode) {
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
    return immersive ? _buildImmersive(filterActive) : _buildList(filterActive);
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
        topBar: _ImmersiveTopBar(
          mode: _mode,
          onMode: _setMode,
          actions: [_viewToggle(true), _filterButton(filterActive), const ProfileButton(), const SizedBox(width: 4)],
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
        actions: [_viewToggle(false), _filterButton(filterActive), const ProfileButton(), const SizedBox(width: 4)],
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
                      child: SegmentedButton<FeedMode>(
                        segments: [
                          ButtonSegment(
                            value: FeedMode.newest,
                            label: Text(l.newest),
                            icon: const Icon(Icons.schedule_rounded),
                          ),
                          ButtonSegment(
                            value: FeedMode.nearby,
                            label: Text(l.nearby),
                            icon: const Icon(Icons.near_me_rounded),
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
                      child: PostCard(post: post, onTap: () => _open(post)),
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
                if (_posts.isEmpty) {
                  return EmptyState(icon: Icons.explore_rounded, title: l.noPostsYet, subtitle: l.noPostsHint);
                }
                return const SizedBox.shrink();
              },
            ),
          );
        },
      ),
    );
  }
}

/// "Newest | Nearby" as text tabs in the middle, buttons on the right, over the full-screen feed.
class _ImmersiveTopBar extends StatelessWidget {
  final FeedMode mode;
  final ValueChanged<FeedMode> onMode;
  final List<Widget> actions;

  const _ImmersiveTopBar({required this.mode, required this.onMode, required this.actions});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    Widget tab(FeedMode value, String label) {
      final selected = value == mode;
      return TextButton(
        onPressed: () => onMode(value),
        style: TextButton.styleFrom(foregroundColor: Colors.white),
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
          const SizedBox(width: 8),
          tab(FeedMode.newest, l.newest),
          tab(FeedMode.nearby, l.nearby),
          const Spacer(),
          ...actions,
        ],
      ),
    );
  }
}
