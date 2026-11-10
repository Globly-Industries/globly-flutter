import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// One of the circles a [GooSimulation] is made of, relative to the blob's centre.
typedef GooCircle = ({Offset centre, double radius});

/// Soft-body physics behind [GooBlob]: a clump of small circles, each sprung towards its place in
/// the clump and to the circles around it. Drawn merged together, they behave like a glob of
/// liquid: a touch wobbles through it, and a finger dragging away pulls lumps out of it that stay
/// joined by a neck and are dragged back by the rest.
///
/// All positions are relative to the blob's resting centre, in logical pixels.
class GooSimulation extends ChangeNotifier {
  GooSimulation({required this.radius}) {
    void add(Offset rest, double size) {
      _rest.add(rest);
      _sizes.add(size);
    }

    // A core, an inner ring and an outer ring, whose outer edges together make the resting circle.
    // The outer circles overlap a lot, so the resting edge is round, not faceted.
    add(Offset.zero, radius * 0.55);
    for (var i = 0; i < 6; i++) {
      add(
        Offset.fromDirection(2 * math.pi * (i + 0.5) / 6, radius * 0.32),
        radius * 0.36,
      );
    }
    for (var i = 0; i < _outerCount; i++) {
      add(
        Offset.fromDirection(
          2 * math.pi * i / _outerCount,
          _outerRing * radius,
        ),
        radius * 0.4,
      );
    }
    // The strand: droplets hidden in the core that a dragging finger draws out in a beaded neck.
    _strandStart = _rest.length;
    for (final size in _strandSizes) {
      add(Offset.zero, radius * size);
    }

    final n = _rest.length;
    _offset = List.filled(n, Offset.zero);
    _velocity = List.filled(n, Offset.zero);
    _target = List.filled(n, Offset.zero);
    // Each circle a little more or less eager than the next, so the clump moves unevenly, like
    // something fluid rather than one rubber ball.
    _eagerness = [
      for (var i = 0; i < _strandStart; i++) 1 + 0.4 * math.sin(i * 2.4),
      // Each droplet further along the strand trails a little more, so it whips about.
      ..._strandEagerness,
    ];

    // Ties between circles of the clump that start near each other. The strand is free.
    for (var i = 0; i < _strandStart; i++) {
      for (var j = i + 1; j < _strandStart; j++) {
        final length = (_rest[i] - _rest[j]).distance;
        if (length < radius * 0.45) _ties.add((i, j, length));
      }
    }
  }

  final double radius;

  static const int _outerCount = 14;

  /// Distance of the outer circles' centres from the middle, as a share of [radius].
  static const double _outerRing = 0.62;

  /// The strand's droplets, from the body outwards: their sizes, how far out each is drawn at full
  /// stretch (both as a share of [radius]), and how eagerly each follows.
  static const _strandSizes = [0.4, 0.33, 0.27];
  static const _strandReach = [0.85, 1.35, 1.8];
  static const _strandEagerness = [0.6, 0.42, 0.3];
  late final int _strandStart;

  final List<Offset> _rest = [];
  final List<double> _sizes = [];
  final List<(int, int, double)> _ties = [];
  late final List<double> _eagerness;

  // For each circle: how far it is from its resting place, how fast it is moving, and where
  // (also relative to its resting place) it is being pulled to.
  late final List<Offset> _offset;
  late final List<Offset> _velocity;
  late final List<Offset> _target;

  Offset? _finger;
  bool _pressed = false;
  bool _atRest = true;

  /// Pull of each circle towards its target.
  static const double _stiffness = 260;

  /// Pull between tied circles back to their starting distance: what holds the clump together.
  static const double _cohesion = 100;

  /// Drag on each circle's movement, and on tied circles moving apart or together. The second
  /// calms the fast jitter without making the slow wobble any less springy.
  static const double _damping = 6;
  static const double _viscosity = 5;

  /// Fixed physics step, so the feel is the same at any frame rate.
  static const double _step = 1 / 240;

  /// How far, at most, the side facing the finger is pulled out towards it.
  double get maxReach => radius * 1.6;

  /// The circles the blob is drawn from.
  List<GooCircle> get circles => [
    for (var i = 0; i < _rest.length; i++)
      (centre: _rest[i] + _offset[i], radius: _sizes[i]),
  ];

