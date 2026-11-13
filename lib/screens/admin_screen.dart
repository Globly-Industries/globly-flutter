import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/api_client.dart';
import '../models/models.dart';
import '../widgets/common.dart';
import '../widgets/errors.dart';
import '../widgets/glass.dart';
import '../widgets/post_card.dart';
import 'post_detail_screen.dart';

/// Administration: review queue (posts hidden by moderation or flagged by the NSFW filter), and
/// user removal.
class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return DefaultTabController(
      length: 2,
      child: GlassScaffold(
        appBar: GlassAppBar(
          title: Text(l.administration),
          bottom: TabBar(tabs: [
            Tab(icon: const Icon(Icons.visibility_off_rounded), text: l.hiddenPosts),
            Tab(icon: const Icon(Icons.group_rounded), text: l.users),
          ]),
        ),
        body: const TabBarView(children: [_HiddenPosts(), _Users()]),
      ),
    );
  }
}

class _HiddenPosts extends StatefulWidget {
  const _HiddenPosts();

  @override
  State<_HiddenPosts> createState() => _HiddenPostsState();
}

class _HiddenPostsState extends State<_HiddenPosts> {
  late final ApiClient _api = context.read<ApiClient>();
  List<Post>? _posts;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final page = await _api.adminPosts(hiddenOnly: true);
      if (mounted) {
        setState(() {
          _posts = page.items;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _act(Future<void> Function() action) async {
    try {
      await action();
      await _load();
    } catch (e) {
      if (mounted) showMessage(context, e);
    }
  }

  String _reason(Post p) {
    final l = context.l10n;
    final percent = ((p.nsfwScore ?? 0) * 100).round();
    if (!p.isHidden && p.needsReview) return l.reasonFlagged(percent);
    return switch (p.hiddenReason) {
      HiddenReason.downvotes => l.reasonDownvotes,
      HiddenReason.admin => l.reasonAdmin,
      HiddenReason.automatic => l.reasonAutomatic(percent),
      HiddenReason.unverified => l.reasonUnverified,
      _ => l.reasonReports(p.reportCount),
    };
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final posts = _posts;

    if (_error != null) return EmptyState(icon: Icons.cloud_off_rounded, title: errorMessage(context, _error!));
    if (posts == null) return const Center(child: CircularProgressIndicator());

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          if (posts.isEmpty) EmptyState(icon: Icons.task_alt_rounded, title: l.nothingToReview),
          for (final p in posts)
            ContentWidth(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  PostCard(
                    post: p,
                    compact: true,
                    trailing: Pill(icon: Icons.flag_rounded, label: _reason(p), color: scheme.error),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => PostDetailScreen(postId: p.id, initial: p)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        // Flagged posts are still visible: restoring them just approves them.
                        icon: Icon(p.isHidden ? Icons.restore_rounded : Icons.check_rounded),
                        label: Text(p.isHidden ? l.restore : l.approve),
                        onPressed: () => _act(() => _api.adminRestore(p.id)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(backgroundColor: scheme.error, foregroundColor: scheme.onError),
                        icon: const Icon(Icons.delete_rounded),
                        label: Text(l.delete),
                        onPressed: () async {
                          if (await confirm(context, l.deletePostTitle, l.deletePostBody)) {
                            await _act(() => _api.adminDeletePost(p.id));
                          }
                        },
                      ),
                    ),
                  ]),
                ]),
              ),
            ),
        ],
      ),
    );
  }
}

class _Users extends StatefulWidget {
  const _Users();

  @override
  State<_Users> createState() => _UsersState();
}

class _UsersState extends State<_Users> {
  late final ApiClient _api = context.read<ApiClient>();
  final _search = TextEditingController();
  List<AdminUser>? _users;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final page = await _api.adminUsers(search: _search.text.trim().isEmpty ? null : _search.text.trim());
      if (mounted) setState(() => _users = page.items);
    } catch (e) {
      if (mounted) showMessage(context, e);
    }
  }

  Future<void> _delete(AdminUser u) async {
    final l = context.l10n;
    if (!await confirm(context, l.deleteUserTitle(u.userName), l.deleteUserBody)) return;
    try {
      await _api.adminDeleteUser(u.id);
      await _load();
    } catch (e) {
      if (mounted) showMessage(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return ContentWidth(
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            controller: _search,
            decoration: InputDecoration(prefixIcon: const Icon(Icons.search_rounded), hintText: l.searchUsers),
            onSubmitted: (_) => _load(),
          ),
        ),
        Expanded(
          child: _users == null
              ? const Center(child: CircularProgressIndicator())
              : ListView(children: [
                  for (final u in _users!)
                    ListTile(
                      leading: UserAvatar(u.userName),
                      title: Text(u.userName, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(l.userPostCount(u.postCount)),
                      trailing: u.isAdmin
                          ? Pill(icon: Icons.verified_user_rounded, label: l.admin, color: Theme.of(context).colorScheme.primary)
                          : IconButton(icon: const Icon(Icons.delete_outline_rounded), onPressed: () => _delete(u)),
                    ),
                ]),
        ),
      ]),
    );
  }
}
