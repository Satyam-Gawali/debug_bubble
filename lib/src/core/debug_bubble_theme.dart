import 'package:flutter/material.dart';

import 'debug_log_level.dart';

/// Theming options for the debug bubble and dashboard.
class DebugBubbleTheme {
  const DebugBubbleTheme({
    this.mode = ThemeMode.system,
    this.bubbleColor,
    this.bubbleIconColor,
    this.levelColors,
  });

  /// Light, dark, or system theme mode for the dashboard.
  final ThemeMode mode;

  /// Background color of the floating bubble.
  final Color? bubbleColor;

  /// Icon / text color of the floating bubble.
  final Color? bubbleIconColor;

  /// Custom per-level colors for indicator dots and tags.
  final Map<DebugLogLevel, Color>? levelColors;

  DebugBubbleTheme copyWith({
    ThemeMode? mode,
    Color? bubbleColor,
    Color? bubbleIconColor,
    Map<DebugLogLevel, Color>? levelColors,
  }) {
    return DebugBubbleTheme(
      mode: mode ?? this.mode,
      bubbleColor: bubbleColor ?? this.bubbleColor,
      bubbleIconColor: bubbleIconColor ?? this.bubbleIconColor,
      levelColors: levelColors ?? this.levelColors,
    );
  }
}
