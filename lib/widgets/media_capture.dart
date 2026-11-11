import 'dart:async';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/api_client.dart';
import '../models/models.dart';
import 'common.dart';
import 'errors.dart';
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

/// Media captured in the app, bound to a server capture ticket (see the API's CapturesController):
/// the ticket is issued right before capturing and sealed with the file's SHA-256 right after, so
/// the server only accepts this exact file, captured just now.
class CapturedMedia {
  final MediaType type;
  final XFile file;
  final String captureId;
  final String sha256;

  /// False when sealing failed (usually no network); [ensureSealed] retries before publishing.
  bool sealed = false;

  CapturedMedia(this.type, this.file, this.captureId, this.sha256);

  Future<void> ensureSealed(ApiClient api) async {
    if (sealed) return;
    await api.sealCapture(captureId, sha256);
    sealed = true;
  }
}

/// The ticket of a capture in progress. Android may kill the app while its camera is open, so the
/// ticket has to outlive the process for [recoverCapture].
const _pendingTicketKey = 'pendingCaptureTicket';

/// Opens the camera app (photo, video) or the recorder (audio). Null if the user backed out or no
/// capture ticket could be had.
Future<CapturedMedia?> captureMedia(BuildContext context, MediaType type) async {
  final failed = context.l10n.captureFailed;
  final messenger = ScaffoldMessenger.of(context);
  final api = context.read<ApiClient>();
  void fail(String message) => messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));

  final String captureId;
  try {
    captureId = await api.startCapture(type);
  } catch (e) {
    if (context.mounted) fail(errorMessage(context, e));
    return null;
  }

  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_pendingTicketKey, '${type.name}:$captureId');
  try {
    if (!context.mounted) return null;
    final picker = ImagePicker();
    final Future<XFile?> capture = switch (type) {
      MediaType.image => picker.pickImage(source: ImageSource.camera, imageQuality: 85, maxWidth: 2560),
      MediaType.video => picker.pickVideo(source: ImageSource.camera, maxDuration: _maxDuration),
      MediaType.audio => showGlassSheet<XFile>(context, builder: (_) => const _AudioRecorder()),
      MediaType.text => Future.value(),
    };
    final file = await capture;
    if (file == null) return null;
    return await _seal(api, type, file, captureId);
  } catch (_) {
    fail(failed);
    return null;
  } finally {
    await prefs.remove(_pendingTicketKey);
  }
}

/// Hashes the file and seals its ticket. Sealing may fail offline; publishing retries it.
Future<CapturedMedia> _seal(ApiClient api, MediaType type, XFile file, String captureId) async {
  final hash = (await sha256.bind(file.openRead()).first).toString();
  final media = CapturedMedia(type, file, captureId, hash);
  try {
    await media.ensureSealed(api);
  } catch (_) {
    // Left unsealed: CreatePostScreen seals before uploading and shows any error then.
  }
  return media;
}

/// Android may close the app while the camera is open (common on low-memory phones). The photo or
/// video then arrives on the next launch, and this hands it back with the ticket it was taken under.
Future<CapturedMedia?> recoverCapture(ApiClient api) async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return null;
  try {
    final lost = await ImagePicker().retrieveLostData();
    final prefs = await SharedPreferences.getInstance();
    final pending = prefs.getString(_pendingTicketKey)?.split(':');
    await prefs.remove(_pendingTicketKey);

    final file = lost.file;
    if (lost.isEmpty || file == null || pending == null || pending.length != 2) return null;
    final type = lost.type == RetrieveType.video ? MediaType.video : MediaType.image;
    if (pending[0] != type.name) return null;
    return await _seal(api, type, file, pending[1]);
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
