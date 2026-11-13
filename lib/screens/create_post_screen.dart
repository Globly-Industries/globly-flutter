import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../api/api_client.dart';
import '../models/models.dart';
import '../theme.dart';
import '../widgets/capture_attestation.dart';
import '../widgets/common.dart';
import '../widgets/errors.dart';
import '../widgets/glass.dart';
import '../widgets/location.dart';
import '../widgets/media_capture.dart';

/// Publishing: adds a title and description to media that was just captured (or to a text post).
/// The location is always the device's current position.
class CreatePostScreen extends StatefulWidget {
  final MediaType type;

  /// The captured media; null only for text posts.
  final CapturedMedia? media;

  const CreatePostScreen({super.key, required this.type, this.media});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();

  late CapturedMedia? _media = widget.media;

  XFile? get _file => _media?.file;

  /// Photo bytes for the preview (Image.file is not available on web).
  Uint8List? _previewBytes;

  LatLng? _location;

  /// Set when the device only shares an approximate location.
  int? _locationRadius;
  bool _locationMocked = false;
  Object? _locationError;
  double? _progress;

  MediaType get _type => widget.type;

  @override
  void initState() {
    super.initState();
    _locate();
    _loadPreview();
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _locate() async {
    setState(() => _locationError = null);
    try {
      final here = await currentDeviceLocation();
      if (mounted) {
        setState(() {
          _location = here.point;
          _locationRadius = here.radiusMeters;
          _locationMocked = here.mocked;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _locationError = e);
    }
  }

  Future<void> _loadPreview() async {
    final file = _file;
    if (_type != MediaType.image || file == null) return;
    final bytes = await file.readAsBytes();
    if (mounted) setState(() => _previewBytes = bytes);
  }

  /// Keeps the current media if the user backs out of the new capture.
  Future<void> _retake() async {
    final media = await captureMedia(context, _type);
    if (media == null || !mounted) return;
    setState(() {
      _media = media;
      _previewBytes = null;
    });
    await _loadPreview();
  }

  Future<void> _submit() async {
    final l = context.l10n;
    if (!_form.currentState!.validate()) return;
    if (_location == null) {
      showMessage(context, l.locationRequired);
      return;
    }
    setState(() => _progress = 0);
    try {
      final api = context.read<ApiClient>();
      final media = _media;
      await media?.ensureSealed(api);
      final attestation = media == null
          ? null
          : await attestCapture(
              captureId: media.captureId,
              sha256: media.sha256,
              latitude: _location!.latitude,
              longitude: _location!.longitude,
              mockedLocation: _locationMocked,
            );
      final post = await api.createPost(
            title: _title.text.trim(),
            description: _description.text.trim(),
            mediaType: _type,
            latitude: _location!.latitude,
            longitude: _location!.longitude,
            locationRadiusMeters: _locationRadius,
            file: _file,
            captureId: media?.captureId,
            attestation: attestation?.chain,
            attestationError: attestation?.error,
            onProgress: (sent, total) {
              if (total > 0 && mounted) setState(() => _progress = sent / total);
            },
          );
      if (!mounted) return;
      showMessage(context, post.isHidden ? l.publishedForReview : l.published);
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _progress = null);
        showMessage(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final busy = _progress != null;

    return GlassScaffold(
      appBar: GlassAppBar(
        title: Text(l.newPost),
        bottom: busy
            ? PreferredSize(
                preferredSize: const Size.fromHeight(4),
                child: LinearProgressIndicator(value: _progress! < 1 ? _progress : null),
              )
            : null,
      ),
      body: AbsorbPointer(
        absorbing: busy,
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              ContentWidth(
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  if (_file != null) ...[_mediaPreview(), const SizedBox(height: 16)],
                  TextFormField(
                    controller: _title,
                    decoration: InputDecoration(labelText: l.title),
                    maxLength: 120,
                    validator: (v) => (v?.trim().isEmpty ?? true) ? l.titleRequired : null,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _description,
                    decoration: InputDecoration(
                      labelText: _type == MediaType.text ? l.text : l.descriptionOptional,
                      alignLabelWithHint: true,
                    ),
                    maxLength: 2000,
                    minLines: _type == MediaType.text ? 5 : 3,
                    maxLines: 10,
                    validator: (v) => _type == MediaType.text && (v?.trim().isEmpty ?? true) ? l.writeSomething : null,
                  ),
                  const SizedBox(height: 8),
                  _locationCard(),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: busy ? null : _submit,
                    icon: busy
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5))
                        : const Icon(Icons.send_rounded),
                    label: Text(busy ? l.uploading(((_progress ?? 0) * 100).round()) : l.publish),
                  ),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _locationCard() {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final String text;
    if (_locationRadius != null) {
      text = l.approximateLocation(formatRadius(_locationRadius!));
    } else if (_location != null) {
      text = '${_location!.latitude.toStringAsFixed(5)}, ${_location!.longitude.toStringAsFixed(5)}';
    } else if (_locationError != null) {
      text = errorMessage(context, _locationError!);
    } else {
      text = l.gettingLocation;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          Icon(Icons.place_rounded, color: _locationError != null ? scheme.error : scheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(l.whereCaptured, style: Theme.of(context).textTheme.titleSmall),
              Text(text, style: TextStyle(color: scheme.onSurfaceVariant)),
            ]),
          ),
          if (_locationError != null) TextButton(onPressed: _locate, child: Text(l.retry)),
        ]),
      ),
    );
  }

  Widget _mediaPreview() {
    final l = context.l10n;
    final color = AppTheme.mediaColor(_type);

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(
        height: 220,
        alignment: Alignment.center,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
        ),
        child: _previewBytes != null
            ? Image.memory(_previewBytes!, fit: BoxFit.cover, width: double.infinity, height: double.infinity)
            : Icon(mediaIcon(_type), size: 56, color: color),
      ),
      const SizedBox(height: 10),
      OutlinedButton.icon(
        onPressed: _retake,
        icon: const Icon(Icons.refresh_rounded),
        label: Text(l.retake),
      ),
    ]);
  }
}
