import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:globly/api/api_client.dart';
import 'package:globly/main.dart';
import 'package:globly/models/models.dart';
import 'package:globly/screens/login_screen.dart';
import 'package:globly/screens/profile_screen.dart';
import 'package:globly/state/auth_state.dart';
import 'package:globly/state/filter_state.dart';
import 'package:globly/state/settings_state.dart';
import 'package:provider/provider.dart';

class _FakeApi extends ApiClient {
  @override
  Future<String?> captchaSiteKey() async => null;

  @override
  Future<Paged<Post>> feed({int page = 1, PostFilter filter = const PostFilter()}) async => const Paged([], false);

  @override
  Future<List<MapPoint>> mapPoints({
    required double minLat,
    required double minLng,
    required double maxLat,
    required double maxLng,
    required double zoom,
    PostFilter filter = const PostFilter(),
    CancelToken? cancelToken,
  }) async =>
      [];
}

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    // The map's tile cache asks for a cache directory.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (_) async => '.',
    );
  });

  testWidgets('guest opens profile from the top right, and signing in returns to the login screen', (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final api = _FakeApi();
    final auth = AuthState(api);
    await tester.runAsync(auth.continueAsGuest);

    await tester.pumpWidget(MultiProvider(
      providers: [
        Provider<ApiClient>.value(value: api),
        ChangeNotifierProvider.value(value: auth),
        ChangeNotifierProvider(create: (_) => SettingsState()),
        ChangeNotifierProvider(create: (_) => FilterState()),
      ],
      child: const GloblyApp(),
    ));
    await tester.pump();

    // Profile is no longer a tab, and its button sits in the top-right corner.
    expect(find.text('Profile'), findsNothing);
    final button = find.byType(ProfileButton).hitTestable();
    expect(button, findsOneWidget);
    final corner = tester.getCenter(button);
    expect(corner.dx, greaterThan(412 * 0.8));
    expect(corner.dy, lessThan(915 * 0.2));

    await tester.tap(button);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(ProfileScreen), findsOneWidget);

    // Leaving guest mode must not leave the profile page covering the login screen.
    await tester.tap(find.byType(FilledButton));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump(); // Rebuilds the gate, whose post-frame callback closes the page.
    await tester.pump(); // Starts the closing animation.
    await tester.pump(const Duration(seconds: 1)); // Finishes it.
    expect(find.byType(ProfileScreen), findsNothing);
    expect(find.byType(LoginScreen), findsOneWidget);
  });
}
