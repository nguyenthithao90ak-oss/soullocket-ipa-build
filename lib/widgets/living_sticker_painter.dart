import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'living_sticker_scene.dart';

part 'living_sticker_characters.dart';
part 'living_sticker_objects.dart';

/// Hệ tọa độ cố định: chỉ các khớp và chi tiết được phép chuyển động.
class LivingStickerPainter extends CustomPainter {
  LivingStickerPainter({required this.scene, required this.animation})
    : super(repaint: animation);

  final LivingStickerScene scene;
  final Animation<double> animation;
  static const ink = Color(0xFF78534F);
  static const cream = Color(0xFFFFF1DB);
  static const pink = Color(0xFFFFD6E0);
  static const rose = Color(0xFFE9799B);
  static const blue = Color(0xFFA3CFDF);
  static const mint = Color(0xFFB9DCC8);
  static const lilac = Color(0xFFC9B9E5);
  static const gold = Color(0xFFF4C36F);

  static double bump(double t, double start, double end) {
    if (t <= start || t >= end) return 0;
    return math
        .pow(math.sin((t - start) / (end - start) * math.pi), 2)
        .toDouble();
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final t = animation.value;
    canvas.save();
    final scale = math.min(size.width, size.height) / 200;
    canvas.translate(
      (size.width - 200 * scale) / 2,
      (size.height - 200 * scale) / 2,
    );
    canvas.scale(scale);
    canvas.drawOval(
      const Rect.fromLTWH(32, 177, 136, 9),
      Paint()..color = rose.withValues(alpha: 0.12),
    );
    if (scene.subject == StickerSubject.couple) {
      _character(
        canvas,
        const Offset(63, 123),
        0.83,
        StickerSubject.cat,
        scene.gesture,
        t,
      );
      _character(
        canvas,
        const Offset(137, 123),
        0.83,
        StickerSubject.bunny,
        scene.gesture,
        t,
        second: true,
      );
    } else if ({
      StickerSubject.cat,
      StickerSubject.bunny,
      StickerSubject.puppy,
    }.contains(scene.subject)) {
      _character(
        canvas,
        const Offset(100, 115),
        1.02,
        scene.subject,
        scene.gesture,
        t,
      );
    } else {
      _object(
        canvas,
        scene.subject,
        const Offset(100, 111),
        1.02,
        t,
        scene.gesture,
        accent: scene.accent,
        detail: scene.detail,
        face: true,
      );
    }
    if (scene.prop != null) {
      _object(
        canvas,
        scene.prop!,
        const Offset(101, 155),
        0.43,
        t,
        scene.gesture,
      );
    } else if ({
          StickerSubject.couple,
          StickerSubject.cat,
          StickerSubject.bunny,
          StickerSubject.puppy,
        }.contains(scene.subject) &&
        {
          StickerGesture.hug,
          StickerGesture.love,
          StickerGesture.heal,
        }.contains(scene.gesture)) {
      _object(
        canvas,
        StickerSubject.heart,
        const Offset(100, 153),
        0.43,
        t,
        scene.gesture,
      );
    }
    _atmosphere(canvas, t);
    canvas.restore();
  }

  void _atmosphere(Canvas canvas, double t) {
    final activity = bump(t, 0.35, 0.95);
    final gesture = scene.gesture;
    if (gesture == StickerGesture.sleep) {
      for (var i = 0; i < 3; i++) {
        final progress = ((t + i / 3) % 1);
        _text(
          canvas,
          'z',
          Offset(154 + progress * 12, 61 - progress * 35),
          11 + progress * 7,
          ink.withValues(alpha: math.sin(progress * math.pi) * 0.7),
        );
      }
    } else if (gesture == StickerGesture.angry ||
        gesture == StickerGesture.pout) {
      final k = 1 + activity * 0.23;
      canvas.save();
      canvas.translate(157, 43);
      canvas.scale(k);
      _line(
        canvas,
        [const Offset(-7, 0), const Offset(-1, 0), const Offset(-1, -7)],
        color: rose,
        width: 2.5,
      );
      _line(
        canvas,
        [const Offset(2, 7), const Offset(2, 2), const Offset(8, 2)],
        color: rose,
        width: 2.5,
      );
      canvas.restore();
    } else if (gesture == StickerGesture.think) {
      for (var i = 0; i < 3; i++) {
        _ellipse(
          canvas,
          Rect.fromCircle(
            center: Offset(146 + i * 9.0, 40),
            radius: 2.1 + bump(t, i * 0.14, 0.5 + i * 0.14),
          ),
          lilac,
          border: false,
        );
      }
    } else if (gesture == StickerGesture.celebrate ||
        gesture == StickerGesture.dance ||
        gesture == StickerGesture.sing) {
      for (var i = 0; i < 6; i++) {
        final p = (t + i / 6) % 1;
        final alpha = math.sin(p * math.pi) * 0.85;
        final color = [gold, rose, lilac, mint][i % 4].withValues(alpha: alpha);
        final point = Offset(25 + i * 29.0, 14 + p * 43);
        if (gesture == StickerGesture.sing) {
          _note(canvas, point, color, 0.42);
        } else {
          canvas.save();
          canvas.translate(point.dx, point.dy);
          canvas.rotate(p * 2);
          _rounded(
            canvas,
            const Rect.fromLTWH(-2, -4, 4, 8),
            color,
            radius: 1,
            border: false,
          );
          canvas.restore();
        }
      }
    } else if (activity > 0 &&
        {
          StickerGesture.love,
          StickerGesture.hug,
          StickerGesture.kiss,
          StickerGesture.shy,
          StickerGesture.heal,
        }.contains(gesture)) {
      for (var i = 0; i < 2; i++) {
        final progress = ((t - 0.35) / 0.60).clamp(0.0, 1.0);
        canvas.save();
        canvas.translate(39 + i * 117.0, 57 - progress * 26);
        canvas.scale(0.18 + i * 0.04);
        _shape(
          canvas,
          _heart(),
          rose.withValues(alpha: activity * 0.8),
          border: false,
        );
        canvas.restore();
      }
    }
  }

