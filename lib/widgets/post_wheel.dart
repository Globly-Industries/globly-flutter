import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../models/models.dart';
import '../theme.dart';
import 'common.dart';
import 'glass.dart';
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

double _optionAngle(int index, int count, double direction) => direction + (index - (count - 1) / 2) * _step;

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
    duration: const Duration(milliseconds: 220),
    reverseDuration: const Duration(milliseconds: 120),
  );

  /// Where the holding finger is; null when the wheel is used by tapping.
  final _finger = ValueNotifier<Offset?>(null);

  /// The option under the finger, to give a little vibration each time it changes.
  int? _hovered;

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
      ),
    );
    Overlay.of(context, rootOverlay: true).insert(overlay);
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

    try {
      await _animation.reverse().orCancel;
    } on TickerCanceled {
      return; // Disposed while closing, which has already removed the overlay.
    }
    overlay.remove();
    _overlay = null;
    _closing = false;
    if (selected != null && mounted) widget.onSelected(selected);
  }

  void _press(Offset position) {
    _finger.value = position;
    _hovered = null;
    Haptics.press();
    _open();
    _move(position);
  }

  void _move(Offset position) {
    if (_overlay == null) return;
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
      child: PostButton(onPressed: _open, tooltip: widget.tooltip, size: widget.size),
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

  const _PostWheel({
    required this.options,
    required this.center,
    required this.direction,
    required this.size,
    required this.animation,
    required this.finger,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final curve = CurvedAnimation(parent: animation, curve: Curves.easeOutBack, reverseCurve: Curves.easeIn);
    final fade = CurvedAnimation(parent: animation, curve: Curves.easeOut);

    return Material(
      type: MaterialType.transparency,
      child: Stack(children: [
        // Tapping anywhere else closes the wheel.
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onClose,
            child: FadeTransition(
              opacity: fade,
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                child: ColoredBox(color: Colors.black.withValues(alpha: 0.25)),
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: FadeTransition(
              opacity: fade,
              child: CustomPaint(
                painter: _TrackPainter(
                  center: center,
                  from: _optionAngle(0, options.length, direction),
                  to: _optionAngle(options.length - 1, options.length, direction),
                  color: glassTint(context),
                ),
              ),
            ),
          ),
        ),
        ValueListenableBuilder<Offset?>(
          valueListenable: finger,
          builder: (context, position, _) {
            final selected = position == null ? null : wheelSelectionAt(position, center, options.length, direction);
            return AnimatedBuilder(
              animation: curve,
              builder: (context, _) => Stack(children: [
                for (var i = 0; i < options.length; i++)
                  _positioned(
                    center + Offset.fromDirection(_optionAngle(i, options.length, direction), _radius * curve.value),
                    _WheelOption(type: options[i], selected: i == selected, onTap: () => onClose(options[i])),
                  ),
              ]),
            );
          },
        ),
        // The "+" turned into a close button, in the exact place of the real one.
        Positioned(
          left: center.dx - size / 2,
          top: center.dy - size / 2,
          child: RotationTransition(
            turns: Tween<double>(begin: 0, end: 0.125).animate(fade),
            child: PostButton(
              onPressed: onClose,
              tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
              size: size,
            ),
          ),
        ),
      ]),
    );
  }

  /// Centres the option's circle (not its label) on [at].
  Widget _positioned(Offset at, Widget child) => Positioned(
        left: at.dx - _optionSize,
        top: at.dy - _optionSize / 2,
        width: _optionSize * 2,
        child: Opacity(opacity: animation.value.clamp(0.0, 1.0), child: child),
      );
}

class _WheelOption extends StatelessWidget {
  final MediaType type;
  final bool selected;
  final VoidCallback onTap;
  const _WheelOption({required this.type, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.mediaColor(type);
    final scheme = Theme.of(context).colorScheme;
    // The label sits inside the circle, so it is always on one solid surface.
    return Center(
      child: AnimatedScale(
        scale: selected ? 1.2 : 1,
        duration: const Duration(milliseconds: 120),
        child: GlassPanel(
          borderRadius: BorderRadius.circular(_optionSize / 2),
          tint: selected ? color : Color.alphaBlend(glassTint(context, strong: true), scheme.surface),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox.square(
              dimension: _optionSize,
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
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
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// The ring segment the options sit on.
class _TrackPainter extends CustomPainter {
  final Offset center;
  final double from;
  final double to;
  final Color color;

  _TrackPainter({required this.center, required this.from, required this.to, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: _radius),
      from,
      to - from,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = _optionSize + 12
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_TrackPainter old) => old.center != center || old.from != from || old.to != to || old.color != color;
}
