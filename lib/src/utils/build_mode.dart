import 'package:flutter/foundation.dart';

/// Internal resolver for the runtime build mode.
///
/// Provides test seams to simulate release and profile modes in unit tests.
class BuildMode {
  BuildMode._();

  @visibleForTesting
  static bool? releaseOverride;

  @visibleForTesting
  static bool? profileOverride;

  @visibleForTesting
  static bool? debugOverride;

  /// True if running in release mode or if release mode is simulated.
  static bool get isRelease => releaseOverride ?? kReleaseMode;

  /// True if running in profile mode or if profile mode is simulated.
  static bool get isProfile => profileOverride ?? kProfileMode;

  /// True if running in debug mode or if debug mode is simulated.
  static bool get isDebug => debugOverride ?? kDebugMode;

  /// Resets all test overrides.
  @visibleForTesting
  static void reset() {
    releaseOverride = null;
    profileOverride = null;
    debugOverride = null;
  }
}
