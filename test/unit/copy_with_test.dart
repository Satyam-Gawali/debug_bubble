import 'package:debug_bubble/debug_bubble.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Nullable copyWith Clearing Behavior', () {
    test('DebugLogFilter copyWith can preserve and clear tag', () {
      const filter = DebugLogFilter(tag: 'auth');
      expect(filter.tag, 'auth');

      // Regular copyWith keeps tag
      final updatedQuery = filter.copyWith(query: 'login');
      expect(updatedQuery.tag, 'auth');
      expect(updatedQuery.query, 'login');

      // Explicit clearTag resets tag to null
      final cleared = filter.copyWith(clearTag: true);
      expect(cleared.tag, isNull);
    });

    test('DebugBubbleConfig copyWith can preserve and clear onExport', () {
      void dummyExport(String json) {}
      final config = DebugBubbleConfig(onExport: dummyExport);
      expect(config.onExport, isNotNull);

      // Regular copyWith keeps onExport
      final updatedEnabled = config.copyWith(enabled: false);
      expect(updatedEnabled.onExport, isNotNull);
      expect(updatedEnabled.enabled, isFalse);

      // Explicit clearOnExport resets onExport to null
      final cleared = config.copyWith(clearOnExport: true);
      expect(cleared.onExport, isNull);
    });

    test(
      'DebugBubbleTheme copyWith can preserve and clear nullable colors',
      () {
        const theme = DebugBubbleTheme(
          bubbleColor: Colors.blue,
          bubbleIconColor: Colors.white,
          levelColors: {DebugLogLevel.error: Colors.red},
        );
        expect(theme.bubbleColor, Colors.blue);
        expect(theme.bubbleIconColor, Colors.white);
        expect(theme.levelColors?[DebugLogLevel.error], Colors.red);

        // Regular copyWith preserves values
        final updatedMode = theme.copyWith(mode: ThemeMode.dark);
        expect(updatedMode.bubbleColor, Colors.blue);
        expect(updatedMode.bubbleIconColor, Colors.white);
        expect(updatedMode.levelColors?[DebugLogLevel.error], Colors.red);
        expect(updatedMode.mode, ThemeMode.dark);

        // Explicit clear flags reset respective properties
        final cleared = theme.copyWith(
          clearBubbleColor: true,
          clearBubbleIconColor: true,
          clearLevelColors: true,
        );
        expect(cleared.bubbleColor, isNull);
        expect(cleared.bubbleIconColor, isNull);
        expect(cleared.levelColors, isNull);
      },
    );
  });
}
