import 'package:flutter/material.dart';

import '../core/debug_bubble_theme.dart';
import '../core/debug_log_level.dart';

/// Central theme resolver and severity color palette for debug_bubble UI per UI_UX_SPEC.md §7, §8.
class DebugDashboardTheme {
  const DebugDashboardTheme._();

  /// Minimum touch target dimension in logical pixels per accessibility guidelines (UI_UX_SPEC.md §8).
  static const double minTouchTarget = 48.0;

  /// Resolves the dashboard's [ThemeData] given the host [context] and [configTheme].
  ///
  /// Guarantees that the dashboard does not inherit unwanted styling from the host app
  /// and respects [ThemeMode.system], [ThemeMode.light], and [ThemeMode.dark] (UI_UX_SPEC.md §7).
  static ThemeData resolveTheme(
    BuildContext context,
    DebugBubbleTheme configTheme,
  ) {
    final platformBrightness =
        MediaQuery.maybePlatformBrightnessOf(context) ?? Brightness.light;

    final isDark = switch (configTheme.mode) {
      ThemeMode.system => platformBrightness == Brightness.dark,
      ThemeMode.dark => true,
      ThemeMode.light => false,
    };

    final colorScheme = ColorScheme.fromSeed(
      seedColor: Colors.deepPurple,
      brightness: isDark ? Brightness.dark : Brightness.light,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: isDark ? Brightness.dark : Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: isDark
          ? const Color(0xFF141218)
          : const Color(0xFFFEF7FF),
      cardTheme: CardThemeData(
        color: isDark ? const Color(0xFF1E1B24) : const Color(0xFFF7F2FA),
        elevation: 1,
        margin: const EdgeInsets.symmetric(vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dividerTheme: DividerThemeData(
        color: isDark ? Colors.white12 : Colors.black12,
        thickness: 1,
        space: 16,
      ),
    );
  }

  /// Returns the color for [level] adhering to high-contrast guidelines and [theme] overrides.
  static Color levelColor(
    DebugLogLevel level, {
    required Brightness brightness,
    DebugBubbleTheme? theme,
  }) {
    if (theme?.levelColors?.containsKey(level) == true) {
      return theme!.levelColors![level]!;
    }

    final isDark = brightness == Brightness.dark;
    return switch (level) {
      DebugLogLevel.debug =>
        isDark ? const Color(0xFF8E8E93) : const Color(0xFF636366),
      DebugLogLevel.info =>
        isDark ? const Color(0xFF0A84FF) : const Color(0xFF007AFF),
      DebugLogLevel.success =>
        isDark ? const Color(0xFF30D158) : const Color(0xFF34C759),
      DebugLogLevel.warning =>
        isDark ? const Color(0xFFFF9F0A) : const Color(0xFFFF9500),
      DebugLogLevel.error =>
        isDark ? const Color(0xFFFF453A) : const Color(0xFFFF3B30),
      DebugLogLevel.critical =>
        isDark ? const Color(0xFFBF5AF2) : const Color(0xFFAF52DE),
    };
  }

  /// Whether animations should be skipped or instant per accessibility settings (UI_UX_SPEC.md §8).
  static bool isReducedMotion(BuildContext context) {
    return MediaQuery.maybeDisableAnimationsOf(context) ?? false;
  }
}
