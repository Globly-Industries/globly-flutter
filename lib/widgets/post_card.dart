import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme.dart';
import 'common.dart';

class PostCard extends StatelessWidget {
  final Post post;
  final VoidCallback? onTap;
  final Widget? trailing;

  /// Shorter layout for previews (smaller media, fewer description lines).
  final bool compact;

  const PostCard({super.key, required this.post, this.onTap, this.trailing, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l = context.l10n;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Author row
            Row(children: [
              UserAvatar(post.author.userName, radius: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(post.author.userName, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                  Text(timeAgo(context, post.createdAt),
                      style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                ]),
              ),
              if (post.isHidden) ...[
                Pill(icon: Icons.visibility_off_rounded, label: l.hidden, color: scheme.error),
                const SizedBox(width: 6),
              ],
              trailing ?? MediaPill(post.mediaType),
            ]),
            const SizedBox(height: 12),

            // Media preview
            if (post.media != null && post.mediaType != MediaType.text) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: post.mediaType == MediaType.image
                    ? AspectRatio(
                        aspectRatio: compact ? 16 / 9 : 4 / 3,
                        child: CachedNetworkImage(
                          imageUrl: post.media!.url,
                          fit: BoxFit.cover,
                          placeholder: (_, _) => ColoredBox(color: scheme.surfaceContainerHighest),
                          errorWidget: (_, _, _) => ColoredBox(
                            color: scheme.surfaceContainerHighest,
                            child: const Center(child: Icon(Icons.broken_image_outlined)),
                          ),
                        ),
                      )
                    : _MediaPlaceholder(type: post.mediaType, height: compact ? 90 : 140),
              ),
              const SizedBox(height: 12),
            ],

            // Text
            Text(post.title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            if (post.description?.isNotEmpty ?? false) ...[
              const SizedBox(height: 4),
              Text(
                post.description!,
                maxLines: compact ? 2 : 4,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
            const SizedBox(height: 10),

            // Stats
            Row(children: [
              _Stat(post.myVote == 1 ? Icons.thumb_up_rounded : Icons.thumb_up_outlined, '${post.score}',
                  highlight: post.myVote == 1),
              _Stat(Icons.chat_bubble_outline_rounded, '${post.commentCount}'),
              _Stat(Icons.visibility_outlined, '${post.views}'),
            ]),
          ]),
        ),
      ),
    );
  }
}

class _MediaPlaceholder extends StatelessWidget {
  final MediaType type;
  final double height;
  const _MediaPlaceholder({required this.type, required this.height});

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.mediaColor(type);
    return Container(
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [color.withValues(alpha: 0.85), color.withValues(alpha: 0.55)]),
      ),
      alignment: Alignment.center,
      child: Icon(
        type == MediaType.video ? Icons.play_circle_fill_rounded : Icons.graphic_eq_rounded,
        size: height * 0.4,
        color: Colors.white,
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool highlight;
  const _Stat(this.icon, this.text, {this.highlight = false});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = highlight ? scheme.primary : scheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: Row(children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}
