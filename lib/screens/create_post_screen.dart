import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../api/api_client.dart';
import '../config.dart';
import '../models/models.dart';
import '../widgets/common.dart';
import '../widgets/location.dart';

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
  String? _locationError;
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
      if (mounted) setState(() => _locationError = e.toString());
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
    } catch (e) {
      if (mounted) showMessage(context, 'Could not open picker: $e');
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
    if (!_form.currentState!.validate()) return;
    if (_type != MediaType.text && _file == null) {
      showMessage(context, 'Choose a file first.');
      return;
    }
    if (_location == null) {
      showMessage(context, 'Location is required.');
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
      showMessage(context, 'Post published.');
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
    final busy = _progress != null;
    return Scaffold(
      appBar: AppBar(
        title: const Text('New post'),
        actions: [
          TextButton(onPressed: busy ? null : _submit, child: const Text('Publish')),
        ],
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
            padding: const EdgeInsets.all(16),
            children: [
              SegmentedButton<MediaType>(
                segments: [
                  for (final t in MediaType.values)
                    ButtonSegment(value: t, icon: Icon(mediaIcon(t)), label: Text(t.apiName)),
                ],
                selected: {_type},
                onSelectionChanged: (s) => setState(() {
                  _type = s.first;
                  _file = null;
                  _previewBytes = null;
                }),
              ),
              const SizedBox(height: 16),
              if (_type != MediaType.text) _mediaPicker(),
              const SizedBox(height: 16),
              TextFormField(
                controller: _title,
                decoration: const InputDecoration(labelText: 'Title', border: OutlineInputBorder()),
                maxLength: 120,
                validator: (v) => (v?.trim().isEmpty ?? true) ? 'Title is required' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _description,
                decoration: InputDecoration(
                  labelText: _type == MediaType.text ? 'Text' : 'Description (optional)',
                  border: const OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                maxLength: 2000,
                minLines: 3,
                maxLines: 8,
                validator: (v) =>
                    _type == MediaType.text && (v?.trim().isEmpty ?? true) ? 'Write something' : null,
              ),
              const SizedBox(height: 8),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.place),
                  title: Text(_location == null
                      ? (_locationError ?? 'Getting your location...')
                      : '${_location!.latitude.toStringAsFixed(5)}, ${_location!.longitude.toStringAsFixed(5)}'),
                  subtitle: const Text('Where was this captured?'),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(tooltip: 'Use my location', icon: const Icon(Icons.my_location), onPressed: _locate),
                    IconButton(tooltip: 'Pick on map', icon: const Icon(Icons.map), onPressed: _pickOnMap),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _mediaPicker() {
    final preview = _file == null
        ? Icon(mediaIcon(_type), size: 64)
        : _previewBytes != null
            ? Image.memory(_previewBytes!, fit: BoxFit.cover, width: double.infinity)
            : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(mediaIcon(_type), size: 48),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(_file!.name, textAlign: TextAlign.center),
                ),
              ]);

    return Column(children: [
      Container(
        height: 220,
        alignment: Alignment.center,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: preview,
      ),
      const SizedBox(height: 8),
      if (_type == MediaType.audio)
        OutlinedButton.icon(onPressed: () => _pick(null), icon: const Icon(Icons.folder_open), label: const Text('Choose audio file'))
      else
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _pick(ImageSource.camera),
              icon: Icon(_type == MediaType.video ? Icons.videocam : Icons.photo_camera),
              label: const Text('Camera'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _pick(ImageSource.gallery),
              icon: const Icon(Icons.photo_library),
              label: const Text('Gallery'),
            ),
          ),
        ]),
    ]);
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tap to choose location'),
        actions: [
          TextButton(
            onPressed: _picked == null ? null : () => Navigator.pop(context, _picked),
            child: const Text('Done'),
          ),
        ],
      ),
      body: FlutterMap(
        options: MapOptions(
          initialCenter: widget.initial ?? const LatLng(30, 10),
          initialZoom: widget.initial == null ? 2.5 : 14,
          onTap: (_, point) => setState(() => _picked = point),
        ),
        children: [
          TileLayer(urlTemplate: AppConfig.tileUrlTemplate, userAgentPackageName: AppConfig.userAgentPackageName),
          if (_picked != null)
            MarkerLayer(markers: [
              Marker(
                point: _picked!,
                width: 40,
                height: 40,
                alignment: Alignment.topCenter,
                child: Icon(Icons.location_pin, size: 40, color: Theme.of(context).colorScheme.error),
              ),
            ]),
        ],
      ),
    );
  }
}
