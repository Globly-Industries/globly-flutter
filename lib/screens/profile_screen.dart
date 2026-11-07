import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/api_client.dart';
import '../models/models.dart';
import '../state/auth_state.dart';
import '../widgets/post_card.dart';
import 'admin_screen.dart';
import 'post_detail_screen.dart';

/// Profile management: account info and the user's own posts (open to edit/delete).
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  List<Post>? _posts;
  Object? _error;
  String? _loadedFor;

  /// Loads posts the first time a (new) user is seen.
  void _ensureLoaded(String? userId) {
    if (userId == null) _loadedFor = null;
    if (userId == null || userId == _loadedFor) return;
    _loadedFor = userId;
    _posts = null;
    Future.microtask(_load);
  }

  Future<void> _load() async {
    try {
      // First page is enough for now; add paging when users have many posts.
      final page = await context.read<ApiClient>().myPosts();
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

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();
    _ensureLoaded(auth.isSignedIn ? auth.user?.id : null);

    if (!auth.isSignedIn) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profile')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.person_outline, size: 64),
              const SizedBox(height: 16),
              const Text('You are browsing as a guest.\nSign in to publish and rate posts.', textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(onPressed: auth.requestSignIn, child: const Text('Sign in or register')),
            ]),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(auth.user!.userName),
        actions: [
          if (auth.isAdmin)
            IconButton(
              tooltip: 'Administration',
              icon: const Icon(Icons.admin_panel_settings),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminScreen())),
            ),
          IconButton(tooltip: 'Sign out', icon: const Icon(Icons.logout), onPressed: auth.signOut),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('My posts', style: Theme.of(context).textTheme.titleMedium),
            ),
            if (_error != null) Padding(padding: const EdgeInsets.all(16), child: Text(_error.toString())),
            if (_posts == null && _error == null) const Center(child: CircularProgressIndicator()),
            if (_posts?.isEmpty ?? false)
              const Padding(padding: EdgeInsets.all(32), child: Center(child: Text('You have not posted anything yet.'))),
            for (final p in _posts ?? const <Post>[])
              PostCard(
                post: p,
                onTap: () async {
                  await Navigator.push(context, MaterialPageRoute(builder: (_) => PostDetailScreen(postId: p.id)));
                  _load(); // reflect edits / deletion
                },
              ),
          ],
        ),
      ),
    );
  }
}
