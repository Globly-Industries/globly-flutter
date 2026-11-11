import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../widgets/common.dart';
import 'app_updater.dart';

/// Checks GitHub for a newer release and offers it. With [silent] (the check at startup) nothing is
/// shown when the app is up to date or the check fails.
Future<void> checkForUpdates(BuildContext context, {bool silent = false}) async {
  if (!AppUpdater.supported) return;
  final updater = AppUpdater();
  AppUpdate? update;
  try {
    update = await updater.check();
  } catch (_) {
    if (!silent && context.mounted) showMessage(context, context.l10n.updateCheckFailed);
    return;
  }
  if (!context.mounted) return;
  if (update == null) {
    if (!silent) showMessage(context, context.l10n.upToDate);
    return;
  }
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _UpdateDialog(updater: updater, update: update!),
  );
}

class _UpdateDialog extends StatefulWidget {
  final AppUpdater updater;
  final AppUpdate update;
  const _UpdateDialog({required this.updater, required this.update});

  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<_UpdateDialog> {
  CancelToken? _cancel;
  double? _progress;
  bool _failed = false;

  bool get _downloading => _cancel != null;

  Future<void> _start() async {
    final cancel = CancelToken();
    setState(() {
      _cancel = cancel;
      _progress = null;
      _failed = false;
    });
    try {
      final path = await widget.updater.download(
        widget.update,
        cancel: cancel,
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
      );
      await widget.updater.install(path);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (!mounted || cancel.isCancelled) return;
      setState(() {
        _cancel = null;
        _failed = true;
      });
    }
  }

  void _close() {
    _cancel?.cancel();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final percent = ((_progress ?? 0) * 100).round();

    return AlertDialog(
      icon: const Icon(Icons.system_update_rounded),
      title: Text(l.updateAvailable),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(l.updateAvailableBody(widget.update.version, widget.update.currentVersion)),
        if (_downloading) ...[
          const SizedBox(height: 16),
          LinearProgressIndicator(value: _progress),
          const SizedBox(height: 8),
          Text(l.updateDownloading(percent), style: theme.textTheme.bodySmall),
        ],
        if (_failed) ...[
          const SizedBox(height: 16),
          Text(l.updateFailed, style: TextStyle(color: theme.colorScheme.error)),
        ],
      ]),
      actions: [
        TextButton(onPressed: _close, child: Text(_downloading ? l.cancel : l.updateLater)),
        if (!_downloading)
          FilledButton(onPressed: _start, child: Text(_failed ? l.retry : l.updateNow)),
      ],
    );
  }
}
