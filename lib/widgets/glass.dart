import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../theme.dart';
import 'goo.dart';

/// Frosted-glass building blocks.
///
/// Real blur is only used on things floating above moving content (bars, map controls, sheets).
/// List cards are just translucent (see the card theme): behind them is the soft [GlassBackground],
/// which looks the same without a blur, and a blur per card would make scrolling stutter on phones.
const double glassBlurSigma = 18;

ui.ImageFilter get _blur => ui.ImageFilter.blur(sigmaX: glassBlurSigma, sigmaY: glassBlurSigma);

/// Fill colour of a glass surface. [strong] is for panels holding a lot of text over busy content.
///
/// The map is a native view that Flutter's blur can't reach, so what is behind a panel stays sharp.
/// The fills are nearly solid to keep panels readable without the blur.
Color glassTint(BuildContext context, {bool strong = false}) =>
    (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF16201A) : Colors.white).withValues(
      alpha: strong ? 0.95 : 0.9,
    );

/// Fill for small buttons floating on the map; solid enough to stand out without the blur.
Color glassButtonTint(BuildContext context) =>
    (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF16201A) : Colors.white).withValues(alpha: 0.85);

/// Thin light edge that makes glass surfaces read as raised panes.
Color glassEdge(BuildContext context) => Theme.of(context).brightness == Brightness.dark
    ? Colors.white.withValues(alpha: 0.12)
    : Colors.white.withValues(alpha: 0.8);

/// Blurs whatever is behind [child] and tints it. Uses the surrounding [BackdropGroup] when there
/// is one, so several panes on the same screen only sample the background once.
class GlassPanel extends StatelessWidget {
  final Widget child;
  final BorderRadius borderRadius;
  final bool strong;
  final Color? tint;

  /// Turn off inside scrolling rows, which would cut the shadow off at their edges.
  final bool shadow;

  const GlassPanel({
    super.key,
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(24)),
    this.strong = false,
    this.tint,
    this.shadow = true,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: shadow
            ? [BoxShadow(color: Colors.black.withValues(alpha: 0.10), blurRadius: 18, offset: const Offset(0, 6))]
            : null,
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter.grouped(
          filter: _blur,
          child: Material(
            type: MaterialType.transparency,
            child: Ink(
              decoration: BoxDecoration(
                color: tint ?? glassTint(context, strong: strong),
                borderRadius: borderRadius,
                border: Border.all(color: glassEdge(context)),
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// The background behind every screen: a calm, near-neutral base with a trace of green.
/// It is opaque, so a page being pushed never shows the previous page through it.
class GlassBackground extends StatelessWidget {
  final Widget child;
  const GlassBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final glow = theme.brightness == Brightness.dark ? 0.05 : 0.07;

    Widget blob(Alignment center, Color color, double radius) => DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: center,
          radius: radius,
          colors: [
            color.withValues(alpha: glow),
            color.withValues(alpha: 0),
          ],
        ),
      ),
    );

    return Stack(
      fit: StackFit.expand,
      children: [
        RepaintBoundary(
          child: Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(color: theme.scaffoldBackgroundColor),
              blob(const Alignment(-1, -1), AppTheme.brandLight, 1.2),
            ],
          ),
        ),
        child,
      ],
    );
  }
}

/// Scaffold on the app background. With [behindBar], the body scrolls under the frosted app bar;
/// scrolling content must then add `MediaQuery.paddingOf(context).top` to its own top padding.
class GlassScaffold extends StatelessWidget {
  final PreferredSizeWidget? appBar;
  final Widget? body;
  final Widget? floatingActionButton;
  final bool behindBar;

  const GlassScaffold({super.key, this.appBar, this.body, this.floatingActionButton, this.behindBar = false});

  @override
  Widget build(BuildContext context) => GlassBackground(
    child: Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: behindBar,
      appBar: appBar,
      body: body,
      floatingActionButton: floatingActionButton,
    ),
  );
}

/// App bar with a frosted background for content scrolling underneath.
class GlassAppBar extends StatelessWidget implements PreferredSizeWidget {
  final Widget? title;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;

  const GlassAppBar({super.key, this.title, this.actions, this.bottom});

