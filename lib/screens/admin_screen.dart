import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/api_client.dart';
import '../models/models.dart';
import '../widgets/common.dart';
import '../widgets/post_card.dart';
import 'post_detail_screen.dart';

/// Administration: moderation queue (reported posts) and user removal.
class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Administration'),
          bottom: const TabBar(tabs: [Tab(text: 'Reported posts'), Tab(text: 'Users')]),
        ),
        body: const TabBarView(children: [_ReportedPosts(), _Users()]),
      ),
    );
  }
}

class _ReportedPosts extends StatefulWidget {
  const _ReportedPosts();

  @override
  State<_ReportedPosts> createState() => _ReportedPostsState();
}

class _ReportedPostsState extends State<_ReportedPosts> {
  late final ApiClient _api = context.read<ApiClient>();
  List<Post>? _posts;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final page = await _api.adminPosts(flaggedOnly: true);
      if (mounted) setState(() => _posts = page.items);
    } catch (e) {
      if (mounted) showMessage(context, e);
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

  @override
  Widget build(BuildContext context) {
    final posts = _posts;
    if (posts == null) return const Center(child: CircularProgressIndicator());
    return RefreshIndicator(
      onRefresh: _load,
      child: posts.isEmpty
          ? ListView(children: const [Padding(padding: EdgeInsets.all(48), child: Center(child: Text('Nothing to review.')))])
          : ListView(
              children: [
                for (final p in posts)
                  PostCard(
                    post: p,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PostDetailScreen(postId: p.id))),
                    trailing: PopupMenuButton<String>(
                      onSelected: (v) async {
                        if (v == 'keep') {
                          await _act(() => _api.adminDismissReports(p.id));
                        } else if (await confirm(context, 'Remove post?', '"${p.title}" will be deleted.')) {
                          await _act(() => _api.adminDeletePost(p.id));
                        }
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'keep', child: Text('Keep (dismiss reports)')),
                        PopupMenuItem(value: 'remove', child: Text('Remove post')),
                      ],
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
    if (!await confirm(context, 'Delete ${u.userName}?', 'Their account and all ${u.postCount} posts will be removed.')) {
      return;
    }
    try {
      await _api.adminDeleteUser(u.id);
      await _load();
    } catch (e) {
      if (mounted) showMessage(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.all(12),
        child: TextField(
          controller: _search,
          decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search users', border: OutlineInputBorder()),
          onSubmitted: (_) => _load(),
        ),
      ),
      Expanded(
        child: _users == null
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                children: [
                  for (final u in _users!)
                    ListTile(
                      leading: Icon(u.isAdmin ? Icons.admin_panel_settings : Icons.person),
                      title: Text(u.userName),
                      subtitle: Text('${u.postCount} posts'),
                      trailing: u.isAdmin
                          ? null
                          : IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => _delete(u)),
                    ),
                ],
              ),
      ),
    ]);
  }
}
