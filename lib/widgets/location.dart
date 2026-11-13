import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

/// Why the location could not be read (translated by widgets/errors.dart).
enum LocationError implements Exception { servicesOff, denied, unavailable }

/// A [LocationError] with the browser's own explanation, shown with the message so that the
/// different causes behind the same error code can be told apart.
class LocationException implements Exception {
  final LocationError reason;
  final String? detail;

  const LocationException(this.reason, [this.detail]);

  @override
  String toString() => 'LocationException($reason, $detail)';
}

/// The device position. [radiusMeters] is set when the user only shares an approximate location
/// (Android's or iOS's "Approximate" permission): the real position is somewhere within it.
typedef DeviceLocation = ({LatLng point, int? radiusMeters, bool mocked});

/// Radius to show for an approximate fix. Never below 2 km, the margin Android blurs by, even if a
/// fix claims better; capped at what the API accepts.
int approximateRadiusMeters(double reportedAccuracy) => math.min(math.max(reportedAccuracy, 2000), 50000).round();

Future<LatLng> currentLocation() async => (await currentDeviceLocation()).point;

/// Whether this app was only given an approximate location. False where that can't be asked (web).
Future<bool> _isApproximate() async {
  try {
    return await Geolocator.getLocationAccuracy() == LocationAccuracyStatus.reduced;
  } catch (_) {
    return false;
  }
}

/// The device position if it can be had without prompting the user and within a moment; else null.
Future<LatLng?> knownLocationWithoutAsking() async {
  try {
    if (kIsWeb) {
      // Only when the browser says it is already granted, so nothing prompts; else null.
      if (await Geolocator.checkPermission() != LocationPermission.whileInUse) return null;
      // Already granted, so no prompt can be open: a short overall limit is safe here.
      final pos = await _webPosition(
        highAccuracy: false,
        timeLimit: const Duration(seconds: 2),
        maximumAge: const Duration(minutes: 5),
      ).timeout(const Duration(seconds: 3));
      return LatLng(pos.latitude, pos.longitude);
    }
    if (!await Geolocator.isLocationServiceEnabled()) return null;
    final permission = await Geolocator.checkPermission();
    if (permission != LocationPermission.always && permission != LocationPermission.whileInUse) return null;
    // Not available on web, which goes straight to asking for a fresh position.
    final last = kIsWeb ? null : await Geolocator.getLastKnownPosition();
    final pos = last ??
        await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.low, timeLimit: Duration(seconds: 2)),
        );
    return LatLng(pos.latitude, pos.longitude);
  } catch (_) {
    return null;
  }
}

/// One browser position request.
///
/// The time limit goes to the browser, whose timeout only starts once the user has allowed
/// location. A timer here would also count the time the permission prompts are open. iOS shows two
/// prompts (Safari's for the site, then the system's), and slow answers then failed as "could not
/// get your location".
///
/// geolocator_web passes `timeLimit.inMicroseconds` to the browser as milliseconds, so the limit
/// is handed over in microseconds to arrive as the intended milliseconds. The Dart timeout is only
/// a backstop for browsers that never call back, and allows plenty of time for the prompts.
Future<Position> _webPosition({required bool highAccuracy, required Duration timeLimit, Duration? maximumAge}) =>
    Geolocator.getCurrentPosition(
      locationSettings: WebSettings(
        accuracy: highAccuracy ? LocationAccuracy.high : LocationAccuracy.low,
        timeLimit: Duration(microseconds: timeLimit.inMilliseconds),
        maximumAge: maximumAge ?? Duration.zero,
      ),
    ).timeout(timeLimit + const Duration(minutes: 2));

/// Web: the browser asks for permission itself when a position is requested. The Permissions API
/// is not trusted for this: Safari on iOS reports "prompt" or "denied" even when location is
/// allowed (or throws), which made the app give up without ever asking.
Future<DeviceLocation> _currentWebLocation() async {
  Position pos;
  try {
    pos = await _webPosition(highAccuracy: true, timeLimit: const Duration(seconds: 15));
  } catch (_) {
    // iOS can fail or stall on a precise fix, and can even refuse it as "permission denied" while
    // location is allowed (e.g. "Precise Location" off). So any failure, a denial included, gets
    // one more try for a coarse or recent fix; only its outcome counts.
    try {
      pos = await _webPosition(
        highAccuracy: false,
        timeLimit: const Duration(seconds: 15),
        maximumAge: const Duration(minutes: 5),
      );
    } on PermissionDeniedException catch (e) {
      throw LocationException(LocationError.denied, e.message);
    } catch (e) {
      throw LocationException(LocationError.unavailable, e.toString());
    }
  }
  return (point: LatLng(pos.latitude, pos.longitude), radiusMeters: null, mocked: false);
}

/// Asks for permission if needed and returns the device position.
/// Throws [LocationError] if location is unavailable (users may refuse to share it).
Future<DeviceLocation> currentDeviceLocation() async {
  if (kIsWeb) return _currentWebLocation();
  if (!await Geolocator.isLocationServiceEnabled()) throw LocationError.servicesOff;

  var permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }
  if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
    throw LocationError.denied;
  }
  try {
    final pos = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 15)),
    );
    return (
      point: LatLng(pos.latitude, pos.longitude),
      radiusMeters: await _isApproximate() ? approximateRadiusMeters(pos.accuracy) : null,
      mocked: pos.isMocked,
    );
  } catch (_) {
    throw LocationError.unavailable;
  }
}
