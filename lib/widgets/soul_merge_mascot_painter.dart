import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Mắt, tai và tay chuyển động riêng trên cùng hệ tọa độ cố định.
class SoulMergeMascotPainter extends CustomPainter {
  SoulMergeMascotPainter({required this.animation}) : super(repaint: animation);

  final Animation<double> animation;

  static const _outline = Color(0xFF78504F);
  static const _cream = Color(0xFFFFFBEE);
  static const _creamShade = Color(0xFFF4DCC2);
  static const _pink = Color(0xFFFFDFE0);
  static const _pinkShade = Color(0xFFF4AFBD);

  double _bump(double phase, double start, double end) {
    if (phase <= start || phase >= end) return 0;
    return math
        .pow(math.sin((phase - start) / (end - start) * math.pi), 2)
        .toDouble();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final phase = animation.value;
    final catBlink = _bump(phase, 0.12, 0.19);
    final bunnyBlink = _bump(phase, 0.18, 0.25);
    final hug = _bump(phase, 0.38, 0.82);
    final beat = _bump(phase, 0.44, 0.55) + _bump(phase, 0.59, 0.70) * 0.7;
    final ear = _bump(phase, 0.25, 0.43) * 0.10;

    canvas.save();
    final scale = math.min(size.width, size.height) / 200;
    canvas.translate(
      (size.width - 200 * scale) / 2,
      (size.height - 200 * scale) / 2,
    );
    canvas.scale(scale);

    canvas.drawOval(
      const Rect.fromLTWH(36, 175, 130, 9),
      Paint()..color = const Color(0xFFD793A8).withValues(alpha: 0.18),
    );

    // Đuôi và thân cố định, không dịch hoặc phóng to toàn bộ hình.
    final tail = Path()
      ..moveTo(45, 164)
      ..cubicTo(18, 174, 12, 153, 20, 139)
      ..cubicTo(26, 130, 34, 137, 29, 146)
      ..cubicTo(24, 155, 36, 157, 46, 151)
      ..close();
    _shape(canvas, tail, _cream, _creamShade);
    _oval(canvas, const Rect.fromLTWH(35, 105, 66, 71), _cream, _creamShade);
    _oval(canvas, const Rect.fromLTWH(104, 106, 62, 70), _pink, _pinkShade);
    _oval(canvas, const Rect.fromLTWH(46, 164, 25, 14), _cream, _creamShade);
    _oval(canvas, const Rect.fromLTWH(74, 164, 23, 14), _cream, _creamShade);
    _oval(canvas, const Rect.fromLTWH(110, 165, 23, 13), _pink, _pinkShade);
    _oval(canvas, const Rect.fromLTWH(138, 165, 25, 13), _pink, _pinkShade);

    // Tai xoay quanh gốc tai, đầu thỏ vẫn đứng yên.
    _bunnyEar(canvas, const Offset(122, 67), -0.12 - ear, 49);
    _bunnyEar(canvas, const Offset(147, 69), 0.24 + ear * 0.8, 53);

    final catHead = Path()
      ..moveTo(29, 76)
      ..quadraticBezierTo(22, 64, 28, 43)
      ..quadraticBezierTo(42, 42, 52, 57)
      ..quadraticBezierTo(65, 53, 77, 57)
      ..quadraticBezierTo(87, 42, 97, 45)
      ..quadraticBezierTo(102, 64, 97, 76)
      ..cubicTo(109, 108, 89, 127, 64, 126)
      ..cubicTo(35, 128, 17, 107, 29, 76)
      ..close();
    _shape(canvas, catHead, _cream, const Color(0xFFFFEED7));
    _fill(
      canvas,
      Path()
        ..moveTo(31, 51)
        ..quadraticBezierTo(32, 66, 36, 69)
        ..lineTo(46, 61)
        ..quadraticBezierTo(38, 51, 31, 51),
      const Color(0xFFF4B4BB),
    );
    _fill(
      canvas,
      Path()
        ..moveTo(92, 53)
        ..quadraticBezierTo(84, 55, 82, 63)
        ..lineTo(92, 69)
        ..close(),
      const Color(0xFFF4B4BB),
    );

    _oval(
      canvas,
      const Rect.fromLTWH(98, 63, 75, 65),
      _pink,
      const Color(0xFFFFCDD7),
    );

    _face(canvas, const Offset(64, 92), catBlink, isCat: true);
    _face(canvas, const Offset(134, 94), bunnyBlink, isCat: false);

    // Tim nở hai nhịp nhỏ; hai tay khép lại theo nhịp ôm.
    canvas.save();
    canvas.translate(100, 139);
    canvas.scale(1 + beat * 0.075);
    final heart = Path()
      ..moveTo(0, 25)
      ..cubicTo(-8, 20, -31, 4, -28, -10)
      ..cubicTo(-26, -26, -7, -27, 0, -15)
      ..cubicTo(9, -28, 28, -24, 29, -9)
      ..cubicTo(30, 5, 8, 20, 0, 25)
      ..close();
    _shape(
      canvas,
      heart,
      const Color(0xFFFF94B1),
      const Color(0xFFE95380),
      outline: const Color(0xFFC94C76),
    );
    _stroke(
      canvas,
      Path()
        ..moveTo(-18, -12)
        ..quadraticBezierTo(-14, -18, -8, -14),
      color: const Color(0xFFFFDFE9),
      width: 3.8,
    );
    canvas.restore();

    _paw(
      canvas,
      Offset(76 + hug * 3.5, 139 - hug * 1.5),
      -0.48 + hug * 0.10,
      _cream,
      _creamShade,
    );
    _paw(
      canvas,
      Offset(126 - hug * 3.5, 139 - hug * 1.5),
      0.48 - hug * 0.10,
      _pink,
      _pinkShade,
    );

    // Tim nhỏ bay lên sau cái ôm, tan trước khi vòng lặp bắt đầu lại.
    final love = ((phase - 0.56) / 0.38).clamp(0.0, 1.0);
    if (love > 0 && love < 1) {
      final opacity = math.sin(love * math.pi) * 0.85;
      canvas.save();
      canvas.translate(91 + love * 3, 44 - love * 19);
      canvas.scale(0.22 + love * 0.06);
      _fill(canvas, heart, const Color(0xFFE96C94).withValues(alpha: opacity));
      canvas.restore();
    }
    canvas.restore();
  }

