import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Lớp họa tiết nhẹ cho preview giao diện.
///
/// Painter này chỉ vẽ trang trí, không chứa state hay logic lưu lựa chọn.
/// Vì vậy preview vẫn an toàn khi rebuild theo từng thay đổi trong UiPrefs.
class ThemeCanvasAmbientPainter extends CustomPainter {
  const ThemeCanvasAmbientPainter({
    required this.themeKey,
    required this.effectKey,
    required this.accent,
    required this.isDark,
    this.reduced = false,
  });

  final String themeKey;
  final String effectKey;
  final Color accent;
  final bool isDark;
  final bool reduced;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || reduced) return;

    final shortest = math.min(size.width, size.height);
    final ambient = Paint()
      ..style = PaintingStyle.fill
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, shortest * .075);

    final topGlow = Color.lerp(accent, Colors.white, isDark ? .06 : .34)!;
    ambient.color = topGlow.withValues(alpha: isDark ? .20 : .25);
    canvas.drawCircle(
      Offset(size.width * .12, size.height * .12),
      shortest * .23,
      ambient,
    );

    final lowerGlow = _secondaryColor();
    ambient.color = lowerGlow.withValues(alpha: isDark ? .19 : .18);
    canvas.drawCircle(
      Offset(size.width * .91, size.height * .84),
      shortest * .25,
      ambient,
    );

    final orbit = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1, shortest * .006)
      ..color = Colors.white.withValues(alpha: isDark ? .16 : .28);
    final orbitRect = Rect.fromCircle(
      center: Offset(size.width * .12, size.height * .10),
      radius: shortest * .31,
    );
    canvas.drawArc(orbitRect, math.pi * .10, math.pi * .95, false, orbit);

    final lowerOrbitRect = Rect.fromCircle(
      center: Offset(size.width * .94, size.height * .88),
      radius: shortest * .35,
    );
    canvas.drawArc(lowerOrbitRect, math.pi * 1.08, math.pi * .72, false, orbit);

    final particle = Paint()..style = PaintingStyle.fill;
    final points = <Offset>[
      Offset(size.width * .08, size.height * .31),
      Offset(size.width * .19, size.height * .22),
      Offset(size.width * .86, size.height * .17),
      Offset(size.width * .93, size.height * .30),
      Offset(size.width * .08, size.height * .70),
      Offset(size.width * .90, size.height * .66),
      Offset(size.width * .78, size.height * .90),
    ];
    for (var i = 0; i < points.length; i++) {
      final radius = shortest * (i.isEven ? .012 : .008);
      particle.color = Colors.white.withValues(alpha: isDark ? .60 : .72);
      canvas.drawCircle(points[i], radius, particle);
    }

    if (effectKey == 'off') return;

    final effect = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = math.max(1, shortest * .007)
      ..color = Color.lerp(
        accent,
        Colors.white,
        isDark ? .22 : .08,
      )!.withValues(alpha: isDark ? .55 : .42);

    if (effectKey == 'hearts') {
      _drawHeart(
        canvas,
        Offset(size.width * .16, size.height * .39),
        shortest * .035,
        effect,
      );
      _drawHeart(
        canvas,
        Offset(size.width * .84, size.height * .43),
        shortest * .027,
        effect,
      );
      _drawHeart(
        canvas,
        Offset(size.width * .20, size.height * .78),
        shortest * .022,
        effect,
      );
      return;
    }

    if (effectKey == 'bubbles') {
      for (final item in <(double, double, double)>[
        (.13, .45, .035),
        (.86, .53, .026),
        (.20, .84, .018),
      ]) {
        canvas.drawCircle(
          Offset(size.width * item.$1, size.height * item.$2),
          shortest * item.$3,
          effect,
        );
      }
      return;
    }

    if (effectKey == 'leaves') {
      _drawLeaf(
        canvas,
        Offset(size.width * .16, size.height * .42),
        shortest * .05,
        effect,
      );
      _drawLeaf(
        canvas,
        Offset(size.width * .86, size.height * .62),
        shortest * .035,
        effect,
      );
      return;
    }

    // Sao, tuyết, tia sáng và hiệu ứng tự động dùng cùng một nhịp chấm
    // tối giản để preview không bị rối khi nội dung chính đổi.
    for (final item in <(double, double, double)>[
      (.14, .43, .030),
      (.86, .39, .024),
      (.12, .62, .018),
      (.88, .75, .032),
    ]) {
      final center = Offset(size.width * item.$1, size.height * item.$2);
      final radius = shortest * item.$3;
      canvas.drawLine(
        center - Offset(radius, 0),
        center + Offset(radius, 0),
        effect,
      );
      canvas.drawLine(
        center - Offset(0, radius),
        center + Offset(0, radius),
        effect,
      );
    }
  }

  Color _secondaryColor() {
    switch (themeKey) {
      case 'theme-ocean':
        return const Color(0xFF4DD0E1);
      case 'theme-sunset':
        return const Color(0xFFFFAB91);
      case 'theme-night':
      case 'theme-dark':
      case 'theme-mystic-dark':
        return const Color(0xFF8E9BFF);
      default:
        return const Color(0xFFFF9CC0);
    }
  }

  void _drawHeart(Canvas canvas, Offset center, double size, Paint paint) {
    final path = Path()
      ..moveTo(center.dx, center.dy + size * .85)
      ..cubicTo(
        center.dx - size * 1.5,
        center.dy - size * .10,
        center.dx - size * .82,
        center.dy - size * 1.15,
        center.dx,
        center.dy - size * .42,
      )
      ..cubicTo(
        center.dx + size * .82,
        center.dy - size * 1.15,
        center.dx + size * 1.5,
        center.dy - size * .10,
        center.dx,
        center.dy + size * .85,
      );
    canvas.drawPath(path, paint);
  }

  void _drawLeaf(Canvas canvas, Offset center, double size, Paint paint) {
    final path = Path()
      ..moveTo(center.dx, center.dy + size)
      ..quadraticBezierTo(
        center.dx - size * 1.1,
        center.dy - size * .10,
        center.dx,
        center.dy - size,
      )
      ..quadraticBezierTo(
        center.dx + size * 1.1,
        center.dy - size * .10,
        center.dx,
        center.dy + size,
      );
    canvas.drawPath(path, paint);
    canvas.drawLine(
      Offset(center.dx, center.dy + size * .72),
      Offset(center.dx, center.dy - size * .72),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant ThemeCanvasAmbientPainter oldDelegate) {
    return oldDelegate.themeKey != themeKey ||
        oldDelegate.effectKey != effectKey ||
        oldDelegate.accent != accent ||
        oldDelegate.isDark != isDark ||
        oldDelegate.reduced != reduced;
  }
}

