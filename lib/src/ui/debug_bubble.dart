import 'package:flutter/widgets.dart';

import '../core/debug_bubble_controller.dart';

/// Floating debug bubble widget providing in-app access to the debug dashboard.
class DebugBubble extends StatefulWidget {
  const DebugBubble({super.key, required this.child, this.controller});

  /// Host app widget subtree.
  final Widget child;

  /// Explicit controller to bind with; if null, follows the default controller.
  final DebugBubbleController? controller;

  @override
  State<DebugBubble> createState() => _DebugBubbleState();
}

class _DebugBubbleState extends State<DebugBubble> {
  @override
  Widget build(BuildContext context) {
    // Minimal stub for Phase 1: renders child directly
    return widget.child;
  }
}
