import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../api/api_client.dart';
import '../models/models.dart';
import '../state/auth_state.dart';
import '../widgets/common.dart';
import '../widgets/errors.dart';
import '../widgets/glass.dart';

/// Lets the signed-in user take a new profile picture, pick one of their posts, or remove it.
Future<void> changeAvatar(BuildContext context) async {
  final l = context.l10n;
  final auth = context.read<AuthState>();
  final api = context.read<ApiClient>();
  final choice = await showGlassSheet<String>(
    context,
    builder: (ctx) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 8),
        ListTile(
          leading: const Icon(Icons.photo_camera_rounded),
          title: Text(l.avatarTakePhoto),
          onTap: () => Navigator.pop(ctx, 'camera'),
        ),
        ListTile(
          leading: const Icon(Icons.photo_library_rounded),
          title: Text(l.avatarFromPost),
          onTap: () => Navigator.pop(ctx, 'post'),
        ),
        if (auth.user?.avatarUrl != null)
          ListTile(
            leading: Icon(Icons.delete_outline_rounded, color: Theme.of(ctx).colorScheme.error),
            title: Text(l.avatarRemove, style: TextStyle(color: Theme.of(ctx).colorScheme.error)),
            onTap: () => Navigator.pop(ctx, 'remove'),
          ),
        const SizedBox(height: 8),
      ]),
    ),
  );
  if (choice == null || !context.mounted) return;

  try {
    switch (choice) {
      case 'camera':
        final photo = await ImagePicker().pickImage(
          source: ImageSource.camera,
          preferredCameraDevice: CameraDevice.front,
          imageQuality: 90,
          maxWidth: 1600,
        );
        if (photo == null) return;
        auth.updateAvatar(await api.setAvatarPhoto(photo));
      case 'post':
        final post = await Navigator.push<Post>(
          context,
          MaterialPageRoute(builder: (_) => const _PostPickerScreen()),
        );
        if (post == null) return;
        auth.updateAvatar(await api.setAvatarFromPost(post.id));
      case 'remove':
        await api.removeAvatar();
        auth.updateAvatar(null);
    }
    if (context.mounted) showMessage(context, choice == 'remove' ? l.avatarRemoved : l.avatarUpdated);
  } catch (e) {
    if (context.mounted) showMessage(context, e);
  }
}

/// The user's own photo and video posts to choose a profile picture from.
class _PostPickerScreen extends StatefulWidget {
  const _PostPickerScreen();

  @override
  State<_PostPickerScreen> createState() => _PostPickerScreenState();
}

class _PostPickerScreenState extends State<_PostPickerScreen> {
  final List<Post> _posts = [];
  int _page = 0;
  bool _hasMore = true;
  bool _loading = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _loadMore();
  }

  Future<void> _loadMore() async {
    if (_loading || !_hasMore) return;
    setState(() => _loading = true);
    try {
      final page = await context.read<ApiClient>().myPosts(page: _page + 1);
      // Hidden posts can't be used, so they aren't offered.
      _posts.addAll(page.items.where((p) =>
          p.media != null && !p.isHidden && (p.mediaType == MediaType.image || p.mediaType == MediaType.video)));
      _page++;
      _hasMore = page.hasMore;
    } catch (e) {
      _error = e;
      _hasMore = false;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return GlassScaffold(
      behindBar: true,
      appBar: GlassAppBar(title: Text(l.avatarFromPost)),
      body: Builder(builder: (context) {
        final insets = MediaQuery.paddingOf(context);
        if (_posts.isEmpty) {
          return Center(
            child: _loading
                ? const CircularProgressIndicator()
                : _error != null
                    ? EmptyState(icon: Icons.cloud_off_rounded, title: errorMessage(context, _error!))
                    : EmptyState(icon: Icons.photo_library_outlined, title: l.avatarNoPosts),
          );
        }
        return GridView.builder(
          padding: EdgeInsets.fromLTRB(8, insets.top + 8, 8, insets.bottom + 24),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 160,
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
          ),
          itemCount: _posts.length,
          itemBuilder: (context, i) {
            if (i >= _posts.length - 6) _loadMore();
            final post = _posts[i];
            return ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Material(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: InkWell(
                  onTap: () => Navigator.pop(context, post),
                  child: post.mediaType == MediaType.image
                      ? CachedNetworkImage(imageUrl: post.media!.url, fit: BoxFit.cover)
                      : Stack(fit: StackFit.expand, children: [
                          const Center(child: Icon(Icons.play_circle_outline_rounded, size: 40)),
                          Positioned(
                            left: 8,
                            right: 8,
                            bottom: 6,
                            child: Text(post.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                          ),
                        ]),
                ),
              ),
            );
          },
        );
      }),
    );
  }
}
