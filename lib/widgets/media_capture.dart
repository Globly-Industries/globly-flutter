import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../models/models.dart';
import 'common.dart';
import 'glass.dart';

/// Posts are captured on the spot, never picked from storage.
///
/// Desktop browsers have no camera flow: asking for one there opens a file dialog instead.
bool get canUseCamera =>
    !kIsWeb || defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS;

/// The kinds of post that can be made on this device, in wheel order.
List<MediaType> get availablePostTypes => [
      if (canUseCamera) MediaType.image,
      if (canUseCamera) MediaType.video,
      MediaType.audio,
      MediaType.text,
    ];

const _maxDuration = Duration(minutes: 3);

/// Opens the camera app (photo, video) or the recorder (audio). Null if the user backed out.
Future<XFile?> captureMedia(BuildContext context, MediaType type) async {
  final failed = context.l10n.captureFailed;
  final messenger = ScaffoldMessenger.of(context);
  try {
    final picker = ImagePicker();
    final Future<XFile?> capture = switch (type) {
      MediaType.image => picker.pickImage(source: ImageSource.camera, imageQuality: 85, maxWidth: 2560),
      MediaType.video => picker.pickVideo(source: ImageSource.camera, maxDuration: _maxDuration),
      MediaType.audio => showGlassSheet<XFile>(context, builder: (_) => const _AudioRecorder()),
      MediaType.text => Future.value(),
    };
    return await capture;
  } catch (_) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(failed)));
    return null;
  }
}

/// Android may close the app while the camera is open (common on low-memory phones). The photo or
/// video then arrives on the next launch, and this hands it back.
Future<(MediaType, XFile)?> recoverCapture() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return null;
  try {
    final lost = await ImagePicker().retrieveLostData();
    final file = lost.file;
    if (lost.isEmpty || file == null) return null;
    return (lost.type == RetrieveType.video ? MediaType.video : MediaType.image, file);
  } catch (_) {
    return null; // Only a recovery attempt: nothing should stop the app starting over this.
  }
}

/// Records as soon as it opens; Stop hands back the file, closing it any other way discards it.
class _AudioRecorder extends StatefulWidget {
  const _AudioRecorder();

  @override
  State<_AudioRecorder> createState() => _AudioRecorderState();
}

class _AudioRecorderState extends State<_AudioRecorder> {
  final _recorder = AudioRecorder();
  final _elapsed = Stopwatch();
  Timer? _ticker;
  bool _recording = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    if (_recording) _recorder.cancel();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    final l = context.l10n;
    try {
      if (!await _recorder.hasPermission()) {
        if (mounted) {
          showMessage(context, l.microphoneNeeded);
          Navigator.pop(context);
        }
        return;
      }
      final directory = kIsWeb ? null : await getTemporaryDirectory();
      await _recorder.start(
        // WAV in browsers: their native format is .webm, which the API takes for video.
        RecordConfig(encoder: kIsWeb ? AudioEncoder.wav : AudioEncoder.aacLc, numChannels: 1),
        path: directory == null ? '' : '${directory.path}/globly_${DateTime.now().millisecondsSinceEpoch}.m4a',
      );
      if (!mounted) return;
      _elapsed.start();
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (_elapsed.elapsed >= _maxDuration) {
          _stop();
        } else {
          setState(() {});
        }
      });
      setState(() => _recording = true);
    } catch (_) {
      if (mounted) {
        showMessage(context, l.captureFailed);
        Navigator.pop(context);
      }
    }
  }

  Future<void> _stop() async {
    if (!_recording) return;
    _ticker?.cancel();
    _recording = false;
    final path = await _recorder.stop();
    if (!mounted) return;
    Navigator.pop(context, path == null ? null : XFile(path, name: 'recording.wav'));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final time = _elapsed.elapsed;
    final seconds = time.inSeconds.remainder(60).toString().padLeft(2, '0');

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.fiber_manual_record_rounded, size: 16, color: theme.colorScheme.error),
            const SizedBox(width: 6),
            Text(l.recording, style: theme.textTheme.titleMedium),
          ]),
          const SizedBox(height: 12),
          Text(
            '${time.inMinutes}:$seconds',
            textAlign: TextAlign.center,
            style: theme.textTheme.displayMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _recording ? _stop : null,
            icon: const Icon(Icons.stop_rounded),
            label: Text(l.stopRecording),
          ),
          const SizedBox(height: 8),
          TextButton(onPressed: () => Navigator.pop(context), child: Text(l.cancel)),
        ]),
      ),
    );
  }
}
