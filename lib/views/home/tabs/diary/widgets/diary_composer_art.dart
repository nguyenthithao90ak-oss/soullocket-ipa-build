import 'dart:math' as math;

import 'package:flutter/material.dart';

@immutable
class DiaryComposerPalette {
  final Color surface;
  final Color surfaceEnd;
  final Color paper;
  final Color ink;
  final Color muted;
  final Color rose;
  final Color lilac;
  final Color line;

  const DiaryComposerPalette({
    required this.surface,
    required this.surfaceEnd,
    required this.paper,
    required this.ink,
    required this.muted,
    required this.rose,
    required this.lilac,
    required this.line,
  });

  static const light = DiaryComposerPalette(
    surface: Color(0xFFFFF9F3),
    surfaceEnd: Color(0xFFFFEFF5),
    paper: Color(0xFFFFFEFA),
    ink: Color(0xFF594452),
    muted: Color(0xFF876C7D),
    rose: Color(0xFFB65C86),
    lilac: Color(0xFF8873BD),
    line: Color(0xFFEBD4D8),
  );

  static const dark = DiaryComposerPalette(
    surface: Color(0xFF302831),
    surfaceEnd: Color(0xFF382B3B),
    paper: Color(0xFF3D333C),
    ink: Color(0xFFFFE9EF),
    muted: Color(0xFFD3B6C7),
    rose: Color(0xFFFFABCC),
    lilac: Color(0xFFCAAFE9),
    line: Color(0xFF65505F),
  );

  static DiaryComposerPalette of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;
}

// Chỉ vẽ trang trí: không có timer, listener hay vùng chạm che lên nội dung.
class DiaryComposerCover extends StatelessWidget {
  const DiaryComposerCover({super.key});

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: ExcludeSemantics(
      child: RepaintBoundary(
        child: CustomPaint(
          painter: DiaryCoverPainter(DiaryComposerPalette.of(context)),
          size: const Size(136, 112),
        ),
      ),
    ),
  );
}

