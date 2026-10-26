import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../core/debug_bubble_controller.dart';
import '../core/debug_log_level.dart';

/// Status of uncaught error capture per DATA_MODELS.md §10.
enum ErrorHookStatus {
  off('off'),
  active('active'),
  handlerReplaced('inactive (handler replaced)');

  const ErrorHookStatus(this.label);

  /// Human-readable label displayed in the Info tab.
  final String label;

  @override
  String toString() => label;
}

/// Process-wide registry managing global error hooks (ARCHITECTURE.md §6, E-1..E-9, D-08).
///
/// Ensures only one wrapper pair is installed across all controllers, chains
/// existing handlers, detects external handler replacements, and restores original
/// handlers when all sinks unregister.
class ErrorHookRegistry {
  ErrorHookRegistry._();

  /// The process-wide singleton registry instance (L-11).
  static final ErrorHookRegistry instance = ErrorHookRegistry._();

  final Set<DebugBubbleController> _sinks = <DebugBubbleController>{};

  FlutterExceptionHandler? _previousFlutterOnError;
  ErrorCallback? _previousPlatformOnError;

  FlutterExceptionHandler? _installedFlutterWrapper;
  ErrorCallback? _installedPlatformWrapper;

  bool _isHandlingFlutterError = false;
  bool _isHandlingPlatformError = false;

  /// Whether error hook wrappers are currently installed.
  bool get isInstalled =>
      _installedFlutterWrapper != null || _installedPlatformWrapper != null;

  /// Number of active controller sinks currently registered.
  int get sinkCount => _sinks.length;

  /// True if another component replaced FlutterError.onError after our installation (E-6).
  bool get isFlutterHandlerReplaced =>
      _installedFlutterWrapper != null &&
      FlutterError.onError != _installedFlutterWrapper;

  /// True if another component replaced PlatformDispatcher.onError after our installation (E-6).
  bool get isPlatformHandlerReplaced =>
      _installedPlatformWrapper != null &&
      PlatformDispatcher.instance.onError != _installedPlatformWrapper;

  /// True if either global error handler was replaced by an external component (E-6).
  bool get isHandlerReplaced =>
      isFlutterHandlerReplaced || isPlatformHandlerReplaced;

  /// Returns the current error-hook status for [controller] per DATA_MODELS.md §10.
  ErrorHookStatus statusFor(DebugBubbleController? controller) {
    if (controller == null ||
        !controller.isActive ||
        !controller.config.captureUncaughtErrors) {
      return ErrorHookStatus.off;
    }
    if (!_sinks.contains(controller)) {
      return ErrorHookStatus.off;
    }
    if (isHandlerReplaced) {
      return ErrorHookStatus.handlerReplaced;
    }
    return ErrorHookStatus.active;
  }

  /// Registers an active controller as a sink for uncaught errors (E-1, E-2).
  void registerSink(DebugBubbleController controller) {
    if (!controller.isActive || !controller.config.captureUncaughtErrors) {
      return;
    }
    if (_sinks.contains(controller)) {
      return;
    }

    if (_sinks.isEmpty) {
      _install();
    }

    _sinks.add(controller);
  }

  /// Unregisters [controller]. Restores previous handlers when the last sink unregisters (E-5).
  void unregisterSink(DebugBubbleController controller) {
    final removed = _sinks.remove(controller);
    if (!removed) return;

    if (_sinks.isEmpty) {
      _uninstall();
    }
  }

  void _install() {
    _previousFlutterOnError = FlutterError.onError;
    _installedFlutterWrapper = _handleFlutterError;
    FlutterError.onError = _installedFlutterWrapper;

    _previousPlatformOnError = PlatformDispatcher.instance.onError;
    _installedPlatformWrapper = _handlePlatformError;
    PlatformDispatcher.instance.onError = _installedPlatformWrapper;
  }

  void _uninstall() {
    // If the current handler is still our wrapper, restore previous;
    // otherwise leave in place and switch to pass-through (E-5).
    if (FlutterError.onError == _installedFlutterWrapper) {
      FlutterError.onError = _previousFlutterOnError;
      _previousFlutterOnError = null;
    }
    _installedFlutterWrapper = null;

    if (PlatformDispatcher.instance.onError == _installedPlatformWrapper) {
      PlatformDispatcher.instance.onError = _previousPlatformOnError;
      _previousPlatformOnError = null;
    }
    _installedPlatformWrapper = null;
  }

  void _handleFlutterError(FlutterErrorDetails details) {
    if (_isHandlingFlutterError) {
      _previousFlutterOnError?.call(details);
      return;
    }
    _isHandlingFlutterError = true;
    try {
      if (_sinks.isNotEmpty) {
        try {
          String message;
          try {
            message = details.exceptionAsString();
          } catch (_) {
            message = 'FlutterError (${details.exception.runtimeType})';
          }

          for (final sink in _sinks) {
            sink.logUncaught(
              DebugLogLevel.error,
              message,
              tag: 'FlutterError',
              subTag: details.library,
              error: details.exception,
              stackTrace: details.stack,
            );
          }
        } catch (_) {
          // Internal failure isolation (NFR-03, E-9)
        }
      }
    } finally {
      _isHandlingFlutterError = false;
    }

    // Always invoke previous handler outside our try/catch (E-3, E-9)
    _previousFlutterOnError?.call(details);
  }

  bool _handlePlatformError(Object error, StackTrace stack) {
    if (_isHandlingPlatformError) {
      return _previousPlatformOnError?.call(error, stack) ?? false;
    }
    _isHandlingPlatformError = true;
    try {
      if (_sinks.isNotEmpty) {
        try {
          String message;
          try {
            message = error.toString();
          } catch (_) {
            message = 'PlatformError (${error.runtimeType})';
          }

          for (final sink in _sinks) {
            sink.logUncaught(
              DebugLogLevel.critical,
              message,
              tag: 'PlatformDispatcher',
              error: error,
              stackTrace: stack,
            );
          }
        } catch (_) {
          // Internal failure isolation (NFR-03, E-9)
        }
      }
    } finally {
      _isHandlingPlatformError = false;
    }

    // Return previous handler result outside our try/catch; never return true on our own (E-4, E-9)
    return _previousPlatformOnError?.call(error, stack) ?? false;
  }

  /// Restores handlers and clears all sinks. Used exclusively in unit test tearDown.
  @visibleForTesting
  static void resetForTesting() {
    instance._forceReset();
  }

  void _forceReset() {
    if (_installedFlutterWrapper != null &&
        FlutterError.onError == _installedFlutterWrapper) {
      FlutterError.onError = _previousFlutterOnError;
    } else if (_previousFlutterOnError != null) {
      FlutterError.onError = _previousFlutterOnError;
    }
    if (_installedPlatformWrapper != null &&
        PlatformDispatcher.instance.onError == _installedPlatformWrapper) {
      PlatformDispatcher.instance.onError = _previousPlatformOnError;
    } else if (_previousPlatformOnError != null) {
      PlatformDispatcher.instance.onError = _previousPlatformOnError;
    }
    _sinks.clear();
    _previousFlutterOnError = null;
    _previousPlatformOnError = null;
    _installedFlutterWrapper = null;
    _installedPlatformWrapper = null;
    _isHandlingFlutterError = false;
    _isHandlingPlatformError = false;
  }
}
