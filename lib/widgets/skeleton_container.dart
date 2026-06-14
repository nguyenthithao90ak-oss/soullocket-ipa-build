import 'package:flutter/material.dart';

class SkeletonContainer extends StatefulWidget {
  final double width;
  final double height;
  final BorderRadius borderRadius;
  final Color? baseColor;
  final Color? highlightColor;

  const SkeletonContainer({
    super.key,
    this.width = double.infinity,
    this.height = double.infinity,
    this.borderRadius = const BorderRadius.all(Radius.circular(8)),
    this.baseColor,
    this.highlightColor,
  });

  const SkeletonContainer.square({
    super.key,
    required double size,
    this.borderRadius = const BorderRadius.all(Radius.circular(8)),
    this.baseColor,
    this.highlightColor,
  })  : width = size,
        height = size;

  const SkeletonContainer.rounded({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
    this.baseColor,
    this.highlightColor,
  });

  const SkeletonContainer.circle({
    super.key,
    required double size,
    this.baseColor,
    this.highlightColor,
  })  : width = size,
        height = size,
        borderRadius = const BorderRadius.all(Radius.circular(1000));

  @override
  State<SkeletonContainer> createState() => _SkeletonContainerState();
}

class _SkeletonContainerState extends State<SkeletonContainer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Color?> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    
    _initAnimation();
  }

  void _initAnimation() {
    _animation = ColorTween(
      begin: widget.baseColor ?? const Color(0xFFF2F3F5),
      end: widget.highlightColor ?? const Color(0xFFE2E4E8),
    ).animate(_controller);
  }

  @override
  void didUpdateWidget(SkeletonContainer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.baseColor != oldWidget.baseColor || 
        widget.highlightColor != oldWidget.highlightColor) {
      _initAnimation();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: _animation.value,
            borderRadius: widget.borderRadius,
          ),
        );
      },
    );
  }
}
