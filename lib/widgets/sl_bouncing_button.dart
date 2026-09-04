import 'package:flutter/material.dart';

class SLBouncingButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double scaleFactor;
  final Duration duration;
  final HitTestBehavior behavior;

  const SLBouncingButton({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.scaleFactor = 0.95,
    this.duration = const Duration(milliseconds: 150),
    this.behavior = HitTestBehavior.opaque,
  });

  @override
  State<SLBouncingButton> createState() => _SLBouncingButtonState();
}

class _SLBouncingButtonState extends State<SLBouncingButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _scaleAnimation = Tween<double>(begin: 1.0, end: widget.scaleFactor)
        .animate(
          CurvedAnimation(
            parent: _controller,
            curve: Curves.easeInOutCubic,
            reverseCurve: Curves.easeOutCubic,
          ),
        );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onPointerDown(PointerDownEvent event) {
    if (widget.onTap != null || widget.onLongPress != null) {
      _controller.forward();
    } else {
      _controller.forward();
    }
  }

  void _onPointerUp(PointerUpEvent event) {
    if (widget.onTap != null || widget.onLongPress != null) {
      _controller.reverse();
      widget.onTap?.call();
    } else {
      _controller.reverse();
    }
  }

  void _onPointerCancel(PointerCancelEvent event) {
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final scaleWidget = ScaleTransition(
      scale: _scaleAnimation,
      child: widget.child,
    );

    if (widget.onTap != null || widget.onLongPress != null) {
      return Semantics(
        button: true,
        enabled: true,
        child: GestureDetector(
          behavior: widget.behavior,
          onTapDown: (_) => _controller.forward(),
          onTapUp: (_) {
            _controller.reverse();
            widget.onTap?.call();
          },
          onTapCancel: () => _controller.reverse(),
          onLongPress: widget.onLongPress,
          child: scaleWidget,
        ),
      );
    }

    return Listener(
      behavior: widget.behavior,
      onPointerDown: _onPointerDown,
      onPointerUp: _onPointerUp,
      onPointerCancel: _onPointerCancel,
      child: scaleWidget,
    );
  }
}
