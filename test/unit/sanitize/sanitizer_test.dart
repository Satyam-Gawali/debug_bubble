import 'package:debug_bubble/debug_bubble.dart';
import 'package:debug_bubble/src/core/sanitize/entry_sanitizer.dart';
import 'package:debug_bubble/src/core/sanitize/payload_sanitizer.dart';
import 'package:debug_bubble/src/core/sanitize/redactor.dart';
import 'package:flutter_test/flutter_test.dart';

class _ThrowingToString {
  @override
  String toString() {
    throw StateError('Hostile toString failure');
  }
}

class _ThrowingIterable extends Iterable<int> {
  @override
  Iterator<int> get iterator => _ThrowingIterator();
}

class _ThrowingIterator implements Iterator<int> {
  int _count = 0;

  @override
  int get current => _count;

  @override
  bool moveNext() {
    _count++;
    if (_count > 3) {
      throw StateError('Mid-iteration failure');
    }
    return true;
  }
}

void main() {
  group(
    'String & Field Cap Boundaries (DATA_MODELS §6, TESTING_STRATEGY §2)',
    () {
      final entrySanitizer = EntrySanitizer();

      test('Tag at boundary: 99, 100, 101 characters', () {
        final tag99 = 'A' * 99;
        final tag100 = 'A' * 100;
        final tag101 = 'A' * 101;

        final res99 = entrySanitizer.sanitize(rawMessage: 'msg', rawTag: tag99);
        expect(res99.tag, equals(tag99));
        expect(res99.truncated, isFalse);

        final res100 = entrySanitizer.sanitize(
          rawMessage: 'msg',
          rawTag: tag100,
        );
        expect(res100.tag, equals(tag100));
        expect(res100.truncated, isFalse);

        final res101 = entrySanitizer.sanitize(
          rawMessage: 'msg',
          rawTag: tag101,
        );
        expect(res101.tag!.length, equals(100));
        expect(res101.tag!.endsWith('…[truncated]'), isTrue);
        expect(res101.truncated, isTrue);
      });

      test('Message at boundary: limit-1, limit, limit+1', () {
        const limit = 100; // customized limit for concise test
        final msg99 = 'M' * 99;
        final msg100 = 'M' * 100;
        final msg101 = 'M' * 101;

        final res99 = entrySanitizer.sanitize(
          rawMessage: msg99,
          maxMessageLength: limit,
        );
        expect(res99.message, equals(msg99));
        expect(res99.truncated, isFalse);

        final res100 = entrySanitizer.sanitize(
          rawMessage: msg100,
          maxMessageLength: limit,
        );
        expect(res100.message, equals(msg100));
        expect(res100.truncated, isFalse);

        final res101 = entrySanitizer.sanitize(
          rawMessage: msg101,
          maxMessageLength: limit,
        );
        expect(res101.message.length, equals(limit));
        expect(res101.message.endsWith('…[truncated]'), isTrue);
        expect(res101.truncated, isTrue);
      });

      test('Error type at boundary: 199, 200, 201 characters', () {
        final type199 = 'E' * 199;
        final type200 = 'E' * 200;
        final type201 = 'E' * 201;

        final res199 = entrySanitizer.sanitize(
          rawMessage: 'm',
          rawError: DebugErrorInfo(type: type199, message: 'err'),
        );
        expect(res199.error!.type, equals(type199));
        expect(res199.truncated, isFalse);

        final res200 = entrySanitizer.sanitize(
          rawMessage: 'm',
          rawError: DebugErrorInfo(type: type200, message: 'err'),
        );
        expect(res200.error!.type, equals(type200));
        expect(res200.truncated, isFalse);

        final res201 = entrySanitizer.sanitize(
          rawMessage: 'm',
          rawError: DebugErrorInfo(type: type201, message: 'err'),
        );
        expect(res201.error!.type.length, equals(200));
        expect(res201.error!.type.endsWith('…[truncated]'), isTrue);
        expect(res201.truncated, isTrue);
      });

      test('Surrogate pair is not split across truncation boundary', () {
        // '😀' is \uD83D\uDE00 (high surrogate 0xD83D, low surrogate 0xDE00)
        // Allowed = 15. Marker is 12 chars. Keep length = 3.
        // String has 20 chars: 'ab' (2) + '😀' (2) + 'cdefghijklmnop' (14).
        // Index 2 is 0xD83D -> surrogate backup to 2!
        final textWithEmoji = 'ab😀cdefghijklmnop';
        var wasTruncated = false;
        final truncated = PayloadSanitizer.truncateString(
          textWithEmoji,
          15, // 15 - 12 = 3. Index 2 is 0xD83D -> surrogate backup to 2!
          onTruncated: () => wasTruncated = true,
        );

        expect(wasTruncated, isTrue);
        expect(truncated, equals('ab…[truncated]'));
        expect(truncated.length, equals(14)); // 2 + 12 = 14 <= 15
      });
    },
  );

  group('Retention Priority & Shared Budgets (DATA_MODELS §6, D-21)', () {
    final entrySanitizer = EntrySanitizer();

    test('Later fields lose first when maxEntryChars is constrained', () {
      // Priority: tag/subTag -> message -> error -> stack trace -> metadata -> json
      // Create an entry where message, error, stack, metadata, and json are present,
      // but total maxEntryChars is severely limited.
      final result = entrySanitizer.sanitize(
        rawTag: 'Tag',
        rawMessage: 'Message that consumes budget',
        rawError: const DebugErrorInfo(type: 'Err', message: 'details'),
        rawStackTrace: StackTrace.fromString('#0 main()'),
        rawMetadata: {'key': 'val'},
        rawJson: {'extra': 123},
        maxEntryChars: 35,
      );

      expect(result.tag, equals('Tag')); // priority 1 preserved
      expect(result.message.isNotEmpty, isTrue); // priority 2 preserved
      // Later fields get omitted when budget runs out
      expect(result.metadata, isNull);
      expect(result.json, isNull);
      expect(result.truncated, isTrue);
    });

    test('Metadata and JSON share maxPayloadLength with metadata first', () {
      final metadata = {'metaKey': 'A' * 200};
      final json = {'jsonKey': 'B' * 200};

      final result = entrySanitizer.sanitize(
        rawMessage: 'test',
        rawMetadata: metadata,
        rawJson: json,
        maxPayloadLength: 150, // not enough for both
      );

      expect(result.metadata, isNotNull);
      // JSON receives remaining budget which is exhausted
      expect(result.json, isNull);
      expect(result.truncated, isTrue);
    });

    test('Output is deterministic for identical input', () {
      final inputMetadata = {'counter': 42, 'user': 'Bob'};
      final inputJson = [1, 2, 3];

      final res1 = entrySanitizer.sanitize(
        rawMessage: 'deterministic',
        rawMetadata: inputMetadata,
        rawJson: inputJson,
      );
      final res2 = entrySanitizer.sanitize(
        rawMessage: 'deterministic',
        rawMetadata: inputMetadata,
        rawJson: inputJson,
      );

      expect(res1.message, equals(res2.message));
      expect(res1.metadata, equals(res2.metadata));
      expect(res1.json, equals(res2.json));
      expect(res1.truncated, equals(res2.truncated));
    });
  });

  group(
    'Payload Sanitizer Traversal Caps & Hostile Inputs (DATA_MODELS §7)',
    () {
      final payloadSanitizer = PayloadSanitizer();

      test('Depth cap: depth > 8 returns [MaxDepth]', () {
        // Build 10-level nested map
        final root = <String, Object?>{};
        var current = root;
        for (var i = 1; i <= 10; i++) {
          final next = <String, Object?>{};
          current['level$i'] = next;
          current = next;
        }

        final result = payloadSanitizer.sanitize(root);
        expect(result.truncated, isTrue);

        // Verify level 9 has [MaxDepth]
        var deep = result.data as Map<String, Object?>;
        for (var i = 1; i <= 8; i++) {
          deep = deep['level$i']! as Map<String, Object?>;
        }
        expect(deep['level9'], equals('[MaxDepth]'));
      });

      test('Cycle detection: self-referencing map returns [Circular]', () {
        final cyclicMap = <String, Object?>{'name': 'cycle'};
        cyclicMap['self'] = cyclicMap;

        final result = payloadSanitizer.sanitize(cyclicMap);
        expect(result.truncated, isTrue);
        final mapData = result.data as Map<String, Object?>;
        expect(mapData['self'], equals('[Circular]'));
      });

      test('Cycle detection: self-referencing list returns [Circular]', () {
        final cyclicList = <Object?>['initial'];
        cyclicList.add(cyclicList);

        final result = payloadSanitizer.sanitize(cyclicList);
        expect(result.truncated, isTrue);
        final listData = result.data as List<Object?>;
        expect(listData[1], equals('[Circular]'));
      });

      test('Collection cap: Map with > 200 entries truncates', () {
        final largeMap = {for (var i = 1; i <= 250; i++) 'key$i': i};
        final result = payloadSanitizer.sanitize(largeMap);

        expect(result.truncated, isTrue);
        final mapData = result.data as Map<String, Object?>;
        expect(mapData.length, equals(201)); // 200 items + [truncated]
        expect(mapData['[truncated]'], equals('50 more entries omitted'));
      });

      test('Collection cap: List with > 200 items truncates', () {
        final largeList = List.generate(250, (i) => i);
        final result = payloadSanitizer.sanitize(largeList);

        expect(result.truncated, isTrue);
        final listData = result.data as List<Object?>;
        expect(listData.length, equals(201)); // 200 items + marker
        expect(listData.last, equals('[50 more items omitted]'));
      });

      test('Collection cap: Infinite generator stops at 200 items', () {
        final infiniteIterable = Iterable<int>.generate(1000000, (i) => i);
        final result = payloadSanitizer.sanitize(infiniteIterable);

        expect(result.truncated, isTrue);
        final listData = result.data as List<Object?>;
        expect(listData.length, equals(201));
      });

      test(
        'Hostile iterable: error mid-iteration yields [IterationError: Type]',
        () {
          final throwingIterable = _ThrowingIterable();
          final result = payloadSanitizer.sanitize(throwingIterable);

          expect(result.truncated, isTrue);
          final listData = result.data as List<Object?>;
          expect(
            listData.length,
            equals(4),
          ); // 3 successful items + error marker
          expect(listData.last, contains('[IterationError:'));
        },
      );

      test(
        'Hostile object: throwing toString() yields [Unprintable: Type]',
        () {
          final hostile = _ThrowingToString();
          final result = payloadSanitizer.sanitize({'hostile': hostile});

          expect(result.truncated, isTrue);
          final mapData = result.data as Map<String, Object?>;
          expect(
            mapData['hostile'],
            equals('[Unprintable: _ThrowingToString]'),
          );
        },
      );

      test('Special numbers and dates are safely converted', () {
        final input = {
          'nan': double.nan,
          'inf': double.infinity,
          'negInf': double.negativeInfinity,
          'date': DateTime.utc(2026, 10, 26, 12, 0, 0),
        };

        final result = payloadSanitizer.sanitize(input);
        final mapData = result.data as Map<String, Object?>;
        expect(mapData['nan'], equals('NaN'));
        expect(mapData['inf'], equals('Infinity'));
        expect(mapData['negInf'], equals('-Infinity'));
        expect(mapData['date'], equals('2026-10-26T12:00:00.000Z'));
      });

      test(
        'Node budget cap (> 2,000 nodes) halts traversal with [Truncated]',
        () {
          // Build a tree with 2500 small nodes
          final tree = {
            for (var i = 0; i < 25; i++)
              'sub$i': {for (var j = 0; j < 100; j++) 'k$j': j},
          };

          final result = payloadSanitizer.sanitize(tree);
          expect(result.truncated, isTrue);
          expect(result.nodesVisited, greaterThanOrEqualTo(2000));
        },
      );
    },
  );

  group('Raw Object Non-Retention (D-22)', () {
    final entrySanitizer = EntrySanitizer();

    test('Mutating raw input map after sanitization does not affect sanitized result', () {
      final originalMetadata = <String, Object?>{
        'user': 'Alice',
        'details': <String, Object?>{'age': 30},
      };

      final result = entrySanitizer.sanitize(
        rawMessage: 'immutability test',
        rawMetadata: originalMetadata,
      );

      // Mutate original source object
      originalMetadata['user'] = 'MUTATED_USER';
      (originalMetadata['details'] as Map<String, Object?>)['age'] = 99;

      // Sanitized entry metadata remains unchanged
      expect(result.metadata!['user'], equals('Alice'));
      expect(
        (result.metadata!['details'] as Map<String, Object?>)['age'],
        equals(30),
      );
    });

    test('Mutating raw input list after sanitization does not affect sanitized result', () {
      final originalList = <Object?>[1, 2, 3];

      final result = entrySanitizer.sanitize(
        rawMessage: 'immutability test',
        rawJson: originalList,
      );

      originalList.add(4);
      originalList[0] = 999;

      expect(result.json, equals([1, 2, 3]));
    });
  });

  group('Redaction Integration (SECURITY_PERFORMANCE §3)', () {
    test(
      'Redacts sensitive keys and value patterns during entry sanitization',
      () {
        final redactor = DebugRedactor(
          config: DebugRedactionConfig(valuePatterns: [RegExp(r'SECRET_\w+')]),
        );
        final sanitizer = EntrySanitizer(redactor: redactor);

        final result = sanitizer.sanitize(
          rawMessage: 'Message with SECRET_TOKEN',
          rawTag: 'Auth/SECRET_TAG',
          rawMetadata: {
            'password': 'superSecretPassword',
            'user_pin': 1234,
            'normalKey': 'value with SECRET_CODE',
          },
        );

        expect(result.message, equals('Message with [REDACTED]'));
        expect(result.tag, equals('Auth/[REDACTED]'));
        expect(result.metadata!['password'], equals('[REDACTED]'));
        expect(result.metadata!['user_pin'], equals('[REDACTED]'));
        expect(result.metadata!['normalKey'], equals('value with [REDACTED]'));
      },
    );
  });
}
