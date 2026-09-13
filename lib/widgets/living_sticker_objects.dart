part of 'living_sticker_painter.dart';

extension _StickerObjects on LivingStickerPainter {
  void _object(
    Canvas c,
    StickerSubject subject,
    Offset center,
    double scale,
    double t,
    StickerGesture gesture, {
    Color accent = LivingStickerPainter.rose,
    String? detail,
    bool face = false,
  }) {
    c.save();
    c.translate(center.dx, center.dy);
    c.scale(scale);
    final a = LivingStickerPainter.bump(t, 0.3, 0.85);
    final blink = LivingStickerPainter.bump(t, 0.12, 0.19);
    const ink = LivingStickerPainter.ink;
    const cream = LivingStickerPainter.cream;
    const pink = LivingStickerPainter.pink;
    const rose = LivingStickerPainter.rose;
    const blue = LivingStickerPainter.blue;
    const mint = LivingStickerPainter.mint;
    const lilac = LivingStickerPainter.lilac;
    const gold = LivingStickerPainter.gold;
    var showFace = face;
    var faceAt = const Offset(0, 0);
    switch (subject) {
      case StickerSubject.heart:
        _shape(c, _heart(), accent);
        // Viền ngoài cố định; tim nhỏ bên trong đập hai nhịp.
        c.save();
        c.translate(0, 29);
        c.scale(
          0.16 +
              (LivingStickerPainter.bump(t, 0.4, 0.52) +
                      LivingStickerPainter.bump(t, 0.56, 0.67)) *
                  0.035,
        );
        _shape(c, _heart(), cream, border: false);
        c.restore();
        if (gesture == StickerGesture.heal) {
          c.save();
          c.translate(33, -22);
          c.rotate(-0.5 + a * 0.08);
          _rounded(c, const Rect.fromLTWH(-14, -6, 28, 12), cream, radius: 4);
          _rounded(
            c,
            const Rect.fromLTWH(-4, -4, 8, 8),
            pink,
            radius: 2,
            border: false,
          );
          c.restore();
        }
        break;
      case StickerSubject.star:
        _shape(c, _star(63, inner: 0.57), gold);
        c.save();
        c.translate(37, -50);
        c.scale(0.14 + a * 0.10);
        _shape(c, _star(32, points: 4, inner: 0.3), rose, border: false);
        c.restore();
        break;
      case StickerSubject.moon:
        _shape(
          c,
          Path()
            ..moveTo(24, -57)
            ..cubicTo(-48, -72, -76, 18, -14, 49)
            ..quadraticBezierTo(24, 67, 49, 29)
            ..cubicTo(-2, 38, -17, -21, 24, -57)
            ..close(),
          gold,
        );
        faceAt = const Offset(-20, 3);
        c.save();
        c.translate(39, -30);
        c.rotate(a * 0.4);
        _shape(c, _star(13), pink);
        c.restore();
        break;
      case StickerSubject.planet:
        _ellipse(c, const Rect.fromLTWH(-48, -48, 96, 96), lilac);
        _stroke(
          c,
          Path()
            ..moveTo(-42, -27)
            ..cubicTo(-91, -4, -38, 48, 38, 14)
            ..cubicTo(76, -1, 79, -25, 44, -20),
          color: gold,
          width: 9,
        );
        final angle = t * math.pi * 2;
        _ellipse(
          c,
          Rect.fromCircle(
            center: Offset(math.cos(angle) * 67, math.sin(angle) * 22),
            radius: 6,
          ),
          cream,
        );
        break;
      case StickerSubject.robot:
        _rounded(c, const Rect.fromLTWH(-37, 15, 74, 42), blue, radius: 13);
        _rounded(c, const Rect.fromLTWH(-51, -47, 102, 73), mint, radius: 21);
        _line(c, [const Offset(0, -48), Offset(a * 5, -68)], width: 3);
        _ellipse(
          c,
          Rect.fromCircle(center: Offset(a * 5, -70), radius: 7),
          rose,
        );
        for (final side in [-1, 1]) {
          c.save();
          c.translate(side * 39.0, 26);
          c.rotate(side * a * 0.6);
          _rounded(
            c,
            Rect.fromLTWH(side == -1 ? -24 : 0, -3, 24, 14),
            blue,
            radius: 7,
          );
          c.restore();
        }
        _rounded(c, const Rect.fromLTWH(-15, 35, 30, 10), cream, radius: 4);
        faceAt = const Offset(0, -17);
        break;
      case StickerSubject.ghost:
        _shape(
          c,
          Path()
            ..moveTo(-47, 47)
            ..lineTo(-47, -7)
            ..cubicTo(-47, -68, 47, -68, 47, -7)
            ..lineTo(47, 47)
            ..quadraticBezierTo(32, 30, 17, 47)
            ..quadraticBezierTo(0, 31, -15, 47)
            ..quadraticBezierTo(-31, 31, -47, 47)
            ..close(),
          cream,
        );
        _objectArms(c, cream, a, gesture);
        break;
      case StickerSubject.cloud:
        _shape(
          c,
          Path()
            ..moveTo(-47, 34)
            ..cubicTo(-86, 26, -76, -21, -48, -23)
            ..cubicTo(-43, -60, -9, -61, 8, -36)
            ..cubicTo(34, -60, 58, -38, 55, -18)
            ..cubicTo(82, -9, 79, 34, 47, 34)
            ..close(),
          cream,
        );
        _objectArms(c, cream, a, gesture);
        break;
      case StickerSubject.drop:
        _shape(
          c,
          Path()
            ..moveTo(0, -65)
            ..cubicTo(-72, -4, -52, 49, 0, 51)
            ..cubicTo(61, 49, 66, -4, 0, -65)
            ..close(),
          blue,
        );
        _objectArms(c, blue, a, gesture);
        break;
      case StickerSubject.game:
        _shape(
          c,
          Path()
            ..moveTo(-37, -28)
            ..lineTo(38, -28)
            ..cubicTo(63, -26, 81, 48, 51, 47)
            ..lineTo(27, 25)
            ..lineTo(-28, 25)
            ..cubicTo(-58, 68, -79, 33, -57, -10)
            ..quadraticBezierTo(-50, -29, -37, -28)
            ..close(),
          lilac,
        );
        _line(c, [const Offset(-44, -7), const Offset(-24, -7)], width: 6);
        _line(c, [const Offset(-34, -17), const Offset(-34, 3)], width: 6);
        for (var i = 0; i < 4; i++) {
          final angle = i * math.pi / 2;
          _ellipse(
            c,
            Rect.fromCircle(
              center: Offset(
                36 + math.cos(angle) * 10,
                -6 + math.sin(angle) * 10,
              ),
              radius: 4.5,
            ),
            i.isEven ? rose : gold,
            border: false,
          );
        }
        _ellipse(
          c,
          Rect.fromCircle(center: const Offset(36, -16), radius: 7 + a * 3),
          gold.withValues(alpha: a * 0.3),
          border: false,
        );
        faceAt = const Offset(0, 5);
        break;
      case StickerSubject.coffee:
        _ellipse(c, const Rect.fromLTWH(-53, 38, 108, 13), pink);
        _rounded(c, const Rect.fromLTWH(25, -25, 36, 39), cream, radius: 16);
        _rounded(
          c,
          const Rect.fromLTWH(31, -18, 22, 24),
          const Color(0xFFFFF8EF),
          radius: 10,
        );
        _shape(
          c,
          Path()
            ..moveTo(-43, -35)
            ..lineTo(38, -35)
            ..lineTo(31, 23)
            ..quadraticBezierTo(25, 49, -14, 41)
            ..quadraticBezierTo(-37, 40, -39, 15)
            ..close(),
          cream,
        );
        _ellipse(
          c,
          const Rect.fromLTWH(-41, -43, 77, 17),
          const Color(0xFFBD8D70),
        );
        for (var i = 0; i < 3; i++) {
          final x = -24 + i * 21.0;
          _stroke(
            c,
            Path()
              ..moveTo(x, -49)
              ..cubicTo(x - 9 + a * 10, -58, x + 10 - a * 8, -66, x, -75),
            color: ink.withValues(alpha: 0.22 + a * 0.25),
            width: 2.5,
          );
        }
        break;
      case StickerSubject.music:
      case StickerSubject.microphone:
        if (subject == StickerSubject.music) {
          _rounded(c, const Rect.fromLTWH(-48, -42, 96, 95), pink, radius: 18);
          _ellipse(c, const Rect.fromLTWH(-28, -27, 56, 56), cream);
          _ellipse(c, const Rect.fromLTWH(-13, -12, 26, 26), rose);
          c.save();
          c.translate(0, 1);
          c.rotate(t * math.pi * 2);
          _ellipse(c, const Rect.fromLTWH(-2, -22, 4, 6), cream, border: false);
          c.restore();
          for (var i = 0; i < 5; i++) {
            _rounded(
              c,
              Rect.fromLTWH(
                -25 + i * 11.0,
                37 - a * (i.isEven ? 10 : 5),
                5,
                7 + a * (i.isEven ? 10 : 5),
              ),
              rose,
              radius: 2,
              border: false,
            );
          }
        } else {
          _line(c, [const Offset(0, 16), const Offset(0, 52)], width: 7);
          _rounded(c, const Rect.fromLTWH(-24, -53, 48, 81), lilac, radius: 23);
          for (var y = -34.0; y < 5; y += 10) {
            _line(c, [Offset(-14, y), Offset(14, y)], color: cream, width: 3);
          }
          _stroke(
            c,
            Path()
              ..moveTo(-35, 1)
              ..lineTo(-35, 17)
              ..quadraticBezierTo(0, 51, 35, 17)
              ..lineTo(35, 1),
            width: 4,
          );
          _rounded(c, const Rect.fromLTWH(-25, 49, 50, 9), blue, radius: 5);
        }
        _note(c, Offset(57, -40 - a * 12), rose, 0.8);
        showFace = false;
        break;
      case StickerSubject.mushroom:
        _rounded(c, const Rect.fromLTWH(-26, -5, 52, 63), cream, radius: 18);
        _shape(
          c,
          Path()
            ..moveTo(-61, -8)
            ..cubicTo(-59, -70, 59, -70, 61, -8)
            ..quadraticBezierTo(0, 17, -61, -8)
            ..close(),
          rose,
        );
        for (final point in [
          const Offset(-33, -24),
          const Offset(0, -39),
          const Offset(33, -20),
        ]) {
          _ellipse(
            c,
            Rect.fromCircle(center: point, radius: 9),
            cream,
            border: false,
          );
        }
        faceAt = const Offset(0, 22);
        _objectArms(c, cream, a, gesture);
        break;
      case StickerSubject.letter:
        _rounded(c, const Rect.fromLTWH(-57, -23, 114, 76), cream, radius: 8);
        _shape(
          c,
          Path()
            ..moveTo(-56, -21)
            ..lineTo(0, -61 * a - 23)
            ..lineTo(56, -21)
            ..close(),
          pink,
        );
        c.save();
        c.translate(0, -8 - a * 23);
        c.scale(0.37);
        _shape(c, _heart(), rose);
        c.restore();
        _shape(
          c,
          Path()
            ..moveTo(-57, -20)
            ..lineTo(0, 14)
            ..lineTo(57, -20)
            ..lineTo(57, 53)
            ..lineTo(-57, 53)
            ..close(),
          cream,
        );
        _line(c, [
          const Offset(-52, 48),
          const Offset(-18, 18),
        ], color: rose.withValues(alpha: 0.5));
        _line(c, [
          const Offset(52, 48),
          const Offset(18, 18),
        ], color: rose.withValues(alpha: 0.5));
        faceAt = const Offset(0, 30);
        break;
      case StickerSubject.calendar:
        _rounded(c, const Rect.fromLTWH(-50, -48, 100, 106), cream, radius: 13);
        _rounded(c, const Rect.fromLTWH(-50, -48, 100, 28), rose, radius: 10);
        for (final x in [-27.0, 27.0]) {
          _line(c, [Offset(x, -57), Offset(x, -37)], width: 6);
        }
        _text(
          c,
          detail ?? '♥',
          const Offset(0, 10),
          detail != null && detail.length > 3 ? 26 : 34,
          rose,
        );
        _shape(
          c,
          Path()
            ..moveTo(50, 38)
            ..lineTo(31 - a * 8, 58)
            ..lineTo(50, 58)
            ..close(),
          pink,
        );
        showFace = false;
        break;
      case StickerSubject.gift:
      case StickerSubject.bag:
        _rounded(c, const Rect.fromLTWH(-44, -14, 88, 72), pink, radius: 10);
        if (subject == StickerSubject.gift) {
          _rounded(
            c,
            const Rect.fromLTWH(-7, -14, 14, 72),
            gold,
            radius: 0,
            border: false,
          );
          c.save();
          c.translate(0, -a * 14);
          c.rotate(a * -0.055);
          _rounded(c, const Rect.fromLTWH(-50, -28, 100, 21), rose, radius: 6);
          _stroke(
            c,
            Path()
              ..moveTo(0, -27)
              ..cubicTo(-67, -76, -19, -75, 0, -27)
              ..cubicTo(68, -76, 20, -75, 0, -27),
            color: gold,
            width: 7,
          );
          c.restore();
        } else {
          _stroke(
            c,
            Path()
              ..moveTo(-20, -7)
              ..cubicTo(-26 - a * 3, -65, 26 + a * 3, -65, 20, -7),
            width: 5,
          );
        }
        faceAt = const Offset(0, 17);
        break;
      case StickerSubject.camera:
        _rounded(c, const Rect.fromLTWH(-28, -43, 49, 24), mint, radius: 8);
        _rounded(c, const Rect.fromLTWH(-59, -28, 118, 78), mint, radius: 17);
        _ellipse(c, const Rect.fromLTWH(-32, -20, 64, 64), cream);
        _ellipse(
          c,
          Rect.fromCircle(center: const Offset(0, 12), radius: 22 - a * 5),
          blue,
        );
        _ellipse(
          c,
          const Rect.fromLTWH(-13, -1, 11, 9),
          Colors.white.withValues(alpha: 0.8),
          border: false,
        );
        _rounded(c, const Rect.fromLTWH(34, -17, 14, 10), gold, radius: 3);
        if (a > 0.65) {
          c.save();
          c.translate(49, -41);
          _shape(
            c,
            _star(9 + a * 4, points: 4, inner: 0.3),
            gold,
            border: false,
          );
          c.restore();
        }
        showFace = false;
        break;
      case StickerSubject.book:
      case StickerSubject.checklist:
        _rounded(c, const Rect.fromLTWH(-45, -58, 90, 119), lilac, radius: 11);
        _rounded(c, const Rect.fromLTWH(-35, -49, 73, 101), cream, radius: 5);
        _line(c, [
          const Offset(-31, -49),
          const Offset(-31, 50),
        ], color: rose.withValues(alpha: 0.6));
        for (var i = 0; i < 4; i++) {
          final y = -25 + i * 18.0;
          _line(c, [Offset(-18, y), Offset(27, y)], color: lilac, width: 2);
          if (subject == StickerSubject.checklist) {
            _line(
              c,
              [Offset(-24, y - 2), Offset(-21, y + 2), Offset(-16, y - 5)],
              color: mint,
              width: 3,
            );
          }
        }
        c.save();
        c.translate(35, 16);
        c.rotate(0.25 + a * 0.16);
        _rounded(c, const Rect.fromLTWH(-4, -41, 8, 66), gold, radius: 3);
        _shape(
          c,
          Path()
            ..moveTo(-4, 25)
            ..lineTo(0, 35)
            ..lineTo(4, 25)
            ..close(),
          cream,
        );
        c.restore();
        showFace = false;
        break;
      case StickerSubject.clock:
        _ellipse(c, const Rect.fromLTWH(-53, -53, 106, 106), pink);
        _ellipse(c, const Rect.fromLTWH(-43, -43, 86, 86), cream);
        for (var i = 0; i < 12; i++) {
          final angle = i * math.pi / 6;
          _ellipse(
            c,
            Rect.fromCircle(
              center: Offset(math.cos(angle) * 34, math.sin(angle) * 34),
              radius: 1.7,
            ),
            rose,
            border: false,
          );
        }
        _line(c, [
          const Offset(0, -22),
          Offset.zero,
          const Offset(19, 9),
        ], width: 3.5);
        c.save();
        c.rotate(t * math.pi * 2);
        _line(
          c,
          [const Offset(0, 7), const Offset(0, -29)],
          color: rose,
          width: 1.8,
        );
        c.restore();
        _ellipse(c, const Rect.fromLTWH(-4, -4, 8, 8), rose);
        showFace = false;
        break;
      case StickerSubject.cake:
        _rounded(c, const Rect.fromLTWH(-41, 5, 82, 49), pink, radius: 9);
        _shape(
          c,
          Path()
            ..moveTo(-43, 13)
            ..cubicTo(-64, -9, -29, -35, -15, -24)
            ..cubicTo(-11, -64, 27, -56, 27, -23)
            ..cubicTo(53, -35, 64, 3, 42, 13)
            ..close(),
          cream,
        );
        _rounded(c, const Rect.fromLTWH(-3, -62, 6, 23), blue, radius: 2);
        _shape(
          c,
          Path()
            ..moveTo(0, -86)
            ..cubicTo(-14, -68, -4, -60, 0, -63)
            ..cubicTo(11, -65, 8 + a * 5, -75, 0, -86)
            ..close(),
          gold,
          border: false,
        );
        faceAt = const Offset(0, 21);
        break;
      case StickerSubject.flower:
        _line(
          c,
          [const Offset(0, 52), Offset(2 + a * 3, -4)],
          color: mint,
          width: 7,
        );
        _ellipse(c, const Rect.fromLTWH(-29, 16, 28, 14), mint);
        c.save();
        c.translate(2 + a * 3, -16);
        c.rotate(a * 0.16);
        for (var i = 0; i < 6; i++) {
          c.save();
          c.rotate(i * math.pi / 3);
          _ellipse(c, const Rect.fromLTWH(-16, -52, 32, 42), pink);
          c.restore();
        }
        _ellipse(c, const Rect.fromLTWH(-23, -23, 46, 46), gold);
        if (face) _face(c, const Offset(0, -3), gesture, blink, t, scale: 0.65);
        c.restore();
        showFace = false;
        break;
      case StickerSubject.umbrella:
        _stroke(
          c,
          Path()
            ..moveTo(0, -38)
            ..lineTo(0, 44)
            ..cubicTo(0, 65, 29, 61, 27, 43),
          color: ink,
          width: 4,
        );
        _shape(
          c,
          Path()
            ..moveTo(-63, -7)
            ..quadraticBezierTo(-49, -72, 0, -65)
            ..quadraticBezierTo(47, -71, 63, -7)
            ..quadraticBezierTo(42, -22, 21, -7)
            ..quadraticBezierTo(0, -22, -21, -7)
            ..quadraticBezierTo(-42, -22, -63, -7)
            ..close(),
          blue,
        );
        _stroke(
          c,
          Path()
            ..moveTo(0, -65)
            ..quadraticBezierTo(-24, -45, -21, -7)
            ..moveTo(0, -65)
            ..quadraticBezierTo(23, -43, 21, -7),
          color: cream,
          width: 2,
        );
        for (var i = 0; i < 4; i++) {
          final p = (t + i / 4) % 1;
          _line(
            c,
            [
              Offset(-65 + i * 42.0, -87 + p * 22),
              Offset(-67 + i * 42.0, -79 + p * 22),
            ],
            color: blue.withValues(alpha: math.sin(p * math.pi)),
            width: 3,
          );
        }
        showFace = false;
        break;
      case StickerSubject.tree:
        _rounded(c, const Rect.fromLTWH(-10, 29, 20, 33), gold, radius: 3);
        _shape(
          c,
          Path()
            ..moveTo(0, -65)
            ..lineTo(34, -18)
            ..lineTo(22, -18)
            ..lineTo(49, 17)
            ..lineTo(34, 17)
            ..lineTo(60, 48)
            ..lineTo(-60, 48)
            ..lineTo(-34, 17)
            ..lineTo(-49, 17)
            ..lineTo(-22, -18)
            ..lineTo(-34, -18)
            ..close(),
          mint,
        );
        for (var i = 0; i < 5; i++) {
          _ellipse(
            c,
            Rect.fromCircle(
              center: Offset(i.isEven ? -17 : 18, -19 + i * 14.0),
              radius: 4 + a * (i.isEven ? 1.5 : -1),
            ),
            i.isEven ? rose : gold,
            border: false,
          );
        }
        c.save();
        c.translate(0, -68);
        _shape(c, _star(13), gold);
        c.restore();
        showFace = false;
        break;
      case StickerSubject.lock:
        c.save();
        c.translate(0, -a * 8);
        _stroke(
          c,
          Path()
            ..moveTo(-28, -3)
            ..lineTo(-28, -30)
            ..cubicTo(-28, -73, 28, -73, 28, -30)
            ..lineTo(28, -3),
          color: gold,
          width: 11,
        );
        c.restore();
        _rounded(c, const Rect.fromLTWH(-47, -6, 94, 66), lilac, radius: 16);
        _ellipse(c, const Rect.fromLTWH(-7, 12, 14, 14), cream);
        _rounded(c, const Rect.fromLTWH(-3, 24, 6, 16), cream, radius: 2);
        showFace = false;
        break;
      case StickerSubject.wheel:
        _rounded(c, const Rect.fromLTWH(-28, 43, 56, 16), lilac, radius: 8);
        c.save();
        c.rotate(a * math.pi / 3);
        for (var i = 0; i < 8; i++) {
          final wedge = Path()
            ..moveTo(0, 0)
            ..arcTo(
              const Rect.fromLTWH(-51, -51, 102, 102),
              i * math.pi / 4,
              math.pi / 4,
              false,
            )
            ..close();
          _shape(c, wedge, [pink, cream, mint, lilac][i % 4]);
        }
        _ellipse(c, const Rect.fromLTWH(-10, -10, 20, 20), gold);
        c.restore();
        _shape(
          c,
          Path()
            ..moveTo(-8, -63)
            ..lineTo(8, -63)
            ..lineTo(0, -47)
            ..close(),
          rose,
        );
        showFace = false;
        break;
      case StickerSubject.film:
        _rounded(c, const Rect.fromLTWH(-54, -20, 108, 74), blue, radius: 10);
        c.save();
        c.translate(-53, -22);
        c.rotate(-a * 0.25);
        _rounded(c, const Rect.fromLTWH(0, -23, 108, 24), ink, radius: 5);
        for (var i = 0; i < 5; i++) {
          _shape(
            c,
            Path()
              ..moveTo(6 + i * 21.0, -23)
              ..lineTo(17 + i * 21.0, -23)
              ..lineTo(7 + i * 21.0, 0)
              ..lineTo(-4 + i * 21.0, 0)
              ..close(),
            cream,
            border: false,
          );
        }
        c.restore();
        _shape(
          c,
          Path()
            ..moveTo(-9, 0)
            ..lineTo(18, 17)
            ..lineTo(-9, 34)
            ..close(),
          cream,
        );
        showFace = false;
        break;
      case StickerSubject.calculator:
        _rounded(c, const Rect.fromLTWH(-42, -58, 84, 119), mint, radius: 13);
        _rounded(c, const Rect.fromLTWH(-30, -43, 60, 27), cream, radius: 6);
        _text(c, a > 0.5 ? '520' : '0', const Offset(3, -29), 19, ink);
        for (var i = 0; i < 9; i++) {
          _rounded(
            c,
            Rect.fromLTWH(-29 + i % 3 * 22, -2 + i ~/ 3 * 19, 14, 12),
            i == 8 ? rose : cream,
            radius: 3,
            border: false,
          );
        }
        showFace = false;
        break;
      case StickerSubject.wallet:
        _rounded(c, const Rect.fromLTWH(-53, -30, 106, 82), lilac, radius: 13);
        c.save();
        c.translate(0, -a * 12);
        _rounded(c, const Rect.fromLTWH(-37, -45, 74, 22), mint, radius: 3);
        _ellipse(c, const Rect.fromLTWH(-10, -41, 20, 16), cream);
        c.restore();
        _rounded(c, const Rect.fromLTWH(19, -1, 40, 27), pink, radius: 8);
        _ellipse(c, const Rect.fromLTWH(29, 7, 10, 10), gold);
        showFace = false;
        break;
      case StickerSubject.brush:
        _ellipse(c, const Rect.fromLTWH(-60, -39, 108, 90), cream);
        for (var i = 0; i < 5; i++) {
          final angle = i * 0.66 + 2.7;
          _ellipse(
            c,
            Rect.fromCircle(
              center: Offset(
                -5 + math.cos(angle) * 36,
                6 + math.sin(angle) * 29,
              ),
              radius: 8,
            ),
            [rose, gold, mint, blue, lilac][i],
            border: false,
          );
        }
        c.save();
        c.translate(25, 12);
        c.rotate(0.5 + a * 0.12);
        _rounded(c, const Rect.fromLTWH(-5, -39, 10, 85), rose, radius: 5);
        _shape(
          c,
          Path()
            ..moveTo(-8, -40)
            ..quadraticBezierTo(-12, -63, 3, -72)
            ..quadraticBezierTo(17, -43, 8, -40)
            ..close(),
          ink,
        );
        c.restore();
        showFace = false;
        break;
      case StickerSubject.health:
        _rounded(c, const Rect.fromLTWH(-52, -40, 104, 90), cream, radius: 18);
        _rounded(c, const Rect.fromLTWH(-23, -53, 46, 18), pink, radius: 8);
        _rounded(
          c,
          const Rect.fromLTWH(-7, -21, 14, 52),
          rose,
          radius: 3,
          border: false,
        );
        _rounded(
          c,
          const Rect.fromLTWH(-26, -2, 52, 14),
          rose,
          radius: 3,
          border: false,
        );
        _line(
          c,
          [
            const Offset(-62, 55),
            const Offset(-40, 55),
            Offset(-30, 55 - a * 12),
            const Offset(-20, 55),
            const Offset(0, 55),
          ],
          color: rose,
          width: 2,
        );
        showFace = false;
        break;
      case StickerSubject.tarot:
        for (final side in [-1, 1]) {
          c.save();
          c.translate(side * 18.0, 0);
          c.rotate(side * (0.2 + a * 0.06));
          _rounded(
            c,
            const Rect.fromLTWH(-35, -57, 70, 114),
            side == 1 ? lilac : pink,
            radius: 9,
          );
          _rounded(
            c,
            const Rect.fromLTWH(-29, -51, 58, 102),
            side == 1 ? lilac : pink,
            radius: 6,
          );
          c.save();
          c.scale(0.5);
          _shape(c, _star(42), gold);
          c.restore();
          c.restore();
        }
        showFace = false;
        break;
      case StickerSubject.telescope:
        _line(c, [const Offset(-7, 9), const Offset(-35, 59)], width: 5);
        _line(c, [const Offset(-7, 9), const Offset(30, 59)], width: 5);
        c.save();
        c.translate(-7, -8);
        c.rotate(-0.4 - a * 0.08);
        _rounded(c, const Rect.fromLTWH(-48, -20, 100, 39), blue, radius: 9);
        _rounded(c, const Rect.fromLTWH(39, -26, 15, 52), lilac, radius: 5);
        _rounded(c, const Rect.fromLTWH(-62, -8, 16, 17), lilac, radius: 4);
        c.restore();
        c.save();
        c.translate(57, -66);
        _shape(c, _star(10 + a * 2), gold);
        c.restore();
        showFace = false;
        break;
      case StickerSubject.cat:
      case StickerSubject.bunny:
      case StickerSubject.puppy:
      case StickerSubject.couple:
        _character(
          c,
          Offset.zero,
          0.8,
          subject == StickerSubject.couple ? StickerSubject.cat : subject,
          gesture,
          t,
        );
        showFace = false;
        break;
    }
    if (showFace)
      _face(
        c,
        faceAt,
        gesture,
        blink,
        t,
        scale: subject == StickerSubject.game ? 0.65 : 0.9,
      );
    c.restore();
  }

  void _objectArms(
    Canvas c,
    Color color,
    double activity,
    StickerGesture gesture,
  ) {
    for (final side in [-1, 1]) {
      c.save();
      c.translate(side * 39.0, 12);
      c.rotate(
        side *
            (gesture == StickerGesture.hug
                ? -0.9 - activity * 0.2
                : 0.4 + activity * 0.4),
      );
      _ellipse(c, const Rect.fromLTWH(-8, -3, 16, 30), color);
      c.restore();
    }
  }
}
