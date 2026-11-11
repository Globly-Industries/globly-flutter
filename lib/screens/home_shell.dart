import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/api_client.dart';
import '../models/models.dart';
import '../state/auth_state.dart';
import '../update/update_dialog.dart';
import '../widgets/common.dart';
import '../widgets/glass.dart';
import '../widgets/media_capture.dart';
import '../widgets/post_wheel.dart';
import 'create_post_screen.dart';
import 'feed_screen.dart';
import 'map_screen.dart';

/// Map / Feed with a round "new post" button in the middle; Profile opens from each tab's top right.
/// Frosted bottom bar on phones, frosted side rail on wide screens.
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

  /// Shared by all glass panes on the tabs, so they only sample the background once per frame.
  final _backdropKey = BackdropKey();

  @override
  void initState() {
    super.initState();
    _recoverCapture();
    // After the first frame, so the dialog has a Navigator and Localizations to use.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) checkForUpdates(context, silent: true);
    });
  }

  /// Picks up a photo or video whose capture was cut short by Android closing the app.
  Future<void> _recoverCapture() async {
    final recovered = await recoverCapture(context.read<ApiClient>());
    if (recovered != null && mounted) await _openComposer(recovered.type, recovered);
  }

  bool _canPost() {
    if (context.read<AuthState>().isSignedIn) return true;
    showMessage(context, context.l10n.signInToPost);
    return false;
  }

  /// Captures first (except for text); the post form only opens once there is something to post.
  Future<void> _startPost(MediaType type) async {
    final media = type == MediaType.text ? null : await captureMedia(context, type);
    if (!mounted || (type != MediaType.text && media == null)) return;
    await _openComposer(type, media);
  }

  Future<void> _openComposer(MediaType type, CapturedMedia? media) async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => CreatePostScreen(type: type, media: media), fullscreenDialog: true),
    );
    if (created == true) {
      _mapKey.currentState?.refresh();
      _feedKey.currentState?.refresh();
    }
  }

  /// Switches to the map and flies to [post], opening its preview there.
  void _showOnMap(Post post) {
    setState(() => _index = 0);
    _mapKey.currentState?.showPost(post);
  }

  Widget _postButton(double direction, double size) => PostWheelButton(
        options: availablePostTypes,
        direction: direction,
        size: size,
        tooltip: context.l10n.newPost,
        canOpen: _canPost,
        onSelected: _startPost,
      );

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final pages = IndexedStack(
      index: _index,
      children: [
        MapScreen(key: _mapKey),
        FeedScreen(key: _feedKey, visible: _index == 1, onShowOnMap: _showOnMap),
      ],
    );

    final items = [
      GlassNavItem(Icons.map_outlined, Icons.map_rounded, l.navMap),
      GlassNavItem(Icons.dynamic_feed_outlined, Icons.dynamic_feed_rounded, l.navFeed),
    ];

    final wide = MediaQuery.sizeOf(context).width >= _wideBreakpoint;
    if (wide) {
      return BackdropGroup(
        backdropKey: _backdropKey,
        child: GlassBackground(
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: Row(children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: GlassPanel(
                  borderRadius: BorderRadius.circular(28),
                  child: NavigationRail(
                    selectedIndex: _index,
                    onDestinationSelected: (i) => setState(() => _index = i),
                    labelType: NavigationRailLabelType.all,
                    leading: Padding(
                      padding: const EdgeInsets.only(top: 8, bottom: 16),
                      child: Column(children: [
                        Image.asset('assets/logo.png', width: 32, height: 32, color: Theme.of(context).colorScheme.primary),
                        const SizedBox(height: 16),
                        _postButton(wheelFansRight, 56),
                      ]),
                    ),
                    destinations: [
                      for (final item in items)
                        NavigationRailDestination(
                          icon: Icon(item.icon),
                          selectedIcon: Icon(item.selectedIcon),
                          label: Text(item.label),
                        ),
                    ],
                  ),
                ),
              ),
              Expanded(child: pages),
            ]),
          ),
        ),
      );
    }

    return BackdropGroup(
      backdropKey: _backdropKey,
      child: Scaffold(
        // Pages run under the bar so it has something to frost; they pad by MediaQuery's bottom inset.
        extendBody: true,
        body: pages,
        bottomNavigationBar: GlassNavBar(
          items: items,
          leadingCount: 1,
          selectedIndex: _index,
          onSelected: (i) => setState(() => _index = i),
          postButton: _postButton(wheelFansUp, GlassNavBar.buttonSize),
        ),
      ),
    );
  }
}
