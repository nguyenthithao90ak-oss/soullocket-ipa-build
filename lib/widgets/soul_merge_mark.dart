import 'package:flutter/material.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';

/// Hai vòng nối tạo thành trái tim, dùng chung cho các điểm vào Soul Merge.
class SoulMergeMark extends StatelessWidget {
  const SoulMergeMark({super.key, required this.size, this.framed = false});

  final double size;
  final bool framed;

  @override
  Widget build(BuildContext context) => Semantics(
    image: true,
    label: context.tr('p4_soul_title'),
    child: RepaintBoundary(
      child: SizedBox.square(
        dimension: size,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(size * .30),
            boxShadow: framed
                ? [
                    BoxShadow(
                      color: const Color(0xFF7D405E).withValues(alpha: .20),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: CustomPaint(painter: _SoulMergeMarkPainter(framed: framed)),
        ),
      ),
    ),
  );
}

class _SoulMergeMarkPainter extends CustomPainter {
  const _SoulMergeMarkPainter({required this.framed});
  final bool framed;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 100, size.height / 100);
    final tile = RRect.fromRectAndRadius(
      const Rect.fromLTWH(2, 2, 96, 96),
      const Radius.circular(29),
    );
    canvas.drawRRect(
      tile,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF573754), Color(0xFFB65C7A)],
        ).createShader(tile.outerRect),
    );
    if (framed) {
      canvas.drawRRect(
        tile,
        Paint()
          ..color = const Color(0xFFFFF9F5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5,
      );
    }
    final left = Path()
      ..moveTo(50, 72)
      ..cubicTo(39, 65, 22, 53, 22, 37)
      ..cubicTo(22, 20, 41, 18, 50, 33)
      ..cubicTo(63, 52, 60, 64, 50, 72);
    final right = Path()
      ..moveTo(50, 72)
      ..cubicTo(61, 65, 78, 53, 78, 37)
      ..cubicTo(78, 20, 59, 18, 50, 33)
      ..cubicTo(37, 52, 40, 64, 50, 72);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(right, stroke..color = const Color(0xFFF4B6C0));
    canvas.drawPath(left, stroke..color = const Color(0xFFFFF5EB));
    canvas.drawPath(
      Path()
        ..moveTo(50, 33)
        ..cubicTo(47, 37, 44, 43, 43, 47),
      stroke..color = const Color(0xFFF4B6C0),
    );
  }

  @override
  bool shouldRepaint(covariant _SoulMergeMarkPainter oldDelegate) =>
      framed != oldDelegate.framed;
}