  Path _heart() => Path()
    ..moveTo(0, 43)
    ..cubicTo(-14, 31, -60, 6, -51, -22)
    ..cubicTo(-44, -47, -13, -47, 0, -25)
    ..cubicTo(15, -48, 47, -43, 53, -20)
    ..cubicTo(61, 5, 17, 32, 0, 43)
    ..close();

  Path _star(double radius, {double inner = 0.5, int points = 5}) {
    final path = Path();
    for (var i = 0; i < points * 2; i++) {
      final angle = -math.pi / 2 + i * math.pi / points;
      final r = i.isEven ? radius : radius * inner;
      final point = Offset(math.cos(angle) * r, math.sin(angle) * r);
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    return path..close();
  }

  void _shape(
    Canvas c,
    Path path,
    Color color, {
    bool border = true,
    double width = 2.2,
  }) {
    final bounds = path.getBounds();
    c.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color.lerp(color, Colors.white, 0.20)!, color],
        ).createShader(bounds),
    );
    if (border) _stroke(c, path, width: width);
  }

  void _stroke(Canvas c, Path path, {Color color = ink, double width = 2.2}) =>
      c.drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = width
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );

  void _line(
    Canvas c,
    List<Offset> points, {
    Color color = ink,
    double width = 2.2,
  }) {
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    _stroke(c, path, color: color, width: width);
  }

  void _ellipse(Canvas c, Rect rect, Color color, {bool border = true}) =>
      _shape(c, Path()..addOval(rect), color, border: border);

  void _rounded(
    Canvas c,
    Rect rect,
    Color color, {
    double radius = 8,
    bool border = true,
  }) => _shape(
    c,
    Path()..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius))),
    color,
    border: border,
  );

  void _text(Canvas c, String value, Offset center, double size, Color color) {
    if (value == 'z') {
      c.save();
      c.translate(center.dx, center.dy);
      c.scale(size / 14);
      _line(
        c,
        [
          const Offset(-4, -5),
          const Offset(4, -5),
          const Offset(-4, 5),
          const Offset(4, 5),
        ],
        color: color,
        width: 2,
      );
      c.restore();
      return;
    }
    c.save();
    c.translate(center.dx, center.dy);
    if (value == '♥') {
      c.scale(size / 95);
      _shape(c, _heart(), color, border: false);
    } else {
      // Chữ số của đồng hồ/lịch là nét vẽ, không phụ thuộc font hay nền tảng.
      const segments = [
        'abcdef',
        'bc',
        'abdeg',
        'abcdg',
        'bcfg',
        'acdfg',
        'acdefg',
        'abc',
        'abcdefg',
        'abcdfg',
      ];
      const lines = [
        [Offset(1, 0), Offset(7, 0)],
        [Offset(8, 1), Offset(8, 6)],
        [Offset(8, 8), Offset(8, 13)],
        [Offset(1, 14), Offset(7, 14)],
        [Offset(0, 8), Offset(0, 13)],
        [Offset(0, 1), Offset(0, 6)],
        [Offset(1, 7), Offset(7, 7)],
      ];
      c.scale(size / 17);
      c.translate(-(value.length * 11 - 3) / 2, -7);
      for (final character in value.split('')) {
        final digit = int.tryParse(character);
        if (digit != null) {
          for (var i = 0; i < lines.length; i++) {
            if (segments[digit].contains(String.fromCharCode(97 + i))) {
              _line(c, lines[i], color: color, width: 1.5);
            }
          }
        }
        c.translate(11, 0);
      }
    }
    c.restore();
  }

  void _note(Canvas c, Offset point, Color color, double scale) {
    c.save();
    c.translate(point.dx, point.dy);
    c.scale(scale);
    _ellipse(c, const Rect.fromLTWH(-10, 2, 13, 9), color, border: false);
    _line(
      c,
      [const Offset(2, 6), const Offset(2, -17), const Offset(12, -12)],
      color: color,
      width: 3.5,
    );
    c.restore();
  }

  @override
  bool shouldRepaint(covariant LivingStickerPainter oldDelegate) =>
      oldDelegate.scene != scene || oldDelegate.animation != animation;
}
