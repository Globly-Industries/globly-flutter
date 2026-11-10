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
    (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF16201A) : Colors.white)
        .withValues(alpha: strong ? 0.95 : 0.9);

/// Fill for small buttons floating on the map; solid enough to stand out without the blur.
Color glassButtonTint(BuildContext context) =>
    (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF16201A) : Colors.white)
        .withValues(alpha: 0.85);

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
              colors: [color.withValues(alpha: glow), color.withValues(alpha: 0)],
            ),
          ),
        );

    return Stack(fit: StackFit.expand, children: [
      RepaintBoundary(
        child: Stack(fit: StackFit.expand, children: [
          ColoredBox(color: theme.scaffoldBackgroundColor),
          blob(const Alignment(-1, -1), AppTheme.brandLight, 1.2),
        ]),
      ),
      child,
    ]);
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
      child: Column(mainAxisSize: MainAxisSize.min, children: [
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
      ]),
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

  const PostButton({super.key, required this.onPressed, required this.tooltip, this.size = 60, this.reachTowards});

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

/// Frosted bottom bar with a curved notch in the middle holding the round post button.
///
/// The first [leadingCount] items sit left of the button, the rest right of it.
class GlassNavBar extends StatelessWidget {
  static const double _barHeight = 68;
  static const double buttonSize = 60;

  /// How far the button rises above the bar's top edge.
  static const double overhang = 26;

  /// Even space between the button and the notch around it.
  static const double notchGap = 6;

  final List<GlassNavItem> items;
  final int leadingCount;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  /// Sits in the notch; must be [buttonSize] across.
  final Widget postButton;

  const GlassNavBar({
    super.key,
    required this.items,
    required this.leadingCount,
    required this.selectedIndex,
    required this.onSelected,
    required this.postButton,
  });

  Widget _item(int i) => Expanded(
        child: _NavButton(item: items[i], selected: i == selectedIndex, onTap: () => onSelected(i)),
      );

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.paddingOf(context).bottom;
    final clipper = _NotchClipper();

    return SizedBox(
      height: overhang + _barHeight + inset,
      // Unclipped, so the post button can stretch up past the bar's top.
      child: Stack(clipBehavior: Clip.none, children: [
        Positioned.fill(child: CustomPaint(painter: _BarShadowPainter(clipper))),
        // The clip also limits touches to the bar's shape, so the corners and the area beside
        // the button still reach the page underneath.
        Positioned.fill(
          child: ClipPath(
            clipper: clipper,
            child: BackdropFilter.grouped(
              filter: _blur,
              child: ColoredBox(color: glassTint(context)),
            ),
          ),
        ),
        Positioned.fill(child: IgnorePointer(child: CustomPaint(painter: _BarEdgePainter(clipper, glassEdge(context))))),
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
              child: Row(children: [
                Expanded(child: Row(children: [for (var i = 0; i < leadingCount; i++) _item(i)])),
                const SizedBox(width: buttonSize + 24),
                Expanded(child: Row(children: [for (var i = leadingCount; i < items.length; i++) _item(i)])),
              ]),
            ),
          ),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Center(child: postButton),
        ),
      ]),
    );
  }
}

class _NavButton extends StatelessWidget {
  final GlassNavItem item;
  final bool selected;
  final VoidCallback onTap;
  const _NavButton({required this.item, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = selected ? scheme.primary : scheme.onSurfaceVariant;

    return Semantics(
      button: true,
      selected: selected,
      excludeSemantics: true,
      label: item.label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            // Soft glow rising from the bottom of the selected tab.
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [scheme.primary.withValues(alpha: selected ? 0.12 : 0), scheme.primary.withValues(alpha: 0)],
            ),
          ),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(selected ? item.selectedIcon : item.icon, color: color, size: 26),
            const SizedBox(height: 3),
            Text(
              item.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: color, fontSize: 12, fontWeight: selected ? FontWeight.w700 : FontWeight.w500),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Bar outline: rounded top corners, and a circular notch sharing the button's centre so the gap
/// around the button is even. Small rounded shoulders join the notch to the top edge.
class _NotchClipper extends CustomClipper<ui.Path> {
  static const double _corner = 24;
  static const double _shoulder = 14;
  static const double _notchRadius = GlassNavBar.buttonSize / 2 + GlassNavBar.notchGap;

  @override
  ui.Path getClip(Size size) {
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
      ..moveTo(0, size.height)
      ..lineTo(0, top + _corner)
      ..arcToPoint(const Offset(_corner, top), radius: const Radius.circular(_corner))
      ..lineTo(cx - dx, top)
      ..arcToPoint(Offset(cx - meetDx, meetY), radius: const Radius.circular(_shoulder))
      ..arcToPoint(Offset(cx + meetDx, meetY), radius: const Radius.circular(_notchRadius), clockwise: false)
      ..arcToPoint(Offset(cx + dx, top), radius: const Radius.circular(_shoulder))
      ..lineTo(size.width - _corner, top)
      ..arcToPoint(Offset(size.width, top + _corner), radius: const Radius.circular(_corner))
      ..lineTo(size.width, size.height)
      ..close();
  }

  @override
  bool shouldReclip(_NotchClipper oldClipper) => false;
}

/// Soft shadow outside the bar only, so it doesn't muddy the glass.
class _BarShadowPainter extends CustomPainter {
  final _NotchClipper clipper;
  _BarShadowPainter(this.clipper);

  @override
  void paint(Canvas canvas, Size size) {
    final bar = clipper.getClip(size);
    final outside = ui.Path.combine(
      ui.PathOperation.difference,
      ui.Path()..addRect(Offset.zero & size),
      bar,
    );
    canvas.save();
    canvas.clipPath(outside);
    canvas.drawShadow(bar, Colors.black.withValues(alpha: 0.5), 10, true);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_BarShadowPainter old) => false;

  @override
  bool? hitTest(Offset position) => false;
}

class _BarEdgePainter extends CustomPainter {
  final _NotchClipper clipper;
  final Color edge;
  _BarEdgePainter(this.clipper, this.edge);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      clipper.getClip(size),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = edge,
    );
  }

  @override
  bool shouldRepaint(_BarEdgePainter old) => old.edge != edge;
}