  @override
  Size get preferredSize => Size.fromHeight(kToolbarHeight + (bottom?.preferredSize.height ?? 0));

  @override
  Widget build(BuildContext context) => AppBar(
    title: title,
    actions: actions,
    bottom: bottom,
    flexibleSpace: ClipRect(
      child: BackdropFilter.grouped(
        filter: _blur,
        // SizedBox.expand: the app bar only gives this a maximum height, and a childless
        // ColoredBox would otherwise collapse to nothing.
        child: ColoredBox(color: glassTint(context), child: const SizedBox.expand()),
      ),
    ),
  );
}

/// Modal bottom sheet on a frosted pane, with its own drag handle.
Future<T?> showGlassSheet<T>(BuildContext context, {required WidgetBuilder builder}) {
  const radius = BorderRadius.vertical(top: Radius.circular(28));
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    elevation: 0,
    constraints: const BoxConstraints(maxWidth: 560),
    builder: (sheetContext) => GlassPanel(
      borderRadius: radius,
      strong: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: Theme.of(sheetContext).colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Flexible(child: builder(sheetContext)),
        ],
      ),
    ),
  );
}

/// The round green "new post" button: a drop of liquid that wobbles under the finger and
/// stretches after it (see [GooBlob]).
class PostButton extends StatelessWidget {
  final VoidCallback onPressed;
  final String tooltip;
  final double size;

  /// A finger's global position to stretch towards, for a touch that started somewhere else.
  final ValueListenable<Offset?>? reachTowards;

  /// Whether it wobbles and drifts about on its own (see [GooBlob.lively]).
  final bool lively;

  const PostButton({
    super.key,
    required this.onPressed,
    required this.tooltip,
    this.size = 60,
    this.reachTowards,
    this.lively = false,
  });

  static const _gradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppTheme.brandLight, AppTheme.brand],
  );

  @override
  Widget build(BuildContext context) {
    // Outermost, so the tooltip doesn't catch touches on the square corners either.
    return RoundHitArea(
      child: Tooltip(
        message: tooltip,
        // Holding the button is a gesture of its own (see PostWheelButton).
        triggerMode: TooltipTriggerMode.manual,
        child: Semantics(
          button: true,
          child: GestureDetector(
            onTap: onPressed,
            child: GooBlob(
              size: size,
              gradient: _gradient,
              shadowColor: AppTheme.brand.withValues(alpha: 0.3),
              reachTowards: reachTowards,
              lively: lively,
              child: Icon(Icons.add_rounded, color: Colors.white, size: size * 0.55),
            ),
          ),
        ),
      ),
    );
  }
}

class GlassNavItem {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  const GlassNavItem(this.icon, this.selectedIcon, this.label);
}

/// Flat bottom bar across the full width with square corners, a hairline along its top, and a
/// curved notch in the middle holding the round post button.
///
/// The first [leadingCount] items sit left of the button, the rest right of it.
class GlassNavBar extends StatelessWidget {
  static const double _barHeight = 60;
  static const double buttonSize = 56;

  /// How far the button rises above the bar's top edge.
  static const double overhang = 22;

  /// Even space between the button and the notch around it.
  static const double notchGap = 5;

  final List<GlassNavItem> items;
  final int leadingCount;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  /// Sits in the notch; must be [buttonSize] across.
  final Widget postButton;

  /// Solid black with light icons, for use over full-screen photos and video.
  final bool dark;

  const GlassNavBar({
    super.key,
    required this.items,
    required this.leadingCount,
    required this.selectedIndex,
    required this.onSelected,
    required this.postButton,
    this.dark = false,
  });

  Widget _item(int i) => Expanded(
    child: _NavButton(item: items[i], selected: i == selectedIndex, onTap: () => onSelected(i)),
  );

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.paddingOf(context).bottom;
    final clipper = _NotchClipper();
    final scheme = (dark ? _darkBarTheme : Theme.of(context)).colorScheme;
    final hairline = dark ? Colors.white.withValues(alpha: 0.14) : scheme.outlineVariant;

