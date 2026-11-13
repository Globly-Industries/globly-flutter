import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/api_client.dart';
import '../models/models.dart';
import '../state/auth_state.dart';
import 'common.dart';
import 'errors.dart';
import 'glass.dart';
import 'mention_text.dart';

const _maxCommentLength = 1000;

/// Opens a post's comments in a sheet over the feed, so reading and writing them doesn't leave it.
/// [onCountChanged] gets the post's new comment count whenever one is added or deleted.
Future<void> showCommentsSheet(BuildContext context, Post post, {required ValueChanged<int> onCountChanged}) =>
    showGlassSheet<void>(
      context,
      builder: (_) => _CommentsSheet(post: post, onCountChanged: onCountChanged),
    );

class _CommentsSheet extends StatefulWidget {
  final Post post;
  final ValueChanged<int> onCountChanged;
  const _CommentsSheet({required this.post, required this.onCountChanged});

  @override
  State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
  late final ApiClient _api = context.read<ApiClient>();
  final _text = TextEditingController();
  final _focus = FocusNode();
  List<Comment>? _comments;
  Object? _error;
  bool _sending = false;
  late int _count = widget.post.commentCount;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final page = await _api.comments(widget.post.id);
      if (mounted) setState(() => _comments = page.items);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  void _changeCount(int delta) {
    _count = (_count + delta).clamp(0, 1 << 30);
    widget.onCountChanged(_count);
  }

  Future<void> _send() async {
    final body = _text.text.trim();
    if (body.isEmpty) return;
    setState(() => _sending = true);
    try {
      await _api.addComment(widget.post.id, body);
      _text.clear();
      _changeCount(1);
      await _load();
    } catch (e) {
      if (mounted) showMessage(context, e);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _delete(Comment c) async {
    final l = context.l10n;
    if (!await confirm(context, l.deleteCommentTitle, l.cannotUndo)) return;
    try {
      await _api.deleteComment(c.id);
      _changeCount(-1);
      await _load();
    } catch (e) {
      if (mounted) showMessage(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final auth = context.watch<AuthState>();
    final media = MediaQuery.of(context);
    final comments = _comments;

    final Widget list;
    if (comments == null) {
      list = Center(
        child: _error != null
            ? EmptyState(icon: Icons.cloud_off_rounded, title: errorMessage(context, _error!))
            : const CircularProgressIndicator(),
      );
    } else if (comments.isEmpty) {
      list = Center(
        child: Text(l.noComments, style: TextStyle(color: scheme.onSurfaceVariant)),
      );
    } else {
      list = ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: comments.length,
        itemBuilder: (context, i) {
          final c = comments[i];
          final canDelete = auth.user?.id == c.author.id || auth.isAdmin;
          final canReply = auth.isSignedIn && auth.user?.id != c.author.id;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                UserAvatar(c.author.userName, radius: 16),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              c.author.userName,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            timeAgo(context, c.createdAt),
                            style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      MentionText(c.body, style: theme.textTheme.bodyMedium),
                      if (canReply) ReplyButton(onPressed: () => startReply(_text, _focus, c.author.userName)),
                    ],
                  ),
                ),
                if (canDelete)
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: Icon(Icons.delete_outline_rounded, color: scheme.onSurfaceVariant),
                    onPressed: () => _delete(c),
                  ),
              ],
            ),
          );
        },
      );
    }

    return Padding(
      // Rides up with the keyboard.
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: SizedBox(
        height: media.size.height * 0.6,
        child: Column(
          children: [
            Text(l.comments, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Expanded(child: list),
            const Divider(height: 1),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                child: auth.isSignedIn
                    ? TextField(
                        controller: _text,
                        focusNode: _focus,
                        maxLength: _maxCommentLength,
                        minLines: 1,
                        maxLines: 4,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _send(),
                        decoration: InputDecoration(
                          hintText: l.addComment,
                          counterText: '',
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.send_rounded),
                            color: scheme.primary,
                            onPressed: _sending ? null : _send,
                          ),
                        ),
                      )
                    : Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text(l.signInToRate, style: TextStyle(color: scheme.onSurfaceVariant)),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
