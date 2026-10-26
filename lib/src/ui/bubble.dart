import 'package:flutter/material.dart';

import '../core/debug_bubble_controller.dart';

/// Floating draggable debug bubble widget per UI_UX_SPEC.md §1.
class FloatingBubble extends StatefulWidget {
  const FloatingBubble({super.key, required this.controller});

  /// The active controller providing state, configuration, and actions.
  final DebugBubbleController controller;

  @override
  State<FloatingBubble> createState() => _FloatingBubbleState();
}

class _FloatingBubbleState extends State<FloatingBubble> {
  static const double _bubbleSize = 56.0;
  static const double _margin = 8.0;

  bool _isInitialized = false;
  bool _isDockedOnRight = true;
  double _fractionalY = 0.5;
  Offset? _dragPosition;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      final alignment = widget.controller.config.initialBubbleAlignment;
      _isDockedOnRight = alignment.x >= 0;
      // Map alignment y (-1.0 to 1.0) to fractional 0.0 to 1.0
      _fractionalY = ((alignment.y + 1.0) / 2.0).clamp(0.0, 1.0);
      _isInitialized = true;
    }
  }

  void _onPanStart(DragStartDetails details) {
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox != null) {
      _dragPosition = renderBox.localToGlobal(Offset.zero);
    }
  }

  void _onPanUpdate(
    DragUpdateDetails details,
    EdgeInsets padding,
    EdgeInsets insets,
    Size screenSize,
  ) {
    final current =
        _dragPosition ?? _calculateRestingPosition(padding, insets, screenSize);
    final minY = padding.top + _margin;
    final maxY =
        screenSize.height - padding.bottom - insets.bottom - _bubbleSize - _margin;
    final minX = padding.left + _margin;
    final maxX = screenSize.width - padding.right - _bubbleSize - _margin;

    final newX = (current.dx + details.delta.dx).clamp(
      minX,
      maxX > minX ? maxX : minX,
    );
    final newY = (current.dy + details.delta.dy).clamp(
      minY,
      maxY > minY ? maxY : minY,
    );

    setState(() {
      _dragPosition = Offset(newX, newY);
    });
  }

  void _onPanEnd(
    DragEndDetails details,
    EdgeInsets padding,
    EdgeInsets insets,
    Size screenSize,
  ) {
    if (_dragPosition != null) {
      final centerX = _dragPosition!.dx + (_bubbleSize / 2);
      final isRight = centerX >= (screenSize.width / 2);

      final minY = padding.top + _margin;
      final maxY =
          screenSize.height - padding.bottom - insets.bottom - _bubbleSize - _margin;
      final availableHeight = (maxY - minY) > 0 ? (maxY - minY) : 1.0;
      final relativeY = (_dragPosition!.dy - minY) / availableHeight;

      setState(() {
        _isDockedOnRight = isRight;
        _fractionalY = relativeY.clamp(0.0, 1.0);
        _dragPosition = null;
      });
    }
  }

  Offset _calculateRestingPosition(
    EdgeInsets padding,
    EdgeInsets insets,
    Size screenSize,
  ) {
    final minY = padding.top + _margin;
    final maxY =
        screenSize.height - padding.bottom - insets.bottom - _bubbleSize - _margin;
    final effectiveMaxY = maxY > minY ? maxY : minY;
    final y = minY + (_fractionalY * (effectiveMaxY - minY));

    final x = _isDockedOnRight
        ? (screenSize.width - padding.right - _bubbleSize - _margin)
        : (padding.left + _margin);

    return Offset(x, y);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final screenSize = MediaQuery.sizeOf(context);
        final padding = MediaQuery.paddingOf(context);
        final insets = MediaQuery.viewInsetsOf(context);

        final position =
            _dragPosition ?? _calculateRestingPosition(padding, insets, screenSize);
        final theme = widget.controller.config.theme;
        final bubbleColor = theme.bubbleColor ?? const Color(0xFF212121);
        final iconColor = theme.bubbleIconColor ?? Colors.white;
        final errorCount = widget.controller.errorCount;

        final semanticLabel = errorCount > 0
            ? 'Open debug dashboard, $errorCount errors'
            : 'Open debug dashboard';

        return Positioned(
          left: position.dx,
          top: position.dy,
          child: Semantics(
            button: true,
            label: semanticLabel,
            child: GestureDetector(
              onTap: widget.controller.openDashboard,
              onPanStart: _onPanStart,
              onPanUpdate: (d) => _onPanUpdate(d, padding, insets, screenSize),
              onPanEnd: (d) => _onPanEnd(d, padding, insets, screenSize),
              behavior: HitTestBehavior.opaque,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: _bubbleSize,
                    height: _bubbleSize,
                    decoration: BoxDecoration(
                      color: bubbleColor,
                      shape: BoxShape.circle,
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x40000000),
                          blurRadius: 8,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Icon(
                        Icons.bug_report,
                        color: iconColor,
                        size: 28,
                      ),
                    ),
                  ),
                  if (errorCount > 0)
                    Positioned(
                      right: -2,
                      top: -2,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 20,
                          minHeight: 20,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        child: Center(
                          child: Text(
                            errorCount > 99 ? '99+' : '$errorCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
