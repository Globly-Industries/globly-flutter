import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../models/models.dart';
import '../theme.dart';
import 'common.dart';
import 'glass.dart';
import 'goo.dart';
import 'haptics.dart';

/// Direction the wheel fans out in: up from a bottom bar, right from a side rail.
const double wheelFansUp = -math.pi / 2;
const double wheelFansRight = 0;

const double _radius = 112;
const double _optionSize = 74;

/// Angle between neighbouring options.
const double _step = 50 * math.pi / 180;

/// Touches closer to the centre than this select nothing, so a hold can stay "undecided".
const double _deadZone = 44;

double _optionAngle(int index, int count, double direction) =>
    direction + (index - (count - 1) / 2) * _step;

/// Which option a finger at [position] points at, or null if it is in the centre or between options.
int? wheelSelectionAt(Offset position, Offset center, int count, double direction) {
  final delta = position - center;
  if (delta.distance < _deadZone) return null;
  for (var i = 0; i < count; i++) {
    var difference = (delta.direction - _optionAngle(i, count, direction)) % (2 * math.pi);
    if (difference > math.pi) difference -= 2 * math.pi;
    if (difference.abs() <= _step / 2) return i;
  }
  return null;
}

/// The round "+" button that opens the wheel of post types.
///
/// Press and drag straight onto an option and let go, or tap to open and then tap an option.
/// Holding still also opens it, so the options can be seen before choosing.
class PostWheelButton extends StatefulWidget {
  final List<MediaType> options;
  final double direction;
  final double size;
  final String tooltip;

  /// Asked before opening, e.g. to turn guests away.
  final bool Function() canOpen;
  final ValueChanged<MediaType> onSelected;

  const PostWheelButton({
    super.key,
    required this.options,
    required this.direction,
    required this.size,
    required this.tooltip,
    required this.canOpen,
    required this.onSelected,
  });

  @override
  State<PostWheelButton> createState() => _PostWheelButtonState();
}

class _PostWheelButtonState extends State<PostWheelButton> with SingleTickerProviderStateMixin {
  late final _animation = AnimationController(
    vsync: this,
    // Long enough opening to see the options drawn out of the button; closing stays snappy.
    duration: const Duration(milliseconds: 380),
    reverseDuration: const Duration(milliseconds: 160),
  );

  /// Where the holding finger is; null when the wheel is used by tapping.
  final _finger = ValueNotifier<Offset?>(null);

  /// The option under the finger, to give a little vibration each time it changes.
  int? _hovered;

  /// A touch anywhere on the open wheel, after the one that opened it (if any) has lifted.
  int? _pointer;
  Offset _pointerStart = Offset.zero;

  // An overlay rather than a dialog: pushing a route makes the Navigator cancel active touches,
  // which would end the hold-and-drag gesture the moment the wheel appears.
  OverlayEntry? _overlay;

  /// Makes the back button close the wheel, as it would a dialog.
  LocalHistoryEntry? _backHandler;
  ModalRoute<Object?>? _route;
  bool _closing = false;

  Offset get _center {
    final box = context.findRenderObject()! as RenderBox;
    return box.localToGlobal(box.size.center(Offset.zero));
  }

