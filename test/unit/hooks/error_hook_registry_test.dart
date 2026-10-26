import 'dart:ui';

import 'package:debug_bubble/debug_bubble.dart';
import 'package:debug_bubble/src/collectors/error_hook_registry.dart';
import 'package:debug_bubble/src/utils/build_mode.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Store top-level handlers to restore after entire suite
  late FlutterExceptionHandler? originalFlutterOnError;
  late ErrorCallback? originalPlatformOnError;

  setUpAll(() {
    originalFlutterOnError = FlutterError.onError;
    originalPlatformOnError = PlatformDispatcher.instance.onError;
  });

  tearDownAll(() {
    FlutterError.onError = originalFlutterOnError;
    PlatformDispatcher.instance.onError = originalPlatformOnError;
  });

  setUp(() {
    // Reset test overrides and clean registry before each test
    BuildMode.reset();
    ErrorHookRegistry.resetForTesting();
  });

  tearDown(() {
    BuildMode.reset();
    ErrorHookRegistry.resetForTesting();
  });

  group('ErrorHookRegistry & Global Error Collection (E-1..E-9, D-08)', () {
    test('Default configuration has captureUncaughtErrors = false and installs zero handlers (E-1, D-08)', () {
      void initialFlutterHandler(FlutterErrorDetails _) {}
      bool initialPlatformHandler(Object _, StackTrace _) => false;
      FlutterError.onError = initialFlutterHandler;
      PlatformDispatcher.instance.onError = initialPlatformHandler;

      final controller = DebugBubbleController();
      expect(controller.config.captureUncaughtErrors, isFalse);
      expect(ErrorHookRegistry.instance.isInstalled, isFalse);
      expect(ErrorHookRegistry.instance.sinkCount, 0);
      expect(FlutterError.onError, equals(initialFlutterHandler));
      expect(
        PlatformDispatcher.instance.onError,
        equals(initialPlatformHandler),
      );
      expect(
        ErrorHookRegistry.instance.statusFor(controller),
        ErrorHookStatus.off,
      );

      controller.dispose();
    });

    test('Inert release controller with captureUncaughtErrors = true never installs handlers (E-1, D-04)', () {
      BuildMode.releaseOverride = true;
      final controller = DebugBubbleController(
        config: const DebugBubbleConfig(captureUncaughtErrors: true),
      );

      expect(controller.isActive, isFalse);
      expect(ErrorHookRegistry.instance.isInstalled, isFalse);
      expect(
        ErrorHookRegistry.instance.statusFor(controller),
        ErrorHookStatus.off,
      );

      controller.dispose();
    });

    test('Active controller with captureUncaughtErrors = true installs wrappers and reports active status (E-1, E-2)', () {
      var flutterCalled = false;
      var platformCalled = false;
      FlutterError.onError = (_) {
        flutterCalled = true;
      };
      PlatformDispatcher.instance.onError = (_, _) {
        platformCalled = true;
        return true;
      };

      final controller = DebugBubbleController(
        config: const DebugBubbleConfig(captureUncaughtErrors: true),
      );

      expect(controller.isActive, isTrue);
      expect(ErrorHookRegistry.instance.isInstalled, isTrue);
      expect(ErrorHookRegistry.instance.sinkCount, 1);
      expect(
        ErrorHookRegistry.instance.statusFor(controller),
        ErrorHookStatus.active,
      );

      // Trigger FlutterError
      final details = FlutterErrorDetails(
        exception: Exception('Widget build failed'),
        library: 'widgets',
      );
      FlutterError.onError!(details);

      expect(flutterCalled, isTrue);
      expect(controller.entryCount, 1);
      final flutterEntry = controller.entries.first;
      expect(flutterEntry.level, DebugLogLevel.error);
      expect(flutterEntry.tag, 'FlutterError');
      expect(flutterEntry.subTag, 'widgets');
      expect(flutterEntry.isUncaught, isTrue);
      expect(flutterEntry.message.contains('Widget build failed'), isTrue);

      // Trigger PlatformDispatcher error
      final platformResult = PlatformDispatcher.instance.onError!(
        Exception('Async crash'),
        StackTrace.empty,
      );

      expect(platformCalled, isTrue);
      expect(platformResult, isTrue); // Propagated previous return value
      expect(controller.entryCount, 2);
      final platformEntry = controller.entries.last;
      expect(platformEntry.level, DebugLogLevel.critical);
      expect(platformEntry.tag, 'PlatformDispatcher');
      expect(platformEntry.isUncaught, isTrue);
      expect(platformEntry.message.contains('Async crash'), isTrue);

      controller.dispose();
    });

    test('Previous handler throwing propagates directly to caller without swallowing (E-3, E-4, E-9)', () {
      FlutterError.onError = (_) {
        throw StateError('Host Flutter handler failure');
      };
      PlatformDispatcher.instance.onError = (_, _) {
        throw FormatException('Host Platform handler failure');
      };

      final controller = DebugBubbleController(
        config: const DebugBubbleConfig(captureUncaughtErrors: true),
      );

      final details = FlutterErrorDetails(exception: Exception('Test'));
      expect(() => FlutterError.onError!(details), throwsA(isA<StateError>()));
      expect(
        controller.entryCount,
        1,
      ); // Still captured before previous handler threw

      expect(
        () => PlatformDispatcher.instance.onError!(
          Exception('Test'),
          StackTrace.empty,
        ),
        throwsA(isA<FormatException>()),
      );
      expect(controller.entryCount, 2);

      controller.dispose();
    });

    test('Null previous PlatformDispatcher.onError defaults to returning false (E-4, E-9)', () {
      PlatformDispatcher.instance.onError = null;

      final controller = DebugBubbleController(
        config: const DebugBubbleConfig(captureUncaughtErrors: true),
      );

      final handled = PlatformDispatcher.instance.onError!(
        Exception('Unhandled error'),
        StackTrace.empty,
      );

      expect(handled, isFalse); // Never marks as handled on its own
      expect(controller.entryCount, 1);

      controller.dispose();
    });

    test('Restoration after last controller disposal restores original handlers (E-5, L-8)', () {
      void initialFlutter(FlutterErrorDetails _) {}
      bool initialPlatform(Object _, StackTrace _) => false;
      FlutterError.onError = initialFlutter;
      PlatformDispatcher.instance.onError = initialPlatform;

      final controller = DebugBubbleController(
        config: const DebugBubbleConfig(captureUncaughtErrors: true),
      );
      expect(ErrorHookRegistry.instance.isInstalled, isTrue);

      controller.dispose();

      expect(ErrorHookRegistry.instance.isInstalled, isFalse);
      expect(ErrorHookRegistry.instance.sinkCount, 0);
      expect(FlutterError.onError, equals(initialFlutter));
      expect(PlatformDispatcher.instance.onError, equals(initialPlatform));
    });

    test('Replaced-handler detection reports inactive (handler replaced) status (E-6)', () {
      final controller = DebugBubbleController(
        config: const DebugBubbleConfig(captureUncaughtErrors: true),
      );
      expect(
        ErrorHookRegistry.instance.statusFor(controller),
        ErrorHookStatus.active,
      );

      // External library replaces FlutterError.onError without chaining
      FlutterError.onError = (_) {};

      expect(ErrorHookRegistry.instance.isFlutterHandlerReplaced, isTrue);
      expect(ErrorHookRegistry.instance.isHandlerReplaced, isTrue);
      expect(
        ErrorHookRegistry.instance.statusFor(controller),
        ErrorHookStatus.handlerReplaced,
      );
      expect(
        ErrorHookRegistry.instance.statusFor(controller).label,
        'inactive (handler replaced)',
      );

      controller.dispose();
    });

    test('Wrapped-by-another-library leaves wrapper in place on dispose and switches to pass-through (E-5, E-6)', () {
      var originalCalled = false;
      FlutterError.onError = (_) {
        originalCalled = true;
      };

      final controller = DebugBubbleController(
        config: const DebugBubbleConfig(captureUncaughtErrors: true),
      );

      // Another library wraps our handler
      final ourHandler = FlutterError.onError!;
      var wrapperCalled = false;
      FlutterError.onError = (details) {
        wrapperCalled = true;
        ourHandler(details);
      };

      // Dispose controller
      controller.dispose();

      // Handlers are left in place because top-level handler is not our wrapper
      expect(wrapperCalled, isFalse);
      expect(originalCalled, isFalse);

      // When called, it passes through to original without logging to the disposed controller
      final details = FlutterErrorDetails(exception: Exception('E'));
      FlutterError.onError!(details);

      expect(wrapperCalled, isTrue);
      expect(originalCalled, isTrue);
      expect(
        controller.entryCount,
        0,
      ); // No entries added to disposed controller
    });

    test('Multiple controllers share single wrapper pair without stacking (E-2, L-9)', () {
      var previousFlutterCalls = 0;
      FlutterError.onError = (_) {
        previousFlutterCalls++;
      };

      final controller1 = DebugBubbleController(
        config: const DebugBubbleConfig(captureUncaughtErrors: true),
      );
      final controller2 = DebugBubbleController(
        config: const DebugBubbleConfig(captureUncaughtErrors: true),
      );

      expect(ErrorHookRegistry.instance.sinkCount, 2);

      // Trigger error once
      FlutterError.onError!(
        FlutterErrorDetails(exception: Exception('Multi-test')),
      );

      // Previous handler called only ONCE
      expect(previousFlutterCalls, 1);
      // Both controllers received the log
      expect(controller1.entryCount, 1);
      expect(controller2.entryCount, 1);

      // Disposing one controller leaves the wrapper active for the other
      controller1.dispose();
      expect(ErrorHookRegistry.instance.sinkCount, 1);
      expect(ErrorHookRegistry.instance.isInstalled, isTrue);

      FlutterError.onError!(
        FlutterErrorDetails(exception: Exception('Multi-test 2')),
      );
      expect(previousFlutterCalls, 2);
      expect(controller1.entryCount, 0); // Controller 1 cleared on dispose
      expect(controller2.entryCount, 2);

      // Disposing final controller restores previous handler
      controller2.dispose();
      expect(ErrorHookRegistry.instance.sinkCount, 0);
      expect(ErrorHookRegistry.instance.isInstalled, isFalse);
    });

    test('Repeated DebugLog.init disposes previous and re-registers cleanly without stacking wrappers (L-3, L-9)', () {
      DebugLog.init(const DebugBubbleConfig(captureUncaughtErrors: true));
      expect(ErrorHookRegistry.instance.sinkCount, 1);

      // Re-init replaces controller
      DebugLog.init(const DebugBubbleConfig(captureUncaughtErrors: true));
      expect(ErrorHookRegistry.instance.sinkCount, 1);
      expect(ErrorHookRegistry.instance.isInstalled, isTrue);

      DebugLog.dispose();
      expect(ErrorHookRegistry.instance.sinkCount, 0);
      expect(ErrorHookRegistry.instance.isInstalled, isFalse);
    });

    test('Installation safety before WidgetsFlutterBinding (E-7)', () {
      // Direct access to static registration works without binding
      final controller = DebugBubbleController(
        config: const DebugBubbleConfig(captureUncaughtErrors: true),
      );
      expect(ErrorHookRegistry.instance.isInstalled, isTrue);
      controller.dispose();
      expect(ErrorHookRegistry.instance.isInstalled, isFalse);
    });
  });
}
