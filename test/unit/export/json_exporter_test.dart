import 'dart:convert';

import 'package:debug_bubble/debug_bubble.dart';
import 'package:debug_bubble/src/utils/build_mode.dart';
import 'package:debug_bubble/src/version.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() {
    BuildMode.reset();
  });

  group('JSON Export Schema v1 (DATA_MODELS §8, D-26)', () {
    test('Exports full schema v1 with all documented fields', () {
      final controller = DebugBubbleController(
        config: const DebugBubbleConfig(
          maxEntries: 50,
          maxEntryChars: 10000,
          maxMessageLength: 2000,
          maxStackTraceLength: 4000,
          maxPayloadLength: 8000,
        ),
      );

      controller.log(
        DebugLogLevel.info,
        'Entry 1',
        tag: 'Auth',
        subTag: 'Login',
        metadata: {'userId': 42},
      );
      controller.log(
        DebugLogLevel.error,
        'Entry 2',
        tag: 'Network',
        error: const DebugErrorInfo(
          type: 'HttpException',
          message: 'Not found',
        ),
        json: {'code': 404},
      );

      final jsonStr = controller.exportJson();
      final doc = jsonDecode(jsonStr) as Map<String, Object?>;

      expect(doc['schemaVersion'], 1);
      expect(DateTime.parse(doc['exportedAt'] as String).isUtc, isTrue);
      expect(doc['packageVersion'], debugBubbleVersion);
      expect(doc['buildMode'], 'debug');

      final redaction = doc['redaction'] as Map<String, Object?>;
      expect(redaction['enabled'], isTrue);
      expect(redaction['valuePatternCount'], 0);

      final limits = doc['limits'] as Map<String, Object?>;
      expect(limits['maxEntries'], 50);
      expect(limits['maxEntryChars'], 10000);
      expect(limits['maxMessageLength'], 2000);
      expect(limits['maxStackTraceLength'], 4000);
      expect(limits['maxPayloadLength'], 8000);

      expect(doc['totalEntries'], 2);
      expect(doc['exportedEntries'], 2);
      expect(doc['droppedCount'], 0);

      final filter = doc['filter'] as Map<String, Object?>;
      expect(filter['levels'], isEmpty);
      expect(filter['query'], '');
      expect(filter['tag'], isNull);

      final entries = doc['entries'] as List<Object?>;
      expect(entries.length, 2);

      final e1 = entries[0] as Map<String, Object?>;
      expect(e1['id'], 1);
      expect(e1['level'], 'info');
      expect(e1['message'], 'Entry 1');
      expect(e1['tag'], 'Auth');
      expect(e1['subTag'], 'Login');
      expect((e1['metadata'] as Map)['userId'], 42);

      final e2 = entries[1] as Map<String, Object?>;
      expect(e2['id'], 2);
      expect(e2['level'], 'error');
      expect(e2['message'], 'Entry 2');
      expect((e2['error'] as Map)['type'], 'HttpException');
      expect((e2['json'] as Map)['code'], 404);
    });

    test('Filtered export reflects matching subset while preserving totalEntries and droppedCount', () {
      final controller = DebugBubbleController(
        config: const DebugBubbleConfig(maxEntries: 2),
      );

      controller.log(DebugLogLevel.info, 'E1', tag: 'A');
      controller.log(DebugLogLevel.warning, 'E2', tag: 'B');
      // Adding E3 evicts E1 from capacity
      controller.log(DebugLogLevel.error, 'E3', tag: 'A');

      expect(controller.droppedCount, 1);
      expect(controller.entryCount, 2);

      const filter = DebugLogFilter(levels: {DebugLogLevel.error}, tag: 'A');
      final jsonStr = controller.exportJson(filter: filter);
      final doc = jsonDecode(jsonStr) as Map<String, Object?>;

      expect(doc['totalEntries'], 2);
      expect(doc['exportedEntries'], 1);
      expect(doc['droppedCount'], 1);

      final filterDoc = doc['filter'] as Map<String, Object?>;
      expect(filterDoc['levels'], ['error']);
      expect(filterDoc['tag'], 'A');

      final entries = doc['entries'] as List<Object?>;
      expect(entries.length, 1);
      expect((entries[0] as Map)['message'], 'E3');
    });

    test('Simulated profile build mode produces buildMode: "profile"', () {
      BuildMode.profileOverride = true;
      final controller = DebugBubbleController();
      controller.log(DebugLogLevel.info, 'msg');

      final doc = jsonDecode(controller.exportJson()) as Map<String, Object?>;
      expect(doc['buildMode'], 'profile');
    });

    test('Disposed controller returns valid zero-entry document (L-8, DATA_MODELS §8)', () {
      final controller = DebugBubbleController();
      controller.log(DebugLogLevel.info, 'msg');
      controller.dispose();

      final doc = jsonDecode(controller.exportJson()) as Map<String, Object?>;
      expect(doc['schemaVersion'], 1);
      expect(doc['totalEntries'], 0);
      expect(doc['exportedEntries'], 0);
      expect(doc['droppedCount'], 0);
      expect(doc['entries'], isEmpty);
    });

    test('Inert release controller cannot export and returns empty string (DATA_MODELS §8)', () {
      BuildMode.releaseOverride = true;
      final controller = DebugBubbleController();
      controller.log(DebugLogLevel.info, 'msg');

      expect(controller.exportJson(), isEmpty);
    });

    test('Sentinel secret is redacted across exportJson output (SECURITY_PERFORMANCE §3)', () {
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
        metadata: {'token': sentinel, 'password': 'abc'},
        json: {'auth': sentinel},
      );

      final jsonStr = controller.exportJson();
      expect(jsonStr.contains(sentinel), isFalse);
      expect(jsonStr.contains('[REDACTED]'), isTrue);
    });

    test('Sensitive keys in metadata and json are redacted in exportJson even without valuePatterns', () {
      const sensitiveVal = 'secret_val_12345';
      final controller = DebugBubbleController();

      controller.log(
        DebugLogLevel.error,
        'Regular error occurred',
        tag: 'Auth',
        metadata: {'token': sensitiveVal, 'password': 'abc'},
        json: {'auth': sensitiveVal},
      );

      final jsonStr = controller.exportJson();
      expect(jsonStr.contains(sensitiveVal), isFalse);
      expect(jsonStr.contains('[REDACTED]'), isTrue);
    });
  });
}
