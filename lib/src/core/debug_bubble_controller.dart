import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../collectors/error_hook_registry.dart';
import '../export/json_exporter.dart';
import '../export/text_exporter.dart';
import '../utils/build_mode.dart';
import 'debug_bubble_config.dart';
import 'debug_log_entry.dart';
import 'debug_log_filter.dart';
import 'debug_log_level.dart';
import 'debug_log_service.dart';
import 'debug_log_store.dart';

/// State and log store manager for the debug bubble toolkit.
class DebugBubbleController extends ChangeNotifier {
  /// Creates a standalone or default controller with the given [config].
  DebugBubbleController({this.config = const DebugBubbleConfig()})
    : _store = DebugLogStore(maxEntries: config.maxEntries) {
    _service = DebugLogService(
      config: config,
      store: _store,
      isActiveGetter: () => isActive,
      onEntryIngested: (_) => _scheduleNotification(),
    );
    if (isActive && config.captureUncaughtErrors) {
      ErrorHookRegistry.instance.registerSink(this);
    }
  }

  bool _notificationScheduled = false;

  void _scheduleNotification() {
    if (_isDisposed || !isActive) return;

    try {
      final binding = SchedulerBinding.instance;
      final phase = binding.schedulerPhase;
      final inFrame = phase == SchedulerPhase.persistentCallbacks ||
          phase == SchedulerPhase.midFrameMicrotasks;

      if (inFrame) {
        if (!_notificationScheduled) {
          _notificationScheduled = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _notificationScheduled = false;
            if (!_isDisposed && isActive) {
              notifyListeners();
            }
          });
        }
        return;
      }
    } catch (_) {
      // In isolated environments without a scheduler binding, fall through
    }

    notifyListeners();
  }

  /// The immutable configuration used by this controller.
  final DebugBubbleConfig config;

  final DebugLogStore _store;
  late final DebugLogService _service;

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
    _service.log(
      level,
      message,
      tag: tag,
      subTag: subTag,
      error: error,
      stackTrace: stackTrace,
      metadata: metadata,
      json: json,
    );
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

  final JsonExporter _jsonExporter = const JsonExporter();
  final TextExporter _textExporter = const TextExporter();

  /// Exports stored entries matching [filter] as a schema v1 JSON string.
  String exportJson({DebugLogFilter filter = const DebugLogFilter()}) {
    if (BuildMode.isRelease) return '';
    if (!isActive) {
      return _jsonExporter.export(
        entries: const <DebugLogEntry>[],
        config: config,
        totalEntries: 0,
        droppedCount: 0,
        filter: filter,
      );
    }
    final filtered = query(filter);
    return _jsonExporter.export(
      entries: filtered,
      config: config,
      totalEntries: _store.length,
      droppedCount: _store.droppedCount,
      filter: filter,
    );
  }

  /// Exports stored entries matching [filter] as formatted plain text.
  String exportText({DebugLogFilter filter = const DebugLogFilter()}) {
    if (BuildMode.isRelease) return '';
    if (!isActive) {
      return _textExporter.export(
        entries: const <DebugLogEntry>[],
        droppedCount: 0,
      );
    }
    final filtered = query(filter);
    return _textExporter.export(
      entries: filtered,
      droppedCount: _store.droppedCount,
    );
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
    _notificationScheduled = false;
    _isDashboardOpen = false;
    ErrorHookRegistry.instance.unregisterSink(this);
    _store.clear();
    // Notify listeners once so mounted observers know the controller is disposed (L-8)
    notifyListeners();
    super.dispose();
  }

  /// Ingests an uncaught error into this controller's service pipeline (E-3, E-4).
  @internal
  void logUncaught(
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
    _service.log(
      level,
      message,
      tag: tag,
      subTag: subTag,
      error: error,
      stackTrace: stackTrace,
      metadata: metadata,
      json: json,
      isUncaught: true,
    );
  }

  @override
  void addListener(VoidCallback listener) {
    if (_isDisposed) return;
    super.addListener(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    if (_isDisposed) return;
    super.removeListener(listener);
  }
}
