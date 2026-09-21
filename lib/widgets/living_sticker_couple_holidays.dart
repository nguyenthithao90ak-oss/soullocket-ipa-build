part of 'living_sticker_painter.dart';

/// Đạo cụ riêng cho lễ cặp đôi; giữ khung cố định và nền trong suốt.
extension _CoupleHolidayArt on LivingStickerPainter {
  void _coupleHoliday(Canvas c, StickerSubject subject, double activity) {
    const rose = LivingStickerPainter.rose;
    const pink = LivingStickerPainter.pink;
    const cream = LivingStickerPainter.cream;
    const mint = LivingStickerPainter.mint;
    const gold = LivingStickerPainter.gold;
    const blue = LivingStickerPainter.blue;
    const lilac = LivingStickerPainter.lilac;
    switch (subject) {
      case StickerSubject.roseStem:
        _line(
          c,
          [const Offset(0, -15), const Offset(0, 58)],
          color: mint,
          width: 7,
        );
        for (final side in [-1.0, 1.0]) {
          _shape(
            c,
            Path()
              ..moveTo(0, 26)
              ..quadraticBezierTo(side * 44, -4, side * 39, 22)
              ..quadraticBezierTo(side * 22, 40, 0, 26),
            mint,
          );
        }
        for (var i = 0; i < 6; i++) {
          final angle = i * math.pi / 3;
          _ellipse(
            c,
            Rect.fromCircle(
              center: Offset(math.sin(angle) * 19, -31 + math.cos(angle) * 19),
              radius: 22,
            ),
            i.isEven ? rose : pink,
          );
        }
        _ellipse(c, const Rect.fromLTWH(-18, -48, 36, 34), rose);
        _stroke(
          c,
          Path()
            ..moveTo(-10, -34)
            ..cubicTo(-2, -47, 19, -31, 4, -24)
            ..quadraticBezierTo(-7, -19, -8, -28),
          color: cream,
          width: 3,
        );
        break;
      case StickerSubject.silverRings:
        for (final x in [-22.0, 22.0]) {
          final ring = Path()
            ..addOval(
              Rect.fromCenter(center: Offset(x, 8), width: 58, height: 67),
            );
          _stroke(c, ring, width: 11);
          _stroke(c, ring, color: const Color(0xFFC1CDD9), width: 7);
          _stroke(
            c,
            Path()
              ..moveTo(x - 18, -8)
              ..quadraticBezierTo(x - 9, -20, x + 5, -19),
            color: Colors.white,
            width: 3,
          );
        }
        _shape(
          c,
          Path()
            ..moveTo(7, -33)
            ..lineTo(17, -48)
            ..lineTo(29, -48)
            ..lineTo(39, -33)
            ..lineTo(23, -18)
            ..close(),
          lilac,
        );
        _line(c, [const Offset(7, -33), const Offset(39, -33)], color: cream);
        break;
      case StickerSubject.wineGlasses:
        for (final side in [-1.0, 1.0]) {
          c.save();
          c.translate(side * 29, 0);
          c.rotate(side * (-.13 - activity * .07));
          _line(
            c,
            [const Offset(0, 2), const Offset(0, 49)],
            color: blue,
            width: 5,
          );
          _ellipse(c, const Rect.fromLTWH(-22, 44, 44, 10), blue);
          _shape(
            c,
            Path()
              ..moveTo(-23, -48)
              ..lineTo(23, -48)
              ..lineTo(23, -18)
              ..cubicTo(23, 13, -23, 13, -23, -18)
              ..close(),
            const Color(0xFFF2F9FB),
          );
          _shape(
            c,
            Path()
              ..moveTo(-18, -23)
              ..lineTo(18, -23)
              ..cubicTo(21, 6, -21, 6, -18, -23)
              ..close(),
            rose,
            border: false,
          );
          _line(
            c,
            [const Offset(-14, -41), const Offset(-14, -30)],
            color: Colors.white,
            width: 4,
          );
          c.restore();
        }
        break;
      case StickerSubject.biscuitSticks:
        for (var i = 0; i < 4; i++) {
          c.save();
          c.translate((i - 1.5) * 23, 0);
          c.rotate((i - 1.5) * .13);
          _rounded(c, const Rect.fromLTWH(-8, -61, 16, 119), gold, radius: 7);
          _rounded(
            c,
            const Rect.fromLTWH(-9, -62, 18, 82),
            i.isEven ? const Color(0xFF976B64) : pink,
            radius: 7,
          );
          for (var n = 0; n < 5; n++) {
            _line(
              c,
              [Offset(-3, -49 + n * 13.0), Offset(3, -46 + n * 13.0)],
              color: cream,
              width: 2,
            );
          }
          c.restore();
        }
        _rounded(c, const Rect.fromLTWH(-48, 20, 96, 14), lilac, radius: 5);
        break;
      case StickerSubject.wishBamboo:
        _line(
          c,
          [const Offset(0, 61), const Offset(0, -63)],
          color: mint,
          width: 7,
        );
        for (var i = 0; i < 3; i++) {
          final y = -42 + i * 30.0;
          final side = i.isEven ? -1.0 : 1.0;
          _line(
            c,
            [Offset(0, y + 14), Offset(side * 45, y - 9)],
            color: mint,
            width: 4,
          );
          _shape(
            c,
            Path()
              ..moveTo(side * 16, y + 4)
              ..quadraticBezierTo(side * 31, y - 28, side * 53, y - 20)
              ..quadraticBezierTo(side * 40, y, side * 16, y + 4),
            mint,
          );
          _line(c, [
            Offset(side * 32, y - 2),
            Offset(side * 32, y + 10),
          ], width: 1.5);
          _rounded(
            c,
            Rect.fromLTWH(side * 32 - 9, y + 10, 18, 32),
            [pink, blue, gold][i],
            radius: 2,
          );
          _line(
            c,
            [Offset(side * 32, y + 17), Offset(side * 32, y + 31)],
            color: cream,
            width: 2,
          );
        }
        break;
      case StickerSubject.lotusCandle:
        _ellipse(c, const Rect.fromLTWH(-58, 36, 116, 18), blue, border: false);
        _rounded(c, const Rect.fromLTWH(-9, -37, 18, 59), cream, radius: 5);
        _shape(
          c,
          Path()
            ..moveTo(0, -66 - activity * 4)
            ..cubicTo(22, -44, 7, -30, 0, -39)
            ..cubicTo(-17, -36, -12, -51, 0, -66 - activity * 4),
          gold,
        );
        for (final side in [-1.0, 1.0]) {
          _shape(
            c,
            Path()
              ..moveTo(0, 41)
              ..quadraticBezierTo(side * 58, 51, side * 54, 0)
              ..quadraticBezierTo(side * 25, -2, 0, 41),
            mint,
          );
          _shape(
            c,
            Path()
              ..moveTo(0, 39)
              ..quadraticBezierTo(side * 51, 28, side * 31, -17)
              ..quadraticBezierTo(side * 9, -5, 0, 39),
            pink,
          );
        }
        _shape(
          c,
          Path()
            ..moveTo(0, -17)
            ..cubicTo(36, 12, 17, 43, 0, 45)
            ..cubicTo(-23, 31, -28, 11, 0, -17),
          rose,
        );
        break;
      case StickerSubject.chamomile:
        _line(
          c,
          [const Offset(0, 8), const Offset(0, 62)],
          color: mint,
          width: 6,
        );
        _shape(
          c,
          Path()
            ..moveTo(0, 42)
            ..quadraticBezierTo(24, 4, 40, 20)
            ..quadraticBezierTo(27, 47, 0, 42),
          mint,
        );
        for (var i = 0; i < 10; i++) {
          c.save();
          c.translate(0, -18);
          c.rotate(i * math.pi / 5);
          _ellipse(
            c,
            const Rect.fromLTWH(-10, -45, 20, 37),
            const Color(0xFFFFFDFA),
          );
          c.restore();
        }
        _ellipse(
          c,
          Rect.fromCircle(center: const Offset(0, -18), radius: 19),
          gold,
        );
        _festivalFace(c, const Offset(0, -19));
        break;
      default:
        break;
    }
  }
}
