import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/api_client.dart';
import '../models/models.dart';
import '../state/auth_state.dart';
import '../widgets/common.dart';
import '../widgets/errors.dart';
import '../widgets/glass.dart';
import '../widgets/post_card.dart';
import 'post_detail_screen.dart';
import 'profile_screen.dart';

/// Opens [author]'s profile; one's own opens the profile tab's screen instead.
void openUserProfile(BuildContext context, Author author) =>
    Navigator.push(context, userProfileRoute(context.read<AuthState>(), author.id, author.userName));

Route<void> userProfileRoute(AuthState auth, String userId, [String? userName]) => MaterialPageRoute(
      builder: (_) => auth.user?.id == userId ? const ProfileScreen() : UserScreen(userId: userId, userName: userName),
    );

/// Opens who follows [userId] ([followers]) or whom they follow.
void openFollowList(BuildContext context, String userId, {required bool followers}) => Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => FollowListScreen(userId: userId, followers: followers)),
    );

/// Someone else's profile: their stats, a follow button and their posts.
class UserScreen extends StatefulWidget {
  final String userId;

  /// Shown until the profile loads; a push only knows the id.
  final String? userName;
  const UserScreen({super.key, required this.userId, this.userName});

  @override
  State<UserScreen> createState() => _UserScreenState();
}

class _UserScreenState extends State<UserScreen> {
  final _scroll = ScrollController();
  final List<Post> _posts = [];
  UserProfile? _profile;
  int _page = 0;
  bool _hasMore = true;
  bool _loading = false;
  bool _following = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.extentAfter < 600) _loadMore();
    });
    _refresh();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final api = context.read<ApiClient>();
    _page = 0;
    _hasMore = true;
    _posts.clear();
    try {
      final profile = await api.userProfile(widget.userId);
      if (mounted) setState(() => _profile = profile);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
    await _loadMore();
  }

  Future<void> _loadMore() async {
    if (_loading || !_hasMore) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await context.read<ApiClient>().userPosts(widget.userId, page: _page + 1);
      _posts.addAll(page.items);
      _page++;
      _hasMore = page.hasMore;
    } catch (e) {
      _error = e;
      _hasMore = false;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleFollow() async {
    final profile = _profile;
    final auth = context.read<AuthState>();
    if (profile == null || _following) return;
    if (!auth.isSignedIn) {
      showMessage(context, context.l10n.signInToFollow);
      return;
    }
    final follow = !profile.isFollowing;
    // Shown right away; corrected by the server's count, or undone if it fails.
    setState(() {
      _following = true;
      _profile = profile.withFollow(follow, profile.followerCount + (follow ? 1 : -1));
    });
    try {
      final r = await context.read<ApiClient>().setFollowing(profile.id, follow);
      if (mounted) setState(() => _profile = profile.withFollow(r.following, r.followers));
    } catch (e) {
      if (!mounted) return;
      setState(() => _profile = profile);
      showMessage(context, e);
    } finally {
      if (mounted) setState(() => _following = false);
    }
  }

  Future<void> _open(Post post) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => PostDetailScreen(postId: post.id, initial: post)),
    );
    if (changed == true) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return GlassScaffold(
      behindBar: true,
      appBar: GlassAppBar(title: Text(_userName)),
      body: Builder(builder: (context) {
        final insets = MediaQuery.paddingOf(context);
        return RefreshIndicator(
          onRefresh: _refresh,
          edgeOffset: insets.top,
          child: ListView.builder(
            controller: _scroll,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(12, insets.top + 8, 12, insets.bottom + 24),
            itemCount: _posts.length + 2,
            itemBuilder: (context, i) {
              if (i == 0) return ContentWidth(child: _header());
              final index = i - 1;
              if (index < _posts.length) {
                final post = _posts[index];
                return ContentWidth(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 12),
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
                  action: OutlinedButton(onPressed: _refresh, child: Text(l.retry)),
                );
              }
              if (_posts.isEmpty) return EmptyState(icon: Icons.photo_library_outlined, title: l.noUserPosts);
              return const SizedBox.shrink();
            },
          ),
        );
      }),
    );
  }

  String get _userName => _profile?.userName ?? widget.userName ?? '';

  Widget _header() {
    final l = context.l10n;
    final theme = Theme.of(context);
    final p = _profile;
    String count(int? n) => n == null ? '–' : '$n';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              UserAvatar(_userName, radius: 34),
              const SizedBox(width: 16),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(_userName,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Wrap(spacing: 24, runSpacing: 8, children: [
                    ProfileStat(value: count(p?.postCount), label: l.posts),
                    ProfileStat(
                      value: count(p?.followerCount),
                      label: l.followers,
                      onTap: () => openFollowList(context, widget.userId, followers: true),
                    ),
                    ProfileStat(
                      value: count(p?.followingCount),
                      label: l.following,
                      onTap: () => openFollowList(context, widget.userId, followers: false),
                    ),
                  ]),
                ]),
              ),
            ]),
            const SizedBox(height: 16),
            if (p?.isFollowing ?? false)
              OutlinedButton.icon(
                onPressed: p == null ? null : _toggleFollow,
                icon: const Icon(Icons.check_rounded),
                label: Text(l.unfollow),
              )
            else
              FilledButton.icon(
                onPressed: p == null ? null : _toggleFollow,
                icon: const Icon(Icons.person_add_alt_1_rounded),
                label: Text(l.follow),
              ),
          ]),
        ),
      ),
    );
  }
}

