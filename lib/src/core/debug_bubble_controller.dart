import 'package:flutter/foundation.dart';

import '../utils/build_mode.dart';
import 'debug_bubble_config.dart';
import 'debug_log_entry.dart';
import 'debug_log_filter.dart';
import 'debug_log_level.dart';
import 'debug_log_store.dart';

/// State and log store manager for the debug bubble toolkit.
class DebugBubbleController extends ChangeNotifier {
  /// Creates a standalone or default controller with the given [config].
  DebugBubbleController({this.config = const DebugBubbleConfig()})
    : _store = DebugLogStore(maxEntries: config.maxEntries);

  /// The immutable configuration used by this controller.
  final DebugBubbleConfig config;

  final DebugLogStore _store;

  /// Whether this controller is currently active (enabled, non-release mode, and not disposed).
  bool get isActive => !isDisposed && config.enabled && !BuildMode.isRelease;

  /// Whether this controller has been disposed.
  bool get isDisposed => _isDisposed;

  /// Unmodifiable view of currently stored log entries, oldest to newest.
  List<DebugLogEntry> get entries => _store.snapshot();

  /// Total number of entries currently stored in the buffer.
  int get entryCount => _store.length;

  /// Number of entries evicted due to ring buffer capacity since creation or last clear.
  int get droppedCount => _store.droppedCount;

  /// Number of stored entries that represent an error level.
  int get errorCount => _store.errorCount;

  /// Whether the dashboard overlay is currently visible.
  bool get isDashboardOpen => _isDashboardOpen;

  bool _isDisposed = false;
  bool _isDashboardOpen = false;

  /// Ingests a new log event into the pipeline.
  ///
  /// *Note: This is a Phase 1 scaffold stub. The full ingestion pipeline,*
  /// *sanitization, redaction, and bounded store fan-out are scheduled for Phase 2.*
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
    // Intentional Phase 1 stub: logging pipeline is implemented in Phase 2 (T2.5).
  }

  /// Returns entries matching the given [filter].
  List<DebugLogEntry> query(DebugLogFilter filter) {
    if (!isActive) return const <DebugLogEntry>[];
    return _store.snapshot().where(filter.matches).toList();
  }

  /// Clears stored log entries and resets [droppedCount].
  void clear() {
    if (!isActive) return;
    _store.clear();
    notifyListeners();
  }

  /// Exports stored entries matching [filter] as a schema v1 JSON string.
  ///
  /// *Note: This is a Phase 1 scaffold stub. Full JSON export formatting is*
  /// *scheduled for Phase 2 (T2.6).*
  String exportJson({DebugLogFilter filter = const DebugLogFilter()}) {
    if (!isActive) return '';
    return '';
  }

  /// Exports stored entries matching [filter] as formatted plain text.
  ///
  /// *Note: This is a Phase 1 scaffold stub. Full plain-text export formatting*
  /// *is scheduled for Phase 2 (T2.6).*
  String exportText({DebugLogFilter filter = const DebugLogFilter()}) {
    if (!isActive) return '';
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
    _store.clear();
    // Notify listeners once so mounted observers know the controller is disposed (L-8)
    notifyListeners();
    super.dispose();
  }
}