class DiaryCoverPainter extends CustomPainter {
  final DiaryComposerPalette palette;
  const DiaryCoverPainter(this.palette);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 136, size.height / 112);
    canvas.drawOval(
      const Rect.fromLTWH(7, 16, 124, 88),
      Paint()..color = palette.rose.withValues(alpha: 0.10),
    );
    canvas.drawOval(
      const Rect.fromLTWH(17, 88, 108, 12),
      Paint()..color = palette.rose.withValues(alpha: 0.12),
    );
    _flower(canvas, const Offset(13, 72), 7, const Color(0xFFE9ACC8));
    _flower(canvas, const Offset(121, 39), 6, const Color(0xFFD1C0EB));
    _flower(canvas, const Offset(115, 91), 8, const Color(0xFFF0C48F));
    _sparkle(canvas, const Offset(19, 30), 5, palette.lilac);
    _sparkle(canvas, const Offset(122, 67), 4, palette.rose);
    _heart(canvas, const Offset(65, 15), 6, palette.rose);
    _heart(canvas, const Offset(102, 12), 4, const Color(0xFFE8A6BB));

    // Hai bé tựa vào lá thư; tai, má và bàn tay được vẽ riêng.
    _friend(canvas, const Offset(40, 51), bunny: false);
    _friend(canvas, const Offset(92, 46), bunny: true);
    canvas.save();
    canvas.translate(37, 69);
    canvas.rotate(-0.09);
    final letter = RRect.fromRectAndRadius(
      const Rect.fromLTWH(0, 0, 60, 31),
      const Radius.circular(5),
    );
    canvas.drawRRect(
      letter.shift(const Offset(0, 2)),
      Paint()..color = const Color(0xFFE4BBC4),
    );
    canvas.drawRRect(letter, Paint()..color = const Color(0xFFFFF7E6));
    canvas.drawRRect(letter, _stroke(const Color(0xFFC99C9A), 1.2));
    canvas.drawPath(
      Path()
        ..moveTo(2, 3)
        ..lineTo(30, 21)
        ..lineTo(58, 3),
      _stroke(const Color(0xFFE2BEAB), 1.3),
    );
    canvas.drawPath(
      Path()
        ..moveTo(2, 29)
        ..lineTo(21, 17)
        ..moveTo(58, 29)
        ..lineTo(39, 17),
      _stroke(const Color(0xFFE2BEAB), 1),
    );
    _heart(canvas, const Offset(30, 16), 6, const Color(0xFFD4879F));
    canvas.restore();
    canvas.drawOval(
      const Rect.fromLTWH(31, 72, 12, 9),
      Paint()..color = const Color(0xFFDDB894),
    );
    canvas.drawOval(
      const Rect.fromLTWH(88, 69, 12, 9),
      Paint()..color = const Color(0xFFFFEEE0),
    );
    _sprig(canvas, const Offset(8, 96), 0.1);
    _sprig(canvas, const Offset(124, 100), -0.5);
    canvas.restore();
  }

  void _friend(Canvas canvas, Offset center, {required bool bunny}) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    final fur = bunny ? const Color(0xFFFFEEE0) : const Color(0xFFDDB894);
    final outline = bunny ? const Color(0xFFD5B5A2) : const Color(0xFFB18A71);
    final fill = Paint()..color = fur;
    if (bunny) {
      for (final x in [-11.0, 8.0]) {
        final ear = RRect.fromRectAndRadius(
          Rect.fromLTWH(x, -35, 11, 32),
          const Radius.circular(8),
        );
        canvas.drawRRect(ear, fill);
        canvas.drawRRect(ear, _stroke(outline, 1.2));
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x + 3, -30, 5, 20),
            const Radius.circular(4),
          ),
          Paint()..color = const Color(0xFFF0BCC9),
        );
      }
    } else {
      for (final x in [-16.0, 16.0]) {
        canvas.drawCircle(Offset(x, -13), 9, fill);
        canvas.drawCircle(Offset(x, -13), 9, _stroke(outline, 1.2));
        canvas.drawCircle(
          Offset(x, -13),
          4.5,
          Paint()..color = const Color(0xFFC69A80),
        );
      }
    }
    canvas.drawOval(const Rect.fromLTWH(-17, 15, 34, 31), fill);
    final face = RRect.fromRectAndRadius(
      const Rect.fromLTWH(-22, -20, 44, 41),
      const Radius.circular(20),
    );
    canvas.drawRRect(face, fill);
    canvas.drawRRect(face, _stroke(outline, 1.2));
    canvas.drawOval(
      const Rect.fromLTWH(-10, 1, 20, 14),
      Paint()..color = const Color(0xFFFFEBDD),
    );
    for (final x in [-8.0, 8.0]) {
      canvas.drawOval(
        Rect.fromCenter(center: Offset(x, -3), width: 3.2, height: 4.2),
        Paint()..color = const Color(0xFF68514B),
      );
      canvas.drawCircle(
        Offset(x - 0.5, -4),
        0.65,
        Paint()..color = Colors.white,
      );
      canvas.drawOval(
        Rect.fromCenter(center: Offset(x * 1.65, 5), width: 8, height: 4),
        Paint()..color = const Color(0xFFEAA5AE).withValues(alpha: 0.65),
      );
    }
    canvas.drawOval(
      const Rect.fromLTWH(-2.3, 2, 4.6, 3),
      Paint()..color = const Color(0xFF8B6262),
    );
    canvas.drawPath(
      Path()
        ..moveTo(0, 5)
        ..lineTo(0, 7)
        ..quadraticBezierTo(-3, 10, -5, 7)
        ..moveTo(0, 7)
        ..quadraticBezierTo(3, 10, 5, 7),
      _stroke(const Color(0xFF8B6262), 1),
    );
    if (bunny) {
      _flower(canvas, const Offset(18, -17), 5.5, const Color(0xFFE8A9C1));
    } else {
      canvas.drawPath(
        Path()
          ..moveTo(-7, 23)
          ..lineTo(0, 26)
          ..lineTo(-7, 30)
          ..close()
          ..moveTo(7, 23)
          ..lineTo(0, 26)
          ..lineTo(7, 30)
          ..close(),
        Paint()..color = const Color(0xFFB4A0D0),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(DiaryCoverPainter oldDelegate) =>
      palette != oldDelegate.palette;
}

class DiaryComposerFramePainter extends CustomPainter {
  final DiaryComposerPalette palette;
  const DiaryComposerFramePainter(this.palette);

  @override
  void paint(Canvas canvas, Size size) {
    final border = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(28),
    );
    canvas.save();
    canvas.clipRRect(border);
    // Chấm giấy chỉ nằm ở mép để không làm rối chữ và các nút.
    for (var y = 12.0; y < size.height; y += 17) {
      for (final x in [7.0, size.width - 7]) {
        canvas.drawCircle(
          Offset(x, y),
          1,
          Paint()..color = palette.rose.withValues(alpha: 0.18),
        );
      }
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.23, 0, 54, 9),
        const Radius.circular(3),
      ),
      Paint()..color = palette.rose.withValues(alpha: 0.17),
    );
    for (var x = size.width * 0.23 + 5; x < size.width * 0.23 + 53; x += 9) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x - 5, 9),
        _stroke(palette.rose.withValues(alpha: 0.14), 2),
      );
    }
    _flower(
      canvas,
      Offset(size.width - 13, size.height - 17),
      7,
      palette.lilac.withValues(alpha: 0.45),
    );
    _heart(
      canvas,
      Offset(12, size.height * 0.48),
      3,
      palette.rose.withValues(alpha: 0.35),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(DiaryComposerFramePainter oldDelegate) =>
      palette != oldDelegate.palette;
}

