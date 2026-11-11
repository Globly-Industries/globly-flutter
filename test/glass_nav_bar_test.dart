import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:globly/widgets/glass.dart';

void main() {
  const items = [
    GlassNavItem(Icons.map_outlined, Icons.map_rounded, 'Map'),
    GlassNavItem(Icons.dynamic_feed_outlined, Icons.dynamic_feed_rounded, 'Feed'),
  ];

  Future<({List<int> tabs, List<String> taps})> pumpBar(WidgetTester tester) async {
    final tabs = <int>[];
    final taps = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          extendBody: true,
          body: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => taps.add('page'),
            child: const SizedBox.expand(),
          ),
          bottomNavigationBar: GlassNavBar(
            items: items,
            leadingCount: 1,
            selectedIndex: 0,
            onSelected: tabs.add,
            postButton: PostButton(
              onPressed: () => taps.add('post'),
              tooltip: 'New post',
              size: GlassNavBar.buttonSize,
            ),
          ),
        ),
      ),
    );
    return (tabs: tabs, taps: taps);
  }

  testWidgets('post button sits in the horizontal middle of the screen and fires onPost', (tester) async {
    final result = await pumpBar(tester);
    final button = find.byType(PostButton);

    expect(tester.getCenter(button).dx, tester.view.physicalSize.width / tester.view.devicePixelRatio / 2);
    await tester.tap(button);
    expect(result.taps, ['post']);
  });

  testWidgets('tabs report their index', (tester) async {
    final result = await pumpBar(tester);

    await tester.tap(find.text('Feed'));
    await tester.tap(find.text('Map'));
    expect(result.tabs, [1, 0]);
  });

  testWidgets('the notch follows a circle around the button, leaving an even gap', (tester) async {
    final result = await pumpBar(tester);
    final center = tester.getCenter(find.byType(PostButton));
    const buttonRadius = GlassNavBar.buttonSize / 2;

    // Sweeps the lower part of the notch, from one side of the button to the other.
    for (final degrees in [30, 60, 90, 120, 150]) {
      final direction = Offset.fromDirection(degrees * math.pi / 180);

      // Middle of the gap: neither the button nor the bar, so the touch reaches the page.
      result.taps.clear();
      await tester.tapAt(center + direction * (buttonRadius + GlassNavBar.notchGap / 2));
      expect(result.taps, ['page'], reason: 'in the gap at $degrees degrees');

      // Just past the gap: the bar takes the touch.
      result.taps.clear();
      await tester.tapAt(center + direction * (buttonRadius + GlassNavBar.notchGap + 2));
      expect(result.taps, isEmpty, reason: 'on the bar at $degrees degrees');
    }
  });

  testWidgets('the bar spans the full width with square corners; above it is the page', (tester) async {
    final result = await pumpBar(tester);
    final bar = tester.getRect(find.byType(GlassNavBar));
    final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
    expect(bar.left, 0);
    expect(bar.right, screen.width);

    // Above the bar's top edge, away from the button: the strip reserved for the overhang.
    await tester.tapAt(Offset(bar.left + 40, bar.top + GlassNavBar.overhang / 2));
    expect(result.taps, ['page']);

    // The very corners of the bar's top edge belong to the bar.
    result.taps.clear();
    await tester.tapAt(Offset(bar.left + 1, bar.top + GlassNavBar.overhang + 1));
    await tester.tapAt(Offset(bar.right - 1, bar.top + GlassNavBar.overhang + 1));
    expect(result.taps, isEmpty);
  });
}
