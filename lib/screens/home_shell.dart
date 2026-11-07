import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/auth_state.dart';
import '../widgets/common.dart';
import 'create_post_screen.dart';
import 'feed_screen.dart';
import 'map_screen.dart';
import 'profile_screen.dart';

/// Bottom navigation: Map / Feed / Profile, plus the "new post" button.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  final _mapKey = GlobalKey<MapScreenState>();
  final _feedKey = GlobalKey<FeedScreenState>();

  Future<void> _createPost() async {
    final auth = context.read<AuthState>();
    if (!auth.isSignedIn) {
      showMessage(context, 'Sign in to publish posts.');
      return;
    }
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const CreatePostScreen(), fullscreenDialog: true),
    );
    if (created == true) {
      _mapKey.currentState?.refresh();
      _feedKey.currentState?.refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          MapScreen(key: _mapKey),
          FeedScreen(key: _feedKey),
          const ProfileScreen(),
        ],
      ),
      floatingActionButton: _index == 2
          ? null
          : FloatingActionButton(
              onPressed: _createPost,
              tooltip: 'New post',
              child: const Icon(Icons.add_location_alt),
            ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.map_outlined), selectedIcon: Icon(Icons.map), label: 'Map'),
          NavigationDestination(icon: Icon(Icons.dynamic_feed_outlined), selectedIcon: Icon(Icons.dynamic_feed), label: 'Feed'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
