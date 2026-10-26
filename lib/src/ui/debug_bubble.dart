import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../core/debug_bubble_controller.dart';
import '../core/debug_log.dart';
import 'bubble.dart';
import 'dashboard.dart';

/// Floating debug bubble widget providing in-app access to the debug dashboard.
///
/// Places the debugging bubble above the application content in a [Stack].
///
/// When [controller] is omitted, [DebugBubble] automatically binds to the default
/// controller initialized by [DebugLog.init], rebinding whenever the default
/// is replaced, created, or disposed (L-6).
class DebugBubble extends StatefulWidget {
  const DebugBubble({super.key, required this.child, this.controller});

  /// Host app widget subtree.
  final Widget child;

  /// Explicit controller to bind with; if null, follows the default controller.
  final DebugBubbleController? controller;

  @override
  State<DebugBubble> createState() => _DebugBubbleState();
}

class _DebugBubbleState extends State<DebugBubble> with WidgetsBindingObserver {
  final GlobalKey<DashboardOverlayState> _dashboardKey =
      GlobalKey<DashboardOverlayState>();
  DebugBubbleController? _subscribedController;

  DebugBubbleController? get _effectiveController =>
      widget.controller ?? DebugLog.controller;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
      try {
        _subscribedController!.removeListener(_onControllerNotified);
      } catch (_) {
        // Ignored if notifier was already disposed
      }
      _subscribedController = null;
    }
  }

  bool _rebuildScheduled = false;

  void _onDefaultControllerChanged() {
    _bindController(_effectiveController);
    _onControllerNotified();
  }

  void _onControllerNotified() {
    if (_subscribedController?.isDisposed == true) {
      _unbindController();
    }
    if (!mounted) return;

    try {
      final binding = SchedulerBinding.instance;
      final phase = binding.schedulerPhase;
      final inFrame = phase == SchedulerPhase.persistentCallbacks ||
          phase == SchedulerPhase.midFrameMicrotasks;

      if (inFrame) {
        if (!_rebuildScheduled) {
          _rebuildScheduled = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _rebuildScheduled = false;
            if (mounted) {
              setState(() {});
            }
          });
        }
        return;
      }
    } catch (_) {
      // In isolated environments without a scheduler binding, fall through
    }

    setState(() {});
  }

  @override
  Future<bool> didPopRoute() async {
    final controller = _effectiveController;
    if (controller != null && controller.isActive && controller.isDashboardOpen) {
      if (_dashboardKey.currentState?.handleBack() == true) {
        return true; // Closed detail view
      }
      controller.closeDashboard();
      return true; // Intercept back to close dashboard without popping host route (D-27)
    }
    return false; // Allow host app to handle back route normally
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _rebuildScheduled = false;
    _unsubscribe();
    // Widgets never dispose controllers (L-7)
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _effectiveController;

    // If controller is absent, disposed, or inactive (e.g. release mode), render only child (L-6, L-8, D-04)
    if (controller == null || !controller.isActive) {
      return widget.child;
    }

    return Stack(
      fit: StackFit.passthrough,
      children: [
        widget.child,
        if (controller.isDashboardOpen)
          DashboardOverlay(key: _dashboardKey, controller: controller)
        else
          FloatingBubble(controller: controller),
      ],
    );
  }
}
