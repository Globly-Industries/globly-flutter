import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../api/api_client.dart';
import '../models/models.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/errors.dart';
import '../widgets/location.dart';
import '../widgets/map_tiles.dart';

/// Publishing: media (photo / video / audio) or text, tied to where it was captured.
class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _picker = ImagePicker();

  MediaType _type = MediaType.image;

  /// Picked media. XFile works on Android (file path) and web (in-memory blob).
  XFile? _file;

  /// Image bytes for the preview (Image.file is not available on web).
  Uint8List? _previewBytes;

  LatLng? _location;
  Object? _locationError;
  double? _progress;

  @override
  void initState() {
    super.initState();
    _locate();
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
      final here = await currentLocation();
      if (mounted) setState(() => _location = here);
    } catch (e) {
      if (mounted) setState(() => _locationError = e);
    }
  }

  Future<void> _pick(ImageSource? source) async {
    XFile? file;
    Uint8List? preview;
    try {
      switch (_type) {
        case MediaType.image:
          file = await _picker.pickImage(source: source!, imageQuality: 85, maxWidth: 2560);
          preview = await file?.readAsBytes();
        case MediaType.video:
          file = await _picker.pickVideo(source: source!, maxDuration: const Duration(minutes: 3));
        case MediaType.audio:
          // On web there is no file path, so ask for the bytes there.
          final result = await FilePicker.platform.pickFiles(type: FileType.audio, withData: kIsWeb);
          final picked = result?.files.single;
          if (picked != null) {
            file = kIsWeb
                ? XFile.fromData(picked.bytes!, name: picked.name)
                : XFile(picked.path!, name: picked.name);
          }
        case MediaType.text:
          return;
      }
    } catch (_) {
      if (mounted) showMessage(context, context.l10n.pickerFailed);
    }
    if (file != null && mounted) {
      setState(() {
        _file = file;
        _previewBytes = preview;
      });
    }
  }

  Future<void> _pickOnMap() async {
    final picked = await Navigator.push<LatLng>(
      context,
      MaterialPageRoute(builder: (_) => _LocationPicker(initial: _location)),
    );
    if (picked != null) setState(() => _location = picked);
  }

  Future<void> _submit() async {
    final l = context.l10n;
    if (!_form.currentState!.validate()) return;
    if (_type != MediaType.text && _file == null) {
      showMessage(context, l.chooseFileFirst);
      return;
    }
    if (_location == null) {
      showMessage(context, l.locationRequired);
      return;
    }
    setState(() => _progress = 0);
    try {
      await context.read<ApiClient>().createPost(
            title: _title.text.trim(),
            description: _description.text.trim(),
            mediaType: _type,
            latitude: _location!.latitude,
            longitude: _location!.longitude,
            file: _type == MediaType.text ? null : _file,
            onProgress: (sent, total) {
              if (total > 0 && mounted) setState(() => _progress = sent / total);
            },
          );
      if (!mounted) return;
      showMessage(context, l.published);
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

    return Scaffold(
      appBar: AppBar(
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
                  // Content type
                  Row(children: [
                    for (final t in MediaType.values)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: _TypeTile(
                            type: t,
                            selected: _type == t,
                            onTap: () => setState(() {
                              _type = t;
                              _file = null;
                              _previewBytes = null;
                            }),
                          ),
                        ),
                      ),
                  ]),
                  const SizedBox(height: 16),
                  if (_type != MediaType.text) ...[_mediaPicker(), const SizedBox(height: 16)],
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
    if (_location != null) {
      text = '${_location!.latitude.toStringAsFixed(5)}, ${_location!.longitude.toStringAsFixed(5)}';
    } else if (_locationError != null) {
      text = errorMessage(context, _locationError!);
    } else {
      text = l.gettingLocation;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.place_rounded, color: _location != null ? scheme.primary : scheme.error),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(l.whereCaptured, style: Theme.of(context).textTheme.titleSmall),
                Text(text, style: TextStyle(color: scheme.onSurfaceVariant)),
              ]),
            ),
          ]),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40)),
              onPressed: _locate,
              icon: const Icon(Icons.my_location_rounded, size: 18),
              label: Text(l.useMyLocation),
            ),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40)),
              onPressed: _pickOnMap,
              icon: const Icon(Icons.map_rounded, size: 18),
              label: Text(l.pickOnMap),
            ),
          ]),
        ]),
      ),
    );
  }

  Widget _mediaPicker() {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final color = AppTheme.mediaColor(_type);

    final Widget preview;
    if (_previewBytes != null) {
      preview = Image.memory(_previewBytes!, fit: BoxFit.cover, width: double.infinity, height: double.infinity);
    } else if (_file != null) {
      preview = Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(mediaIcon(_type), size: 48, color: color),
        Padding(
          padding: const EdgeInsets.all(8),
          child: Text(_file!.name, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w600)),
        ),
      ]);
    } else {
      preview = Icon(mediaIcon(_type), size: 56, color: color.withValues(alpha: 0.6));
    }

    return Column(children: [
      Container(
        height: 220,
        alignment: Alignment.center,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
        ),
        child: preview,
      ),
      const SizedBox(height: 10),
      if (_type == MediaType.audio)
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => _pick(null),
            icon: const Icon(Icons.folder_open_rounded),
            label: Text(l.chooseAudio),
          ),
        )
      else
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _pick(ImageSource.camera),
              icon: Icon(_type == MediaType.video ? Icons.videocam_rounded : Icons.photo_camera_rounded),
              label: Text(l.camera),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _pick(ImageSource.gallery),
              icon: const Icon(Icons.photo_library_rounded),
              label: Text(l.gallery),
            ),
          ),
        ]),
      if (_file != null)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(_file!.name, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
        ),
    ]);
  }
}

class _TypeTile extends StatelessWidget {
  final MediaType type;
  final bool selected;
  final VoidCallback onTap;
  const _TypeTile({required this.type, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.mediaColor(type);
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: selected ? color : scheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Column(children: [
            Icon(mediaIcon(type), color: selected ? Colors.white : color, size: 26),
            const SizedBox(height: 6),
            Text(
              mediaLabel(context, type),
              style: TextStyle(fontWeight: FontWeight.w600, color: selected ? Colors.white : scheme.onSurface),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Full-screen map; tap to choose a location.
class _LocationPicker extends StatefulWidget {
  final LatLng? initial;
  const _LocationPicker({this.initial});

  @override
  State<_LocationPicker> createState() => _LocationPickerState();
}

class _LocationPickerState extends State<_LocationPicker> {
  LatLng? _picked;

  @override
  void initState() {
    super.initState();
    _picked = widget.initial;
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l.tapToChoose)),
      floatingActionButton: _picked == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () => Navigator.pop(context, _picked),
              icon: const Icon(Icons.check_rounded),
              label: Text(l.done),
            ),
      body: FlutterMap(
        options: MapOptions(
          initialCenter: widget.initial ?? const LatLng(35, 15),
          initialZoom: widget.initial == null ? 2.5 : 14,
          onTap: (_, point) => setState(() => _picked = point),
        ),
        children: [
          const AppTileLayer(),
          const AppAttribution(),
          if (_picked != null)
            MarkerLayer(markers: [
              Marker(
                point: _picked!,
                width: 48,
                height: 48,
                alignment: Alignment.topCenter,
                child: Icon(Icons.location_on_rounded, size: 48, color: Theme.of(context).colorScheme.error),
              ),
            ]),
        ],
      ),
    );
  }
}
