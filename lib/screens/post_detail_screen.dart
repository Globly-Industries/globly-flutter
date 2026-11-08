import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/api_client.dart';
import '../l10n/app_localizations.dart';
import '../models/models.dart';
import '../state/auth_state.dart';
import '../widgets/common.dart';
import '../widgets/errors.dart';
import '../widgets/glass.dart';
import '../widgets/media_view.dart';

const quickEmoji = ['👍', '❤️', '😂', '😮', '😢', '🔥'];

/// Full post with rating (votes, emoji, comments, report) and edit/delete for the author.
/// Pops with `true` if the post changed (edited, deleted or hidden) so lists can refresh.
class PostDetailScreen extends StatefulWidget {
  final String postId;

  /// Already-loaded copy to show instantly while the full post loads.
  final Post? initial;

  const PostDetailScreen({super.key, required this.postId, this.initial});

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

enum _CommentKind { all, text, emoji }

class _PostDetailScreenState extends State<PostDetailScreen> {
  late final ApiClient _api = context.read<ApiClient>();
  final _commentText = TextEditingController();

  Post? _post;
  Object? _error;
  List<Comment> _comments = [];
  Map<String, int> _emoji = {};
  _CommentKind _kind = _CommentKind.all;
  bool _sending = false;
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _post = widget.initial;
    _load();
  }

