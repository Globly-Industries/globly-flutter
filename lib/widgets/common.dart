import 'package:flutter/material.dart';

import '../models/models.dart';

void showMessage(BuildContext context, Object message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message.toString())));
}

IconData mediaIcon(MediaType? type) => switch (type) {
      MediaType.image => Icons.photo,
      MediaType.video => Icons.videocam,
      MediaType.audio => Icons.audiotrack,
      _ => Icons.notes,
    };

String timeAgo(DateTime time) {
  final d = DateTime.now().difference(time.toLocal());
  if (d.inMinutes < 1) return 'just now';
  if (d.inHours < 1) return '${d.inMinutes} min ago';
  if (d.inDays < 1) return '${d.inHours} h ago';
  if (d.inDays < 30) return '${d.inDays} d ago';
  final t = time.toLocal();
  return '${t.day.toString().padLeft(2, '0')}.${t.month.toString().padLeft(2, '0')}.${t.year}';
}

Future<bool> confirm(BuildContext context, String title, String message, {String action = 'Delete'}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(action)),
      ],
    ),
  );
  return result ?? false;
}
