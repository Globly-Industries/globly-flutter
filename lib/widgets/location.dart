import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

/// Why the location could not be read (translated by widgets/errors.dart).
enum LocationError implements Exception { servicesOff, denied, unavailable }

/// Asks for permission if needed and returns the device position.
/// Throws [LocationError] if location is unavailable (users may refuse to share it).
Future<LatLng> currentLocation() async {
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
    return LatLng(pos.latitude, pos.longitude);
  } catch (_) {
    throw LocationError.unavailable;
  }
}