class DiaryMoodHaloPainter extends CustomPainter {
  final Color accent;
  final bool active;
  const DiaryMoodHaloPainter({required this.accent, required this.active});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide * 0.40;
    canvas.drawCircle(
      center,
      radius,
      Paint()..color = accent.withValues(alpha: active ? 0.15 : 0.08),
    );
    if (active) {
      canvas.drawCircle(
        center,
        radius + 3,
        _stroke(accent.withValues(alpha: 0.32), 1),
      );
    }
    _sparkle(
      canvas,
      Offset(size.width - 5, 8),
      4,
      accent.withValues(alpha: 0.65),
    );
    _heart(
      canvas,
      Offset(5, size.height - 9),
      3,
      accent.withValues(alpha: 0.55),
    );
    canvas.drawCircle(
      const Offset(9, 6),
      1.7,
      Paint()..color = accent.withValues(alpha: 0.55),
    );
    canvas.drawCircle(
      Offset(size.width - 5, size.height - 16),
      1.2,
      Paint()..color = accent.withValues(alpha: 0.45),
    );
  }

  @override
  bool shouldRepaint(DiaryMoodHaloPainter oldDelegate) =>
      accent != oldDelegate.accent || active != oldDelegate.active;
}

class DiaryLetterPaperPainter extends CustomPainter {
  final DiaryComposerPalette palette;
  final double lineHeight;
  final bool rtl;
  const DiaryLetterPaperPainter({
    required this.palette,
    required this.lineHeight,
    required this.rtl,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    if (rtl) {
      canvas.translate(size.width, 0);
      canvas.scale(-1, 1);
    }
    final ink = palette.line.withValues(alpha: 0.55);
    for (var y = 38.0; y < size.height - 36; y += lineHeight) {
      canvas.drawLine(
        Offset(18, y),
        Offset(size.width - 18, y),
        _stroke(ink, 0.65),
      );
    }
    canvas.drawLine(
      const Offset(14, 18),
      Offset(14, size.height - 34),
      _stroke(palette.rose.withValues(alpha: 0.15), 1),
    );
    canvas.drawPath(
      Path()
        ..moveTo(size.width - 25, 0)
        ..lineTo(size.width - 25, 19)
        ..quadraticBezierTo(size.width - 25, 25, size.width - 19, 25)
        ..lineTo(size.width, 25)
        ..close(),
      Paint()..color = palette.rose.withValues(alpha: 0.09),
    );
    _sprig(canvas, Offset(26, size.height - 6), 0.9);
    _flower(
      canvas,
      Offset(43, size.height - 16),
      5,
      palette.rose.withValues(alpha: 0.50),
    );
    _sparkle(
      canvas,
      Offset(59, size.height - 10),
      3,
      palette.lilac.withValues(alpha: 0.5),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(DiaryLetterPaperPainter oldDelegate) =>
      palette != oldDelegate.palette ||
      lineHeight != oldDelegate.lineHeight ||
      rtl != oldDelegate.rtl;
}

class DiarySubmitPainter extends CustomPainter {
  const DiarySubmitPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = _stroke(Colors.white.withValues(alpha: 0.12), 1);
    for (final x in [19.0, size.width - 19]) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(x, size.height / 2),
          width: 26,
          height: 46,
        ),
        paint,
      );
      _sparkle(canvas, Offset(x, 13), 3, Colors.white.withValues(alpha: 0.35));
      _heart(
        canvas,
        Offset(x, size.height - 14),
        3,
        Colors.white.withValues(alpha: 0.28),
      );
    }
  }

  @override
  bool shouldRepaint(DiarySubmitPainter oldDelegate) => false;
}

