import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'models/models.dart';

/// Visual identity: a fresh green primary on soft, frosted-glass surfaces.
class AppTheme {
  /// Main brand green. Dark enough for white text on buttons (about 5:1 contrast).
  static const brand = Color(0xFF15803D);

  /// Brighter green for the dark theme and for gradients.
  static const brandLight = Color(0xFF22C55E);

  /// Fixed background of the login screen, readable in both light and dark mode.
  static const brandGradient = [Color(0xFF136F36), Color(0xFF15803D)];

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  /// On web the default transition scales the page below by 10%. The map measures itself on screen,
  /// so it would keep that size afterwards, drawing everything too large and off-centre.
  /// This one leaves the page below untouched.
  static final _webPageTransitions = PageTransitionsTheme(builders: {
    for (final platform in TargetPlatform.values) platform: const FadeUpwardsPageTransitionsBuilder(),
  });

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: brand,
      brightness: brightness,
      dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
    ).copyWith(
      primary: isDark ? const Color(0xFF4ADE80) : brand,
      onPrimary: isDark ? const Color(0xFF052E16) : Colors.white,
    );
    final rounded = RoundedRectangleBorder(borderRadius: BorderRadius.circular(16));
    // A faint dark line in light mode: on the near-white background a light edge would vanish.
    final hairline = isDark ? Colors.white.withValues(alpha: 0.10) : Colors.black.withValues(alpha: 0.06);
    final fieldFill = isDark ? Colors.white.withValues(alpha: 0.06) : Colors.white.withValues(alpha: 0.55);

    return ThemeData(
      pageTransitionsTheme: kIsWeb ? _webPageTransitions : null,
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: isDark ? const Color(0xFF0F1412) : const Color(0xFFF1F3F2),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: scheme.onSurface),
      ),
      // Translucent over the soft app background; see GlassPanel for why cards skip the real blur.
      cardTheme: CardThemeData(
        elevation: 0,
        color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.white.withValues(alpha: 0.72),
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: BorderSide(color: hairline)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: fieldFill,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: hairline)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(minimumSize: const Size(64, 52), shape: rounded,
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 52),
          shape: rounded,
          backgroundColor: fieldFill,
          side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(shape: rounded)),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          side: WidgetStatePropertyAll(BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5))),
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected) ? scheme.primary : fieldFill,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected) ? scheme.onPrimary : scheme.onSurface,
          ),
          iconColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected) ? scheme.onPrimary : scheme.onSurface,
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: fieldFill,
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        shape: const StadiumBorder(),
      ),
      navigationRailTheme: const NavigationRailThemeData(backgroundColor: Colors.transparent),
      dialogTheme: DialogThemeData(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24))),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant.withValues(alpha: 0.5)),
    );
  }

  /// Accent colour per content type, used for map pins and badges.
  static Color mediaColor(MediaType? type) => switch (type) {
        MediaType.image => const Color(0xFF00897B),
        MediaType.video => const Color(0xFFE53935),
        MediaType.audio => const Color(0xFF8E24AA),
        _ => const Color(0xFF1E88E5),
      };
}
