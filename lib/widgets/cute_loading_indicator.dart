import 'dart:math';
import 'package:flutter/material.dart';

class CuteLoadingIndicator extends StatefulWidget {
  final double size;
  final Color color;

  const CuteLoadingIndicator({
    super.key,
    this.size = 40.0,
    this.color = const Color(0xFFFF3D8D),
  });

  @override
  State<CuteLoadingIndicator> createState() => _CuteLoadingIndicatorState();
}

class _CuteLoadingIndicatorState extends State<CuteLoadingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.rotate(
          angle: _controller.value * 2 * pi,
          child: SizedBox(
            width: widget.size,
            height: widget.size,
            child: Stack(
              children: List.generate(6, (index) {
                final angle = index * (2 * pi / 6);
                return Align(
                  alignment: Alignment(
                    cos(angle) * 0.65,
                    sin(angle) * 0.65,
                  ),
                  child: Transform.rotate(
                    angle: angle + pi / 2,
                    child: Icon(
                      Icons.favorite_rounded,
                      color: widget.color.withOpacity(1.0 - (index * 0.12)),
                      size: widget.size * 0.35,
                    ),
                  ),
                );
              }),
            ),
          ),
        );
      },
    );
  }
}