  @override
  void dispose() {
    _commentText.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final post = await _api.post(widget.postId);
      if (mounted) setState(() => _post = post);
      await _loadRatings();
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _loadRatings() async {
    final kind = switch (_kind) { _CommentKind.text => 'Text', _CommentKind.emoji => 'Emoji', _ => 'All' };
    final results = await Future.wait([
      _api.comments(widget.postId, kind: kind),
      _api.emojiSummary(widget.postId),
    ]);
    if (!mounted) return;
    setState(() {
      _comments = (results[0] as Paged<Comment>).items;
      _emoji = results[1] as Map<String, int>;
    });
  }

  bool _requireSignIn() {
    if (context.read<AuthState>().isSignedIn) return true;
    showMessage(context, context.l10n.signInToRate);
    return false;
  }

  Future<void> _vote(int value) async {
    if (!_requireSignIn()) return;
    final post = _post!;
    final newValue = post.myVote == value ? 0 : value;
    try {
      final r = await _api.vote(post.id, newValue);
      setState(() => _post = post.copyWith(upvotes: r.upvotes, downvotes: r.downvotes, myVote: newValue, isHidden: r.hidden));
      if (r.hidden) _changed = true;
    } catch (e) {
      if (mounted) showMessage(context, e);
    }
  }

  Future<void> _send({String? emoji}) async {
    if (!_requireSignIn()) return;
    final body = emoji == null ? _commentText.text.trim() : null;
    if (emoji == null && (body == null || body.isEmpty)) return;
    setState(() => _sending = true);
    try {
      await _api.addComment(widget.postId, body: body, emoji: emoji);
      _commentText.clear();
      await _loadRatings();
    } catch (e) {
      if (mounted) showMessage(context, e);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _deleteComment(Comment c) async {
    final l = context.l10n;
    if (!await confirm(context, l.deleteCommentTitle, l.cannotUndo)) return;
    try {
      await _api.deleteComment(c.id);
      await _loadRatings();
    } catch (e) {
      if (mounted) showMessage(context, e);
    }
  }

  Future<void> _report() async {
    if (!_requireSignIn()) return;
    final l = context.l10n;
    final reason = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.flag_rounded),
        title: Text(l.reportTitle),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(l.reportHint),
          const SizedBox(height: 16),
          TextField(controller: reason, decoration: InputDecoration(labelText: l.reportReason), maxLength: 500),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.cancel)),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(64, 44)),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.report),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final hidden = await _api.report(widget.postId, reason.text.trim().isEmpty ? null : reason.text.trim());
      if (!mounted) return;
      showMessage(context, hidden ? l.reportHidden : l.reportThanks);
      if (hidden) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) showMessage(context, e);
    }
  }

  Future<void> _edit() async {
    final l = context.l10n;
    final post = _post!;
    final title = TextEditingController(text: post.title);
    final description = TextEditingController(text: post.description);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.editPost),
        content: SizedBox(
          width: 480,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: title, decoration: InputDecoration(labelText: l.title), maxLength: 120),
            const SizedBox(height: 8),
            TextField(
              controller: description,
              decoration: InputDecoration(labelText: post.mediaType == MediaType.text ? l.text : l.descriptionOptional),
              maxLength: 2000,
              maxLines: 5,
              minLines: 2,
            ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.cancel)),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(64, 44)),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.save),
          ),
        ],
      ),
    );
    if (ok != true || title.text.trim().isEmpty) return;
    try {
      final updated = await _api.updatePost(post.id, title: title.text.trim(), description: description.text.trim());
      setState(() => _post = updated);
      _changed = true;
    } catch (e) {
      if (mounted) showMessage(context, e);
    }
  }

  Future<void> _delete() async {
    final l = context.l10n;
    if (!await confirm(context, l.deletePostTitle, l.deletePostBody)) return;
    try {
      await _api.deletePost(widget.postId);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) showMessage(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final auth = context.watch<AuthState>();
    final post = _post;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, _changed);
      },
      child: GlassScaffold(
        behindBar: true,
        appBar: GlassAppBar(
          actions: [
            if (post != null) _menu(post, auth),
            const SizedBox(width: 4),
          ],
        ),
        body: post == null
            ? Center(
                child: _error != null
                    ? EmptyState(icon: Icons.error_outline_rounded, title: errorMessage(context, _error!))
                    : const CircularProgressIndicator(),
              )
            // Builder: only below the scaffold does MediaQuery include the app bar.
            : Builder(builder: (context) {
                final insets = MediaQuery.paddingOf(context);
                return RefreshIndicator(onRefresh: _load, edgeOffset: insets.top, child: _body(post, auth, l, insets));
              }),
      ),
    );
  }

  Widget _menu(Post post, AuthState auth) {
    final l = context.l10n;
    final isOwner = auth.user?.id == post.author.id;
    final canModify = isOwner || auth.isAdmin;
    return PopupMenuButton<String>(
      onSelected: (v) => switch (v) {
        'edit' => _edit(),
        'delete' => _delete(),
        _ => _report(),
      },
      itemBuilder: (_) => [
        if (canModify) PopupMenuItem(value: 'edit', child: ListTile(leading: const Icon(Icons.edit_rounded), title: Text(l.edit))),
        if (canModify) PopupMenuItem(value: 'delete', child: ListTile(leading: const Icon(Icons.delete_rounded), title: Text(l.delete))),
        if (!isOwner) PopupMenuItem(value: 'report', child: ListTile(leading: const Icon(Icons.flag_rounded), title: Text(l.report))),
      ],
    );
  }

  Widget _body(Post post, AuthState auth, AppLocalizations l, EdgeInsets insets) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return ListView(
      padding: EdgeInsets.only(top: insets.top + 8, bottom: insets.bottom + 32),
      children: [
        ContentWidth(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (post.isHidden) ...[HiddenBanner(post), const SizedBox(height: 16)],

              // Author
              Row(children: [
                UserAvatar(post.author.userName, radius: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(post.author.userName, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                    Text(timeAgo(context, post.createdAt),
                        style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                  ]),
                ),
                MediaPill(post.mediaType),
              ]),
              const SizedBox(height: 16),
              Text(post.title, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
              if (post.description?.isNotEmpty ?? false) ...[
                const SizedBox(height: 8),
                Text(post.description!, style: theme.textTheme.bodyLarge?.copyWith(height: 1.45)),
              ],
              const SizedBox(height: 16),
              if (post.media != null) ...[
                ClipRRect(borderRadius: BorderRadius.circular(18), child: MediaView(post: post)),
                const SizedBox(height: 12),
              ],

              // Location & views
              Wrap(spacing: 8, runSpacing: 8, children: [
                Pill(
                  icon: Icons.place_rounded,
                  label: post.locationRadiusMeters != null
                      ? l.approximateLocation(formatRadius(post.locationRadiusMeters!))
                      : '${post.latitude.toStringAsFixed(4)}, ${post.longitude.toStringAsFixed(4)}',
                  color: scheme.primary,
                ),
                Pill(icon: Icons.visibility_rounded, label: l.viewsCount(post.views), color: scheme.secondary),
              ]),
              const SizedBox(height: 16),

              // Votes
              Row(children: [
                Container(
                  decoration: BoxDecoration(
                    color: glassTint(context),
                    border: Border.all(color: glassEdge(context)),
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(
                      color: post.myVote == 1 ? scheme.primary : null,
                      icon: Icon(post.myVote == 1 ? Icons.thumb_up_rounded : Icons.thumb_up_outlined),
                      onPressed: () => _vote(1),
                    ),
                    Text('${post.score}', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                    IconButton(
                      color: post.myVote == -1 ? scheme.error : null,
                      icon: Icon(post.myVote == -1 ? Icons.thumb_down_rounded : Icons.thumb_down_outlined),
                      onPressed: () => _vote(-1),
                    ),
                  ]),
                ),
                const SizedBox(width: 12),
                Text('${post.upvotes} ↑  ${post.downvotes} ↓',
                    style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
              ]),
              const SizedBox(height: 12),

              // Emoji reactions
              Wrap(spacing: 6, runSpacing: 6, children: [
                for (final e in quickEmoji)
                  ActionChip(
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                    label: Text(_emoji[e] == null ? e : '$e ${_emoji[e]}', style: const TextStyle(fontSize: 16)),
                    backgroundColor: _emoji[e] == null ? null : scheme.primaryContainer.withValues(alpha: 0.6),
                    onPressed: _sending ? null : () => _send(emoji: e),
                  ),
              ]),
              const Divider(height: 40),

              // Comments
              Row(children: [
                Text(l.comments, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                const Spacer(),
                SegmentedButton<_CommentKind>(
                  showSelectedIcon: false,
                  style: const ButtonStyle(visualDensity: VisualDensity.compact),
                  segments: [
                    ButtonSegment(value: _CommentKind.all, label: Text(l.allComments)),
                    ButtonSegment(value: _CommentKind.text, label: Text(l.textComments)),
                    ButtonSegment(value: _CommentKind.emoji, icon: const Icon(Icons.emoji_emotions_outlined, size: 18)),
                  ],
                  selected: {_kind},
                  onSelectionChanged: (s) {
                    setState(() => _kind = s.first);
                    _loadRatings();
                  },
                ),
              ]),
              const SizedBox(height: 12),
              if (auth.isSignedIn)
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: UserAvatar(auth.user!.userName, radius: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _commentText,
                      decoration: InputDecoration(
                        hintText: l.addComment,
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.send_rounded),
                          color: scheme.primary,
                          onPressed: _sending ? null : () => _send(),
                        ),
                      ),
                      maxLength: 1000,
                      minLines: 1,
                      maxLines: 4,
                    ),
                  ),
                ]),
              for (final c in _comments) _commentTile(c, auth),
              if (_comments.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: Text(l.noComments, style: TextStyle(color: scheme.onSurfaceVariant))),
                ),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _commentTile(Comment c, AuthState auth) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final canDelete = auth.user?.id == c.author.id || auth.isAdmin;
    final emojiOnly = c.body == null && c.emoji != null;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        UserAvatar(c.author.userName, radius: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: glassTint(context),
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(16),
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
                topLeft: Radius.circular(4),
              ),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(c.author.userName, style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(width: 8),
                Text(timeAgo(context, c.createdAt),
                    style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
              ]),
              const SizedBox(height: 2),
              if (emojiOnly)
                Text(context.l10n.reacted(c.emoji!), style: theme.textTheme.bodyMedium)
              else
                Text([if (c.emoji != null) c.emoji!, c.body!].join(' '), style: theme.textTheme.bodyMedium),
            ]),
          ),
        ),
        if (canDelete)
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: Icon(Icons.delete_outline_rounded, color: scheme.onSurfaceVariant),
            onPressed: () => _deleteComment(c),
          ),
      ]),
    );
  }
}
