import 'package:debug_bubble/debug_bubble.dart';
import 'package:debug_bubble/src/core/debug_log_store.dart';
import 'package:flutter_test/flutter_test.dart';

DebugLogEntry _entry({
  required int id,
  DebugLogLevel level = DebugLogLevel.info,
  String message = 'msg',
}) {
  return DebugLogEntry(
    id: id,
    timestamp: DateTime.utc(2026, 10, 26, 10, 0, id),
    level: level,
    message: message,
  );
}

void main() {
  group('DebugLogStore Capacity & Eviction (D-06, DATA_MODELS §5)', () {
    test('Throws on invalid capacity (< 1)', () {
      expect(() => DebugLogStore(maxEntries: 0), throwsAssertionError);
      expect(() => DebugLogStore(maxEntries: -5), throwsAssertionError);
    });

    test('Initializes with empty state and correct capacity', () {
      final store = DebugLogStore(maxEntries: 5);
      expect(store.maxEntries, 5);
      expect(store.length, 0);
      expect(store.isEmpty, isTrue);
      expect(store.isNotEmpty, isFalse);
      expect(store.droppedCount, 0);
      expect(store.errorCount, 0);
      expect(store.snapshot(), isEmpty);
    });

    test('Appends entries up to capacity in FIFO order', () {
      final store = DebugLogStore(maxEntries: 3);
      store.add(_entry(id: 1));
      store.add(_entry(id: 2));
      store.add(_entry(id: 3));

      expect(store.length, 3);
      expect(store.isEmpty, isFalse);
      expect(store.isNotEmpty, isTrue);
      expect(store.droppedCount, 0);

      final ids = store.snapshot().map((e) => e.id).toList();
      expect(ids, equals([1, 2, 3]));
    });

    test('Evicts single oldest entry when capacity is exceeded', () {
      final store = DebugLogStore(maxEntries: 3);
      store.add(_entry(id: 1));
      store.add(_entry(id: 2));
      store.add(_entry(id: 3));

      // Adding 4th entry evicts id: 1
      store.add(_entry(id: 4));
      expect(store.length, 3);
      expect(store.droppedCount, 1);
      expect(store.snapshot().map((e) => e.id).toList(), equals([2, 3, 4]));

      // Adding 5th entry evicts id: 2
      store.add(_entry(id: 5));
      expect(store.length, 3);
      expect(store.droppedCount, 2);
      expect(store.snapshot().map((e) => e.id).toList(), equals([3, 4, 5]));
    });

    test('Works correctly with boundary capacity maxEntries = 1', () {
      final store = DebugLogStore(maxEntries: 1);
      expect(store.length, 0);

      store.add(_entry(id: 10));
      expect(store.length, 1);
      expect(store.droppedCount, 0);
      expect(store.snapshot().single.id, 10);

      store.add(_entry(id: 20));
      expect(store.length, 1);
      expect(store.droppedCount, 1);
      expect(store.snapshot().single.id, 20);

      store.add(_entry(id: 30));
      expect(store.length, 1);
      expect(store.droppedCount, 2);
      expect(store.snapshot().single.id, 30);
    });

    test(
      'Burst adding 100 entries into capacity 10 retains last 10 entries',
      () {
        final store = DebugLogStore(maxEntries: 10);
        for (var i = 1; i <= 100; i++) {
          store.add(_entry(id: i));
        }

        expect(store.length, 10);
        expect(store.droppedCount, 90);
        final expectedIds = List.generate(10, (index) => 91 + index);
        expect(store.snapshot().map((e) => e.id).toList(), equals(expectedIds));
      },
    );
  });

  group('DebugLogStore Counters & Clear (D-23, DATA_MODELS §5)', () {
    test('errorCount accurately increments and decrements on eviction', () {
      final store = DebugLogStore(maxEntries: 3);

      // Add non-error entries
      store.add(_entry(id: 1, level: DebugLogLevel.debug));
      expect(store.errorCount, 0);

      store.add(_entry(id: 2, level: DebugLogLevel.warning));
      expect(store.errorCount, 0);

      // Add error entry
      store.add(_entry(id: 3, level: DebugLogLevel.error));
      expect(store.errorCount, 1);

      // Evict id: 1 (debug) -> errorCount stays 1
      store.add(_entry(id: 4, level: DebugLogLevel.info));
      expect(store.errorCount, 1);

      // Evict id: 2 (warning) -> errorCount stays 1, add critical (isError) -> errorCount becomes 2
      store.add(_entry(id: 5, level: DebugLogLevel.critical));
      expect(store.errorCount, 2);

      // Store now holds [id: 3 (error), id: 4 (info), id: 5 (critical)]
      expect(store.snapshot().map((e) => e.id).toList(), equals([3, 4, 5]));

      // Evict id: 3 (error) -> errorCount decrements to 1
      store.add(_entry(id: 6, level: DebugLogLevel.info));
      expect(store.errorCount, 1);

      // Evict id: 4 (info) -> errorCount remains 1
      store.add(_entry(id: 7, level: DebugLogLevel.success));
      expect(store.errorCount, 1);

      // Evict id: 5 (critical) -> errorCount decrements to 0
      store.add(_entry(id: 8, level: DebugLogLevel.debug));
      expect(store.errorCount, 0);
    });

    test('clear resets entries, droppedCount, and errorCount', () {
      final store = DebugLogStore(maxEntries: 2);
      store.add(_entry(id: 1, level: DebugLogLevel.error));
      store.add(_entry(id: 2, level: DebugLogLevel.critical));
      store.add(_entry(id: 3, level: DebugLogLevel.info));

      expect(store.length, 2);
      expect(store.droppedCount, 1);
      expect(store.errorCount, 1); // id: 2 is critical

      store.clear();

      expect(store.length, 0);
      expect(store.isEmpty, isTrue);
      expect(store.droppedCount, 0);
      expect(store.errorCount, 0);
      expect(store.snapshot(), isEmpty);

      // Adding new entries after clear works normally
      store.add(_entry(id: 4, level: DebugLogLevel.error));
      expect(store.length, 1);
      expect(store.droppedCount, 0);
      expect(store.errorCount, 1);
    });
  });

  group('DebugLogStore Snapshot Caching & Immutability (DATA_MODELS §5)', () {
    test('snapshot returns an unmodifiable view', () {
      final store = DebugLogStore(maxEntries: 5);
      store.add(_entry(id: 1));

      final snapshot = store.snapshot();
      expect(() => snapshot.add(_entry(id: 2)), throwsUnsupportedError);
      expect(() => snapshot.removeAt(0), throwsUnsupportedError);
      expect(() => snapshot.clear(), throwsUnsupportedError);
      expect(() => snapshot[0] = _entry(id: 99), throwsUnsupportedError);
    });

    test('snapshot is cached until next mutation', () {
      final store = DebugLogStore(maxEntries: 5);
      store.add(_entry(id: 1));
      store.add(_entry(id: 2));

      final s1 = store.snapshot();
      final s2 = store.snapshot();
      expect(identical(s1, s2), isTrue);

      // Mutation by add invalidates cache
      store.add(_entry(id: 3));
      final s3 = store.snapshot();
      expect(identical(s1, s3), isFalse);
      expect(s3.length, 3);

      final s4 = store.snapshot();
      expect(identical(s3, s4), isTrue);

      // Mutation by clear updates/invalidates cache
      store.clear();
      final s5 = store.snapshot();
      expect(identical(s4, s5), isFalse);
      expect(s5, isEmpty);
    });

    test('Previously obtained snapshot is isolated from subsequent store mutations', () {
      final store = DebugLogStore(maxEntries: 2);
      store.add(_entry(id: 1));
      final snapshotBeforeEviction = store.snapshot();

      store.add(_entry(id: 2));
      store.add(_entry(id: 3)); // evicts 1

      expect(snapshotBeforeEviction.length, 1);
      expect(snapshotBeforeEviction.first.id, 1);

      final currentSnapshot = store.snapshot();
      expect(currentSnapshot.length, 2);
      expect(currentSnapshot.map((e) => e.id).toList(), equals([2, 3]));
    });
  });
}
