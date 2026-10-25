import 'dart:io';

import 'package:debug_bubble/debug_bubble.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('public API surface exports exactly the ten documented symbols', () {
    // 1. DebugLogLevel
    expect(DebugLogLevel.values.length, 6);
    expect(DebugLogLevel.error.isError, isTrue);

    // 2. DebugErrorInfo
    const errorInfo = DebugErrorInfo(
      type: 'FormatException',
      message: 'invalid',
    );
    expect(errorInfo.type, 'FormatException');
    expect(errorInfo.message, 'invalid');

    // 3. DebugLogEntry
    final entry = DebugLogEntry(
      id: 1,
      timestamp: DateTime.now().toUtc(),
      level: DebugLogLevel.info,
      message: 'test message',
    );
    expect(entry.id, 1);
    expect(entry.message, 'test message');

    // 4. DebugLogFilter
    const filter = DebugLogFilter();
    expect(filter.isEmpty, isTrue);

    // 5. DebugRedactionConfig
    const redactionConfig = DebugRedactionConfig();
    expect(redactionConfig.enabled, isTrue);

    // 6. DebugBubbleTheme
    const theme = DebugBubbleTheme();
    expect(theme.bubbleColor, isNull);

    // 7. DebugBubbleConfig
    const config = DebugBubbleConfig();
    expect(config.enabled, isTrue);
    expect(config.minLevel, DebugLogLevel.debug);

    // 8. DebugBubbleController
    final controller = DebugBubbleController();
    expect(controller.entryCount, 0);
    expect(controller.isActive, isTrue);

    // 9. DebugLog
    expect(DebugLog.controller, isNull);
    final defaultController = DebugLog.init();
    expect(DebugLog.controller, equals(defaultController));
    DebugLog.dispose();
    expect(DebugLog.controller, isNull);

    // 10. DebugBubble
    const bubble = DebugBubble(child: SizedBox());
    expect(bubble.child, isA<SizedBox>());

    // Verify lib/debug_bubble.dart exports ONLY the 10 documented symbols
    var file = File('lib/debug_bubble.dart');
    if (!file.existsSync()) {
      file = File('../../lib/debug_bubble.dart');
    }
    expect(file.existsSync(), isTrue);

    const expectedSymbols = {
      'DebugBubble',
      'DebugBubbleConfig',
      'DebugBubbleController',
      'DebugBubbleTheme',
      'DebugLog',
      'DebugLogLevel',
      'DebugLogEntry',
      'DebugErrorInfo',
      'DebugLogFilter',
      'DebugRedactionConfig',
    };

    final exportedSymbols = <String>{};
    final lines = file.readAsLinesSync();
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.startsWith('export ')) {
        final showIndex = trimmed.indexOf('show ');
        expect(
          showIndex != -1,
          isTrue,
          reason: 'Every export directive must use explicit show',
        );
        final symbolPart = trimmed
            .substring(showIndex + 5)
            .replaceAll(';', '')
            .trim();
        for (final sym in symbolPart.split(',')) {
          final s = sym.trim();
          if (s.isNotEmpty) exportedSymbols.add(s);
        }
      }
    }

    expect(exportedSymbols, equals(expectedSymbols));
    expect(exportedSymbols.length, 10);
  });
}
