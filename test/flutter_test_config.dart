import 'dart:async';

import 'package:globly/screens/map_screen.dart';

/// Runs before every test file. The Mapbox map is a native view, which widget tests can't host.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  MapScreen.showMap = false;
  await testMain();
}