enum AppearanceArtKind {
  palette,
  frames,
  typography,
  calendar,
  performance,
  music,
}

/// Hình vẽ riêng cho từng nhóm, giữ toàn bộ chữ và vùng chạm ở lớp widget.
class AppearanceArtworkPainter extends CustomPainter {
  const AppearanceArtworkPainter({
    required this.kind,
    required this.accent,
    required this.isDark,
  });

  final AppearanceArtKind kind;
  final Color accent;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    canvas.save();
    canvas.scale(size.width / 88, size.height / 76);
    final paper = isDark ? const Color(0xFF403341) : const Color(0xFFFFFCF7);
    final ink = Color.lerp(accent, paper, .15)!;
    final fill = Paint()..color = paper;
    final line = Paint()
      ..color = ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.1
      ..strokeCap = StrokeCap.round;

    void card(Rect rect, {double radius = 10, Color? color}) {
      fill.color = color ?? paper;
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(radius)),
        fill,
      );
    }

    switch (kind) {
      case AppearanceArtKind.palette:
        for (var i = 0; i < 4; i++) {
          canvas.save();
          canvas.translate(42, 60);
          canvas.rotate((i - 1.5) * .30);
          card(
            const Rect.fromLTWH(-13, -50, 26, 52),
            radius: 7,
            color: Color.lerp(accent, paper, .15 + i * .18),
          );
          fill.color = paper.withValues(alpha: .70);
          canvas.drawCircle(const Offset(0, -38), 4, fill);
          canvas.restore();
        }
        fill.color = paper;
        canvas.drawCircle(const Offset(42, 58), 4, fill);
      case AppearanceArtKind.frames:
        canvas.save();
        canvas.translate(17, 14);
        canvas.rotate(-.12);
        card(
          const Rect.fromLTWH(0, 0, 42, 48),
          color: ink.withValues(alpha: .30),
        );
        canvas.restore();
        canvas.save();
        canvas.translate(31, 13);
        canvas.rotate(.12);
        card(const Rect.fromLTWH(0, 0, 42, 50));
        fill.color = ink.withValues(alpha: .18);
        canvas.drawCircle(const Offset(21, 20), 13, fill);
        canvas.drawCircle(const Offset(21, 17), 5, line);
        canvas.drawArc(
          const Rect.fromLTWH(12, 22, 18, 15),
          math.pi,
          math.pi,
          false,
          line,
        );
        canvas.drawLine(const Offset(12, 42), const Offset(30, 42), line);
        canvas.restore();
      case AppearanceArtKind.typography:
        card(
          const Rect.fromLTWH(14, 9, 61, 57),
          color: ink.withValues(alpha: .12),
        );
        card(const Rect.fromLTWH(9, 5, 61, 57));
        final letter = Path()
          ..moveTo(22, 44)
          ..lineTo(34, 16)
          ..lineTo(46, 44)
          ..moveTo(27, 33)
          ..lineTo(41, 33)
          ..moveTo(18, 44)
          ..lineTo(27, 44)
          ..moveTo(42, 44)
          ..lineTo(50, 44);
        canvas.drawPath(letter, line..strokeWidth = 2.7);
        canvas.drawOval(const Rect.fromLTWH(50, 30, 12, 14), line);
        canvas.drawLine(const Offset(62, 30), const Offset(62, 44), line);
        canvas.drawLine(
          const Offset(23, 53),
          const Offset(57, 53),
          line..strokeWidth = 1.3,
        );
      case AppearanceArtKind.calendar:
        card(const Rect.fromLTWH(15, 12, 59, 53));
        card(
          const Rect.fromLTWH(15, 12, 59, 17),
          radius: 6,
          color: ink.withValues(alpha: .25),
        );
        canvas.drawLine(const Offset(29, 8), const Offset(29, 18), line);
        canvas.drawLine(const Offset(60, 8), const Offset(60, 18), line);
        fill.color = ink.withValues(alpha: .35);
        for (var x = 0; x < 3; x++) {
          for (var y = 0; y < 2; y++) {
            canvas.drawCircle(Offset(29 + x * 15, 39 + y * 14), 2.5, fill);
          }
        }
        fill.color = ink;
        canvas.drawCircle(const Offset(44, 39), 7, fill);
        canvas.drawLine(
          const Offset(41, 39),
          const Offset(43, 41),
          line..color = paper,
        );
        canvas.drawLine(const Offset(43, 41), const Offset(47, 36), line);
      case AppearanceArtKind.performance:
        fill.color = ink.withValues(alpha: .12);
        canvas.drawCircle(const Offset(44, 37), 30, fill);
        canvas.drawArc(
          const Rect.fromLTWH(16, 9, 56, 56),
          math.pi * .7,
          math.pi * 1.6,
          false,
          line..strokeWidth = 4.5,
        );
        final bolt = Path()
          ..moveTo(47, 17)
          ..lineTo(31, 40)
          ..lineTo(43, 40)
          ..lineTo(39, 57)
          ..lineTo(58, 32)
          ..lineTo(46, 32)
          ..close();
        canvas.drawPath(bolt, Paint()..color = ink);
      case AppearanceArtKind.music:
        card(
          const Rect.fromLTWH(12, 13, 65, 49),
          color: ink.withValues(alpha: .13),
        );
        for (var i = 0; i < 9; i++) {
          final height = 8 + (math.sin(i * 1.4).abs() * 28);
          canvas.drawLine(
            Offset(22 + i * 5.5, 37 - height / 2),
            Offset(22 + i * 5.5, 37 + height / 2),
            line..strokeWidth = 3,
          );
        }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant AppearanceArtworkPainter oldDelegate) =>
      kind != oldDelegate.kind ||
      accent != oldDelegate.accent ||
      isDark != oldDelegate.isDark;
}

