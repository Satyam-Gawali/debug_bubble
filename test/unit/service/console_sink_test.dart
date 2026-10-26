import 'package:debug_bubble/debug_bubble.dart';
import 'package:debug_bubble/src/collectors/console_sink.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() {
    ConsoleSink.testListener = null;
  });

  group('ConsoleSink Formatting (DATA_MODELS §9)', () {
    const sink = ConsoleSink();

    test('Formats full entry matching schema header and body', () {
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
      expect(
        text,
        contains('[2026-10-26T10:00:00.000Z] WARNING Network (#2) (truncated)'),
      );
    });

    test('Omits absent fields cleanly', () {
      final entry = DebugLogEntry(
        id: 3,
        timestamp: DateTime.utc(2026, 10, 26, 10, 0, 0),
        level: DebugLogLevel.info,
        message: 'Minimal message',
      );

      final text = sink.format(entry);
      expect(
        text,
        equals('[2026-10-26T10:00:00.000Z] INFO (#3)\nMinimal message'),
      );
      expect(text, isNot(contains('Error:')));
      expect(text, isNot(contains('Metadata:')));
      expect(text, isNot(contains('JSON:')));
      expect(text, isNot(contains('Stack trace:')));
    });

    test('Output callback invokes test listener without throwing', () {
      String? recordedText;
      DebugLogEntry? recordedEntry;
      ConsoleSink.testListener = (text, entry) {
        recordedText = text;
        recordedEntry = entry;
      };

      final entry = DebugLogEntry(
        id: 4,
        timestamp: DateTime.utc(2026, 10, 26, 10, 0, 0),
        level: DebugLogLevel.debug,
        message: 'Testing output',
      );

      sink.output(entry);

      expect(recordedText, isNotNull);
      expect(recordedText, contains('Testing output'));
      expect(recordedEntry?.id, 4);
    });

    test('Output gracefully swallows any listener or internal failure', () {
      ConsoleSink.testListener = (text, entry) {
        throw StateError('Simulated console sink failure');
      };

      final entry = DebugLogEntry(
        id: 5,
        timestamp: DateTime.utc(2026, 10, 26, 10, 0, 0),
        level: DebugLogLevel.error,
        message: 'Failure isolation test',
      );

      expect(() => sink.output(entry), returnsNormally);
    });
  });
}