  /// Where the middle of the blob has moved to.
  Offset get centre => _offset[0];

  /// Whether a finger is holding or pulling the blob.
  bool get isHeld => _finger != null;

  /// Whether it is sitting still as a plain circle of [radius].
  bool get atRest => _atRest;

  /// How strong the circles' summed pull (see [gooField]) is round the edge of the resting blob:
  /// the level at which the outline is traced, so that at rest it is a circle of [radius].
  late final double edgeStrength = () {
    final rest = circles;
    const samples = 48;
    var sum = 0.0;
    for (var k = 0; k < samples; k++) {
      sum += gooField(
        rest,
        Offset.fromDirection(2 * math.pi * k / samples, radius),
      );
    }
    return sum / samples;
  }();

  /// A finger touched down at [at].
  void press(Offset at) {
    _pressed = true;
    // A quick squeeze inwards makes the touch wobble through the whole blob.
    for (var i = 0; i < _rest.length; i++) {
      _velocity[i] -= _rest[i] * 4;
    }
    drag(at);
  }

  /// The finger moved to [at], which may be well outside the circle.
  void drag(Offset at) {
    _finger = at;
    _atRest = false;
    _retarget();
  }

  /// The finger let go: the blob springs back, overshooting a little.
  void release() {
    _finger = null;
    _pressed = false;
    _retarget();
  }

  void _retarget() {
    final finger = _finger;
    if (finger == null) {
      _target.fillRange(0, _target.length, Offset.zero);
      return;
    }
    final distance = finger.distance;
    // Gives more and more slowly the further the finger goes, like stretching something elastic.
    final reach = maxReach * (1 - math.exp(-distance / maxReach));
    final pull = distance == 0 ? Offset.zero : finger / distance * reach;
    final squeeze = _pressed ? 0.08 : 0.0;
    final towards = finger.direction;

    for (var i = 0; i < _strandStart; i++) {
      final rest = _rest[i];
      final out = rest.distance / (radius * _outerRing);
      final along = rest == Offset.zero
          ? 0.0
          : math.cos(rest.direction - towards);
      final front = math.pow(math.max(0.0, along), 6) * out;
      // The body leans a little towards the finger and bulges on that side; the strand does the reaching.
      _target[i] = pull * (0.15 + 0.4 * front) * _eagerness[i] - rest * squeeze;
    }
    final stretch = reach / maxReach;
    for (var k = 0; k < _strandSizes.length; k++) {
      _target[_strandStart + k] =
          pull / (reach == 0 ? 1 : reach) * radius * _strandReach[k] * stretch;
    }
  }

  /// Moves the simulation on by [seconds]. Returns false once it has come to rest with nothing
  /// holding it, so the caller can stop asking for frames.
  bool advance(double seconds) {
    // After a long stall (a dropped frame, the app paused), carry on rather than catch up.
    var remaining = math.min(seconds, 1 / 30);
    while (remaining > 0) {
      final dt = math.min(_step, remaining);
      _integrate(dt);
      remaining -= dt;
    }

    var moving = isHeld;
    for (var i = 0; i < _rest.length && !moving; i++) {
      moving =
          _velocity[i].distance > 0.5 ||
          (_target[i] - _offset[i]).distance > 0.05;
    }
    if (!moving) {
      _offset.setAll(0, _target);
      _velocity.fillRange(0, _velocity.length, Offset.zero);
      _atRest = true;
    }
    notifyListeners();
    return moving;
  }

  void _integrate(double dt) {
    final n = _rest.length;
    final force = List<Offset>.generate(
      n,
      (i) =>
          (_target[i] - _offset[i]) * _stiffness * _eagerness[i] -
          _velocity[i] * _damping,
    );
    for (final (i, j, length) in _ties) {
      final between = (_rest[j] + _offset[j]) - (_rest[i] + _offset[i]);
      final distance = between.distance;
      if (distance == 0) continue;
      final unit = between / distance;
      final relative = _velocity[j] - _velocity[i];
      final closing = relative.dx * unit.dx + relative.dy * unit.dy;
      final pull =
          unit * ((distance - length) * _cohesion + closing * _viscosity);
      force[i] += pull;
      force[j] -= pull;
    }
    // Semi-implicit Euler: velocity first, so the springs stay stable at this step size.
    for (var i = 0; i < n; i++) {
      _velocity[i] += force[i] * dt;
      _offset[i] += _velocity[i] * dt;
    }
  }
}

