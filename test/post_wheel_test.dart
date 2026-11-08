import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:globly/l10n/app_localizations.dart';
import 'package:globly/models/models.dart';
import 'package:globly/widgets/glass.dart';
import 'package:globly/widgets/post_wheel.dart';

void main() {
  const options = [MediaType.image, MediaType.video, MediaType.audio, MediaType.text];

  Future<List<MediaType>> pumpWheel(WidgetTester tester, {bool canOpen = true}) async {
    final selected = <MediaType>[];
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Scaffold(
        body: Align(
          alignment: const Alignment(0, 0.8),
          child: PostWheelButton(
            options: options,
            direction: wheelFansUp,
            size: 60,
            tooltip: 'New post',
            canOpen: () => canOpen,
            onSelected: selected.add,
          ),
        ),
      ),
    ));
    return selected;
  }

  Future<void> settle(WidgetTester tester) => tester.pump(const Duration(seconds: 1));

  group('wheelSelectionAt', () {
    const center = Offset(200, 600);

    test('the centre selects nothing', () {
      expect(wheelSelectionAt(center + const Offset(10, -10), center, 4, wheelFansUp), isNull);
    });

    test('options run left to right when fanning up', () {
      final picks = [
        for (final degrees in [-165.0, -115.0, -65.0, -15.0])
          wheelSelectionAt(center + Offset.fromDirection(degrees * 3.14159265 / 180, 110), center, 4, wheelFansUp),
      ];
      expect(picks, [0, 1, 2, 3]);
    });

    test('pointing away from the wheel selects nothing', () {
      expect(wheelSelectionAt(center + const Offset(0, 110), center, 4, wheelFansUp), isNull);
    });

    test('works across the angle wrap-around, fanning right', () {
      expect(wheelSelectionAt(center + const Offset(80, -80), center, 3, wheelFansRight), 0);
      expect(wheelSelectionAt(center + const Offset(110, 0), center, 3, wheelFansRight), 1);
      expect(wheelSelectionAt(center + const Offset(80, 80), center, 3, wheelFansRight), 2);
    });
  });

  testWidgets('tap opens the wheel and tapping an option selects it', (tester) async {
    final selected = await pumpWheel(tester);
    expect(find.text('Video'), findsNothing);

    await tester.tap(find.byType(PostButton));
    await tester.pump();
    await settle(tester);
    expect(find.text('Photo'), findsOneWidget);
    expect(find.text('Audio'), findsOneWidget);

    await tester.tap(find.text('Video'));
    await tester.pump();
    await settle(tester);
    expect(selected, [MediaType.video]);
    expect(find.text('Video'), findsNothing);
  });

  testWidgets('hold, drag onto an option and release selects it', (tester) async {
    final selected = await pumpWheel(tester);
    final center = tester.getCenter(find.byType(PostButton));

    final finger = await tester.startGesture(center);
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    await settle(tester);
    expect(find.text('Audio'), findsOneWidget);

    await finger.moveTo(tester.getCenter(find.text('Audio')));
    await tester.pump();
    await finger.up();
    await tester.pump();
    await settle(tester);
    expect(selected, [MediaType.audio]);
    expect(find.text('Audio'), findsNothing);
  });

  testWidgets('pressing and dragging straight away selects with one motion, no waiting', (tester) async {
    final selected = await pumpWheel(tester);
    final center = tester.getCenter(find.byType(PostButton));

    final finger = await tester.startGesture(center);
    await tester.pump(const Duration(milliseconds: 20));
    await finger.moveBy(const Offset(0, -30));
    await tester.pump(const Duration(milliseconds: 20));
    expect(find.text('Video'), findsOneWidget); // Open well before a long press would have fired.

    await tester.pump(const Duration(milliseconds: 300));
    await finger.moveTo(tester.getCenter(find.text('Video')));
    await tester.pump();
    await finger.up();
    await tester.pump();
    await settle(tester);
    expect(selected, [MediaType.video]);
    expect(find.text('Video'), findsNothing);
  });

  testWidgets('dragging vibrates on opening and once per option entered', (tester) async {
    final pulses = <int>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(const MethodChannel('vibration'), (call) async {
      if (call.method == 'vibrate') pulses.add((call.arguments as Map)['duration'] as int);
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(const MethodChannel('vibration'), null));

    await pumpWheel(tester);
    final center = tester.getCenter(find.byType(PostButton));

    final finger = await tester.startGesture(center);
    await finger.moveBy(const Offset(0, -30));
    await tester.pump();
    await settle(tester);
    expect(pulses, hasLength(1)); // Opening.

    await finger.moveTo(tester.getCenter(find.text('Video')));
    await tester.pump();
    await finger.moveBy(const Offset(2, 2)); // Still on Video: no new pulse.
    await tester.pump();
    await finger.moveTo(tester.getCenter(find.text('Audio')));
    await tester.pump();
    expect(pulses, hasLength(3));
    expect(pulses.every((ms) => ms >= 20), isTrue, reason: 'Too short to spin up a small motor.');

    await finger.up();
    await tester.pump();
    await settle(tester);
  });

  testWidgets('dragging away from every option and letting go selects nothing and keeps it open', (tester) async {
    final selected = await pumpWheel(tester);
    final center = tester.getCenter(find.byType(PostButton));

    final finger = await tester.startGesture(center);
    await finger.moveBy(const Offset(0, 60)); // Down, where there are no options.
    await tester.pump();
    await settle(tester);
    await finger.up();
    await tester.pump();
    await settle(tester);
    expect(selected, isEmpty);
    expect(find.text('Photo'), findsOneWidget);
  });

  testWidgets('a plain tap still opens the wheel without selecting anything', (tester) async {
    final selected = await pumpWheel(tester);

    await tester.tap(find.byType(PostButton));
    await tester.pump();
    await settle(tester);
    expect(selected, isEmpty);
    expect(find.text('Photo'), findsOneWidget);
  });

  testWidgets('holding and letting go without choosing keeps the wheel open for tapping', (tester) async {
    final selected = await pumpWheel(tester);

    final finger = await tester.startGesture(tester.getCenter(find.byType(PostButton)));
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    await settle(tester);
    await finger.up();
    await tester.pump();
    await settle(tester);
    expect(selected, isEmpty);
    expect(find.text('Text'), findsOneWidget);

    await tester.tap(find.text('Text'));
    await tester.pump();
    await settle(tester);
    expect(selected, [MediaType.text]);
  });

  testWidgets('tapping outside closes the wheel without selecting', (tester) async {
    final selected = await pumpWheel(tester);
    await tester.tap(find.byType(PostButton));
    await tester.pump();
    await settle(tester);

    await tester.tapAt(const Offset(10, 10));
    await tester.pump();
    await settle(tester);
    expect(selected, isEmpty);
    expect(find.text('Photo'), findsNothing);
  });

  testWidgets('the back button closes the wheel, and only the wheel', (tester) async {
    final selected = await pumpWheel(tester);
    await tester.tap(find.byType(PostButton));
    await tester.pump();
    await settle(tester);
    expect(find.text('Photo'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pump();
    await settle(tester);
    expect(selected, isEmpty);
    expect(find.text('Photo'), findsNothing);
    expect(find.byType(PostWheelButton), findsOneWidget);

    // It can be opened again afterwards.
    await tester.tap(find.byType(PostButton));
    await tester.pump();
    await settle(tester);
    expect(find.text('Photo'), findsOneWidget);
  });

  testWidgets('a blocked user never sees the wheel', (tester) async {
    await pumpWheel(tester, canOpen: false);
    await tester.tap(find.byType(PostButton));
    await tester.pump();
    await settle(tester);
    expect(find.text('Photo'), findsNothing);
  });
}
