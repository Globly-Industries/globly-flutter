import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/auth_state.dart';
import '../widgets/common.dart';
import 'create_post_screen.dart';
import 'feed_screen.dart';
import 'map_screen.dart';
import 'profile_screen.dart';

/// Map / Feed / Profile with a "new post" button. Bottom bar on phones, side rail on wide screens.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  static const _wideBreakpoint = 840.0;

  int _index = 0;
  final _mapKey = GlobalKey<MapScreenState>();
  final _feedKey = GlobalKey<FeedScreenState>();

  Future<void> _createPost() async {
    if (!context.read<AuthState>().isSignedIn) {
      showMessage(context, context.l10n.signInToPost);
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
    final l = context.l10n;
    final pages = IndexedStack(
      index: _index,
      children: [MapScreen(key: _mapKey), FeedScreen(key: _feedKey), const ProfileScreen()],
    );

    final destinations = [
      (Icons.map_outlined, Icons.map_rounded, l.navMap),
      (Icons.dynamic_feed_outlined, Icons.dynamic_feed_rounded, l.navFeed),
      (Icons.person_outline_rounded, Icons.person_rounded, l.navProfile),
    ];

    final wide = MediaQuery.sizeOf(context).width >= _wideBreakpoint;
    if (wide) {
      return Scaffold(
        body: Row(children: [
          NavigationRail(
            selectedIndex: _index,
            onDestinationSelected: (i) => setState(() => _index = i),
            labelType: NavigationRailLabelType.all,
            leading: Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 16),
              child: Column(children: [
                Icon(Icons.public_rounded, size: 32, color: Theme.of(context).colorScheme.primary),
                const SizedBox(height: 16),
                FloatingActionButton(
                  heroTag: 'new-post',
                  elevation: 0,
                  tooltip: l.newPost,
                  onPressed: _createPost,
                  child: const Icon(Icons.add_location_alt_rounded),
                ),
              ]),
            ),
            destinations: [
              for (final (icon, selected, label) in destinations)
                NavigationRailDestination(icon: Icon(icon), selectedIcon: Icon(selected), label: Text(label)),
            ],
          ),
          Expanded(child: pages),
        ]),
      );
    }

    return Scaffold(
      body: pages,
      floatingActionButton: _index == 2
          ? null
          : FloatingActionButton(
              heroTag: 'new-post',
              tooltip: l.newPost,
              onPressed: _createPost,
              child: const Icon(Icons.add_location_alt_rounded),
            ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          for (final (icon, selected, label) in destinations)
            NavigationDestination(icon: Icon(icon), selectedIcon: Icon(selected), label: label),
        ],
      ),
    );
  }
}
