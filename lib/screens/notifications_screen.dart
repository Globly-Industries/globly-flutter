import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/api_client.dart';
import '../models/models.dart';
import '../state/auth_state.dart';
import '../state/notifications_state.dart';
import '../widgets/common.dart';
import '../widgets/errors.dart';
import '../widgets/glass.dart';
import 'post_detail_screen.dart';

/// Bell with an unread badge, next to the profile button. Hidden for guests.
class NotificationsButton extends StatelessWidget {
  /// Puts the button on its own frosted pane, for use directly on the map.
  final bool glass;

  /// Space above the button, only taken while it shows.
  final double topGap;
  const NotificationsButton({super.key, this.glass = false, this.topGap = 0});

  @override
  Widget build(BuildContext context) {
    if (!context.select<AuthState, bool>((a) => a.isSignedIn)) return const SizedBox.shrink();
    final unread = context.select<NotificationsState, int>((n) => n.unread);
    final button = IconButton(
      tooltip: context.l10n.notifications,
      icon: Badge(
        isLabelVisible: unread > 0,
        label: Text(unread > 99 ? '99+' : '$unread'),
        child: Icon(unread > 0 ? Icons.notifications_rounded : Icons.notifications_none_rounded),
      ),
      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen())),
    );
    final child = glass
        ? GlassPanel(borderRadius: BorderRadius.circular(16), shadow: false, tint: glassButtonTint(context), child: button)
        : button;
    return topGap > 0 ? Padding(padding: EdgeInsets.only(top: topGap), child: child) : child;
  }
}

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late final ApiClient _api = context.read<ApiClient>();
  late final NotificationsState _state = context.read<NotificationsState>();
  List<AppNotification>? _items;
  bool _hasMore = false;
  bool _loadingMore = false;
  int _page = 1;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final page = await _api.notifications();
      if (!mounted) return;
      setState(() {
        _items = page.items;
        _hasMore = page.hasMore;
        _page = 1;
        _error = null;
      });
      _state.refresh();
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore) return;
    _loadingMore = true;
    try {
      final page = await _api.notifications(page: _page + 1);
      if (!mounted) return;
      setState(() {
        _items = [...?_items, ...page.items];
        _hasMore = page.hasMore;
        _page++;
      });
    } catch (e) {
      if (mounted) showMessage(context, e);
    } finally {
      _loadingMore = false;
    }
  }

  Future<void> _open(int index) async {
    final n = _items![index];
    if (!n.isRead) {
      setState(() => _items![index] = n.markedRead());
      _state.markRead();
      _api.markNotificationRead(n.id).ignore();
    }
    await Navigator.push(context, MaterialPageRoute(builder: (_) => PostDetailScreen(postId: n.postId)));
  }

  Future<void> _markAllRead() async {
    try {
      await _api.markAllNotificationsRead();
      _state.markRead(all: true);
      if (mounted) setState(() => _items = _items?.map((n) => n.markedRead()).toList());
    } catch (e) {
      if (mounted) showMessage(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final items = _items;
    final hasUnread = items?.any((n) => !n.isRead) ?? false;

    final Widget body;
    if (items == null) {
      body = Center(
        child: _error != null
            ? EmptyState(icon: Icons.cloud_off_rounded, title: errorMessage(context, _error!))
            : const CircularProgressIndicator(),
      );
    } else if (items.isEmpty) {
      body = EmptyState(icon: Icons.notifications_none_rounded, title: l.noNotifications);
    } else {
      body = RefreshIndicator(
        onRefresh: _load,
        child: ListView.builder(
          itemCount: items.length + (_hasMore ? 1 : 0),
          itemBuilder: (context, i) {
            if (i == items.length) {
              _loadMore();
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            return _tile(items[i], () => _open(i));
          },
        ),
      );
    }

    return GlassScaffold(
      appBar: GlassAppBar(
        title: Text(l.notifications),
        actions: [
          if (hasUnread)
            IconButton(tooltip: l.markAllRead, icon: const Icon(Icons.done_all_rounded), onPressed: _markAllRead),
        ],
      ),
      body: body,
    );
  }

  Widget _tile(AppNotification n, VoidCallback onTap) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final title = n.type == NotificationType.mention
        ? l.notificationMention(n.actor.userName, n.postTitle)
        : l.notificationComment(n.actor.userName, n.postTitle);

    return ListTile(
      onTap: onTap,
      tileColor: n.isRead ? null : scheme.primary.withValues(alpha: 0.08),
      leading: UserAvatar(n.actor.userName, radius: 20),
      title: Text(title, style: n.isRead ? null : const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(n.commentBody, maxLines: 2, overflow: TextOverflow.ellipsis),
        Text(timeAgo(context, n.createdAt), style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
      ]),
      isThreeLine: true,
    );
  }
}
