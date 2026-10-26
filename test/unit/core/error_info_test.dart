import 'package:debug_bubble/debug_bubble.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DebugErrorInfo (DATA_MODELS §3)', () {
    test('Constructs and retains type and message', () {
      const error = DebugErrorInfo(
        type: 'FormatException',
        message: 'Invalid character at position 4',
      );
      expect(error.type, 'FormatException');
      expect(error.message, 'Invalid character at position 4');
    });

    test('toJson produces expected structure', () {
      const error = DebugErrorInfo(
        type: 'HttpException',
        message: 'Connection closed',
      );
      expect(error.toJson(), {
        'type': 'HttpException',
        'message': 'Connection closed',
      });
    });

    test('Value equality and hashCode by type and message', () {
      const e1 = DebugErrorInfo(type: 'SocketException', message: 'timeout');
      const e2 = DebugErrorInfo(type: 'SocketException', message: 'timeout');
      const e3 = DebugErrorInfo(type: 'SocketException', message: 'refused');

      expect(e1, equals(e2));
      expect(e1.hashCode, equals(e2.hashCode));
      expect(e1, isNot(equals(e3)));
    });

    test('toString produces readable summary', () {
      const error = DebugErrorInfo(
        type: 'TypeError',
        message: 'null is not int',
      );
      expect(error.toString(), 'TypeError: null is not int');
    });
  });
}
