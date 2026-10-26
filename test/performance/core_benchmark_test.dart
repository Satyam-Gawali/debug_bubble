import 'package:debug_bubble/debug_bubble.dart';
import 'package:flutter_test/flutter_test.dart';

import 'benchmark_runner.dart';

void main() {
  setUpAll(() {
    BenchmarkRunner.printEnvironment();
  });

  group('Core Engine Benchmarks (SECURITY_PERFORMANCE §6, T2.9)', () {
    test('Scenario 1: Small entry ingestion throughput', () {
      final controller = DebugBubbleController(
        config: const DebugBubbleConfig(maxEntries: 2000, consoleOutput: false),
      );

      final result = BenchmarkRunner.measure(
        'Small Entry Ingestion',
        (i) => controller.log(
          DebugLogLevel.info,
          'User action performed',
          tag: 'Auth',
          subTag: 'Session',
        ),
        iterations: 1000,
        warmup: 100,
      );

      // ignore: avoid_print
      print(result);
      expect(result.elapsedMicros, greaterThan(0));
      expect(controller.entryCount, 1100); // 100 warmup + 1000 iterations
      controller.dispose();
    });

    test('Scenario 2: Large message ingestion and budget truncation', () {
      final largeMessage =
          'A' * 10000; // Exceeds default maxMessageLength (8000)
      final controller = DebugBubbleController(
        config: const DebugBubbleConfig(maxEntries: 1000, consoleOutput: false),
      );

      final result = BenchmarkRunner.measure(
        'Large Message Ingestion (10k chars)',
        (i) =>
            controller.log(DebugLogLevel.warning, largeMessage, tag: 'Payload'),
        iterations: 200,
        warmup: 20,
      );

      // ignore: avoid_print
      print(result);
      expect(result.elapsedMicros, greaterThan(0));
      expect(controller.entries.first.truncated, isTrue);
      controller.dispose();
    });

    test(
      'Scenario 3: Complex payload sanitization (nested structures and cycles)',
      () {
        final controller = DebugBubbleController(
          config: const DebugBubbleConfig(
            maxEntries: 1000,
            consoleOutput: false,
          ),
        );

        // Construct a deep structure with a circular reference
        final nested = <String, Object?>{
          'level1': {
            'items': List.generate(50, (index) => 'item_$index'),
            'metadata': {
              'enabled': true,
              'count': 100,
              'tags': ['a', 'b', 'c', 'd'],
            },
          },
        };
        final cyclicMap = <String, Object?>{'data': 'test'};
        cyclicMap['self'] = cyclicMap;

        final result = BenchmarkRunner.measure(
          'Complex & Cyclic Payload Sanitization',
          (i) => controller.log(
            DebugLogLevel.info,
            'Payload event',
            metadata: nested,
            json: cyclicMap,
          ),
          iterations: 300,
          warmup: 30,
        );

        // ignore: avoid_print
        print(result);
        expect(result.elapsedMicros, greaterThan(0));
        controller.dispose();
      },
    );

    test('Scenario 4: Redaction overhead (baseline vs key token vs regex value patterns)', () {
      // 4a. Redaction disabled
      final disabledController = DebugBubbleController(
        config: const DebugBubbleConfig(
          maxEntries: 1000,
          consoleOutput: false,
          redaction: DebugRedactionConfig(enabled: false),
        ),
      );
      final disabledResult = BenchmarkRunner.measure(
        'Redaction Disabled',
        (i) => disabledController.log(
          DebugLogLevel.info,
          'Payment token 1234567890 for user pin 9999',
          metadata: {'password': 'secret', 'token': 'abc', 'pin': '1234'},
        ),
        iterations: 300,
        warmup: 30,
      );
      // ignore: avoid_print
      print(disabledResult);

      // 4b. Standard key redaction enabled
      final keyController = DebugBubbleController(
        config: const DebugBubbleConfig(maxEntries: 1000, consoleOutput: false),
      );
      final keyResult = BenchmarkRunner.measure(
        'Standard Key Redaction',
        (i) => keyController.log(
          DebugLogLevel.info,
          'Payment token 1234567890 for user pin 9999',
          metadata: {'password': 'secret', 'token': 'abc', 'pin': '1234'},
        ),
        iterations: 300,
        warmup: 30,
      );
      // ignore: avoid_print
      print(keyResult);

      // 4c. Key redaction + multiple regex value patterns
      final regexController = DebugBubbleController(
        config: DebugBubbleConfig(
          maxEntries: 1000,
          consoleOutput: false,
          redaction: DebugRedactionConfig(
            valuePatterns: [
              RegExp(r'\b\d{4}[ -]?\d{4}[ -]?\d{4}[ -]?\d{4}\b'),
              RegExp(r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b'),
              RegExp(r'Bearer\s+[A-Za-z0-9\-._~+/]+=*'),
            ],
          ),
        ),
      );
      final regexResult = BenchmarkRunner.measure(
        'Redaction with 3 Value Regex Patterns',
        (i) => regexController.log(
          DebugLogLevel.info,
          'User email test@example.com with Bearer token_xyz and card 4111-2222-3333-4444',
          metadata: {'password': 'secret', 'token': 'abc'},
        ),
        iterations: 300,
        warmup: 30,
      );
      // ignore: avoid_print
      print(regexResult);

      expect(disabledResult.elapsedMicros, greaterThan(0));
      expect(keyResult.elapsedMicros, greaterThan(0));
      expect(regexResult.elapsedMicros, greaterThan(0));

      disabledController.dispose();
      keyController.dispose();
      regexController.dispose();
    });

    test('Scenario 5: High-volume burst and ring-buffer eviction overhead', () {
      final controller = DebugBubbleController(
        config: const DebugBubbleConfig(
          maxEntries: 500, // Small capacity to force continuous evictions
          consoleOutput: false,
        ),
      );

      final result = BenchmarkRunner.measure(
        'High-Volume Burst with Evictions (2000 into capacity 500)',
        (i) =>
            controller.log(DebugLogLevel.info, 'Burst event #$i', tag: 'Burst'),
        iterations: 2000,
        warmup: 200,
      );

      // ignore: avoid_print
      print(result);
      expect(result.elapsedMicros, greaterThan(0));
      expect(controller.entryCount, 500); // Capped at maxEntries
      expect(controller.droppedCount, 1700); // 2200 total - 500 kept
      controller.dispose();
    });

    test('Scenario 6: Full store export serialization overhead (exportJson and exportText)', () {
      final controller = DebugBubbleController(
        config: const DebugBubbleConfig(maxEntries: 1000, consoleOutput: false),
      );

      // Populate full store
      for (var i = 0; i < 1000; i++) {
        controller.log(
          i.isEven ? DebugLogLevel.info : DebugLogLevel.error,
          'Event #$i with some realistic log content',
          tag: 'Module_${i % 10}',
          metadata: {'index': i, 'active': true},
        );
      }
      expect(controller.entryCount, 1000);

      // Measure exportJson
      final jsonResult = BenchmarkRunner.measure(
        'exportJson across 1000 entries',
        (i) => controller.exportJson(),
        iterations: 10,
        warmup: 2,
      );
      // ignore: avoid_print
      print(jsonResult);

      // Measure exportText
      final textResult = BenchmarkRunner.measure(
        'exportText across 1000 entries',
        (i) => controller.exportText(),
        iterations: 10,
        warmup: 2,
      );
      // ignore: avoid_print
      print(textResult);

      expect(jsonResult.elapsedMicros, greaterThan(0));
      expect(textResult.elapsedMicros, greaterThan(0));
      controller.dispose();
    });
  });
}
