import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Lớp trang trí Canvas cho thẻ Tâm sự. Lớp này chỉ vẽ, không nhận thao tác.
class DiaryPostCanvasDecor extends StatelessWidget {
  final Color accent;
  final String mood;
  final bool isMine;
  final bool pinned;

  const DiaryPostCanvasDecor({
    super.key,
    required this.accent,
    required this.mood,
    required this.isMine,
    required this.pinned,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return IgnorePointer(
      child: ExcludeSemantics(
        child: RepaintBoundary(
          child: CustomPaint(
            painter: DiaryPostCanvasPainter(
              accent: accent,
              mood: mood,
              isMine: isMine,
              pinned: pinned,
              dark: dark,
            ),
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
  }
}

/// Nền giấy kẻ nhẹ cho phần nội dung của một bài viết.
class DiaryPostPaperSurface extends StatelessWidget {
  final Widget child;
  final Color accent;
  final double lineSpacing;

  const DiaryPostPaperSurface({
    super.key,
    required this.child,
    required this.accent,
    this.lineSpacing = 24,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return CustomPaint(
      painter: DiaryPostPaperPainter(
        accent: accent,
        dark: dark,
        lineSpacing: lineSpacing,
      ),
      child: child,
    );
  }
}

/// Khung sticker nhỏ cho mood, có đường viền vẽ tay và băng dính góc.
class DiaryPostMoodFrame extends StatelessWidget {
  final Color accent;
  final Widget child;

  const DiaryPostMoodFrame({
    super.key,
    required this.accent,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return CustomPaint(
      painter: DiaryPostMoodFramePainter(accent: accent, dark: dark),
      child: Padding(padding: const EdgeInsets.all(10), child: child),
    );
  }
}

class DiaryPostMoodFramePainter extends CustomPainter {
  final Color accent;
  final bool dark;

  const DiaryPostMoodFramePainter({required this.accent, required this.dark});

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final rect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(20),
    );
    final fill = dark
        ? const Color(0xFF4A3E4B).withValues(alpha: 0.80)
        : accent.withValues(alpha: 0.10);
    canvas.drawRRect(rect, Paint()..color = fill);
    canvas.drawRRect(
      rect,
      _stroke(accent.withValues(alpha: dark ? 0.54 : 0.30), 1.2),
    );
    canvas.drawLine(
      const Offset(12, 8),
      Offset(size.width - 12, 8),
      _stroke(accent.withValues(alpha: dark ? 0.42 : 0.22), 1),
    );
    canvas.drawLine(
      Offset(12, size.height - 8),
      Offset(size.width - 12, size.height - 8),
      _stroke(accent.withValues(alpha: dark ? 0.42 : 0.22), 1),
    );
    _sparkle(
      canvas,
      Offset(size.width - 11, 14),
      3,
      accent.withValues(alpha: 0.60),
    );
    _tape(
      canvas,
      Offset(size.width * 0.46, 1),
      accent.withValues(alpha: dark ? 0.35 : 0.23),
      32,
      8,
      -0.08,
    );
  }

  @override
  bool shouldRepaint(DiaryPostMoodFramePainter oldDelegate) =>
      accent != oldDelegate.accent || dark != oldDelegate.dark;
}

class DiaryPostCanvasPainter extends CustomPainter {
  final Color accent;
  final String mood;
  final bool isMine;
  final bool pinned;
  final bool dark;

  const DiaryPostCanvasPainter({
    required this.accent,
    required this.mood,
    required this.isMine,
    required this.pinned,
    required this.dark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final border = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(28),
    );
    final ink = dark ? Colors.white : const Color(0xFF6B5261);
    final tape = Color.alphaBlend(
      accent.withValues(alpha: dark ? 0.30 : 0.18),
      dark ? const Color(0xFF443443) : const Color(0xFFFFF7FA),
    );

    canvas.save();
    canvas.clipRRect(border);

    // Mép giấy chấm bi tạo cảm giác scrapbook nhưng tránh vùng chữ.
    for (var y = 20.0; y < size.height - 18; y += 18) {
      canvas.drawCircle(
        Offset(8, y),
        1.15,
        Paint()..color = accent.withValues(alpha: dark ? 0.38 : 0.20),
      );
      canvas.drawCircle(
        Offset(size.width - 8, y + 6),
        1.15,
        Paint()..color = accent.withValues(alpha: dark ? 0.30 : 0.16),
      );
    }
    canvas.drawLine(
      const Offset(14, 42),
      Offset(14, size.height - 35),
      _stroke(accent.withValues(alpha: dark ? 0.22 : 0.11), 0.8),
    );

    _tape(canvas, Offset(size.width * 0.16, 0), tape, 52, 9, -0.04);
    _tape(
      canvas,
      Offset(size.width * 0.72, 0),
      tape.withValues(alpha: 0.78),
      42,
      8,
      0.05,
    );

    // Quầng màu phía trên phải và các tia vẽ tay.
    final glowCenter = Offset(size.width - 19, 14);
    canvas.drawCircle(
      glowCenter,
      58,
      Paint()..color = accent.withValues(alpha: dark ? 0.10 : 0.07),
    );
    for (var i = 0; i < 5; i++) {
      final angle = -1.05 + i * 0.48;
      final from = glowCenter + Offset(math.cos(angle), math.sin(angle)) * 43;
      final to = glowCenter + Offset(math.cos(angle), math.sin(angle)) * 51;
      canvas.drawLine(from, to, _stroke(accent.withValues(alpha: 0.25), 1));
    }

    // Tem nằm trong mép dưới đã chừa riêng, không bị nút xóa che mất.
    _postageStamp(
      canvas,
      Offset(size.width - 70, size.height - 36),
      accent,
      dark,
    );
    _sprig(canvas, Offset(18, size.height - 14), -0.22, accent);
    _flower(
      canvas,
      Offset(31, size.height - 20),
      6,
      accent.withValues(alpha: dark ? 0.85 : 0.62),
    );
    _ribbon(canvas, Offset(size.width - 19, size.height - 16), accent, dark);

    final moodCenter = Offset(size.width - 19, size.height - 63);
    if (mood == '🌙') {
      _moon(canvas, moodCenter, accent, dark);
    } else if (mood == '⭐' || mood == '🤩') {
      _star(canvas, moodCenter, 8, accent.withValues(alpha: 0.7));
    } else {
      _heart(canvas, moodCenter, 6, accent.withValues(alpha: 0.55));
    }
    _sparkle(
      canvas,
      Offset(size.width - 47, size.height - 43),
      3,
      ink.withValues(alpha: 0.32),
    );

    if (pinned) {
      _pin(canvas, Offset(size.width * 0.60, 17), accent, dark);
    }
    _tinyPostmark(
      canvas,
      Offset(size.width - 87, size.height - 23),
      ink.withValues(alpha: dark ? 0.24 : 0.18),
    );
    if (!isMine) {
      _heart(canvas, const Offset(19, 63), 3.5, accent.withValues(alpha: 0.42));
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(DiaryPostCanvasPainter oldDelegate) =>
      accent != oldDelegate.accent ||
      mood != oldDelegate.mood ||
      isMine != oldDelegate.isMine ||
      pinned != oldDelegate.pinned ||
      dark != oldDelegate.dark;
}

class DiaryPostPaperPainter extends CustomPainter {
  final Color accent;
  final bool dark;
  final double lineSpacing;

  const DiaryPostPaperPainter({
    required this.accent,
    required this.dark,
    required this.lineSpacing,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final paper = dark ? const Color(0xFF403540) : const Color(0xFFFFFEFC);
    final line = accent.withValues(alpha: dark ? 0.16 : 0.11);
    final rect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(21),
    );
    canvas.drawRRect(rect, Paint()..color = paper.withValues(alpha: 0.86));
    canvas.drawRRect(
      rect,
      _stroke(accent.withValues(alpha: dark ? 0.20 : 0.12), 1),
    );

    final spacing = lineSpacing.isFinite && lineSpacing > 0
        ? math.max(12.0, lineSpacing)
        : 24.0;
    for (var y = spacing; y < size.height - 15; y += spacing) {
      canvas.drawLine(
        Offset(17, y),
        Offset(size.width - 17, y),
        _stroke(line, 0.75),
      );
    }
    canvas.drawLine(
      const Offset(15, 14),
      Offset(15, size.height - 15),
      _stroke(accent.withValues(alpha: dark ? 0.18 : 0.10), 0.8),
    );

    final fold = Path()
      ..moveTo(size.width - 38, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, 38)
      ..quadraticBezierTo(size.width - 38, 38, size.width - 38, 0)
      ..close();
    canvas.drawPath(
      fold,
      Paint()..color = accent.withValues(alpha: dark ? 0.10 : 0.08),
    );
    canvas.drawPath(
      Path()
        ..moveTo(size.width - 38, 0)
        ..lineTo(size.width - 38, 25)
        ..quadraticBezierTo(size.width - 38, 31, size.width - 32, 31)
        ..lineTo(size.width, 31),
      _stroke(accent.withValues(alpha: dark ? 0.22 : 0.15), 0.8),
    );
    _miniFlower(canvas, Offset(24, size.height - 17), accent, dark);
  }

  @override
  bool shouldRepaint(DiaryPostPaperPainter oldDelegate) =>
      accent != oldDelegate.accent ||
      dark != oldDelegate.dark ||
      lineSpacing != oldDelegate.lineSpacing;
}

void _tape(
  Canvas canvas,
  Offset origin,
  Color color,
  double width,
  double height,
  double angle,
) {
  canvas.save();
  canvas.translate(origin.dx, origin.dy);
  canvas.rotate(angle);
  final rect = RRect.fromRectAndRadius(
    Rect.fromLTWH(-width / 2, 0, width, height),
    const Radius.circular(3),
  );
  canvas.drawRRect(rect, Paint()..color = color);
  for (var x = -width / 2 + 6; x < width / 2; x += 9) {
    canvas.drawLine(
      Offset(x, 0),
      Offset(x - 5, height),
      _stroke(color.withValues(alpha: 0.42), 1.6),
    );
  }
  canvas.restore();
}

void _postageStamp(Canvas canvas, Offset origin, Color accent, bool dark) {
  final rect = RRect.fromRectAndRadius(
    Rect.fromLTWH(origin.dx, origin.dy, 31, 27),
    const Radius.circular(5),
  );
  canvas.drawRRect(
    rect,
    Paint()..color = Colors.white.withValues(alpha: dark ? 0.12 : 0.70),
  );
  canvas.drawRRect(rect, _stroke(accent.withValues(alpha: 0.30), 0.8));
  _heart(
    canvas,
    origin + const Offset(15.5, 13),
    4,
    accent.withValues(alpha: 0.68),
  );
  canvas.drawCircle(
    origin + const Offset(5, 5),
    1,
    Paint()..color = accent.withValues(alpha: 0.45),
  );
  canvas.drawCircle(
    origin + const Offset(26, 21),
    1,
    Paint()..color = accent.withValues(alpha: 0.45),
  );
}

void _ribbon(Canvas canvas, Offset origin, Color accent, bool dark) {
  final paint = Paint()..color = accent.withValues(alpha: dark ? 0.30 : 0.18);
  canvas.drawPath(
    Path()
      ..moveTo(origin.dx - 16, origin.dy)
      ..lineTo(origin.dx + 13, origin.dy)
      ..lineTo(origin.dx + 8, origin.dy + 11)
      ..lineTo(origin.dx - 5, origin.dy + 8)
      ..lineTo(origin.dx - 16, origin.dy + 14)
      ..close(),
    paint,
  );
  canvas.drawLine(
    Offset(origin.dx - 4, origin.dy + 2),
    Offset(origin.dx - 7, origin.dy + 12),
    _stroke(accent.withValues(alpha: 0.35), 1),
  );
}

void _pin(Canvas canvas, Offset center, Color accent, bool dark) {
  canvas.drawCircle(
    center,
    4.5,
    Paint()..color = accent.withValues(alpha: dark ? 0.45 : 0.30),
  );
  canvas.drawLine(
    center + const Offset(0, 4),
    center + const Offset(0, 13),
    _stroke(accent.withValues(alpha: 0.48), 1.4),
  );
  canvas.drawLine(
    center + const Offset(-5, 8),
    center + const Offset(5, 8),
    _stroke(accent.withValues(alpha: 0.48), 1.2),
  );
}

void _tinyPostmark(Canvas canvas, Offset center, Color color) {
  canvas.drawArc(
    Rect.fromCenter(center: center, width: 18, height: 12),
    -0.8,
    1.9,
    false,
    _stroke(color, 0.9),
  );
  canvas.drawLine(
    center + const Offset(-8, 5),
    center + const Offset(7, 5),
    _stroke(color, 0.8),
  );
}

void _miniFlower(Canvas canvas, Offset center, Color accent, bool dark) {
  _flower(canvas, center, 5, accent.withValues(alpha: dark ? 0.75 : 0.55));
  canvas.drawLine(
    center + const Offset(-1, 3),
    center + const Offset(-6, 14),
    _stroke(const Color(0xFF8DAE91).withValues(alpha: dark ? 0.72 : 0.62), 1),
  );
}

void _sprig(Canvas canvas, Offset origin, double angle, Color accent) {
  canvas.save();
  canvas.translate(origin.dx, origin.dy);
  canvas.rotate(angle);
  const leaf = Color(0xFF9DB7A0);
  canvas.drawPath(
    Path()
      ..moveTo(0, 0)
      ..quadraticBezierTo(-2, -11, 2, -25),
    _stroke(leaf.withValues(alpha: 0.74), 1.15),
  );
  for (var i = 0; i < 3; i++) {
    final y = -5.0 - i * 7;
    canvas.drawPath(
      Path()
        ..moveTo(0, y)
        ..quadraticBezierTo(-11, y - 8, -3, y - 10)
        ..quadraticBezierTo(0, y - 7, 0, y)
        ..close(),
      Paint()..color = leaf.withValues(alpha: 0.78),
    );
    canvas.drawPath(
      Path()
        ..moveTo(0, y - 3)
        ..quadraticBezierTo(11, y - 8, 7, y - 12)
        ..quadraticBezierTo(1, y - 10, 0, y - 3)
        ..close(),
      Paint()..color = leaf.withValues(alpha: 0.48),
    );
  }
  _sparkle(canvas, const Offset(10, -25), 3, accent.withValues(alpha: 0.42));
  canvas.restore();
}

void _flower(Canvas canvas, Offset center, double radius, Color color) {
  for (var i = 0; i < 6; i++) {
    final angle = i * math.pi / 3;
    final petal =
        center + Offset(math.cos(angle), math.sin(angle)) * radius * 0.57;
    canvas.drawCircle(petal, radius * 0.42, Paint()..color = color);
  }
  canvas.drawCircle(
    center,
    radius * 0.25,
    Paint()..color = const Color(0xFFFFE6A9),
  );
}

void _heart(Canvas canvas, Offset center, double radius, Color color) {
  canvas.save();
  canvas.translate(center.dx, center.dy);
  canvas.scale(radius / 10);
  canvas.drawPath(
    Path()
      ..moveTo(0, 9)
      ..cubicTo(-20, -3, -8, -15, 0, -6)
      ..cubicTo(8, -15, 20, -3, 0, 9)
      ..close(),
    Paint()..color = color,
  );
  canvas.restore();
}

void _moon(Canvas canvas, Offset center, Color accent, bool dark) {
  final moon = Paint()..color = accent.withValues(alpha: dark ? 0.55 : 0.46);
  canvas.drawCircle(center, 9, moon);
  canvas.drawCircle(
    center + const Offset(4, -3),
    9,
    Paint()..color = dark ? const Color(0xFF403540) : const Color(0xFFFFF9FC),
  );
}

void _star(Canvas canvas, Offset center, double radius, Color color) {
  final path = Path();
  for (var i = 0; i < 10; i++) {
    final angle = -math.pi / 2 + i * math.pi / 5;
    final r = i.isEven ? radius : radius * 0.42;
    final point = center + Offset(math.cos(angle), math.sin(angle)) * r;
    if (i == 0) {
      path.moveTo(point.dx, point.dy);
    } else {
      path.lineTo(point.dx, point.dy);
    }
  }
  path.close();
  canvas.drawPath(path, Paint()..color = color);
}

void _sparkle(Canvas canvas, Offset center, double radius, Color color) {
  final path = Path()
    ..moveTo(center.dx, center.dy - radius)
    ..quadraticBezierTo(
      center.dx + 1,
      center.dy - 1,
      center.dx + radius,
      center.dy,
    )
    ..quadraticBezierTo(
      center.dx + 1,
      center.dy + 1,
      center.dx,
      center.dy + radius,
    )
    ..quadraticBezierTo(
      center.dx - 1,
      center.dy + 1,
      center.dx - radius,
      center.dy,
    )
    ..quadraticBezierTo(
      center.dx - 1,
      center.dy - 1,
      center.dx,
      center.dy - radius,
    )
    ..close();
  canvas.drawPath(path, Paint()..color = color);
}

Paint _stroke(Color color, double width) => Paint()
  ..color = color
  ..style = PaintingStyle.stroke
  ..strokeCap = StrokeCap.round
  ..strokeJoin = StrokeJoin.round
  ..strokeWidth = width;
