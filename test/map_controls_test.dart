import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:globly/api/api_client.dart';
import 'package:globly/l10n/app_localizations.dart';
import 'package:globly/models/models.dart';
import 'package:globly/screens/map_screen.dart';
import 'package:globly/screens/profile_screen.dart';
import 'package:globly/state/auth_state.dart';
import 'package:globly/state/filter_state.dart';
import 'package:provider/provider.dart';

class _FakeApi extends ApiClient {
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
  late FilterState filters;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (_) async => '.',
    );
  });

  Future<void> pumpMap(WidgetTester tester, {Size size = const Size(412, 915)}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    filters = FilterState();
    final api = _FakeApi();
    await tester.pumpWidget(MultiProvider(
      providers: [
        Provider<ApiClient>.value(value: api),
        ChangeNotifierProvider(create: (_) => AuthState(api)),
        ChangeNotifierProvider.value(value: filters),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const Scaffold(body: MapScreen()),
      ),
    ));
    await tester.pump();
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  final filterButton = find.byIcon(Icons.tune_rounded);

  testWidgets('filters stay out of the way until the button is pressed', (tester) async {
    await pumpMap(tester);
    expect(find.text('Photo'), findsNothing);
    expect(find.text('More filters'), findsNothing);

    await tester.tap(filterButton);
    await settle(tester);
    for (final label in ['Text', 'Photo', 'Video', 'Audio', 'More filters']) {
      expect(find.text(label), findsOneWidget);
    }
  });

  testWidgets('types toggle on and off and the dropdown stays open for choosing several', (tester) async {
    await pumpMap(tester);
    await tester.tap(filterButton);
    await settle(tester);

    await tester.tap(find.text('Photo'));
    await tester.pump();
    await tester.tap(find.text('Video'));
    await settle(tester);
    expect(filters.filter.types, {MediaType.image, MediaType.video});
    expect(find.text('Photo'), findsOneWidget);
    expect(find.byIcon(Icons.check_rounded), findsNWidgets(2));

    await tester.tap(find.text('Photo'));
    await settle(tester);
    expect(filters.filter.types, {MediaType.video});
  });

  testWidgets('toggling a type keeps the options set in the full filter sheet', (tester) async {
    await pumpMap(tester);
    filters.filter = const PostFilter(maxAge: Duration(days: 7), minScore: 1);
    await settle(tester);
    await tester.tap(find.byIcon(Icons.filter_alt_rounded));
    await settle(tester);

    await tester.tap(find.text('Audio'));
    await settle(tester);
    expect(filters.filter.types, {MediaType.audio});
    expect(filters.filter.maxAge, const Duration(days: 7));
    expect(filters.filter.minScore, 1);
  });

  testWidgets('"More filters" closes the dropdown and opens the full sheet', (tester) async {
    await pumpMap(tester);
    await tester.tap(filterButton);
    await settle(tester);

    await tester.tap(find.text('More filters'));
    await settle(tester);
    expect(find.text('More filters'), findsNothing);
    expect(find.text('Only positively rated'), findsOneWidget);
  });

  testWidgets('tapping the map or pressing back closes the dropdown', (tester) async {
    await pumpMap(tester);
    await tester.tap(filterButton);
    await settle(tester);

    await tester.tapAt(const Offset(300, 700));
    await settle(tester);
    expect(find.text('Photo'), findsNothing);

    await tester.tap(filterButton);
    await settle(tester);
    await tester.binding.handlePopRoute();
    await settle(tester);
    expect(find.text('Photo'), findsNothing);
    expect(find.byType(MapScreen), findsOneWidget);
  });

  testWidgets('the location button sits directly under the profile button at the top right', (tester) async {
    await pumpMap(tester);
    final profile = tester.getRect(find.byType(ProfileButton));
    final location = tester.getRect(find.ancestor(of: find.byIcon(Icons.my_location_rounded), matching: find.byType(IconButton)));

    expect(location.center.dx, profile.center.dx);
    expect(location.top, greaterThan(profile.bottom));
    expect(profile.right, greaterThan(412 * 0.85));
  });

  testWidgets('the open dropdown fits on a phone held sideways', (tester) async {
    await pumpMap(tester, size: const Size(640, 300));
    await tester.tap(filterButton);
    await settle(tester);

    expect(tester.takeException(), isNull); // A layout overflow would be reported here.
    expect(find.text('Photo'), findsOneWidget);
  });
}