  @override
  void dispose() {
    _overlay?.remove();
    _overlay = null;
    final backHandler = _backHandler;
    final route = _route;
    if (backHandler != null && route != null) {
      // Not while the tree is being torn down, as this updates the route, which may be going too.
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (route.isActive) backHandler.remove();
      });
    }
    _animation.dispose();
    _finger.dispose();
    super.dispose();
  }

  void _open() {
    if (_overlay != null || !widget.canOpen()) return;
    final center = _center;
    final overlay = _overlay = OverlayEntry(
      builder: (_) => _PostWheel(
        options: widget.options,
        center: center,
        direction: widget.direction,
        size: widget.size,
        animation: _animation,
        finger: _finger,
        onClose: _close,
        onPointerDown: _pointerDown,
        onPointerMove: _pointerMove,
        onPointerUp: _pointerUp,
      ),
    );
    Overlay.of(context, rootOverlay: true).insert(overlay);
    setState(() {}); // Hides this button behind its copy on the wheel.
    final backHandler = _backHandler = LocalHistoryEntry(onRemove: _close);
    _route = ModalRoute.of(context)?..addLocalHistoryEntry(backHandler);
    _animation.forward();
  }

  Future<void> _close([MediaType? selected]) async {
    final overlay = _overlay;
    if (overlay == null || _closing) return;
    _closing = true;

    final backHandler = _backHandler;
    _backHandler = null;
    backHandler?.remove();
    _finger.value = null;
    _pointer = null;
    // Acted on at once, still within the tap, not after the closing animation: browsers only open
    // the camera from inside the user's gesture, and iOS Safari ignores it a moment later.
    if (selected != null && mounted) widget.onSelected(selected);

    try {
      await _animation.reverse().orCancel;
    } on TickerCanceled {
      return; // Disposed while closing, which has already removed the overlay.
    }
    overlay.remove();
    _overlay = null;
    _closing = false;
    if (mounted) setState(() {});
  }

  void _press(Offset position) {
    _finger.value = position;
    _hovered = null;
    Haptics.press();
    _open();
    _move(position);
  }

  void _move(Offset position) {
    if (_overlay == null || _closing) return;
    _finger.value = position;
    final index = wheelSelectionAt(position, _center, widget.options.length, widget.direction);
    if (index != _hovered && index != null) Haptics.tick();
    _hovered = index;
  }

  void _release() {
    final finger = _finger.value;
    if (finger == null || _overlay == null) return;
    final index = wheelSelectionAt(finger, _center, widget.options.length, widget.direction);
    _finger.value = null;
    // Let go without choosing: the wheel stays open for tapping.
    if (index != null) _close(widget.options[index]);
  }

  // Touches on the open wheel. The button reaches after them and the option under them swells,
  // just as for the finger that opened it; dragging onto an option and letting go chooses it. A
  // plain tap is left to the options and the shade, so tapping far off doesn't pick anything.
  void _pointerDown(PointerDownEvent event) {
    if (_pointer != null || _closing) return;
    _pointer = event.pointer;
    _pointerStart = event.position;
    _hovered = null;
    _move(event.position);
  }

  void _pointerMove(PointerMoveEvent event) {
    if (event.pointer == _pointer) _move(event.position);
  }

  void _pointerUp(PointerEvent event) {
    if (event.pointer != _pointer) return;
    _pointer = null;
    if (event is PointerUpEvent && (event.position - _pointerStart).distance > kTouchSlop) {
      _release();
    } else {
      _finger.value = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // Whichever comes first: the finger moving off the button, or staying on it for a moment.
      onPanStart: (details) => _press(details.globalPosition),
      onPanUpdate: (details) => _move(details.globalPosition),
      onPanEnd: (_) => _release(),
      onPanCancel: () => _finger.value = null,
      onLongPressStart: (details) => _press(details.globalPosition),
      onLongPressMoveUpdate: (details) => _move(details.globalPosition),
      onLongPressEnd: (_) => _release(),
      // While the wheel is open its copy of the button stands in for this one. Hidden rather than
      // removed: it still follows the finger that opened the wheel. Left showing, it would peek
      // out from behind the copy whenever that squeezes or stretches.
      child: Opacity(
        opacity: _overlay == null ? 1 : 0,
        child: PostButton(onPressed: _open, tooltip: widget.tooltip, size: widget.size),
      ),
    );
  }
}

class _PostWheel extends StatelessWidget {
  final List<MediaType> options;
  final Offset center;
  final double direction;
  final double size;
  final Animation<double> animation;
  final ValueNotifier<Offset?> finger;
  final void Function([MediaType? selected]) onClose;
  final PointerDownEventListener onPointerDown;
  final PointerMoveEventListener onPointerMove;
  final ValueChanged<PointerEvent> onPointerUp;

  const _PostWheel({
    required this.options,
    required this.center,
    required this.direction,
    required this.size,
    required this.animation,
    required this.finger,
    required this.onClose,
    required this.onPointerDown,
    required this.onPointerMove,
    required this.onPointerUp,
  });

  @override
  Widget build(BuildContext context) {
    final curve = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutBack,
      reverseCurve: Curves.easeIn,
    );
    final fade = CurvedAnimation(parent: animation, curve: Curves.easeOut);

