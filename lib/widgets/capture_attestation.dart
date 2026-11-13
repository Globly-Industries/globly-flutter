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

/// Attestation chain (base64, comma separated), or the reason there is none.
Future<({String? chain, String? error})> attestCapture({
  required String captureId,
  required String sha256,
  required double latitude,
  required double longitude,
  required bool mockedLocation,
}) async {
  if (kIsWeb) return (chain: null, error: 'web');
  if (defaultTargetPlatform != TargetPlatform.android) return (chain: null, error: 'not_android');
  if (mockedLocation) return (chain: null, error: 'mocked_location');
  try {
    final chain = await _channel.invokeListMethod<Uint8List>('attest', {
      'challenge': Uint8List.fromList(captureChallenge(captureId, sha256, latitude, longitude)),
    });
    if (chain == null || chain.isEmpty) return (chain: null, error: 'empty_chain');
    return (chain: chain.map(base64.encode).join(','), error: null);
  } on PlatformException catch (e) {
    return (chain: null, error: _short('keystore_error: ${e.message ?? e.code}'));
  } catch (e) {
    return (chain: null, error: _short('error: $e'));
  }
}

String _short(String s) => s.length <= 300 ? s : s.substring(0, 300);
