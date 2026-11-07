import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

/// Asks for permission if needed and returns the device position.
/// Throws a readable message if location is unavailable (user can disable sharing).
Future<LatLng> currentLocation() async {
  if (!await Geolocator.isLocationServiceEnabled()) {
    throw 'Location services are turned off.';
  }
  var permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }
  if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
    throw 'Location permission was not granted.';
  }
  final pos = await Geolocator.getCurrentPosition(
    locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 15)),
  );
  return LatLng(pos.latitude, pos.longitude);
}
