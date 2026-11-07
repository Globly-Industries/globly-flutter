import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/api_client.dart';
import '../models/models.dart';
import '../state/auth_state.dart';
import '../widgets/common.dart';
import '../widgets/media_view.dart';

const quickEmoji = ['👍', '❤️', '😂', '😮', '😢', '🔥'];

/// Full post view with rating: votes, emoji, comments, moderation report; edit/delete for the author.
class PostDetailScreen extends StatefulWidget {
  final String postId;
  const PostDetailScreen({super.key, required this.postId});

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  late final ApiClient _api = context.read<ApiClient>();
  final _commentText = TextEditingController();

  Post? _post;
  Object? _error;
  List<Comment> _comments = [];
  Map<String, int> _emoji = {};
  String _commentKind = 'All';
  bool _sending = false;

  @override
  void initState() {
    super.initState();
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
    final results = await Future.wait([
      _api.comments(widget.postId, kind: _commentKind),
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
    showMessage(context, 'Sign in to rate posts.');
    return false;
  }

  Future<void> _vote(int value) async {
    if (!_requireSignIn()) return;
    final post = _post!;
    final newValue = post.myVote == value ? 0 : value;
    try {
      final (up, down) = await _api.vote(post.id, newValue);
      setState(() => _post = post.copyWith(upvotes: up, downvotes: down, myVote: newValue));
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
    if (!await confirm(context, 'Delete comment?', 'This cannot be undone.')) return;
    try {
      await _api.deleteComment(c.id);
      await _loadRatings();
    } catch (e) {
      if (mounted) showMessage(context, e);
    }
  }

  Future<void> _report() async {
    if (!_requireSignIn()) return;
    final reason = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Request moderation'),
        content: TextField(
          controller: reason,
          decoration: const InputDecoration(labelText: 'Reason (optional)'),
          maxLength: 500,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Report')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _api.report(widget.postId, reason.text.trim().isEmpty ? null : reason.text.trim());
      if (mounted) showMessage(context, 'Thanks, moderators will take a look.');
    } catch (e) {
      if (mounted) showMessage(context, e);
    }
  }

  Future<void> _edit() async {
    final post = _post!;
    final title = TextEditingController(text: post.title);
    final description = TextEditingController(text: post.description);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit post'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: title, decoration: const InputDecoration(labelText: 'Title'), maxLength: 120),
          TextField(
            controller: description,
            decoration: const InputDecoration(labelText: 'Description'),
            maxLength: 2000,
            maxLines: 4,
            minLines: 1,
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );
    if (ok != true || title.text.trim().isEmpty) return;
    try {
      final updated = await _api.updatePost(post.id, title: title.text.trim(), description: description.text.trim());
      setState(() => _post = updated);
    } catch (e) {
      if (mounted) showMessage(context, e);
    }
  }

  Future<void> _delete() async {
    if (!await confirm(context, 'Delete post?', 'The post and its media will be removed permanently.')) return;
    try {
      await _api.deletePost(widget.postId);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) showMessage(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();
    final post = _post;

    if (post == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: _error != null ? Text(_error.toString()) : const CircularProgressIndicator()),
      );
    }

    final isOwner = auth.user?.id == post.author.id;
    final canModify = isOwner || auth.isAdmin;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(post.author.userName),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) => switch (v) {
              'edit' => _edit(),
              'delete' => _delete(),
              _ => _report(),
            },
            itemBuilder: (_) => [
              if (canModify) const PopupMenuItem(value: 'edit', child: Text('Edit')),
              if (canModify) const PopupMenuItem(value: 'delete', child: Text('Delete')),
              if (!isOwner) const PopupMenuItem(value: 'report', child: Text('Request moderation')),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          children: [
            MediaView(post: post),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(post.title, style: theme.textTheme.headlineSmall),
                const SizedBox(height: 4),
                Text(
                  '${timeAgo(post.createdAt)} · ${post.latitude.toStringAsFixed(4)}, ${post.longitude.toStringAsFixed(4)} · ${post.views} views',
                  style: theme.textTheme.bodySmall,
                ),
                if (post.description?.isNotEmpty ?? false) ...[
                  const SizedBox(height: 12),
                  Text(post.description!, style: theme.textTheme.bodyLarge),
                ],
              ]),
            ),
            // Votes
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(children: [
                IconButton(
                  icon: Icon(post.myVote == 1 ? Icons.thumb_up : Icons.thumb_up_outlined),
                  onPressed: () => _vote(1),
                ),
                Text('${post.upvotes}'),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(post.myVote == -1 ? Icons.thumb_down : Icons.thumb_down_outlined),
                  onPressed: () => _vote(-1),
                ),
                Text('${post.downvotes}'),
              ]),
            ),
            // Emoji reactions
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Wrap(spacing: 6, children: [
                for (final e in quickEmoji)
                  ActionChip(
                    label: Text(_emoji[e] == null ? e : '$e ${_emoji[e]}'),
                    onPressed: _sending ? null : () => _send(emoji: e),
                  ),
              ]),
            ),
            const Divider(height: 32),
            // Comments header + filter
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(children: [
                Text('Comments', style: theme.textTheme.titleMedium),
                const Spacer(),
                DropdownButton<String>(
                  value: _commentKind,
                  underline: const SizedBox.shrink(),
                  items: const [
                    DropdownMenuItem(value: 'All', child: Text('All')),
                    DropdownMenuItem(value: 'Text', child: Text('Text only')),
                    DropdownMenuItem(value: 'Emoji', child: Text('Emoji only')),
                  ],
                  onChanged: (v) {
                    setState(() => _commentKind = v!);
                    _loadRatings();
                  },
                ),
              ]),
            ),
            if (auth.isSignedIn)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 8, 8),
                child: Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _commentText,
                      decoration: const InputDecoration(hintText: 'Add a comment...'),
                      maxLength: 1000,
                      minLines: 1,
                      maxLines: 4,
                    ),
                  ),
                  IconButton(icon: const Icon(Icons.send), onPressed: _sending ? null : () => _send()),
                ]),
              ),
            for (final c in _comments)
              ListTile(
                leading: c.emoji != null && c.body == null
                    ? Text(c.emoji!, style: const TextStyle(fontSize: 24))
                    : CircleAvatar(child: Text(c.author.userName.characters.first.toUpperCase())),
                title: Text(c.author.userName),
                subtitle: Text([if (c.emoji != null && c.body != null) c.emoji, c.body ?? 'reacted ${c.emoji}']
                    .whereType<String>()
                    .join(' ')),
                trailing: (auth.user?.id == c.author.id || auth.isAdmin)
                    ? IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => _deleteComment(c))
                    : Text(timeAgo(c.createdAt), style: theme.textTheme.bodySmall),
              ),
            if (_comments.isEmpty)
              const Padding(padding: EdgeInsets.all(24), child: Center(child: Text('No comments yet.'))),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