/// Các biểu tượng hiệu ứng là nét vẽ tĩnh, không tạo ticker cho lưới lựa chọn.
class AppearanceEffectPainter extends CustomPainter {
  const AppearanceEffectPainter({required this.effectKey, required this.color});
  final String effectKey;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final r = size.shortestSide * .32;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    switch (effectKey) {
      case 'off':
        canvas.drawCircle(center, r * .82, paint);
        canvas.drawLine(
          center + Offset(-r * .55, -r * .55),
          center + Offset(r * .55, r * .55),
          paint,
        );
      case 'hearts':
        final path = Path()
          ..moveTo(center.dx, center.dy + r * .8)
          ..cubicTo(
            center.dx - r * 1.8,
            center.dy - r * .1,
            center.dx - r * .7,
            center.dy - r * 1.4,
            center.dx,
            center.dy - r * .45,
          )
          ..cubicTo(
            center.dx + r * .7,
            center.dy - r * 1.4,
            center.dx + r * 1.8,
            center.dy - r * .1,
            center.dx,
            center.dy + r * .8,
          );
        canvas.drawPath(path, paint);
      case 'bubbles':
        canvas.drawCircle(center + Offset(-r * .25, r * .15), r * .7, paint);
        canvas.drawCircle(center + Offset(r * .65, -r * .65), r * .32, paint);
      case 'leaves':
      case 'auto':
        final leaf = Path()
          ..moveTo(center.dx - r * .7, center.dy + r * .8)
          ..quadraticBezierTo(
            center.dx - r,
            center.dy - r,
            center.dx + r * .8,
            center.dy - r * .8,
          )
          ..quadraticBezierTo(
            center.dx + r,
            center.dy + r,
            center.dx - r * .7,
            center.dy + r * .8,
          );
        canvas.drawPath(leaf, paint);
        canvas.drawLine(
          center + Offset(-r * .7, r * .8),
          center + Offset(r * .5, -r * .5),
          paint,
        );
      case 'meteors':
        canvas.drawLine(
          center + Offset(-r, -r),
          center + Offset(r * .5, r * .5),
          paint,
        );
        canvas.drawLine(
          center + Offset(-r, -r * .2),
          center + Offset(0, r * .8),
          paint,
        );
        canvas.drawCircle(center + Offset(r * .6, r * .6), r * .25, paint);
      case 'snow':
        for (var i = 0; i < 3; i++) {
          final delta = Offset(
            math.cos(i * math.pi / 3) * r,
            math.sin(i * math.pi / 3) * r,
          );
          canvas.drawLine(center - delta, center + delta, paint);
        }
      case 'stars':
        final star = Path();
        for (var i = 0; i < 10; i++) {
          final angle = -math.pi / 2 + i * math.pi / 5;
          final radius = i.isEven ? r : r * .46;
          final point =
              center +
              Offset(math.cos(angle) * radius, math.sin(angle) * radius);
          if (i == 0) {
            star.moveTo(point.dx, point.dy);
          } else {
            star.lineTo(point.dx, point.dy);
          }
        }
        canvas.drawPath(star..close(), paint);
      default:
        final spark = Path()
          ..moveTo(center.dx, center.dy - r)
          ..quadraticBezierTo(
            center.dx + r * .2,
            center.dy - r * .2,
            center.dx + r,
            center.dy,
          )
          ..quadraticBezierTo(
            center.dx + r * .2,
            center.dy + r * .2,
            center.dx,
            center.dy + r,
          )
          ..quadraticBezierTo(
            center.dx - r * .2,
            center.dy + r * .2,
            center.dx - r,
            center.dy,
          )
          ..quadraticBezierTo(
            center.dx - r * .2,
            center.dy - r * .2,
            center.dx,
            center.dy - r,
          );
        canvas.drawPath(spark, paint);
    }
  }

  @override
  bool shouldRepaint(covariant AppearanceEffectPainter oldDelegate) =>
      effectKey != oldDelegate.effectKey || color != oldDelegate.color;
}
