import 'debug_log_entry.dart';

/// In-memory bounded store for sanitized [DebugLogEntry] instances.
///
/// Implements a ring-buffer-like store bounded by [maxEntries]. When capacity
/// is reached, the single oldest entry is evicted first and [droppedCount] is
/// incremented.
///
/// Internal in 0.1.0 per DATA_MODELS.md §5 and PROJECT_SPEC.md (D-06, D-23).
class DebugLogStore {
  /// Creates a bounded store with the specified [maxEntries] capacity limit.
  ///
  /// [maxEntries] must be >= 1.
  DebugLogStore({required this.maxEntries})
    : assert(maxEntries >= 1, 'maxEntries must be >= 1') {
    if (maxEntries < 1) {
      throw ArgumentError.value(
        maxEntries,
        'maxEntries',
        'Capacity must be >= 1.',
      );
    }
  }

  /// Maximum number of entries this store can retain simultaneously.
  final int maxEntries;

  final List<DebugLogEntry> _entries = <DebugLogEntry>[];
  int _droppedCount = 0;
  int _errorCount = 0;
  List<DebugLogEntry>? _cachedSnapshot;

  /// Number of entries currently stored in the buffer (always <= [maxEntries]).
  int get length => _entries.length;

  /// Whether the store currently contains zero entries.
  bool get isEmpty => _entries.isEmpty;

  /// Whether the store currently contains at least one entry.
  bool get isNotEmpty => _entries.isNotEmpty;

  /// Number of entries evicted due to exceeding [maxEntries] capacity since
  /// creation or the last [clear] call (D-23).
  int get droppedCount => _droppedCount;

  /// Number of entries currently stored whose level represents an error (`level.isError`).
  int get errorCount => _errorCount;

  /// Appends [entry] to the store.
  ///
  /// If [length] equals [maxEntries], the single oldest entry is evicted,
  /// [droppedCount] is incremented by 1, [errorCount] is decremented if the
  /// evicted entry was an error, and the new entry is appended.
  ///
  /// Invalidates any previously cached [snapshot].
  void add(DebugLogEntry entry) {
    while (_entries.length >= maxEntries) {
      final evicted = _entries.removeAt(0);
      _droppedCount++;
      if (evicted.level.isError) {
        _errorCount--;
      }
    }

    _entries.add(entry);
    if (entry.level.isError) {
      _errorCount++;
    }
    _cachedSnapshot = null;
  }

  /// Returns an unmodifiable view of stored entries from oldest to newest.
  ///
  /// The result is cached until the next mutation ([add] or [clear]).
  List<DebugLogEntry> snapshot() {
    return _cachedSnapshot ??= List<DebugLogEntry>.unmodifiable(_entries);
  }

  /// Clears all entries from the store and resets [droppedCount] and [errorCount] to 0.
  ///
  /// Monotonic entry IDs are managed externally by the controller/service and
  /// are not reset by clearing the store (DATA_MODELS.md §5).
  void clear() {
    _entries.clear();
    _droppedCount = 0;
    _errorCount = 0;
    _cachedSnapshot = const <DebugLogEntry>[];
  }
}