    return Material(
      type: MaterialType.transparency,
      // Sees every touch on the wheel without getting in the way of the taps below it.
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: onPointerDown,
        onPointerMove: onPointerMove,
        onPointerUp: onPointerUp,
        onPointerCancel: onPointerUp,
        child: Stack(
          children: [
            // Tapping anywhere else closes the wheel. The shade pools round the wheel and fades out
            // towards the edges, so the screen stays in view without competing with the options.
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onClose,
                child: FadeTransition(
                  opacity: fade,
                  child: CustomPaint(painter: _ShadePainter(center)),
                ),
              ),
            ),
            ValueListenableBuilder<Offset?>(
              valueListenable: finger,
              builder: (context, position, _) => _GooOptions(
                options: options,
                center: center,
                direction: direction,
                buttonSize: size,
                open: curve,
                selected: position == null
                    ? null
                    : wheelSelectionAt(position, center, options.length, direction),
                onTap: (type) => onClose(type),
              ),
            ),
            // The "+" turned into a close button, in the exact place of the real one. It reaches after
            // the finger that is choosing, as if the option were being pulled out of it, and stirs
            // restlessly for as long as a finger is down.
            Positioned(
              left: center.dx - size / 2,
              top: center.dy - size / 2,
              child: RotationTransition(
                turns: Tween<double>(begin: 0, end: 0.125).animate(fade),
                child: ValueListenableBuilder<Offset?>(
                  valueListenable: finger,
                  builder: (context, position, _) => PostButton(
                    onPressed: onClose,
                    tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                    size: size,
                    reachTowards: finger,
                    lively: position != null,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The options as droplets of the same goo as the button. Opening, each is drawn out of the button
/// on a beaded neck that thins and snaps; closing, they are sucked back in. The option under the
/// finger swells and fills with its colour.
class _GooOptions extends StatefulWidget {
  final List<MediaType> options;
  final Offset center;
  final double direction;
  final double buttonSize;
  final Animation<double> open;
  final int? selected;
  final ValueChanged<MediaType> onTap;

  const _GooOptions({
    required this.options,
    required this.center,
    required this.direction,
    required this.buttonSize,
    required this.open,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_GooOptions> createState() => _GooOptionsState();
}

class _GooOptionsState extends State<_GooOptions> with TickerProviderStateMixin {
  /// How swollen each option is: 1 while the finger is on it.
  late final List<AnimationController> _swell = [
    for (final _ in widget.options)
      AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 260),
        reverseDuration: const Duration(milliseconds: 160),
      ),
  ];
  late final List<Animation<double>> _swellCurve = [
    for (final controller in _swell)
      CurvedAnimation(parent: controller, curve: Curves.elasticOut, reverseCurve: Curves.easeOut),
  ];

  @override
  void didUpdateWidget(_GooOptions old) {
    super.didUpdateWidget(old);
    if (old.selected == widget.selected) return;
    for (var i = 0; i < _swell.length; i++) {
      if (i == widget.selected) {
        _swell[i].forward();
      } else {
        _swell[i].reverse();
      }
    }
  }

  @override
  void dispose() {
    for (final controller in _swell) {
      controller.dispose();
    }
    super.dispose();
  }

  Offset _direction(int i) =>
      Offset.fromDirection(_optionAngle(i, widget.options.length, widget.direction));

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final plain = Color.alphaBlend(glassTint(context, strong: true), scheme.surface);

    return AnimatedBuilder(
      animation: Listenable.merge([widget.open, ..._swellCurve]),
      builder: (context, _) {
        final t = widget.open.value;
        // The labels come in once the droplets are mostly out, so they never sit on a neck.
        final contentOpacity = ((t - 0.5) / 0.5).clamp(0.0, 1.0);
        return Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _OptionGooPainter(
                    center: widget.center,
                    directions: [for (var i = 0; i < widget.options.length; i++) _direction(i)],
                    buttonSize: widget.buttonSize,
                    open: t,
                    swell: [for (final s in _swellCurve) s.value],
                    colors: [
                      for (var i = 0; i < widget.options.length; i++)
                        Color.lerp(
                          plain,
                          AppTheme.mediaColor(widget.options[i]),
                          _swellCurve[i].value.clamp(0.0, 1.0),
                        )!,
                    ],
                    edge: glassEdge(context),
                  ),
                ),
              ),
            ),
            for (var i = 0; i < widget.options.length; i++)
              Positioned(
                left: widget.center.dx + _direction(i).dx * _radius * t - _optionSize,
                top: widget.center.dy + _direction(i).dy * _radius * t - _optionSize / 2,
                width: _optionSize * 2,
                child: Opacity(
                  opacity: contentOpacity,
                  child: Transform.scale(
                    scale: 1 + 0.15 * _swellCurve[i].value,
                    child: _WheelOption(
                      type: widget.options[i],
                      selected: i == widget.selected,
                      onTap: () => widget.onTap(widget.options[i]),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// An option's icon and label, sitting in its droplet (drawn by [_OptionGooPainter]).
class _WheelOption extends StatelessWidget {
  final MediaType type;
  final bool selected;
  final VoidCallback onTap;
  const _WheelOption({required this.type, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.mediaColor(type);
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox.square(
          dimension: _optionSize,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(mediaIcon(type), size: 26, color: selected ? Colors.white : color),
              const SizedBox(height: 2),
              Text(
                mediaLabel(context, type),
                maxLines: 1,
                style: TextStyle(
                  color: selected ? Colors.white : scheme.onSurface,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OptionGooPainter extends CustomPainter {
  final Offset center;
  final List<Offset> directions;
  final double buttonSize;

  /// How far open the wheel is: 0 shut, 1 open (a little past 1 while overshooting).
  final double open;
  final List<double> swell;
  final List<Color> colors;
  final Color edge;

  _OptionGooPainter({
    required this.center,
    required this.directions,
    required this.buttonSize,
    required this.open,
    required this.swell,
    required this.colors,
    required this.edge,
  });

  /// Where along the way out the neck's beads sit, and how big each starts, as shares.
  static const _beads = [
    (along: 0.3, size: 0.42),
    (along: 0.55, size: 0.34),
    (along: 0.8, size: 0.28),
  ];

  /// Smallest bead drawn, in logical pixels.
  static const double _minBead = 6;

  @override
  void paint(Canvas canvas, Size size) {
    if (open <= 0) return;
    final shadow = Paint()
      ..color = Colors.black.withValues(alpha: 0.14)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    final outline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = edge;

    for (var i = 0; i < directions.length; i++) {
      final direction = directions[i];
      final out = _radius * open;
      final spot = center + direction * out;
      final grown = open.clamp(0.0, 1.0);
      final s = swell[i];
      final radius = _optionSize / 2 * (0.25 + 0.75 * grown) * (1 + 0.15 * s);
      // The neck thins as the droplet gets further out, and snaps just as it arrives.
      final neck = math.pow((1 - grown).clamp(0.0, 1.0), 0.6).toDouble();

      final circles = <GooCircle>[
        // Where the neck grows out of the button; small enough to stay hidden under it even when
        // the button leans, and gone once the neck has snapped.
        if (neck > 0.05) (centre: center, radius: buttonSize / 2 * 0.6),
        (centre: spot, radius: radius),
        // Beads too small to read as part of a neck would just look like specks.
        for (final bead in _beads)
          if (_optionSize / 2 * bead.size * neck >= _minBead)
            (
              centre: center + direction * out * bead.along,
              radius: _optionSize / 2 * bead.size * neck,
            ),
      ];
      // Once the neck has snapped the droplet is a lone circle, which traces as exactly itself, so
      // it can skip the tracing. That is how it spends nearly all its time on screen.
      final path = circles.length == 1
          ? (Path()..addOval(Rect.fromCircle(center: spot, radius: radius)))
          : traceGoo(circles, gooLoneLevel, 3);

      canvas.drawPath(path.shift(const Offset(0, 3)), shadow);
      canvas.drawPath(path, Paint()..color = colors[i]);
      canvas.drawPath(path, outline);
    }
  }

  @override
  // Rebuilt on every finger movement, to find the option under it; only what is drawn counts.
  bool shouldRepaint(_OptionGooPainter old) =>
      old.center != center ||
      old.buttonSize != buttonSize ||
      old.open != open ||
      old.edge != edge ||
      !listEquals(old.directions, directions) ||
      !listEquals(old.swell, swell) ||
      !listEquals(old.colors, colors);
}

/// A soft shade pooled round the wheel, fading towards the edges of the screen.
class _ShadePainter extends CustomPainter {
  final Offset center;
  _ShadePainter(this.center);

  @override
  void paint(Canvas canvas, Size size) {
    final reach = math.max(_radius * 3.2, size.longestSide * 0.75);
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = ui.Gradient.radial(center, reach, [
          Colors.black.withValues(alpha: 0.42),
          Colors.black.withValues(alpha: 0.10),
        ]),
    );
  }

  @override
  bool shouldRepaint(_ShadePainter old) => old.center != center;
}
