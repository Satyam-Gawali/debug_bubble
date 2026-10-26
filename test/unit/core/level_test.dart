import 'package:debug_bubble/debug_bubble.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DebugLogLevel (DATA_MODELS §1, D-11)', () {
    test('Enum values and ordering match specification exactly', () {
      expect(DebugLogLevel.values, const [
        DebugLogLevel.debug,
        DebugLogLevel.info,
        DebugLogLevel.success,
        DebugLogLevel.warning,
        DebugLogLevel.error,
        DebugLogLevel.critical,
      ]);

      expect(DebugLogLevel.debug.index, 0);
      expect(DebugLogLevel.info.index, 1);
      expect(DebugLogLevel.success.index, 2);
      expect(DebugLogLevel.warning.index, 3);
      expect(DebugLogLevel.error.index, 4);
      expect(DebugLogLevel.critical.index, 5);
    });

    test('Names are stable lowercase strings used for export', () {
      expect(DebugLogLevel.debug.name, 'debug');
      expect(DebugLogLevel.info.name, 'info');
      expect(DebugLogLevel.success.name, 'success');
      expect(DebugLogLevel.warning.name, 'warning');
      expect(DebugLogLevel.error.name, 'error');
      expect(DebugLogLevel.critical.name, 'critical');
    });

    test('isError is true only for error and critical', () {
      expect(DebugLogLevel.debug.isError, isFalse);
      expect(DebugLogLevel.info.isError, isFalse);
      expect(DebugLogLevel.success.isError, isFalse);
      expect(DebugLogLevel.warning.isError, isFalse);
      expect(DebugLogLevel.error.isError, isTrue);
      expect(DebugLogLevel.critical.isError, isTrue);
    });

    test('Comparison operators order severity monotonically', () {
      expect(DebugLogLevel.info >= DebugLogLevel.debug, isTrue);
      expect(DebugLogLevel.success >= DebugLogLevel.info, isTrue);
      expect(DebugLogLevel.warning >= DebugLogLevel.success, isTrue);
      expect(DebugLogLevel.error >= DebugLogLevel.warning, isTrue);
      expect(DebugLogLevel.critical >= DebugLogLevel.error, isTrue);

      expect(DebugLogLevel.debug < DebugLogLevel.info, isTrue);
      expect(DebugLogLevel.debug <= DebugLogLevel.debug, isTrue);
      expect(DebugLogLevel.critical > DebugLogLevel.error, isTrue);
    });

    test('minLevel threshold gate: warning drops success (D-11)', () {
      const minLevel = DebugLogLevel.warning;

      expect(DebugLogLevel.debug >= minLevel, isFalse);
      expect(DebugLogLevel.info >= minLevel, isFalse);
      expect(DebugLogLevel.success >= minLevel, isFalse); // D-11: drops success
      expect(DebugLogLevel.warning >= minLevel, isTrue);
      expect(DebugLogLevel.error >= minLevel, isTrue);
      expect(DebugLogLevel.critical >= minLevel, isTrue);
    });
  });
}
