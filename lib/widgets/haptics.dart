import 'package:vibration/vibration.dart';

/// Short vibrations that drive the motor directly.
///
/// Flutter's HapticFeedback asks Android for system effects, which depend on the phone and on its
/// touch-feedback setting, and can be too faint to feel on budget phones. The durations are about the
/// shortest that the small motors in such phones still reliably spin up for.
class Haptics {
  /// Something opened or started under the finger.
  static Future<void> press() => _pulse(45);

  /// The finger moved onto another option.
  static Future<void> tick() => _pulse(30);

  static Future<void> _pulse(int milliseconds) async {
    try {
      await Vibration.vibrate(duration: milliseconds);
    } catch (_) {
      // Purely a nicety: never let it get in the way of what the user is doing.
    }
  }
}
