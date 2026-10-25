import 'package:debug_bubble/debug_bubble.dart';
import 'package:flutter/material.dart';

void main() {
  // First statement: logs written before init are silently dropped (L-4, D-24).
  DebugLog.init(const DebugBubbleConfig(captureUncaughtErrors: true));
  // If you use Crashlytics/Sentry, initialize them BEFORE DebugLog.init (ARCHITECTURE.md E-6).
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    builder: (context, child) =>
        DebugBubble(child: child ?? const SizedBox.shrink()),
    home: const HomePage(),
  );
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('debug_bubble Example')),
      body: const Center(child: Text('Debug Bubble Example App')),
    );
  }
}