/// Followers of a user, or the people they follow, each with a follow button.
class FollowListScreen extends StatefulWidget {
  final String userId;
  final bool followers;
  const FollowListScreen({super.key, required this.userId, required this.followers});

  @override
  State<FollowListScreen> createState() => _FollowListScreenState();
}

class _FollowListScreenState extends State<FollowListScreen> {
  final List<FollowUser> _users = [];

  /// Ids with a follow request on the way.
  final Set<String> _busy = {};
  int _page = 0;
  bool _hasMore = true;
  bool _loading = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    _page = 0;
    _hasMore = true;
    _users.clear();
    await _loadMore();
  }

  Future<void> _loadMore() async {
    if (_loading || !_hasMore) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await context.read<ApiClient>().followList(widget.userId, followers: widget.followers, page: _page + 1);
      _users.addAll(page.items);
      _page++;
      _hasMore = page.hasMore;
    } catch (e) {
      _error = e;
      _hasMore = false;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggle(int index) async {
    final u = _users[index];
    if (!context.read<AuthState>().isSignedIn) {
      showMessage(context, context.l10n.signInToFollow);
      return;
    }
    setState(() => _busy.add(u.id));
    try {
      final r = await context.read<ApiClient>().setFollowing(u.id, !u.isFollowing);
      if (mounted) setState(() => _users[index] = FollowUser(u.id, u.userName, r.following));
    } catch (e) {
      if (mounted) showMessage(context, e);
    } finally {
      if (mounted) setState(() => _busy.remove(u.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final me = context.select<AuthState, String?>((a) => a.user?.id);
    return GlassScaffold(
      behindBar: true,
      appBar: GlassAppBar(title: Text(widget.followers ? l.followers : l.following)),
      body: Builder(builder: (context) {
        final insets = MediaQuery.paddingOf(context);
        return RefreshIndicator(
          onRefresh: _refresh,
          edgeOffset: insets.top,
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.only(top: insets.top + 8, bottom: insets.bottom + 24),
            itemCount: _users.length + 1,
            itemBuilder: (context, i) {
              if (i < _users.length) {
                if (i >= _users.length - 5) _loadMore();
                final u = _users[i];
                return ContentWidth(
                  child: ListTile(
                    leading: UserAvatar(u.userName, radius: 20),
                    title: Text(u.userName, style: const TextStyle(fontWeight: FontWeight.w600)),
                    onTap: () => openUserProfile(context, u.author),
                    trailing: u.id == me ? null : _followButton(i, u),
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
                  action: OutlinedButton(onPressed: _refresh, child: Text(l.retry)),
                );
              }
              if (_users.isEmpty) {
                return EmptyState(
                  icon: Icons.people_outline_rounded,
                  title: widget.followers ? l.noFollowers : l.noFollowing,
                );
              }
              return const SizedBox.shrink();
            },
          ),
        );
      }),
    );
  }

  Widget _followButton(int index, FollowUser u) {
    final l = context.l10n;
    final onPressed = _busy.contains(u.id) ? null : () => _toggle(index);
    return u.isFollowing
        ? OutlinedButton(onPressed: onPressed, child: Text(l.unfollow))
        : FilledButton(onPressed: onPressed, child: Text(l.follow));
  }
}
