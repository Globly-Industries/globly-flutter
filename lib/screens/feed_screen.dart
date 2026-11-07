import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/api_client.dart';
import '../models/models.dart';
import '../state/filter_state.dart';
import '../widgets/common.dart';
import '../widgets/errors.dart';
import '../widgets/filter_sheet.dart';
import '../widgets/location.dart';
import '../widgets/post_card.dart';
import 'post_detail_screen.dart';

enum FeedMode { newest, nearby }

/// Feed of posts: newest first (paged) or nearest to the user.
class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

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

  /// Incremented on refresh so responses of superseded requests are dropped.
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _filters = context.read<FilterState>()..addListener(refresh);
    _scroll.addListener(() {
      if (_scroll.position.extentAfter < 600) _loadMore();
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

  Future<void> _open(Post post) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => PostDetailScreen(postId: post.id, initial: post)),
    );
    if (changed == true) refresh();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final filterActive = context.watch<FilterState>().filter.isActive;

    return Scaffold(
      appBar: AppBar(
        title: Text(l.navFeed),
        actions: [
          IconButton(
            tooltip: l.filters,
            icon: Badge(
              isLabelVisible: filterActive,
              smallSize: 8,
              child: const Icon(Icons.tune_rounded),
            ),
            onPressed: () => showFilterSheet(context),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: refresh,
        child: ListView.builder(
          controller: _scroll,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 96),
          itemCount: _posts.length + 2,
          itemBuilder: (context, i) {
            if (i == 0) {
              return ContentWidth(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                  child: SegmentedButton<FeedMode>(
                    segments: [
                      ButtonSegment(value: FeedMode.newest, label: Text(l.newest), icon: const Icon(Icons.schedule_rounded)),
                      ButtonSegment(value: FeedMode.nearby, label: Text(l.nearby), icon: const Icon(Icons.near_me_rounded)),
                    ],
                    selected: {_mode},
                    onSelectionChanged: (s) {
                      setState(() => _mode = s.first);
                      refresh();
                    },
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
              return const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()));
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
      ),
    );
  }
}
