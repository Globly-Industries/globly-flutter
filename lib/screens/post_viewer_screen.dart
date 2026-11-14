import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../api/api_client.dart';
import '../models/models.dart';
import '../widgets/immersive_feed.dart';
import '../widgets/location.dart';
import 'post_detail_screen.dart';

/// One post full screen, like a page of the full-screen feed. Pops with `true` if the post changed.
class PostViewerScreen extends StatefulWidget {
  final String postId;
  final Post? initial;

  const PostViewerScreen({super.key, required this.postId, this.initial});

  @override
  State<PostViewerScreen> createState() => _PostViewerScreenState();
}

class _PostViewerScreenState extends State<PostViewerScreen> {
  late final ApiClient _api = context.read<ApiClient>();
  Post? _post;
  Object? _error;
  bool _loading = false;
  bool _changed = false;
  LatLng? _here;

  @override
  void initState() {
    super.initState();
    _post = widget.initial;
    knownLocationWithoutAsking().then((here) {
      if (here != null && mounted) setState(() => _here = here);
    });
    if (_post == null) _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final post = await _api.post(widget.postId);
      if (mounted) setState(() => _post = post);
    } catch (e) {
      if (mounted && _post == null) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openDetails(Post post) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => PostDetailScreen(postId: post.id, initial: post),
      ),
    );
    if (changed != true || !mounted) return;
    _changed = true;
    try {
      final updated = await _api.post(post.id);
      if (mounted) setState(() => _post = updated);
    } catch (_) {
      // Deleted or no longer visible.
      if (mounted) Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final post = _post;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, _changed);
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: ImmersiveFeed(
          posts: [?post],
          generation: 0,
          loading: _loading,
          hasMore: false,
          error: _error,
          visible: true,
          here: _here,
          onRefresh: _load,
          onLoadMore: () {},
          onPostChanged: (p) => setState(() => _post = p),
          onOpen: _openDetails,
          topBar: const Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: EdgeInsets.only(left: 4),
              child: BackButton(color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}
