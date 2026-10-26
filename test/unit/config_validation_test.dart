import 'package:debug_bubble/debug_bubble.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DebugBubbleConfig Validation (API_DESIGN §5)', () {
    test('Default configuration satisfies all constraints', () {
      expect(() => const DebugBubbleConfig(), returnsNormally);
      const config = DebugBubbleConfig();
      expect(config.maxEntries, 1000);
      expect(config.maxEntryChars, 40000);
      expect(config.maxMessageLength, 8000);
      expect(config.maxStackTraceLength, 16000);
      expect(config.maxPayloadLength, 32000);
      expect(config.captureUncaughtErrors, isFalse);
    });

    test('Valid boundary values are accepted', () {
      expect(
        () => const DebugBubbleConfig(
          maxEntries: 1,
          maxEntryChars: 1024,
          maxMessageLength: 256,
          maxStackTraceLength: 256,
          maxPayloadLength: 256,
        ),
        returnsNormally,
      );
    });

    test('Out-of-range values trigger assertions in debug mode', () {
      expect(() => DebugBubbleConfig(maxEntries: 0), throwsAssertionError);
      expect(
        () => DebugBubbleConfig(maxEntryChars: 1023),
        throwsAssertionError,
      );
      expect(
        () => DebugBubbleConfig(maxMessageLength: 255),
        throwsAssertionError,
      );
      expect(
        () => DebugBubbleConfig(maxStackTraceLength: 255),
        throwsAssertionError,
      );
      expect(
        () => DebugBubbleConfig(maxPayloadLength: 255),
        throwsAssertionError,
      );
    });
  });
}