    final Widget bar = SizedBox(
      height: overhang + _barHeight + inset,
      // Unclipped, so the post button can stretch up past the bar's top.
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // The clip also limits touches to the bar's shape, so the area beside the button above
          // the bar still reaches the page underneath.
          Positioned.fill(
            child: ClipPath(
              clipper: clipper,
              child: dark
                  ? const ColoredBox(color: Colors.black)
                  : BackdropFilter.grouped(
                      filter: _blur,
                      child: ColoredBox(color: glassTint(context)),
                    ),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(child: CustomPaint(painter: _BarEdgePainter(clipper, hairline))),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: overhang,
            height: _barHeight + inset,
            // Own Material so tab ripples draw above the glass, not behind it.
            child: Material(
              type: MaterialType.transparency,
              child: Padding(
                padding: EdgeInsets.only(bottom: inset),
                child: Row(
                  children: [
                    Expanded(child: Row(children: [for (var i = 0; i < leadingCount; i++) _item(i)])),
                    const SizedBox(width: buttonSize + 2 * notchGap + 28),
                    Expanded(child: Row(children: [for (var i = leadingCount; i < items.length; i++) _item(i)])),
                  ],
                ),
              ),
            ),
          ),
          Positioned(top: 0, left: 0, right: 0, child: Center(child: postButton)),
        ],
      ),
    );
    return dark ? Theme(data: _darkBarTheme, child: bar) : bar;
  }
}

final _darkBarTheme = AppTheme.dark();

class _NavButton extends StatelessWidget {
  final GlassNavItem item;
  final bool selected;
  final VoidCallback onTap;
  const _NavButton({required this.item, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = selected ? scheme.primary : scheme.onSurfaceVariant.withValues(alpha: 0.7);

    return Semantics(
      button: true,
      selected: selected,
      excludeSemantics: true,
      label: item.label,
      child: InkResponse(
        onTap: onTap,
        radius: 34,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(selected ? item.selectedIcon : item.icon, color: color, size: 25),
              const SizedBox(height: 3),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 220),
                style: TextStyle(
                  color: color,
                  fontSize: 11.5,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
                child: Text(item.label, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bar outline: a straight top edge across the full width with square corners, and a circular
/// notch sharing the button's centre so the gap around the button is even. Small rounded shoulders
/// join the notch to the top edge.
class _NotchClipper extends CustomClipper<ui.Path> {
  static const double _shoulder = 12;
  static const double _notchRadius = GlassNavBar.buttonSize / 2 + GlassNavBar.notchGap;

  /// Just the top edge with the notch, from the left side to the right.
  ui.Path topEdge(Size size) {
    final cx = size.width / 2;
    const top = GlassNavBar.overhang;
    const buttonCenterY = GlassNavBar.buttonSize / 2;

    // Each shoulder is a circle touching both the top edge and the notch from outside, which fixes
    // its centre (dx, dy away from the button's centre) and where it meets the notch (scale).
    const dy = top + _shoulder - buttonCenterY;
    const reach = _notchRadius + _shoulder;
    final dx = math.sqrt(reach * reach - dy * dy);
    const scale = _notchRadius / reach;
    const meetY = buttonCenterY + dy * scale;
    final meetDx = dx * scale;

    return ui.Path()
      ..moveTo(0, top)
      ..lineTo(cx - dx, top)
      ..arcToPoint(Offset(cx - meetDx, meetY), radius: const Radius.circular(_shoulder))
      ..arcToPoint(Offset(cx + meetDx, meetY), radius: const Radius.circular(_notchRadius), clockwise: false)
      ..arcToPoint(Offset(cx + dx, top), radius: const Radius.circular(_shoulder))
      ..lineTo(size.width, top);
  }

  @override
  ui.Path getClip(Size size) => topEdge(size)
    ..lineTo(size.width, size.height)
    ..lineTo(0, size.height)
    ..close();

  @override
  bool shouldReclip(_NotchClipper oldClipper) => false;
}

/// Hairline along the bar's top edge and around the notch.
class _BarEdgePainter extends CustomPainter {
  final _NotchClipper clipper;
  final Color edge;
  _BarEdgePainter(this.clipper, this.edge);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      clipper.topEdge(size),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = edge,
    );
  }

  @override
  bool shouldRepaint(_BarEdgePainter old) => old.edge != edge;
}
