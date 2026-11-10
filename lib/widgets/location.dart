import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

/// Why the location could not be read (translated by widgets/errors.dart).
enum LocationError implements Exception { servicesOff, denied, unavailable }

/// The device position. [radiusMeters] is set when the user only shares an approximate location
/// (Android's or iOS's "Approximate" permission): the real position is somewhere within it.
typedef DeviceLocation = ({LatLng point, int? radiusMeters});

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
      final pos = await _webPosition(
        highAccuracy: false,
        timeLimit: const Duration(seconds: 2),
        maximumAge: const Duration(minutes: 5),
      );
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

/// One browser position request. geolocator_web passes the time limit to the browser in the wrong
/// unit (microseconds as milliseconds), so it is enforced here instead.
Future<Position> _webPosition({required bool highAccuracy, required Duration timeLimit, Duration? maximumAge}) =>
    Geolocator.getCurrentPosition(
      locationSettings: WebSettings(
        accuracy: highAccuracy ? LocationAccuracy.high : LocationAccuracy.low,
        maximumAge: maximumAge ?? Duration.zero,
      ),
    ).timeout(timeLimit);

/// Web: the browser asks for permission itself when a position is requested. The Permissions API
/// is not trusted for this: Safari on iOS reports "prompt" or "denied" even when location is
/// allowed (or throws), which made the app give up without ever asking.
Future<DeviceLocation> _currentWebLocation() async {
  Position pos;
  try {
    pos = await _webPosition(highAccuracy: true, timeLimit: const Duration(seconds: 15));
  } on PermissionDeniedException {
    throw LocationError.denied;
  } catch (_) {
    // iOS can fail or stall on a precise fix (e.g. "Precise Location" off); a coarse or recent one will do.
    try {
      pos = await _webPosition(
        highAccuracy: false,
        timeLimit: const Duration(seconds: 15),
        maximumAge: const Duration(minutes: 5),
      );
    } on PermissionDeniedException {
      throw LocationError.denied;
    } catch (_) {
      throw LocationError.unavailable;
    }
  }
  return (point: LatLng(pos.latitude, pos.longitude), radiusMeters: null);
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
    );
  } catch (_) {
    throw LocationError.unavailable;
  }
}
