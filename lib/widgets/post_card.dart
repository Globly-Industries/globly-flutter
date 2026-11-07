import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/models.dart';
import 'common.dart';

class PostCard extends StatelessWidget {
  final Post post;
  final VoidCallback? onTap;
  final Widget? trailing;

  const PostCard({super.key, required this.post, this.onTap, this.trailing});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              leading: CircleAvatar(child: Text(post.author.userName.characters.first.toUpperCase())),
              title: Text(post.author.userName),
              subtitle: Text(timeAgo(post.createdAt)),
              trailing: trailing ?? Icon(mediaIcon(post.mediaType)),
            ),
            if (post.mediaType == MediaType.image && post.media != null)
              AspectRatio(
                aspectRatio: 4 / 3,
                child: CachedNetworkImage(
                  imageUrl: post.media!.url,
                  fit: BoxFit.cover,
                  placeholder: (_, _) => const ColoredBox(color: Colors.black12),
                  errorWidget: (_, _, _) => const Center(child: Icon(Icons.broken_image)),
                ),
              )
            else if (post.mediaType == MediaType.video || post.mediaType == MediaType.audio)
              Container(
                height: 120,
                color: theme.colorScheme.surfaceContainerHighest,
                alignment: Alignment.center,
                child: Icon(
                  post.mediaType == MediaType.video ? Icons.play_circle_outline : Icons.graphic_eq,
                  size: 56,
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(post.title, style: theme.textTheme.titleMedium),
            ),
            if (post.description?.isNotEmpty ?? false)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(post.description!, maxLines: 3, overflow: TextOverflow.ellipsis),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
              child: Row(
                children: [
                  _Stat(Icons.thumb_up_alt_outlined, '${post.score}'),
                  _Stat(Icons.chat_bubble_outline, '${post.commentCount}'),
                  _Stat(Icons.visibility_outlined, '${post.views}'),
                  if (post.isFlagged) ...[
                    const Spacer(),
                    Icon(Icons.flag, size: 18, color: theme.colorScheme.error),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Stat(this.icon, this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(children: [Icon(icon, size: 18), const SizedBox(width: 4), Text(text)]),
      );
}
