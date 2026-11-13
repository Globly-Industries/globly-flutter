import 'package:flutter_test/flutter_test.dart';
import 'package:globly/widgets/capture_attestation.dart';

void main() {
  // Same vector as the API's AndroidAttestationTests.
  test('challenge matches the API', () {
    final challenge = captureChallenge('0195F3A0-0000-7000-8000-000000000001', 'a' * 64, 56.9496, -24.10525);
    expect(challenge.map((b) => b.toRadixString(16).padLeft(2, '0')).join(), 'b4d279ca0374e8fb252be9fa2899e31b4191c5cc649b18ce46399282926915b6');
  });

  test('location is part of the challenge', () {
    final here = captureChallenge('id', 'a' * 64, 56.9496, 24.1052);
    expect(captureChallenge('id', 'a' * 64, 56.9496004, 24.1052), here);
    expect(captureChallenge('id', 'a' * 64, 56.949601, 24.1052), isNot(here));
  });
}
