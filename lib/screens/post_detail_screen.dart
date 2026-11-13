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
import '../widgets/mention_text.dart';

const _quickEmoji = ['👍', '❤️', '😂', '😮', '😢', '🔥'];
const _maxCommentLength = 1000;

/// Full post with rating (votes, comments, report) and edit/delete for the author.
/// Pops with `true` if the post changed (edited, deleted or hidden) so lists can refresh.
class PostDetailScreen extends StatefulWidget {
  final String postId;

  /// Already-loaded copy to show instantly while the full post loads.
  final Post? initial;

  const PostDetailScreen({super.key, required this.postId, this.initial});

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  late final ApiClient _api = context.read<ApiClient>();
  final _commentText = TextEditingController();
  final _commentFocus = FocusNode();

  Post? _post;
  Object? _error;
  List<Comment> _comments = [];
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
    _commentFocus.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final post = await _api.post(widget.postId);
      if (mounted) setState(() => _post = post);
      await _loadComments();
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _loadComments() async {
    final page = await _api.comments(widget.postId);
    if (mounted) setState(() => _comments = page.items);
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

  /// Smiley button in the comment field; opens a small bubble of quick emoji that type into the comment.
  /// The bubble opens at the smiley's left edge; shift it left so its right edge lines up with the
  /// send button's (the smiley and send are two 48-wide icon buttons). Fixed sizes keep the width known.
  static const _emojiButtonSize = 40.0;
  static const _emojiBubblePadding = 4.0;
  static final _emojiBubbleWidth = _quickEmoji.length * _emojiButtonSize + 2 * _emojiBubblePadding;

  Widget _emojiPicker(ColorScheme scheme) {
    return MenuAnchor(
      alignmentOffset: Offset(2 * 48 - _emojiBubbleWidth, 8),
      style: MenuStyle(
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: _emojiBubblePadding),
        ),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        ),
      ),
      menuChildren: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final e in _quickEmoji)
              Builder(
                builder: (context) => IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(width: _emojiButtonSize, height: _emojiButtonSize),
                  style: const ButtonStyle(tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                  icon: Text(e, style: const TextStyle(fontSize: 22)),
                  onPressed: () {
                    _insertEmoji(e);
                    MenuController.maybeOf(context)?.close();
                  },
                ),
              ),
          ],
        ),
      ],
      builder: (context, menu, _) => IconButton(
        icon: const Icon(Icons.emoji_emotions_outlined),
        color: menu.isOpen ? scheme.primary : scheme.onSurfaceVariant,
        onPressed: () => menu.isOpen ? menu.close() : menu.open(),
      ),
    );
  }

  /// Types [emoji] into the comment at the cursor (replacing any selection), or at the end if it has no cursor.
  void _insertEmoji(String emoji) {
    final value = _commentText.value;
    if (value.text.length + emoji.length > _maxCommentLength) return;
    final sel = value.selection;
    final start = sel.isValid ? sel.start : value.text.length;
    final end = sel.isValid ? sel.end : value.text.length;
    _commentText.value = TextEditingValue(
      text: value.text.replaceRange(start, end, emoji),
      selection: TextSelection.collapsed(offset: start + emoji.length),
    );
  }

  Future<void> _send() async {
    if (!_requireSignIn()) return;
    final body = _commentText.text.trim();
    if (body.isEmpty) return;
    setState(() => _sending = true);
    try {
      await _api.addComment(widget.postId, body);
      _commentText.clear();
      await _loadComments();
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
      await _loadComments();
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
              const Divider(height: 40),

              // Comments
              Text(l.comments, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
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
                      focusNode: _commentFocus,
                      decoration: InputDecoration(
                        hintText: l.addComment,
                            suffixIcon: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _emojiPicker(scheme),
                                IconButton(
                                  icon: const Icon(Icons.send_rounded),
                                  color: scheme.primary,
                                  onPressed: _sending ? null : () => _send(),
                                ),
                              ],
                            ),
                      ),
                          maxLength: _maxCommentLength,
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
    final canReply = auth.isSignedIn && auth.user?.id != c.author.id;

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
              MentionText(c.body, style: theme.textTheme.bodyMedium),
              if (canReply)
                ReplyButton(onPressed: () => startReply(_commentText, _commentFocus, c.author.userName)),
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
