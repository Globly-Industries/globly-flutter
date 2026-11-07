import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/api_client.dart';
import '../models/models.dart';
import '../state/filter_state.dart';
import '../widgets/common.dart';
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
  String? _error;
  late final FilterState _filters;

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

  /// Incremented on refresh so responses of superseded requests are dropped.
  int _generation = 0;

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
      _error = e.toString();
      _hasMore = false;
    } finally {
      if (mounted && gen == _generation) setState(() => _loading = false);
    }
  }

  Future<void> _open(Post post) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => PostDetailScreen(postId: post.id)));
  }

  @override
  Widget build(BuildContext context) {
    final filterActive = context.watch<FilterState>().filter.isActive;
    return Scaffold(
      appBar: AppBar(
        title: SegmentedButton<FeedMode>(
          segments: const [
            ButtonSegment(value: FeedMode.newest, label: Text('Newest'), icon: Icon(Icons.schedule)),
            ButtonSegment(value: FeedMode.nearby, label: Text('Nearby'), icon: Icon(Icons.near_me)),
          ],
          selected: {_mode},
          onSelectionChanged: (s) {
            setState(() => _mode = s.first);
            refresh();
          },
        ),
        actions: [
          IconButton(
            icon: Icon(filterActive ? Icons.filter_alt : Icons.filter_alt_outlined),
            onPressed: () => showFilterSheet(context),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: refresh,
        child: ListView.builder(
          controller: _scroll,
          physics: const AlwaysScrollableScrollPhysics(),
          itemCount: _posts.length + 1,
          itemBuilder: (context, i) {
            if (i < _posts.length) {
              return PostCard(post: _posts[i], onTap: () => _open(_posts[i]));
            }
            if (_loading) {
              return const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()));
            }
            if (_error != null) {
              return Padding(
                padding: const EdgeInsets.all(24),
                child: Column(children: [
                  Text(_error!, textAlign: TextAlign.center),
                  TextButton(onPressed: refresh, child: const Text('Retry')),
                ]),
              );
            }
            if (_posts.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(48),
                child: Column(children: [
                  Icon(mediaIcon(null), size: 48),
                  const SizedBox(height: 8),
                  const Text('No posts yet.'),
                ]),
              );
            }
            return const SizedBox(height: 80);
          },
        ),
      ),
    );
  }
}
