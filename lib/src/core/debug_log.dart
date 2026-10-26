import 'package:flutter/foundation.dart';

import 'debug_bubble_config.dart';
import 'debug_bubble_controller.dart';
import 'debug_log_level.dart';

/// Static facade providing easy access to the default toolkit controller.
class DebugLog {
  DebugLog._();

  static DebugBubbleController? _defaultController;

  /// Internal notifier that signals when the default controller changes,
  /// is replaced, or is disposed. Used by [DebugBubble] to rebind automatically (L-6).
  @internal
  static final ValueNotifier<DebugBubbleController?> defaultControllerNotifier =
      ValueNotifier<DebugBubbleController?>(null);

  static bool _warnedBeforeInit = false;

  /// Resets the pre-init warning flag for testing.
  @visibleForTesting
  static void resetWarningFlag() {
    _warnedBeforeInit = false;
  }

  /// Initializes the default controller with [config], replacing and disposing
  /// any existing default controller (L-3, D-03).
  static DebugBubbleController init([
    DebugBubbleConfig config = const DebugBubbleConfig(),
  ]) {
    if (_defaultController != null) {
      debugPrint(
        '[debug_bubble] DebugLog.init() replaced an existing default controller (L-3, D-03).',
      );
      _defaultController!.dispose();
    }
    final controller = DebugBubbleController(config: config);
    _defaultController = controller;
    defaultControllerNotifier.value = controller;
    return controller;
  }

  /// The active default controller, or null before [init] or after [dispose].
  static DebugBubbleController? get controller => _defaultController;

  /// Disposes and clears the active default controller. Idempotent (L-5, L-8).
  static void dispose() {
    _defaultController?.dispose();
    _defaultController = null;
    defaultControllerNotifier.value = null;
  }

  /// Records a log entry through the default controller.
  static void log(
    DebugLogLevel level,
    String message, {
    String? tag,
    String? subTag,
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?>? metadata,
    Object? json,
  }) {
    if (_defaultController == null) {
      if (!_warnedBeforeInit) {
        _warnedBeforeInit = true;
        debugPrint(
          '[debug_bubble] DebugLog facade was called before DebugLog.init(). '
          'Logs emitted before init are dropped (L-4, D-24).',
        );
      }
      return;
    }

    _defaultController!.log(
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

  /// Convenience logging method for [DebugLogLevel.debug].
  static void debug(
    String message, {
    String? tag,
    String? subTag,
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?>? metadata,
    Object? json,
  }) => log(
    DebugLogLevel.debug,
    message,
    tag: tag,
    subTag: subTag,
    error: error,
    stackTrace: stackTrace,
    metadata: metadata,
    json: json,
  );

  /// Convenience logging method for [DebugLogLevel.info].
  static void info(
    String message, {
    String? tag,
    String? subTag,
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?>? metadata,
    Object? json,
  }) => log(
    DebugLogLevel.info,
    message,
    tag: tag,
    subTag: subTag,
    error: error,
    stackTrace: stackTrace,
    metadata: metadata,
    json: json,
  );

  /// Convenience logging method for [DebugLogLevel.success].
  static void success(
    String message, {
    String? tag,
    String? subTag,
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?>? metadata,
    Object? json,
  }) => log(
    DebugLogLevel.success,
    message,
    tag: tag,
    subTag: subTag,
    error: error,
    stackTrace: stackTrace,
    metadata: metadata,
    json: json,
  );

  /// Convenience logging method for [DebugLogLevel.warning].
  static void warning(
    String message, {
    String? tag,
    String? subTag,
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?>? metadata,
    Object? json,
  }) => log(
    DebugLogLevel.warning,
    message,
    tag: tag,
    subTag: subTag,
    error: error,
    stackTrace: stackTrace,
    metadata: metadata,
    json: json,
  );

  /// Convenience logging method for [DebugLogLevel.error].
  static void error(
    String message, {
    String? tag,
    String? subTag,
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?>? metadata,
    Object? json,
  }) => log(
    DebugLogLevel.error,
    message,
    tag: tag,
    subTag: subTag,
    error: error,
    stackTrace: stackTrace,
    metadata: metadata,
    json: json,
  );

  /// Convenience logging method for [DebugLogLevel.critical].
  static void critical(
    String message, {
    String? tag,
    String? subTag,
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?>? metadata,
    Object? json,
  }) => log(
    DebugLogLevel.critical,
    message,
    tag: tag,
    subTag: subTag,
    error: error,
    stackTrace: stackTrace,
    metadata: metadata,
    json: json,
  );
}