  void _bunnyEar(Canvas canvas, Offset pivot, double angle, double height) {
    canvas.save();
    canvas.translate(pivot.dx, pivot.dy);
    canvas.rotate(angle);
    final ear = Path()
      ..moveTo(-9, 3)
      ..cubicTo(-14, -16, -13, -height, 0, -height)
      ..cubicTo(14, -height, 13, -13, 9, 3)
      ..close();
    _shape(canvas, ear, _pink, _pinkShade);
    canvas.drawOval(
      Rect.fromLTWH(-5, -height + 8, 10, height - 13),
      Paint()..color = const Color(0xFFF3A0B2),
    );
    canvas.restore();
  }

  void _face(
    Canvas canvas,
    Offset center,
    double blink, {
    required bool isCat,
  }) {
    final x = center.dx;
    final y = center.dy;
    final blush = Paint()
      ..color = const Color(0xFFF2A5B4).withValues(alpha: 0.65);
    canvas.drawOval(
      Rect.fromCenter(center: Offset(x - 22, y + 9), width: 14, height: 8),
      blush,
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(x + 22, y + 9), width: 14, height: 8),
      blush,
    );
    for (final eyeX in [x - 12, x + 12]) {
      if (blink > 0.78) {
        _stroke(
          canvas,
          Path()
            ..moveTo(eyeX - 3.8, y + 1)
            ..quadraticBezierTo(eyeX, y + 4, eyeX + 3.8, y + 1),
          width: 2.5,
        );
      } else {
        final height = 7.6 * (1 - blink * 0.85);
        canvas.drawOval(
          Rect.fromCenter(center: Offset(eyeX, y), width: 5.5, height: height),
          Paint()..color = _outline,
        );
        if (blink < 0.3) {
          canvas.drawCircle(
            Offset(eyeX - 0.7, y - 1.5),
            0.8,
            Paint()..color = Colors.white,
          );
        }
      }
    }
    canvas.drawOval(
      Rect.fromCenter(center: Offset(x, y + 7), width: 6, height: 4),
      Paint()..color = const Color(0xFFD9798F),
    );
    _stroke(
      canvas,
      Path()
        ..moveTo(x, y + 9)
        ..cubicTo(x - 1, y + 16, x - 7, y + 16, x - 8, y + 12)
        ..moveTo(x, y + 9)
        ..cubicTo(x + 1, y + 16, x + 7, y + 16, x + 8, y + 12),
      width: 1.8,
    );
    if (isCat) {
      _stroke(
        canvas,
        Path()
          ..moveTo(x - 27, y + 3)
          ..lineTo(x - 33, y + 1)
          ..moveTo(x - 27, y + 9)
          ..lineTo(x - 33, y + 10),
        width: 1.4,
      );
    }
  }

  void _paw(
    Canvas canvas,
    Offset center,
    double angle,
    Color top,
    Color bottom,
  ) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);
    _oval(canvas, const Rect.fromLTWH(-10, -7, 20, 16), top, bottom);
    _stroke(
      canvas,
      Path()
        ..moveTo(-3, 3)
        ..lineTo(-3, 5),
      width: 1.1,
    );
    _stroke(
      canvas,
      Path()
        ..moveTo(2, 3)
        ..lineTo(2, 5),
      width: 1.1,
    );
    canvas.restore();
  }

  void _oval(Canvas canvas, Rect rect, Color top, Color bottom) {
    _shape(canvas, Path()..addOval(rect), top, bottom);
  }

  void _shape(
    Canvas canvas,
    Path path,
    Color top,
    Color bottom, {
    Color outline = _outline,
  }) {
    final bounds = path.getBounds();
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [top, bottom],
        ).createShader(bounds),
    );
    _stroke(canvas, path, color: outline);
  }

  void _fill(Canvas canvas, Path path, Color color) {
    canvas.drawPath(path, Paint()..color = color);
  }

  void _stroke(
    Canvas canvas,
    Path path, {
    Color color = _outline,
    double width = 2.1,
  }) {
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant SoulMergeMascotPainter oldDelegate) =>
      oldDelegate.animation != animation;
}
