import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:globly/widgets/glass.dart';
import 'package:globly/widgets/goo.dart';

void main() {
  const radius = 30.0;

  /// Runs [goo] for [seconds] in 60 fps frames; returns whether it was still moving at the end.
  bool run(GooSimulation goo, double seconds) {
    var moving = true;
    for (var t = 0.0; t < seconds; t += 1 / 60) {
      moving = goo.advance(1 / 60);
    }
    return moving;
  }

  /// How far the blob reaches out in [direction] (a unit vector).
  double reachIn(GooSimulation goo, Offset direction) => goo.circles
      .map((c) => c.centre.dx * direction.dx + c.centre.dy * direction.dy + c.radius)
      .reduce((a, b) => a > b ? a : b);

  double furthestRight(GooSimulation goo) => reachIn(goo, const Offset(1, 0));

  group('GooSimulation', () {
    test('rests as a round clump of circles filling the button', () {
      final goo = GooSimulation(radius: radius);
      expect(goo.advance(1 / 60), isFalse);
      expect(goo.circles.length, greaterThan(10));
      for (final degrees in [0, 45, 90, 135, 180, 225, 270, 315]) {
        final reach = reachIn(goo, Offset.fromDirection(degrees * 3.14159265 / 180));
        expect(reach, closeTo(radius, radius * 0.05), reason: 'at $degrees degrees');
      }
    });

    test('stretches towards a finger dragged away, but only so far', () {
      final goo = GooSimulation(radius: radius);
      goo.press(Offset.zero);
      goo.drag(const Offset(500, 0));
      expect(run(goo, 2), isTrue, reason: 'Held, so never at rest.');

      final reach = furthestRight(goo);
      expect(reach, greaterThan(radius * 1.5));
      expect(reach, lessThan(radius + goo.maxReach * 1.4));
      expect(goo.centre.dx, greaterThan(0), reason: 'The body leans towards the finger.');
      expect(reachIn(goo, const Offset(-1, 0)), lessThan(radius), reason: 'The back follows.');
    });

    test('springs back once let go, overshooting on the way', () {
      final goo = GooSimulation(radius: radius);
      goo.press(Offset.zero);
      goo.drag(const Offset(200, 0));
      run(goo, 1);
      goo.release();

      var overshot = false;
      for (var i = 0; i < 40; i++) {
        goo.advance(1 / 60);
        if (furthestRight(goo) < radius - 0.5) overshot = true;
      }
      expect(overshot, isTrue, reason: 'Should wobble, not just ease back.');

      expect(run(goo, 5), isFalse);
      final fresh = GooSimulation(radius: radius).circles;
      final settled = goo.circles;
      for (var i = 0; i < fresh.length; i++) {
        expect((settled[i].centre - fresh[i].centre).distance, lessThan(0.01));
      }
    });

    test('a long stall does not blow it up', () {
      final goo = GooSimulation(radius: radius);
      goo.press(const Offset(10, 0));
      goo.advance(5);
      for (final c in goo.circles) {
        expect(c.centre.distance.isFinite && c.centre.distance < radius * 3, isTrue);
      }
    });
  });

  group('traceGoo', () {
    test('traces the resting clump as the resting circle, so settling causes no jump', () {
      final goo = GooSimulation(radius: radius);
      final outline = traceGoo(goo.circles, goo.edgeStrength, radius / 15);
      final bounds = outline.getBounds();
      expect(bounds.width, closeTo(radius * 2, 1));
      expect(bounds.height, closeTo(radius * 2, 1));
      for (final degrees in [0, 30, 60, 90, 120, 150, 180, 210, 240, 270, 300, 330]) {
        final direction = Offset.fromDirection(degrees * 3.14159265 / 180);
        expect(outline.contains(direction * (radius - 1.5)), isTrue, reason: 'inside at $degrees');
        expect(outline.contains(direction * (radius + 1.5)), isFalse, reason: 'outside at $degrees');
      }
    });

    test('a stretched blob stays one piece, reaching towards the finger', () {
      final goo = GooSimulation(radius: radius)
        ..press(Offset.zero)
        ..drag(const Offset(300, 0));
      run(goo, 1);
      final outline = traceGoo(goo.circles, goo.edgeStrength, radius / 15);
      expect(outline.getBounds().right, greaterThan(radius * 1.6));
      // Every point along the way from the middle to the tip is filled: nothing has broken off.
      for (var x = 0.0; x < outline.getBounds().right - 2; x += 1) {
        final tipY = outline.getBounds().center.dy;
        expect(outline.contains(Offset(x, tipY)) || outline.contains(Offset(x, 0)), isTrue, reason: 'gap at x = $x');
      }
    });
  });

  group('PostButton', () {
    Future<List<String>> pump(WidgetTester tester, {bool disableAnimations = false}) async {
      final taps = <String>[];
      await tester.pumpWidget(MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: disableAnimations),
          child: Scaffold(
            body: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => taps.add('page'),
              child: Center(child: PostButton(onPressed: () => taps.add('post'), tooltip: 'New post')),
            ),
          ),
        ),
      ));
      return taps;
    }

    testWidgets('only the circle takes taps, not the corners of its box', (tester) async {
      final taps = await pump(tester);
      final box = tester.getRect(find.byType(PostButton));

      await tester.tapAt(box.center);
      await tester.pump(const Duration(seconds: 3));
      await tester.tapAt(box.topLeft + const Offset(3, 3));
      await tester.pump(const Duration(seconds: 3));
      expect(taps, ['post', 'page']);
    });

    testWidgets('wobbles while touched and settles afterwards', (tester) async {
      await pump(tester);
      final center = tester.getCenter(find.byType(PostButton));

      final finger = await tester.startGesture(center);
      await tester.pump(const Duration(milliseconds: 16));
      expect(tester.binding.hasScheduledFrame, isTrue);
      await finger.moveBy(const Offset(25, 0));
      await tester.pump(const Duration(milliseconds: 200));
      await finger.up();

      // Frame by frame: one long pump is a single frame, and the physics caps how far a frame goes.
      for (var i = 0; i < 4 * 60; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(tester.binding.hasScheduledFrame, isFalse, reason: 'Stops animating once at rest.');
    });

    testWidgets('stays still with animations turned off', (tester) async {
      await pump(tester, disableAnimations: true);
      final finger = await tester.startGesture(tester.getCenter(find.byType(PostButton)));
      await tester.pump();
      expect(tester.binding.hasScheduledFrame, isFalse);
      await finger.up();
    });
  });
}
