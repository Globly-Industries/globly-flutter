import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/models.dart';
import '../theme.dart';
import 'errors.dart';

extension L10nContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

/// Shows a snackbar. Strings are shown as-is; anything else goes through [errorMessage].
void showMessage(BuildContext context, Object message) {
  final text = message is String ? message : errorMessage(context, message);
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));
}

IconData mediaIcon(MediaType? type) => switch (type) {
      MediaType.image => Icons.photo_camera_rounded,
      MediaType.video => Icons.videocam_rounded,
      MediaType.audio => Icons.graphic_eq_rounded,
      _ => Icons.notes_rounded,
    };

String mediaLabel(BuildContext context, MediaType type) => switch (type) {
      MediaType.text => context.l10n.mediaText,
      MediaType.image => context.l10n.mediaImage,
      MediaType.video => context.l10n.mediaVideo,
      MediaType.audio => context.l10n.mediaAudio,
    };

String timeAgo(BuildContext context, DateTime time) {
  final l = context.l10n;
  final d = DateTime.now().difference(time.toLocal());
  if (d.inMinutes < 1) return l.justNow;
  if (d.inHours < 1) return l.minutesAgo(d.inMinutes);
  if (d.inDays < 1) return l.hoursAgo(d.inHours);
  if (d.inDays < 30) return l.daysAgo(d.inDays);
  final t = time.toLocal();
  return '${t.day.toString().padLeft(2, '0')}.${t.month.toString().padLeft(2, '0')}.${t.year}';
}

/// "800 m", "2 km", "2.5 km". The units read the same in English and Latvian.
String formatRadius(int meters) {
  if (meters < 1000) return '$meters m';
  final km = meters / 1000;
  return km == km.roundToDouble() ? '${km.round()} km' : '${km.toStringAsFixed(1)} km';
}

Future<bool> confirm(BuildContext context, String title, String message, {String? action}) async {
  final l = context.l10n;
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.cancel)),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(64, 44)),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(action ?? l.delete),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Coloured circle with the user's initial; the colour is stable per username.
class UserAvatar extends StatelessWidget {
  final String name;
  final double radius;
  const UserAvatar(this.name, {super.key, this.radius = 20});

  static const _palette = [
    Color(0xFF1E88E5), Color(0xFF00897B), Color(0xFF8E24AA), Color(0xFFE53935),
    Color(0xFFF4511E), Color(0xFF3949AB), Color(0xFF43A047), Color(0xFF6D4C41),
  ];

  @override
  Widget build(BuildContext context) {
    final color = _palette[name.codeUnits.fold(0, (a, b) => a + b) % _palette.length];
    return CircleAvatar(
      radius: radius,
      backgroundColor: color,
      child: Text(
        name.isEmpty ? '?' : name.characters.first.toUpperCase(),
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: radius * 0.85),
      ),
    );
  }
}

/// Small rounded label, e.g. content type or moderation state.
class Pill extends StatelessWidget {
  final IconData? icon;
  final String label;
  final Color color;
  const Pill({super.key, this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: 14, color: color), const SizedBox(width: 4)],
        Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

class MediaPill extends StatelessWidget {
  final MediaType type;
  const MediaPill(this.type, {super.key});

  @override
  Widget build(BuildContext context) =>
      Pill(icon: mediaIcon(type), label: mediaLabel(context, type), color: AppTheme.mediaColor(type));
}

/// Friendly placeholder for empty lists and errors.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;
  const EmptyState({super.key, required this.icon, required this.title, this.subtitle, this.action});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: theme.colorScheme.primaryContainer, shape: BoxShape.circle),
          child: Icon(icon, size: 36, color: theme.colorScheme.onPrimaryContainer),
        ),
        const SizedBox(height: 16),
        Text(title, textAlign: TextAlign.center, style: theme.textTheme.titleMedium),
        if (subtitle != null) ...[
          const SizedBox(height: 6),
          Text(subtitle!, textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ],
        if (action != null) ...[const SizedBox(height: 16), action!],
      ]),
    );
  }
}

/// Keeps content readable on wide (web/tablet) screens.
class ContentWidth extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  const ContentWidth({super.key, required this.child, this.maxWidth = 680});

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(constraints: BoxConstraints(maxWidth: maxWidth), child: child),
      );
}

/// Explains to the author (or an admin) why a post is hidden.
class HiddenBanner extends StatelessWidget {
  final Post post;
  const HiddenBanner(this.post, {super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final text = switch (post.hiddenReason) {
      HiddenReason.downvotes => l.hiddenDownvotes,
      HiddenReason.admin => l.hiddenAdmin,
      HiddenReason.automatic => l.hiddenAutomatic,
      _ => l.hiddenReports,
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: scheme.errorContainer, borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        Icon(Icons.visibility_off_rounded, color: scheme.onErrorContainer),
        const SizedBox(width: 12),
        Expanded(child: Text(text, style: TextStyle(color: scheme.onErrorContainer))),
      ]),
    );
  }
}
