import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

import '../api/api_client.dart';
import '../models/models.dart';
import '../state/auth_state.dart';
import '../state/settings_state.dart';
import '../update/app_updater.dart';
import '../update/update_dialog.dart';
import '../widgets/common.dart';
import '../widgets/errors.dart';
import '../widgets/glass.dart';
import '../widgets/language_menu.dart';
import '../widgets/post_card.dart';
import 'admin_screen.dart';
import 'post_detail_screen.dart';

/// Top-right button opening the profile: the user's avatar, or a person icon for guests.
class ProfileButton extends StatelessWidget {
  /// Puts the button on its own frosted pane, for use directly on the map.
  final bool glass;
  const ProfileButton({super.key, this.glass = false});

  @override
  Widget build(BuildContext context) {
    final user = context.select<AuthState, String?>((auth) => auth.user?.userName);
    final button = IconButton(
      tooltip: context.l10n.navProfile,
      icon: user == null ? const Icon(Icons.person_outline_rounded) : UserAvatar(user, radius: 14),
      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen())),
    );
    return glass
        ? GlassPanel(borderRadius: BorderRadius.circular(16), shadow: false, tint: glassButtonTint(context), child: button)
        : button;
  }
}

/// Profile management: account, language, the user's own posts (open to edit/delete).
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  List<Post>? _posts;
  bool _hasMore = false;
  Object? _error;
  String? _loadedFor;
  String? _version;

  @override
  void initState() {
    super.initState();
    if (AppUpdater.supported) {
      PackageInfo.fromPlatform().then((info) {
        if (mounted) setState(() => _version = info.version);
      });
    }
  }

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
          _hasMore = page.hasMore;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final auth = context.watch<AuthState>();
    _ensureLoaded(auth.isSignedIn ? auth.user?.id : null);

    return GlassScaffold(
      behindBar: true,
      appBar: GlassAppBar(title: Text(l.navProfile)),
      // Builder: only below the scaffold does MediaQuery include the app and bottom bars.
      body: Builder(builder: (context) {
        final insets = MediaQuery.paddingOf(context);
        return RefreshIndicator(
          onRefresh: auth.isSignedIn ? _load : () async {},
          edgeOffset: insets.top,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(12, insets.top + 8, 12, insets.bottom + 24),
            children: [
              ContentWidth(
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  if (auth.isSignedIn) _header(auth) else _guestCard(auth),
                  const SizedBox(height: 12),
                  _settingsCard(auth),
                  if (auth.isSignedIn) ..._myPosts(),
                ]),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _guestCard(AuthState auth) {
    final l = context.l10n;
    return Card(
      child: EmptyState(
        icon: Icons.person_outline_rounded,
        title: l.guestTitle,
        subtitle: l.guestBody,
        action: FilledButton(onPressed: auth.requestSignIn, child: Text(l.signInOrRegister)),
      ),
    );
  }

  Widget _header(AuthState auth) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final posts = _posts ?? const <Post>[];
    final totalScore = posts.fold<int>(0, (sum, p) => sum + p.score);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(children: [
          UserAvatar(auth.user!.userName, radius: 34),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(
                  child: Text(auth.user!.userName,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                ),
                if (auth.isAdmin) ...[
                  const SizedBox(width: 8),
                  Pill(icon: Icons.verified_user_rounded, label: l.admin, color: theme.colorScheme.primary),
                ],
              ]),
              const SizedBox(height: 8),
              Row(children: [
                _Stat(value: _posts == null ? '–' : '${posts.length}${_hasMore ? '+' : ''}', label: l.posts),
                const SizedBox(width: 24),
                _Stat(value: _posts == null ? '–' : '$totalScore', label: l.score),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _settingsCard(AuthState auth) {
    final l = context.l10n;
    final settings = context.watch<SettingsState>();
    final current = settings.locale?.languageCode;

    return Card(
      child: Column(children: [
        ListTile(
          leading: const Icon(Icons.translate_rounded),
          title: Text(l.language),
          trailing: DropdownButton<String?>(
            value: current,
            underline: const SizedBox.shrink(),
            borderRadius: BorderRadius.circular(12),
            items: [
              for (final code in appLanguages.keys)
                DropdownMenuItem(value: code, child: Text(languageLabel(context, code))),
            ],
            onChanged: (code) => settings.setLocale(code == null ? null : Locale(code)),
          ),
        ),
        if (AppUpdater.supported)
          ListTile(
            leading: const Icon(Icons.system_update_rounded),
            title: Text(l.checkForUpdates),
            subtitle: _version == null ? null : Text(l.appVersion(_version!)),
            onTap: () => checkForUpdates(context),
          ),
        if (auth.isAdmin)
          ListTile(
            leading: const Icon(Icons.admin_panel_settings_rounded),
            title: Text(l.administration),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminScreen()));
              _load();
            },
          ),
        if (auth.isSignedIn)
          ListTile(
            leading: Icon(Icons.logout_rounded, color: Theme.of(context).colorScheme.error),
            title: Text(l.signOut, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            onTap: auth.signOut,
          ),
      ]),
    );
  }

  List<Widget> _myPosts() {
    final l = context.l10n;
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 24, 4, 12),
        child: Text(l.myPosts, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
      ),
      if (_error != null) EmptyState(icon: Icons.cloud_off_rounded, title: errorMessage(context, _error!)),
      if (_posts == null && _error == null) const Center(child: CircularProgressIndicator()),
      if (_posts?.isEmpty ?? false) EmptyState(icon: Icons.add_location_alt_rounded, title: l.noMyPosts),
      for (final p in _posts ?? const <Post>[])
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: PostCard(
            post: p,
            onTap: () async {
              final changed = await Navigator.push<bool>(
                context,
                MaterialPageRoute(builder: (_) => PostDetailScreen(postId: p.id, initial: p)),
              );
              if (changed == true) _load();
            },
          ),
        ),
    ];
  }
}

class _Stat extends StatelessWidget {
  final String value;
  final String label;
  const _Stat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(value, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
      Text(label, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
    ]);
  }
}
