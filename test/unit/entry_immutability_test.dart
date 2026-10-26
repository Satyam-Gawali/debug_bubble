import 'package:debug_bubble/debug_bubble.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DebugLogEntry Immutability (DATA_MODELS §2)', () {
    test('Mutating original metadata map does not alter created log entry', () {
      final map = <String, Object?>{'key': 'initial_value'};
      final entry = DebugLogEntry(
        id: 1,
        timestamp: DateTime.now().toUtc(),
        level: DebugLogLevel.info,
        message: 'immutability test',
        metadata: map,
      );

      // Mutate the original map
      map['key'] = 'modified_value';
      map['new_key'] = 'added';

      expect(entry.metadata?['key'], 'initial_value');
      expect(entry.metadata?.containsKey('new_key'), isFalse);

      // Attempting to mutate entry.metadata directly should throw
      expect(() => entry.metadata?['key'] = 'hack', throwsUnsupportedError);
    });

    test('Mutating original nested json map/list does not alter entry', () {
      final jsonPayload = <String, Object?>{
        'list': <int>[1, 2, 3],
      };
      final entry = DebugLogEntry(
        id: 2,
        timestamp: DateTime.now().toUtc(),
        level: DebugLogLevel.debug,
        message: 'json immutability test',
        json: jsonPayload,
      );

      jsonPayload['list'] = <int>[999];
      expect(
        (entry.json as Map<String, Object?>)['list'],
        equals(<int>[1, 2, 3]),
      );

      final entryList = (entry.json as Map<String, Object?>)['list'] as List;
      expect(() => entryList.add(4), throwsUnsupportedError);
    });
  });
}