/// A round glob of liquid that wobbles when touched and stretches after the finger.
///
/// It reacts to touches on itself and, through [reachTowards], to a finger anywhere on screen,
/// e.g. one that started on another copy of it. Only the resting circle takes touches, however far
/// the blob is stretched. With animations turned off in the system settings it stays still.
class GooBlob extends StatefulWidget {
  final double size;
  final Gradient gradient;
  final Color shadowColor;

  /// A finger's global position for the blob to reach towards, or null to let go.
  final ValueListenable<Offset?>? reachTowards;

  /// Drawn in the middle, following the blob's body as it moves.
  final Widget child;

  const GooBlob({
    super.key,
    required this.size,
    required this.gradient,
    required this.shadowColor,
    required this.child,
    this.reachTowards,
  });

  @override
  State<GooBlob> createState() => _GooBlobState();
}

class _GooBlobState extends State<GooBlob> with SingleTickerProviderStateMixin {
  late GooSimulation _goo = GooSimulation(radius: widget.size / 2);
  late final Ticker _ticker;
  Duration _lastTick = Duration.zero;

  /// The touch on the blob itself; any others are ignored until it lifts.
  int? _pointer;

  Offset get _middle => Offset(widget.size / 2, widget.size / 2);

  bool get _still => MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick);
    widget.reachTowards?.addListener(_follow);
    // Already being pulled when it appears: catch up once laid out.
    if (widget.reachTowards?.value != null) {
      SchedulerBinding.instance.addPostFrameCallback((_) => _follow());
    }
  }

  @override
  void didUpdateWidget(GooBlob old) {
    super.didUpdateWidget(old);
    if (old.reachTowards != widget.reachTowards) {
      old.reachTowards?.removeListener(_follow);
      widget.reachTowards?.addListener(_follow);
    }
    if (old.size != widget.size) {
      _goo.dispose();
      _goo = GooSimulation(radius: widget.size / 2);
    }
  }

  @override
  void dispose() {
    widget.reachTowards?.removeListener(_follow);
    _ticker.dispose();
    _goo.dispose();
    super.dispose();
  }

  void _wake() {
    if (_ticker.isActive) return;
    _lastTick = Duration.zero;
    _ticker.start();
  }

  void _tick(Duration elapsed) {
    final seconds =
        (elapsed - _lastTick).inMicroseconds / Duration.microsecondsPerSecond;
    _lastTick = elapsed;
    if (!_goo.advance(seconds)) _ticker.stop();
  }

  void _follow() {
    if (!mounted) return;
    final global = widget.reachTowards?.value;
    if (global == null) {
      if (_pointer == null && _goo.isHeld) {
        _goo.release();
        _wake();
      }
      return;
    }
    final box = context.findRenderObject() as RenderBox?;
    if (_still || box == null || !box.hasSize) return;
    _goo.drag(box.globalToLocal(global) - _middle);
    _wake();
  }

  void _down(PointerDownEvent event) {
    if (_still || _pointer != null) return;
    _pointer = event.pointer;
    _goo.press(event.localPosition - _middle);
    _wake();
  }

  void _moved(PointerMoveEvent event) {
    if (event.pointer != _pointer) return;
    _goo.drag(event.localPosition - _middle);
  }

  void _up(PointerEvent event) {
    if (event.pointer != _pointer) return;
    _pointer = null;
    _goo.release();
    _wake();
  }

  @override
  Widget build(BuildContext context) {
    return RoundHitArea(
      // A Listener rather than a gesture recogniser: it sees every touch without competing with
      // the taps, drags and holds that whoever wraps this is listening for.
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: _down,
        onPointerMove: _moved,
        onPointerUp: _up,
        onPointerCancel: _up,
        // Repaints every frame while moving; keeps that from spreading to what is around it.
        child: RepaintBoundary(
          child: CustomPaint(
            painter: _GooPainter(_goo, widget.gradient, widget.shadowColor),
            child: SizedBox.square(
              dimension: widget.size,
              child: ListenableBuilder(
                listenable: _goo,
                builder: (context, child) => Transform.translate(
                  offset: _goo.centre * 0.8,
                  child: child,
                ),
                child: Center(child: widget.child),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GooPainter extends CustomPainter {
  final GooSimulation goo;
  final Gradient gradient;
  final Color shadowColor;

  _GooPainter(this.goo, this.gradient, this.shadowColor) : super(repaint: goo);

  @override
  void paint(Canvas canvas, Size size) {
    final middle = size.center(Offset.zero);
    final path = goo.atRest
        ? (Path()..addOval(Rect.fromCircle(center: middle, radius: goo.radius)))
        : traceGoo(
            [
              for (final c in goo.circles)
                (centre: middle + c.centre, radius: c.radius),
            ],
            goo.edgeStrength,
            goo.radius / 15,
          );

    canvas.drawPath(
      path.shift(const Offset(0, 3)),
      Paint()
        ..color = shadowColor
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
    );

    final body = Rect.fromCircle(
      center: middle + goo.centre,
      radius: goo.radius,
    );
    canvas.drawPath(path, Paint()..shader = gradient.createShader(body));

    // A soft highlight that slides with the body, so it reads as a glossy drop. It fades out
    // before reaching the body's edge, so it needs no clipping.
    final shine = Rect.fromCenter(
      center: body.center + const Offset(-0.3, -0.4) * goo.radius,
      width: goo.radius * 0.9,
      height: goo.radius * 0.55,
    );
    canvas.drawOval(
      shine,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFFFFFFF).withValues(alpha: 0.28),
            const Color(0x00FFFFFF),
          ],
        ).createShader(shine),
    );
  }

  @override
  bool shouldRepaint(_GooPainter old) =>
      old.goo != goo ||
      old.gradient != gradient ||
      old.shadowColor != shadowColor;
}

/// How far each circle's pull reaches, as a multiple of its radius. Larger melts circles into each
/// other sooner and gives thicker necks between lumps pulled apart.
const double _spread = 1.4;

/// The [gooField] level at which a circle on its own is traced at exactly its own radius. Circles
/// close enough to add to each other's pull swell out and melt together at this level.
const double gooLoneLevel = (1 - 1 / (_spread * _spread)) * (1 - 1 / (_spread * _spread));

/// The circles' summed pull at [point]: each pulls hardest at its centre, fading smoothly to
/// nothing [_spread] radii away. Where circles are close, their pulls add up and fill the gap
/// between them, which is what melts them together.
double gooField(List<GooCircle> circles, Offset point) {
  // (See [gooLoneLevel] for the level at which a circle on its own traces at its own radius.)
  var sum = 0.0;
  for (final c in circles) {
    final reach = c.radius * _spread;
    final d2 = (point - c.centre).distanceSquared / (reach * reach);
    if (d2 < 1) sum += (1 - d2) * (1 - d2);
  }
  return sum;
}

/// The outline of [circles] melted together: where [gooField] reaches [level], traced on a grid
/// of [cell]-sized squares (marching squares) and smoothed. Pieces pulled apart come out as
/// separate loops.
Path traceGoo(List<GooCircle> circles, double level, double cell) {
  final bounds = circles
      .map((c) => Rect.fromCircle(center: c.centre, radius: c.radius * _spread))
      .reduce((a, b) => a.expandToInclude(b))
      .inflate(cell * 2);
  final nx = (bounds.width / cell).ceil() + 1;
  final ny = (bounds.height / cell).ceil() + 1;
  final left = bounds.left, top = bounds.top;

  // The field at every grid node. Each circle only touches the nodes within its reach.
  final field = Float32List(nx * ny);
  for (final c in circles) {
    final reach = c.radius * _spread;
    final reach2 = reach * reach;
    final i0 = math.max(0, ((c.centre.dx - reach - left) / cell).floor());
    final i1 = math.min(nx - 1, ((c.centre.dx + reach - left) / cell).ceil());
    final j0 = math.max(0, ((c.centre.dy - reach - top) / cell).floor());
    final j1 = math.min(ny - 1, ((c.centre.dy + reach - top) / cell).ceil());
    for (var j = j0; j <= j1; j++) {
      final dy = top + j * cell - c.centre.dy;
      final dy2 = dy * dy;
      if (dy2 >= reach2) continue;
      for (var i = i0; i <= i1; i++) {
        final dx = left + i * cell - c.centre.dx;
        final d2 = (dx * dx + dy2) / reach2;
        if (d2 < 1) field[j * nx + i] += (1 - d2) * (1 - d2);
      }
    }
  }

  // Where the outline crosses a grid edge, keyed by the edge: 2 * node for the edge running right
  // from that node, 2 * node + 1 for the one running down. Each crossing is joined to two others.
  final crossings = <int, Offset>{};
  final links = Int32List(nx * ny * 4)..fillRange(0, nx * ny * 4, -1);

  Offset crossing(int edge) => crossings.putIfAbsent(edge, () {
    final node = edge >> 1;
    final down = edge.isOdd;
    final a = field[node];
    final b = field[down ? node + nx : node + 1];
    final t = (level - a) / (b - a);
    final i = node % nx, j = node ~/ nx;
    return Offset(
      left + (i + (down ? 0 : t)) * cell,
      top + (j + (down ? t : 0)) * cell,
    );
  });

  void join(int a, int b) {
    crossing(a);
    crossing(b);
    links[links[2 * a] == -1 ? 2 * a : 2 * a + 1] = b;
    links[links[2 * b] == -1 ? 2 * b : 2 * b + 1] = a;
  }

  for (var j = 0; j < ny - 1; j++) {
    for (var i = 0; i < nx - 1; i++) {
      final node = j * nx + i;
      final tl = field[node],
          tr = field[node + 1],
          br = field[node + nx + 1],
          bl = field[node + nx];
      final shape =
          (tl >= level ? 1 : 0) |
          (tr >= level ? 2 : 0) |
          (br >= level ? 4 : 0) |
          (bl >= level ? 8 : 0);
      if (shape == 0 || shape == 15) continue;
      final up = 2 * node,
          bottom = 2 * (node + nx),
          side = 2 * node + 1,
          right = 2 * (node + 1) + 1;
      switch (shape) {
        case 1 || 14:
          join(side, up);
        case 2 || 13:
          join(up, right);
        case 3 || 12:
          join(side, right);
        case 4 || 11:
          join(right, bottom);
        case 6 || 9:
          join(up, bottom);
        case 7 || 8:
          join(bottom, side);
        case 5 || 10:
          // Two opposite corners inside: whether they are joined through the middle decides
          // which pair of corners gets cut off.
          final joined = (tl + tr + br + bl) / 4 >= level;
          if ((shape == 5) == joined) {
            join(up, right);
            join(bottom, side);
          } else {
            join(side, up);
            join(right, bottom);
          }
      }
    }
  }

  // Walk each loop of crossings, drawing curves through the midpoints between them so the
  // grid's corners don't show.
  final path = Path()..fillType = PathFillType.evenOdd;
  final visited = <int>{};
  for (final start in crossings.keys) {
    if (!visited.add(start)) continue;
    final loop = [crossings[start]!];
    var previous = -1, current = start;
    while (true) {
      final first = links[2 * current], second = links[2 * current + 1];
      final next = first != previous ? first : second;
      if (next == -1 || next == start || !visited.add(next)) break;
      loop.add(crossings[next]!);
      previous = current;
      current = next;
    }
    if (loop.length < 3) continue;
    Offset mid(int k) =>
        (loop[k % loop.length] + loop[(k + 1) % loop.length]) / 2;
    final from = mid(loop.length - 1);
    path.moveTo(from.dx, from.dy);
    for (var k = 0; k < loop.length; k++) {
      final to = mid(k);
      path.quadraticBezierTo(loop[k].dx, loop[k].dy, to.dx, to.dy);
    }
    path.close();
  }
  return path;
}

/// Only takes touches inside the circle filling its box, so the corners reach whatever is behind.
/// Unlike a clip, it lets the child paint outside that circle.
class RoundHitArea extends SingleChildRenderObjectWidget {
  const RoundHitArea({super.key, required super.child});

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderRoundHitArea();
}

class _RenderRoundHitArea extends RenderProxyBox {
  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if ((position - size.center(Offset.zero)).distance > size.shortestSide / 2) {
      return false;
    }
    return super.hitTest(result, position: position);
  }
}
