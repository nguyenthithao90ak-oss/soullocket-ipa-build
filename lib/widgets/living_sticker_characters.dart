part of 'living_sticker_painter.dart';

extension _StickerCharacters on LivingStickerPainter {
  void _character(
    Canvas c,
    Offset center,
    double scale,
    StickerSubject kind,
    StickerGesture gesture,
    double t, {
    bool second = false,
  }) {
    c.save();
    c.translate(center.dx, center.dy);
    c.scale(scale);
    final color = kind == StickerSubject.bunny
        ? LivingStickerPainter.pink
        : LivingStickerPainter.cream;
    final activity = LivingStickerPainter.bump(t, 0.3, 0.85);
    final blink = LivingStickerPainter.bump(
      t,
      second ? 0.2 : 0.12,
      second ? 0.27 : 0.19,
    );
    if (kind == StickerSubject.cat) {
      _shape(
        c,
        Path()
          ..moveTo(-22, 49)
          ..cubicTo(-65, 52, -47, 19, -39, 27)
          ..cubicTo(-50, 46, -27, 38, -24, 34)
          ..close(),
        color,
      );
    }
    _ellipse(c, const Rect.fromLTWH(-27, -4, 54, 61), color);
    _ellipse(c, const Rect.fromLTWH(-28, 48, 26, 13), color);
    _ellipse(c, const Rect.fromLTWH(2, 48, 26, 13), color);
    if (kind == StickerSubject.bunny) {
      for (final side in [-1, 1]) {
        c.save();
        c.translate(side * 20.0, -48);
        c.rotate(
          side * (0.16 + LivingStickerPainter.bump(t, 0.28, 0.47) * 0.17),
        );
        _rounded(c, const Rect.fromLTWH(-9, -48, 18, 55), color, radius: 11);
        _rounded(
          c,
          const Rect.fromLTWH(-4, -39, 8, 35),
          LivingStickerPainter.rose.withValues(alpha: 0.45),
          radius: 5,
          border: false,
        );
        c.restore();
      }
    }
    if (kind == StickerSubject.puppy) {
      for (final side in [-1, 1]) {
        c.save();
        c.translate(side * 31.0, -52);
        c.rotate(side * (0.2 + activity * 0.18));
        _ellipse(
          c,
          const Rect.fromLTWH(-12, -2, 24, 44),
          const Color(0xFFE3B78E),
        );
        c.restore();
      }
    }
    if (kind == StickerSubject.cat) {
      _shape(
        c,
        Path()
          ..moveTo(-32, -49)
          ..quadraticBezierTo(-40, -70, -32, -79)
          ..quadraticBezierTo(-19, -77, -12, -62)
          ..quadraticBezierTo(0, -66, 13, -62)
          ..quadraticBezierTo(25, -80, 33, -77)
          ..quadraticBezierTo(39, -64, 32, -48)
          ..cubicTo(49, -10, 25, 4, 0, 4)
          ..cubicTo(-29, 4, -49, -16, -32, -49)
          ..close(),
        color,
      );
      _shape(
        c,
        Path()
          ..moveTo(-29, -69)
          ..lineTo(-27, -54)
          ..lineTo(-18, -61)
          ..close(),
        LivingStickerPainter.pink,
        border: false,
      );
      _shape(
        c,
        Path()
          ..moveTo(29, -68)
          ..lineTo(19, -61)
          ..lineTo(29, -54)
          ..close(),
        LivingStickerPainter.pink,
        border: false,
      );
    } else {
      _ellipse(c, const Rect.fromLTWH(-38, -62, 76, 66), color);
    }
    _face(c, const Offset(0, -29), gesture, blink, t);

    // Tay xoay quanh vai; thân giữ nguyên vị trí và tỷ lệ.
    for (final side in [-1, 1]) {
      var angle = side * -0.48;
      var x = side * 25.0;
      var y = 16.0;
      switch (gesture) {
        case StickerGesture.wave:
        case StickerGesture.dance:
        case StickerGesture.celebrate:
        case StickerGesture.sing:
          angle = -side * (1.8 + activity * math.sin(t * math.pi * 8) * 0.55);
          y = 2;
          break;
        case StickerGesture.peek:
        case StickerGesture.shy:
          x = side * (16 - activity * 3);
          y = -13 - activity * 17;
          angle = side * 0.2;
          break;
        case StickerGesture.pout:
        case StickerGesture.angry:
          x = side * 13;
          y = 17;
          angle = side * (0.9 + activity * 0.18);
          break;
        case StickerGesture.sad:
        case StickerGesture.sorry:
          x = side * (12 - activity * 3);
          y = 23;
          angle = side * -0.25;
          break;
        case StickerGesture.think:
          if (side == 1) {
            x = 12 + activity * 2;
            y = -6;
            angle = 0.7;
          }
          break;
        default:
          x -= side * activity * 5;
          angle += side * activity * 0.15;
      }
      c.save();
      c.translate(x, y);
      c.rotate(angle);
      _ellipse(c, const Rect.fromLTWH(-9, -3, 18, 25), color);
      _line(c, [const Offset(-3, 15), const Offset(-3, 18)], width: 1);
      c.restore();
    }
    c.restore();
  }

