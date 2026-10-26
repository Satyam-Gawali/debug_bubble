import 'package:debug_bubble/debug_bubble.dart';
import 'package:debug_bubble/src/collectors/console_sink.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() {
    ConsoleSink.testListener = null;
  });

  group('ConsoleSink Formatting & ANSI Colors', () {
    const sink = ConsoleSink();

    test('Each severity maps to the expected ANSI color code', () {
      final expectedColors = <DebugLogLevel, String>{
        DebugLogLevel.debug: '\x1B[90m',
        DebugLogLevel.info: '\x1B[36m',
        DebugLogLevel.success: '\x1B[32m',
        DebugLogLevel.warning: '\x1B[33m',
        DebugLogLevel.error: '\x1B[31m',
        DebugLogLevel.critical: '\x1B[35m',
      };

      for (final entry in expectedColors.entries) {
        final level = entry.key;
        final expectedAnsi = entry.value;

        expect(
          ConsoleSink.ansiColorForLevel(level),
          equals(expectedAnsi),
          reason: 'Expected $level to map to $expectedAnsi',
        );

        final logEntry = DebugLogEntry(
          id: 1,
          timestamp: DateTime.utc(2026, 10, 26, 10, 0, 0),
          level: level,
          message: 'Test message for $level',
        );

        final formatted = sink.format(logEntry);
        expect(
          formatted.startsWith(expectedAnsi),
          isTrue,
          reason: 'Formatted output for $level should start with $expectedAnsi',
        );
      }
    });

    test('ANSI reset is applied at the end so color does not leak', () {
      for (final level in DebugLogLevel.values) {
        final entry = DebugLogEntry(
          id: 10,
          timestamp: DateTime.utc(2026, 10, 26, 10, 0, 0),
          level: level,
          message: 'Reset test for $level',
        );

        final formatted = sink.format(entry);
        expect(
          formatted.endsWith(ConsoleSink.resetAnsi),
          isTrue,
          reason: 'Formatted output for $level must end with reset sequence',
        );
      }
    });

    test('Plain text remains meaningful when ANSI colors are disabled', () {
      const plainSink = ConsoleSink(useColor: false);
      final entry = DebugLogEntry(
        id: 3,
        timestamp: DateTime.utc(2026, 10, 26, 10, 0, 0),
        level: DebugLogLevel.info,
        message: 'Minimal message',
        tag: 'App',
      );

      final uncolored = plainSink.format(entry);
      expect(
        uncolored,
        equals('[2026-10-26T10:00:00.000Z] INFO App (#3)\nMinimal message'),
      );
      expect(uncolored.contains('\x1B'), isFalse);

      // format with explicit color: false
      final explicitUncolored = sink.format(entry, color: false);
      expect(explicitUncolored, equals(uncolored));
      expect(explicitUncolored.contains('\x1B'), isFalse);
    });

    test('Formats full entry matching schema header and body with color', () {
      final entry = DebugLogEntry(
        id: 1,
        timestamp: DateTime.utc(2026, 10, 26, 10, 0, 0),
        level: DebugLogLevel.error,
        message: 'Login failed',
        tag: 'Auth',
        subTag: 'Login',
        error: const DebugErrorInfo(
          type: 'FormatException',
          message: 'Bad token',
        ),
        stackTrace: '#0 main()',
        metadata: {'userId': 42},
        json: {'attempt': 1},
        truncated: false,
      );

      final text = sink.format(entry);

      expect(text.startsWith('\x1B[31m'), isTrue);
      expect(text.endsWith('\x1B[0m'), isTrue);
      expect(
        text,
        contains('[2026-10-26T10:00:00.000Z] ERROR Auth/Login (#1)'),
      );
      expect(text, contains('Login failed'));
      expect(text, contains('Error: FormatException: Bad token'));
      expect(text, contains('Metadata:'));
      expect(text, contains('"userId": 42'));
      expect(text, contains('JSON:'));
      expect(text, contains('"attempt": 1'));
      expect(text, contains('Stack trace:'));
      expect(text, contains('#0 main()'));
      expect(text, isNot(contains('(truncated)')));
    });

    test('Appends (truncated) to header line when truncated is true', () {
      final entry = DebugLogEntry(
        id: 2,
        timestamp: DateTime.utc(2026, 10, 26, 10, 0, 0),
        level: DebugLogLevel.warning,
        message: 'Partial payload…[truncated]',
        tag: 'Network',
        truncated: true,
      );

      final text = sink.format(entry);
      expect(text.startsWith('\x1B[33m'), isTrue);
      expect(
        text,
        contains(
          '[2026-10-26T10:00:00.000Z] WARNING Network (#2) (truncated)',
        ),
      );
      expect(text.endsWith('\x1B[0m'), isTrue);
    });

    test('Omits absent fields cleanly in uncolored and colored format', () {
      final entry = DebugLogEntry(
        id: 3,
        timestamp: DateTime.utc(2026, 10, 26, 10, 0, 0),
        level: DebugLogLevel.info,
        message: 'Minimal message',
      );

      final plainText = sink.format(entry, color: false);
      expect(
        plainText,
        equals('[2026-10-26T10:00:00.000Z] INFO (#3)\nMinimal message'),
      );
      expect(plainText, isNot(contains('Error:')));
      expect(plainText, isNot(contains('Metadata:')));
      expect(plainText, isNot(contains('JSON:')));
      expect(plainText, isNot(contains('Stack trace:')));

      final coloredText = sink.format(entry, color: true);
      expect(
        coloredText,
        equals(
          '\x1B[36m[2026-10-26T10:00:00.000Z] INFO (#3)\nMinimal message\x1B[0m',
        ),
      );
    });
  });

  group('ConsoleSink Output & Emission Control', () {
    test('Console callback receives formatted output and entry', () {
      String? recordedText;
      DebugLogEntry? recordedEntry;
      ConsoleSink.testListener = (text, entry) {
        recordedText = text;
        recordedEntry = entry;
      };

      const sink = ConsoleSink();
      final entry = DebugLogEntry(
        id: 4,
        timestamp: DateTime.utc(2026, 10, 26, 10, 0, 0),
        level: DebugLogLevel.debug,
        message: 'Testing output callback',
      );

      sink.output(entry);

      expect(recordedText, isNotNull);
      expect(recordedText!.startsWith('\x1B[90m'), isTrue);
      expect(recordedText!.endsWith('\x1B[0m'), isTrue);
      expect(recordedText, contains('Testing output callback'));
      expect(recordedEntry?.id, 4);
    });

    test('Custom outputCallback is invoked with formatted output', () {
      final outputs = <String>[];
      final sink = ConsoleSink(
        outputCallback: (formatted) => outputs.add(formatted),
      );

      final entry = DebugLogEntry(
        id: 5,
        timestamp: DateTime.utc(2026, 10, 26, 10, 0, 0),
        level: DebugLogLevel.success,
        message: 'Custom callback test',
      );

      sink.output(entry);

      expect(outputs.length, equals(1));
      expect(outputs.first.startsWith('\x1B[32m'), isTrue);
      expect(outputs.first.endsWith('\x1B[0m'), isTrue);
      expect(outputs.first, contains('Custom callback test'));
    });

    test('Each log is emitted only once per output invocation', () {
      var emissionCount = 0;
      final sink = ConsoleSink(
        outputCallback: (_) {
          emissionCount++;
        },
      );

      final entry = DebugLogEntry(
        id: 6,
        timestamp: DateTime.utc(2026, 10, 26, 10, 0, 0),
        level: DebugLogLevel.info,
        message: 'Single emission test',
      );

      sink.output(entry);
      expect(emissionCount, equals(1));

      sink.output(entry);
      expect(emissionCount, equals(2));
    });

    test('Redaction remains effective in console output', () {
      String? outputReceived;
      final sink = ConsoleSink(
        outputCallback: (formatted) {
          outputReceived = formatted;
        },
      );

      // Entry created with redacted fields (as produced by pipeline sanitizer)
      final entry = DebugLogEntry(
        id: 7,
        timestamp: DateTime.utc(2026, 10, 26, 10, 0, 0),
        level: DebugLogLevel.error,
        message: 'User authentication with token: [REDACTED]',
        metadata: {'password': '[REDACTED]', 'safe_key': 'safe_value'},
      );

      sink.output(entry);

      expect(outputReceived, isNotNull);
      expect(outputReceived, contains('[REDACTED]'));
      expect(outputReceived, contains('"safe_key": "safe_value"'));
      expect(outputReceived, isNot(contains('secret_12345')));
    });

    test('Output gracefully swallows any listener or internal failure', () {
      ConsoleSink.testListener = (text, entry) {
        throw StateError('Simulated test listener failure');
      };

      final throwingSink = ConsoleSink(
        outputCallback: (_) {
          throw Exception('Simulated output callback failure');
        },
      );

      final entry = DebugLogEntry(
        id: 8,
        timestamp: DateTime.utc(2026, 10, 26, 10, 0, 0),
        level: DebugLogLevel.critical,
        message: 'Failure isolation test',
      );

      expect(() => throwingSink.output(entry), returnsNormally);
    });
  });
}