Paint _stroke(Color color, double width) => Paint()
  ..color = color
  ..style = PaintingStyle.stroke
  ..strokeCap = StrokeCap.round
  ..strokeJoin = StrokeJoin.round
  ..strokeWidth = width;

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

void _flower(Canvas canvas, Offset center, double radius, Color color) {
  for (var i = 0; i < 6; i++) {
    final angle = i * math.pi / 3;
    final petal =
        center + Offset(math.cos(angle), math.sin(angle)) * radius * 0.57;
    canvas.drawCircle(petal, radius * 0.44, Paint()..color = color);
  }
  canvas.drawCircle(
    center,
    radius * 0.25,
    Paint()..color = const Color(0xFFFFEDBF),
  );
  canvas.drawCircle(
    center + Offset(-radius * 0.07, -radius * 0.07),
    radius * 0.08,
    Paint()..color = Colors.white,
  );
}

void _sparkle(Canvas canvas, Offset center, double radius, Color color) {
  canvas.drawPath(
    Path()
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
      ..close(),
    Paint()..color = color,
  );
}

void _sprig(Canvas canvas, Offset origin, double angle) {
  canvas.save();
  canvas.translate(origin.dx, origin.dy);
  canvas.rotate(angle);
  const leaf = Color(0xFF9EBAA1);
  canvas.drawPath(
    Path()
      ..moveTo(0, 0)
      ..quadraticBezierTo(-3, -12, 1, -25),
    _stroke(leaf, 1.2),
  );
  for (var i = 0; i < 3; i++) {
    final y = -5.0 - i * 7;
    canvas.drawPath(
      Path()
        ..moveTo(0, y)
        ..quadraticBezierTo(-13, y - 8, -3, y - 10)
        ..quadraticBezierTo(0, y - 7, 0, y)
        ..close(),
      Paint()..color = leaf.withValues(alpha: 0.85),
    );
    canvas.drawPath(
      Path()
        ..moveTo(0, y - 3)
        ..quadraticBezierTo(12, y - 9, 7, y - 12)
        ..quadraticBezierTo(1, y - 10, 0, y - 3)
        ..close(),
      Paint()..color = leaf.withValues(alpha: 0.55),
    );
  }
  canvas.restore();
}
