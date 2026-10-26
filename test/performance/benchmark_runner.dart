import 'dart:io';

import 'package:flutter/foundation.dart';

/// Result summary of a single benchmark scenario.
class BenchmarkResult {
  const BenchmarkResult({
    required this.name,
    required this.iterations,
    required this.elapsedMicros,
  });

  final String name;
  final int iterations;
  final int elapsedMicros;

  /// Average duration per operation in microseconds.
  double get avgMicros => iterations > 0 ? elapsedMicros / iterations : 0.0;

  /// Operations per second.
  double get opsPerSecond =>
      elapsedMicros > 0 ? (iterations * 1000000.0) / elapsedMicros : 0.0;

  @override
  String toString() {
    return '$name: $iterations ops in ${(elapsedMicros / 1000).toStringAsFixed(2)} ms '
        '(${avgMicros.toStringAsFixed(2)} µs/op, ${opsPerSecond.toStringAsFixed(0)} ops/s)';
  }
}

/// Lightweight harness for executing and reporting micro-benchmarks.
class BenchmarkRunner {
  const BenchmarkRunner();

  /// Executes [action] for [iterations] after [warmup] iterations, measuring total time.
  static BenchmarkResult measure(
    String name,
    void Function(int i) action, {
    int iterations = 1000,
    int warmup = 100,
  }) {
    // 1. Warmup phase
    for (var i = 0; i < warmup; i++) {
      action(i);
    }

    // 2. Timed benchmark phase
    final stopwatch = Stopwatch()..start();
    for (var i = 0; i < iterations; i++) {
      action(i);
    }
    stopwatch.stop();

    return BenchmarkResult(
      name: name,
      iterations: iterations,
      elapsedMicros: stopwatch.elapsedMicroseconds,
    );
  }

  /// Prints environment summary header.
  static void printEnvironment() {
    // ignore: avoid_print
    print('================================================================');
    // ignore: avoid_print
    print('  debug_bubble Core Benchmark Harness (T2.9)');
    // ignore: avoid_print
    print('================================================================');
    // ignore: avoid_print
    print('OS: ${Platform.operatingSystem} ${Platform.operatingSystemVersion}');
    // ignore: avoid_print
    print('Dart: ${Platform.version.split(' ').first}');
    // ignore: avoid_print
    print(
      'Mode: ${kReleaseMode ? "release" : (kProfileMode ? "profile" : "debug")}',
    );
    // ignore: avoid_print
    print('Date: ${DateTime.now().toUtc().toIso8601String()}');
    // ignore: avoid_print
    print('----------------------------------------------------------------');
  }
}
