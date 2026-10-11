import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Nhận diện riêng cho trò ghép ảnh nhật ký.
///
/// Đây là icon vector vẽ trực tiếp bằng Flutter để không phụ thuộc vào icon
/// chung của Soul Block hoặc một asset tải mạng. Bốn màu mảnh ghép cũng giúp
/// người chơi nhận ra game ngay cả khi ảnh nhật ký đang tải/chưa có cache.
class MemoryPuzzleBrandMark extends StatelessWidget {
  const MemoryPuzzleBrandMark({super.key, this.size = 48, this.semanticLabel});

  final double size;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final mark = SizedBox.square(
      dimension: size,
      child: const CustomPaint(painter: MemoryPuzzleBrandPainter()),
    );
    if (semanticLabel == null || semanticLabel!.isEmpty) {
      return ExcludeSemantics(child: mark);
    }
    return Semantics(image: true, label: semanticLabel, child: mark);
  }
}

class MemoryPuzzleBrandPainter extends CustomPainter {
  const MemoryPuzzleBrandPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final side = size.shortestSide;
    if (side <= 0) return;

    final bounds = Offset.zero & size;
    final radius = side * .25;
    final outer = RRect.fromRectAndRadius(
      bounds.deflate(side * .035),
      Radius.circular(radius),
    );
    final outerPath = Path()..addRRect(outer);
    canvas.drawShadow(
      outerPath,
      Colors.black.withValues(alpha: .28),
      side * .1,
      true,
    );
    canvas.drawRRect(
      outer,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF29253E), Color(0xFF171C31)],
        ).createShader(bounds),
    );

    final inner = bounds.deflate(side * .19);
    final gap = side * .018;
    final cellWidth = (inner.width - gap) / 2;
    final cellHeight = (inner.height - gap) / 2;
    final cells = <_BrandPiece>[
      _BrandPiece(
        Rect.fromLTWH(inner.left, inner.top, cellWidth, cellHeight),
        const Color(0xFFFF8B7B),
        top: 0,
        right: 1,
        bottom: 1,
        left: 0,
      ),
      _BrandPiece(
        Rect.fromLTWH(
          inner.left + cellWidth + gap,
          inner.top,
          cellWidth,
          cellHeight,
        ),
        const Color(0xFF59C6B4),
        top: 0,
        right: 0,
        bottom: -1,
        left: -1,
      ),
      _BrandPiece(
        Rect.fromLTWH(
          inner.left,
          inner.top + cellHeight + gap,
          cellWidth,
          cellHeight,
        ),
        const Color(0xFFFFD166),
        top: -1,
        right: -1,
        bottom: 0,
        left: 0,
      ),
      _BrandPiece(
        Rect.fromLTWH(
          inner.left + cellWidth + gap,
          inner.top + cellHeight + gap,
          cellWidth,
          cellHeight,
        ),
        const Color(0xFF8B7CFF),
        top: 1,
        right: 0,
        bottom: 0,
        left: 1,
      ),
    ];
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1, side * .025)
      ..color = Colors.white.withValues(alpha: .64);
    for (final piece in cells) {
      final path = _piecePath(
        piece.rect,
        piece.top,
        piece.right,
        piece.bottom,
        piece.left,
      );
      canvas.drawPath(path, Paint()..color = piece.color);
      canvas.drawPath(path, stroke);
    }

    // Một tia sáng nhỏ tạo điểm nhận diện nhưng không lấn át ảnh/mảnh ghép.
    final sparkle = Path();
    final center = Offset(bounds.right - side * .2, bounds.top + side * .2);
    final outerRadius = side * .095;
    final innerRadius = outerRadius * .3;
    for (var i = 0; i < 8; i++) {
      final angle = -math.pi / 2 + i * math.pi / 4;
      final radiusForPoint = i.isEven ? outerRadius : innerRadius;
      final point =
          center + Offset(math.cos(angle), math.sin(angle)) * radiusForPoint;
      if (i == 0) {
        sparkle.moveTo(point.dx, point.dy);
      } else {
        sparkle.lineTo(point.dx, point.dy);
      }
    }
    sparkle.close();
    canvas.drawPath(
      sparkle,
      Paint()..color = Colors.white.withValues(alpha: .9),
    );
  }

  Path _piecePath(Rect rect, int top, int right, int bottom, int left) {
    final path = Path()..moveTo(rect.left, rect.top);

    void edge(Offset start, Offset end, int tab) {
      final delta = end - start;
      final length = delta.distance;
      final normal = Offset(delta.dy, -delta.dx) * (tab / length);
      Offset point(double t, double depth) =>
          start + delta * t + normal * (length * depth);
      final neck = point(.36, 0);
      path.lineTo(neck.dx, neck.dy);
      if (tab == 0) {
        path.lineTo(end.dx, end.dy);
        return;
      }
      final shoulder = point(.405, .06);
      final cheek = point(.38, .18);
      final crown = point(.5, .22);
      final otherCheek = point(.62, .18);
      final otherShoulder = point(.595, .06);
      path.cubicTo(
        shoulder.dx,
        shoulder.dy,
        cheek.dx,
        cheek.dy,
        crown.dx,
        crown.dy,
      );
      final otherNeck = point(.64, 0);
      path.cubicTo(
        otherCheek.dx,
        otherCheek.dy,
        otherShoulder.dx,
        otherShoulder.dy,
        otherNeck.dx,
        otherNeck.dy,
      );
      path.lineTo(end.dx, end.dy);
    }

    edge(rect.topLeft, rect.topRight, top);
    edge(rect.topRight, rect.bottomRight, right);
    edge(rect.bottomRight, rect.bottomLeft, bottom);
    edge(rect.bottomLeft, rect.topLeft, left);
    return path..close();
  }

  @override
  bool shouldRepaint(covariant MemoryPuzzleBrandPainter oldDelegate) => false;
}

class _BrandPiece {
  const _BrandPiece(
    this.rect,
    this.color, {
    required this.top,
    required this.right,
    required this.bottom,
    required this.left,
  });

  final Rect rect;
  final Color color;
  final int top, right, bottom, left;
}
