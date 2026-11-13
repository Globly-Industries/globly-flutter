import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

const _channel = MethodChannel('globly/attestation');

/// Must match AndroidAttestation.Challenge in the API.
@visibleForTesting
List<int> captureChallenge(String captureId, String sha256, double latitude, double longitude) {
  int e6(double degrees) => (degrees * 1000000).round();
  final text = 'globly-capture|${captureId.toLowerCase()}|$sha256|${e6(latitude)}|${e6(longitude)}';
  return _hash(utf8.encode(text));
}

List<int> _hash(List<int> bytes) => sha256.convert(bytes).bytes;

/// Attestation chain (base64, comma separated), or null on web, unsupported phones or mocked location.
Future<String?> attestCapture({
  required String captureId,
  required String sha256,
  required double latitude,
  required double longitude,
  required bool mockedLocation,
}) async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android || mockedLocation) return null;
  try {
    final chain = await _channel.invokeListMethod<Uint8List>('attest', {
      'challenge': Uint8List.fromList(captureChallenge(captureId, sha256, latitude, longitude)),
    });
    if (chain == null || chain.isEmpty) return null;
    return chain.map(base64.encode).join(',');
  } catch (_) {
    return null;
  }
}
