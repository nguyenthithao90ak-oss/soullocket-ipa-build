import 'package:flutter/material.dart';

class HeartbeatThreadWidget extends StatefulWidget {
  final bool isOnline;
  const HeartbeatThreadWidget({super.key, this.isOnline = true});

  @override
  State<HeartbeatThreadWidget> createState() => _HeartbeatThreadWidgetState();
}

class _HeartbeatThreadWidgetState extends State<HeartbeatThreadWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
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
        return CustomPaint(
          size: Size.infinite,
          painter: _HeartbeatThreadPainter(
            progress: _controller.value,
            isOnline: widget.isOnline,
          ),
        );
      },
    );
  }
}

class _HeartbeatThreadPainter extends CustomPainter {
  final double progress;
  final bool isOnline;

  _HeartbeatThreadPainter({
    required this.progress,
    required this.isOnline,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final start = Offset(size.width * 0.2, size.height * 0.5);
    final end = Offset(size.width * 0.8, size.height * 0.5);
    final controlPoint = Offset(size.width * 0.5, size.height * 0.2);

    final path = Path()
      ..moveTo(start.dx, start.dy)
      ..quadraticBezierTo(controlPoint.dx, controlPoint.dy, end.dx, end.dy);

    final basePaint = Paint()
      ..color = const Color(0xFFFF4D79).withValues(alpha: isOnline ? 0.6 : 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(path, basePaint);

    if (isOnline) {
      final t = progress;
      final x = (1 - t) * (1 - t) * start.dx +
          2 * (1 - t) * t * controlPoint.dx +
          t * t * end.dx;
      final y = (1 - t) * (1 - t) * start.dy +
          2 * (1 - t) * t * controlPoint.dy +
          t * t * end.dy;

      final glowPaint = Paint()
        ..color = const Color(0xFFFF8FB1)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

      canvas.drawCircle(Offset(x, y), 5.0, glowPaint);

      final corePaint = Paint()..color = Colors.white;
      canvas.drawCircle(Offset(x, y), 2.5, corePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _HeartbeatThreadPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.isOnline != isOnline;
  }
}