  void _face(
    Canvas c,
    Offset center,
    StickerGesture gesture,
    double blink,
    double t, {
    double scale = 1,
  }) {
    c.save();
    c.translate(center.dx, center.dy);
    c.scale(scale);
    final activity = LivingStickerPainter.bump(t, 0.3, 0.85);
    final sad =
        gesture == StickerGesture.sad || gesture == StickerGesture.sorry;
    final grumpy =
        gesture == StickerGesture.angry || gesture == StickerGesture.pout;
    final sleepy = gesture == StickerGesture.sleep;
    final happy =
        gesture == StickerGesture.laugh || gesture == StickerGesture.celebrate;
    for (final side in [-1, 1]) {
      final x = side * 13.0;
      _ellipse(
        c,
        Rect.fromCenter(center: Offset(side * 23.0, 10), width: 14, height: 7),
        LivingStickerPainter.rose.withValues(
          alpha: 0.45 + (gesture == StickerGesture.shy ? activity * 0.2 : 0),
        ),
        border: false,
      );
      if (sleepy ||
          happy ||
          blink > 0.78 ||
          (gesture == StickerGesture.play && side == 1 && activity > 0.5)) {
        _stroke(
          c,
          Path()
            ..moveTo(x - 4, 1)
            ..quadraticBezierTo(x, happy ? -5 : 5, x + 4, 1),
          width: 2.6,
        );
      } else {
        _ellipse(
          c,
          Rect.fromCenter(
            center: Offset(x, 0),
            width: 5.5,
            height: 7.5 * (1 - blink * 0.85),
          ),
          LivingStickerPainter.ink,
          border: false,
        );
      }
      if (grumpy || sad) {
        _line(c, [
          Offset(x - 4, -8 + side * (grumpy ? 2 : -2)),
          Offset(x + 4, -8 + side * (grumpy ? -2 : 2)),
        ], width: 2);
      }
      if (sad) {
        final p = (t + (side == 1 ? 0.4 : 0)) % 1;
        c.save();
        c.translate(x + side * 2, 10 + p * 17);
        c.scale(0.12);
        _shape(
          c,
          Path()
            ..moveTo(0, -20)
            ..cubicTo(-32, 14, -15, 34, 0, 34)
            ..cubicTo(23, 34, 28, 12, 0, -20)
            ..close(),
          LivingStickerPainter.blue.withValues(alpha: math.sin(p * math.pi)),
          border: false,
        );
        c.restore();
      }
    }
    if (gesture == StickerGesture.kiss) {
      _stroke(
        c,
        Path()
          ..moveTo(-3, 8)
          ..lineTo(3 + activity * 2, 11)
          ..lineTo(-3, 14),
        color: LivingStickerPainter.rose,
        width: 2.8,
      );
    } else if (happy || gesture == StickerGesture.sing) {
      _ellipse(
        c,
        Rect.fromCenter(
          center: const Offset(0, 12),
          width: 11 + activity * 4,
          height: 8 + activity * 6,
        ),
        LivingStickerPainter.ink,
        border: false,
      );
      _ellipse(
        c,
        const Rect.fromLTWH(-4, 13, 8, 4),
        LivingStickerPainter.rose,
        border: false,
      );
    } else if (grumpy || sad) {
      _stroke(
        c,
        Path()
          ..moveTo(-5, 14)
          ..quadraticBezierTo(0, grumpy ? 14 - activity * 4 : 8, 5, 14),
        width: 2,
      );
    } else if (gesture == StickerGesture.play) {
      _stroke(
        c,
        Path()
          ..moveTo(-5, 9)
          ..quadraticBezierTo(0, 16, 5, 9),
        width: 2,
      );
      _rounded(
        c,
        Rect.fromLTWH(-2, 12, 5, 4 + activity * 5),
        LivingStickerPainter.rose,
        radius: 3,
        border: false,
      );
    } else {
      _ellipse(
        c,
        const Rect.fromLTWH(-2.5, 6, 5, 3.5),
        LivingStickerPainter.rose,
        border: false,
      );
      _stroke(
        c,
        Path()
          ..moveTo(-6, 11)
          ..quadraticBezierTo(-3, 17, 0, 11)
          ..quadraticBezierTo(3, 17, 6, 11),
        width: 1.8,
      );
    }
    c.restore();
  }
}
