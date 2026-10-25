import 'package:flutter/foundation.dart';

import 'debug_bubble_config.dart';
import 'debug_log_entry.dart';
import 'debug_log_filter.dart';
import 'debug_log_level.dart';

/// State and log store manager for the debug bubble toolkit.
class DebugBubbleController extends ChangeNotifier {
  /// Creates a standalone or default controller with the given [config].
  DebugBubbleController({this.config = const DebugBubbleConfig()});

  /// The immutable configuration used by this controller.
  final DebugBubbleConfig config;

  /// Whether this controller is currently active (enabled, non-release mode, and not disposed).
  bool get isActive => !isDisposed && config.enabled;

  /// Whether this controller has been disposed.
  bool get isDisposed => _isDisposed;

  /// Unmodifiable view of currently stored log entries, oldest to newest.
  List<DebugLogEntry> get entries => List.unmodifiable(_entries);

  /// Total number of entries currently stored in the buffer.
  int get entryCount => _entries.length;

  /// Number of entries evicted due to ring buffer capacity since creation or last clear.
  int get droppedCount => _droppedCount;

  /// Number of stored entries that represent an error level.
  int get errorCount => _entries.where((e) => e.level.isError).length;

  /// Whether the dashboard overlay is currently visible.
  bool get isDashboardOpen => _isDashboardOpen;

  final List<DebugLogEntry> _entries = <DebugLogEntry>[];
  int _droppedCount = 0;
  bool _isDisposed = false;
  bool _isDashboardOpen = false;

  /// Ingests a new log event into the pipeline.
  void log(
    DebugLogLevel level,
    String message, {
    String? tag,
    String? subTag,
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?>? metadata,
    Object? json,
  }) {
    if (!isActive) return;
    // Minimal stub for Phase 1: logging engine will be implemented in Phase 2
  }

  /// Returns entries matching the given [filter].
  List<DebugLogEntry> query(DebugLogFilter filter) {
    if (!isActive) return const <DebugLogEntry>[];
    return _entries.where(filter.matches).toList();
  }

  /// Clears stored log entries and resets [droppedCount].
  void clear() {
    if (!isActive) return;
    _entries.clear();
    _droppedCount = 0;
    notifyListeners();
  }

  /// Exports stored entries matching [filter] as a schema v1 JSON string.
  String exportJson({DebugLogFilter filter = const DebugLogFilter()}) {
    return '';
  }

  /// Exports stored entries matching [filter] as formatted plain text.
  String exportText({DebugLogFilter filter = const DebugLogFilter()}) {
    return '';
  }

  /// Opens the dashboard overlay.
  void openDashboard() {
    if (!isActive || _isDashboardOpen) return;
    _isDashboardOpen = true;
    notifyListeners();
  }

  /// Closes the dashboard overlay.
  void closeDashboard() {
    if (!isActive || !_isDashboardOpen) return;
    _isDashboardOpen = false;
    notifyListeners();
  }

  @override
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    _entries.clear();
    super.dispose();
  }
}
