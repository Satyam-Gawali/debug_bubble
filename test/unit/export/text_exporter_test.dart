import 'package:debug_bubble/debug_bubble.dart';
import 'package:debug_bubble/src/export/text_exporter.dart';
import 'package:debug_bubble/src/utils/build_mode.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() {
    BuildMode.reset();
  });

  group('Plain-Text Formatting & Export (DATA_MODELS §9, D-26)', () {
    final utcTime = DateTime.utc(2026, 10, 26, 14, 0, 0);

    test(
      'Single entry block formatting with all fields and truncated marker',
      () {
        final entry = DebugLogEntry(
          id: 42,
          timestamp: utcTime,
          level: DebugLogLevel.error,
          message: 'Something went wrong',
          tag: 'Auth',
          subTag: 'OAuth2',
          error: const DebugErrorInfo(
            type: 'FormatException',
            message: 'Invalid token',
          ),
          metadata: {'attempt': 3},
          json: {'code': 400},
          stackTrace: '#0 main.dart:10\n#1 test.dart:20',
          truncated: true,
        );

        final formatted = TextExporter.formatEntry(entry);
        final lines = formatted.split('\n');

        expect(
          lines[0],
          '[2026-10-26T14:00:00.000Z] ERROR Auth/OAuth2 (#42) (truncated)',
        );
        expect(lines[1], 'Something went wrong');
        expect(lines[2], 'Error: FormatException: Invalid token');
        expect(formatted.contains('Metadata: {\n  "attempt": 3\n}'), isTrue);
        expect(formatted.contains('JSON: {\n  "code": 400\n}'), isTrue);
        expect(
          formatted.contains('Stack trace:\n#0 main.dart:10\n#1 test.dart:20'),
          isTrue,
        );
      },
    );

    test('Single entry block omits lines for absent fields', () {
      final minimal = DebugLogEntry(
        id: 1,
        timestamp: utcTime,
        level: DebugLogLevel.info,
        message: 'Just a simple log',
      );

      final formatted = TextExporter.formatEntry(minimal);
      expect(
        formatted,
        '[2026-10-26T14:00:00.000Z] INFO (#1)\nJust a simple log',
      );
      expect(formatted.contains('Error:'), isFalse);
      expect(formatted.contains('Metadata:'), isFalse);
      expect(formatted.contains('JSON:'), isFalse);
      expect(formatted.contains('Stack trace:'), isFalse);
      expect(formatted.contains('(truncated)'), isFalse);
    });

    test(
      'Multi-entry export formats header and entries in oldest to newest order',
      () {
        final controller = DebugBubbleController();
        controller.log(DebugLogLevel.info, 'First event', tag: 'System');
        controller.log(DebugLogLevel.warning, 'Second event', tag: 'System');

        final text = controller.exportText();
        final blocks = text.split('\n\n');

        expect(
          blocks[0],
          'debug_bubble log export — 2 entries (0 older entries dropped)',
        );
        expect(blocks[1].contains('INFO System (#1)'), isTrue);
        expect(blocks[1].contains('First event'), isTrue);
        expect(blocks[2].contains('WARNING System (#2)'), isTrue);
        expect(blocks[2].contains('Second event'), isTrue);
      },
    );

    test('Header accurately reflects store capacity droppedCount', () {
      final controller = DebugBubbleController(
        config: const DebugBubbleConfig(maxEntries: 2),
      );

      controller.log(DebugLogLevel.info, 'One');
      controller.log(DebugLogLevel.info, 'Two');
      controller.log(DebugLogLevel.info, 'Three'); // Evicts 'One'

      expect(controller.droppedCount, 1);
      final text = controller.exportText();

      expect(
        text.startsWith(
          'debug_bubble log export — 2 entries (1 older entries dropped)',
        ),
        isTrue,
      );
      expect(text.contains('One'), isFalse);
      expect(text.contains('Two'), isTrue);
      expect(text.contains('Three'), isTrue);
    });

    test(
      'Zero entries export produces valid zero-entry plain text document',
      () {
        final controller = DebugBubbleController();
        expect(
          controller.exportText(),
          'debug_bubble log export — 0 entries (0 older entries dropped)',
        );
      },
    );

    test('Clipboard character budget cap omits oldest entries when exceeded (D-26)', () {
      const exporter = TextExporter();
      final e1 = DebugLogEntry(
        id: 1,
        timestamp: utcTime,
        level: DebugLogLevel.info,
        message: 'Message number 1 with some details',
      );
      final e2 = DebugLogEntry(
        id: 2,
        timestamp: utcTime.add(const Duration(seconds: 1)),
        level: DebugLogLevel.info,
        message: 'Message number 2 with some details',
      );
      final e3 = DebugLogEntry(
        id: 3,
        timestamp: utcTime.add(const Duration(seconds: 2)),
        level: DebugLogLevel.info,
        message: 'Message number 3 with some details',
      );

      final fullExport = exporter.export(
        entries: [e1, e2, e3],
        droppedCount: 0,
      );
      expect(
        fullExport.startsWith(
          'debug_bubble log export — 3 entries (0 older entries dropped)',
        ),
        isTrue,
      );

      // Constrain budget so only the newest 2 entries fit
      final tightBudget = fullExport.length - 20;
      final cappedExport = exporter.export(
        entries: [e1, e2, e3],
        droppedCount: 0,
        maxChars: tightBudget,
      );

      expect(cappedExport.length <= tightBudget, isTrue);
      expect(
        cappedExport.startsWith(
          'debug_bubble log export — 2 entries (1 older entries dropped)',
        ),
        isTrue,
      );
      expect(cappedExport.contains('Message number 1'), isFalse);
      expect(cappedExport.contains('Message number 2'), isTrue);
      expect(cappedExport.contains('Message number 3'), isTrue);

      // Constrain budget so only the newest 1 entry fits
      final oneEntryBudget = cappedExport.length - 20;
      final singleExport = exporter.export(
        entries: [e1, e2, e3],
        droppedCount: 0,
        maxChars: oneEntryBudget,
      );

      expect(singleExport.length <= oneEntryBudget, isTrue);
      expect(
        singleExport.startsWith(
          'debug_bubble log export — 1 entries (2 older entries dropped)',
        ),
        isTrue,
      );
      expect(singleExport.contains('Message number 1'), isFalse);
      expect(singleExport.contains('Message number 2'), isFalse);
      expect(singleExport.contains('Message number 3'), isTrue);
    });

    test('Disposed controller returns valid zero-entry document (L-8)', () {
      final controller = DebugBubbleController();
      controller.log(DebugLogLevel.info, 'test');
      controller.dispose();

      expect(
        controller.exportText(),
        'debug_bubble log export — 0 entries (0 older entries dropped)',
      );
    });

    test('Inert release controller returns empty string (DATA_MODELS §8)', () {
      BuildMode.releaseOverride = true;
      final controller = DebugBubbleController();
      controller.log(DebugLogLevel.info, 'test');

      expect(controller.exportText(), isEmpty);
    });

    test('Sentinel secret is redacted across exportText output (SECURITY_PERFORMANCE §3)', () {
      const sentinel = 'super_secret_token_12345';
      final controller = DebugBubbleController(
        config: DebugBubbleConfig(
          redaction: DebugRedactionConfig(
            valuePatterns: [RegExp(r'super_secret_token_\w+')],
          ),
        ),
      );

      controller.log(
        DebugLogLevel.error,
        'Failure with $sentinel',
        tag: 'Auth_$sentinel',
        metadata: {'token': sentinel},
        json: {'auth': sentinel},
      );

      final text = controller.exportText();
      expect(text.contains(sentinel), isFalse);
      expect(text.contains('[REDACTED]'), isTrue);
    });

    test('Sensitive keys in metadata and json are redacted in exportText even without valuePatterns', () {
      const sensitiveVal = 'secret_val_12345';
      final controller = DebugBubbleController();

      controller.log(
        DebugLogLevel.error,
        'Regular error occurred',
        tag: 'Auth',
        metadata: {'token': sensitiveVal},
        json: {'auth': sensitiveVal},
      );

      final text = controller.exportText();
      expect(text.contains(sensitiveVal), isFalse);
      expect(text.contains('[REDACTED]'), isTrue);
    });
  });
}
