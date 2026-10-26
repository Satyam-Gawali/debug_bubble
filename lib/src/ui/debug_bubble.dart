import 'package:flutter/widgets.dart';

import '../core/debug_bubble_controller.dart';
import '../core/debug_log.dart';

/// Floating debug bubble widget providing in-app access to the debug dashboard.
///
/// Places the debugging bubble above the application content.
///
/// When [controller] is omitted, [DebugBubble] automatically binds to the default
/// controller initialized by [DebugLog.init], rebinding whenever the default
/// is replaced, created, or disposed (L-6).
///
/// *Note: In Phase 1, this widget renders [child] directly. Draggable bubble*
/// *interaction, badges, and dashboard overlays are scheduled for Phase 3 (T3.1–T3.8).*
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
  DebugBubbleController? _subscribedController;

  DebugBubbleController? get _effectiveController =>
      widget.controller ?? DebugLog.controller;

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  @override
  void didUpdateWidget(DebugBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      _resubscribe();
    }
  }

  void _subscribe() {
    // If following the default controller, listen for default controller replacements (L-6)
    if (widget.controller == null) {
      DebugLog.defaultControllerNotifier.addListener(
        _onDefaultControllerChanged,
      );
    }
    _bindController(_effectiveController);
  }

  void _unsubscribe() {
    DebugLog.defaultControllerNotifier.removeListener(
      _onDefaultControllerChanged,
    );
    _unbindController();
  }

  void _resubscribe() {
    _unsubscribe();
    _subscribe();
  }

  void _bindController(DebugBubbleController? controller) {
    if (_subscribedController == controller) return;
    _unbindController();
    if (controller != null && !controller.isDisposed) {
      _subscribedController = controller;
      controller.addListener(_onControllerNotified);
    }
  }

  void _unbindController() {
    if (_subscribedController != null) {
      // Guard against removing listener on already disposed controller
      try {
        _subscribedController!.removeListener(_onControllerNotified);
      } catch (_) {
        // Ignored if notifier was already disposed
      }
      _subscribedController = null;
    }
  }

  void _onDefaultControllerChanged() {
    _bindController(_effectiveController);
    if (mounted) setState(() {});
  }

  void _onControllerNotified() {
    if (_subscribedController?.isDisposed == true) {
      _unbindController();
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _unsubscribe();
    // Widgets never dispose controllers (L-7)
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // In Phase 1 scaffold, renders child directly.
    // Floating bubble, gesture snapping, badge, and dashboard layer
    // are implemented in Phase 3 (UI).
    return widget.child;
  }
}
