part of 'living_sticker_painter.dart';

/// Mỗi dịp có đường nét riêng; chỉ chi tiết nhỏ chuyển động, không đổi bố cục.
extension _StickerCelebrations on LivingStickerPainter {
  void _celebration(Canvas c, StickerSubject subject, double activity) {
    const cream = LivingStickerPainter.cream;
    const rose = LivingStickerPainter.rose;
    const pink = LivingStickerPainter.pink;
    const gold = LivingStickerPainter.gold;
    const mint = LivingStickerPainter.mint;
    const lilac = LivingStickerPainter.lilac;
    const blue = LivingStickerPainter.blue;
    const orange = Color(0xFFF3AA71);
    switch (subject) {
      case StickerSubject.pumpkin:
        _shape(c, Path()..moveTo(-6, -37)..lineTo(-2, -66)..lineTo(13, -59)..lineTo(7, -34)..close(), mint);
        for (final x in [-24.0, 24.0, 0.0]) {
          _ellipse(c, Rect.fromCenter(center: Offset(x, 0), width: 59, height: 85), orange);
        }
        _festivalFace(c, const Offset(0, 8));
        _line(c, [const Offset(14, -47), const Offset(29, -58), Offset(37, -52 - activity * 4)], color: mint, width: 4);
        break;
      case StickerSubject.lantern:
        _line(c, [const Offset(0, -65), const Offset(0, -49)], width: 3);
        _ellipse(c, const Rect.fromLTWH(-49, -46, 98, 85), rose);
        _ellipse(c, const Rect.fromLTWH(-25, -46, 50, 85), pink);
        _rounded(c, const Rect.fromLTWH(-29, -52, 58, 12), gold, radius: 4);
        _rounded(c, const Rect.fromLTWH(-24, 34, 48, 10), gold, radius: 4);
        for (var x = -10.0; x <= 10; x += 5) {
          _line(c, [Offset(x, 44), Offset(x + activity * 4, 63)], color: rose, width: 3);
        }
        _festivalFace(c, const Offset(0, 0));
        break;
      case StickerSubject.stocking:
        _shape(c, Path()..moveTo(-28, -47)..lineTo(28, -47)..lineTo(28, 17)..cubicTo(63, 17, 64, 56, 26, 56)..lineTo(-10, 56)..quadraticBezierTo(-32, 54, -28, 24)..close(), rose);
        _rounded(c, const Rect.fromLTWH(-35, -54, 70, 24), cream, radius: 9);
        _ellipse(c, const Rect.fromLTWH(24, 22, 29, 29), cream);
        _festivalFace(c, const Offset(0, -5));
        _text(c, '♥', const Offset(0, 30), 22, cream);
        break;
      case StickerSubject.fireworks:
        for (var i = 0; i < 3; i++) {
          c.save();
          c.translate([-29.0, 30.0, 4.0][i], [-27.0, -17.0, 30.0][i]);
          final color = [rose, lilac, gold][i];
          for (var ray = 0; ray < 10; ray++) {
            final angle = ray * math.pi / 5;
            final d = Offset(math.cos(angle), math.sin(angle));
            _line(c, [d * 17, d * (29 + activity * 5)], color: color, width: 4);
          }
          _shape(c, _star(12), color);
          c.restore();
        }
        break;
      case StickerSubject.balloons:
        for (var i = 0; i < 3; i++) {
          final x = (i - 1) * 32.0;
          final y = i == 1 ? -33.0 : -16.0;
          _stroke(c, Path()..moveTo(x, y + 29)..quadraticBezierTo(x - 8 + activity * 4, 40, 0, 60));
          _ellipse(c, Rect.fromCenter(center: Offset(x, y), width: 45, height: 59), [lilac, pink, gold][i]);
          _ellipse(c, Rect.fromLTWH(x - 12, y - 18, 8, 14), cream, border: false);
          _shape(c, Path()..moveTo(x, y + 29)..lineTo(x - 4, y + 35)..lineTo(x + 4, y + 35)..close(), rose);
        }
        _text(c, '♥', const Offset(0, 54), 20, rose);
        break;
      case StickerSubject.fish:
        _shape(c, Path()..moveTo(-20, 0)..lineTo(-61, -29)..quadraticBezierTo(-47, 0, -61, 29)..close(), orange);
        _ellipse(c, const Rect.fromLTWH(-35, -33, 89, 66), blue);
        _shape(c, Path()..moveTo(-4, -29)..lineTo(11, -48)..lineTo(26, -26)..close(), mint);
        _shape(c, Path()..moveTo(-3, 3)..quadraticBezierTo(-23, 30, 18, 24)..close(), mint);
        _ellipse(c, const Rect.fromCircle(center: Offset(29, -7), radius: 4), LivingStickerPainter.ink, border: false);
        _ellipse(c, const Rect.fromCircle(center: Offset(51, -47), radius: 6), cream);
        _ellipse(c, Rect.fromCircle(center: Offset(41, -60 - activity * 3), radius: 3), blue);
        break;
      case StickerSubject.rings:
        for (final x in [-21.0, 21.0]) {
          final path = Path()..addOval(Rect.fromCenter(center: Offset(x, 5), width: 59, height: 66));
          _stroke(c, path, width: 10);
          _stroke(c, path, color: gold, width: 6);
        }
        _shape(c, Path()..moveTo(8, -32)..lineTo(15, -44)..lineTo(29, -44)..lineTo(37, -32)..lineTo(22, -18)..close(), blue);
        _line(c, [const Offset(8, -32), const Offset(37, -32)], color: Colors.white);
        _text(c, '♥', Offset(-23, -42 - activity * 3), 24, rose);
        break;
      case StickerSubject.bouquet:
        _shape(c, Path()..moveTo(-45, -8)..lineTo(45, -8)..lineTo(10, 61)..lineTo(-10, 61)..close(), cream);
        for (var i = 0; i < 3; i++) {
          final x = (i - 1) * 29.0;
          final y = i == 1 ? -40.0 : -23.0;
          _line(c, [Offset(x, y), const Offset(0, 39)], color: mint, width: 4);
          for (var p = 0; p < 5; p++) {
            final angle = p * math.pi * 2 / 5;
            _ellipse(c, Rect.fromCircle(center: Offset(x + math.sin(angle) * 12, y + math.cos(angle) * 12), radius: 11), [pink, lilac, rose][i]);
          }
          _ellipse(c, Rect.fromCircle(center: Offset(x, y), radius: 7), gold);
        }
        _shape(c, Path()..moveTo(0, 34)..quadraticBezierTo(-29, 15, -23, 42)..close(), rose);
        _shape(c, Path()..moveTo(0, 34)..quadraticBezierTo(29, 15, 23, 42)..close(), pink);
        _ellipse(c, const Rect.fromCircle(center: Offset(0, 34), radius: 6), gold);
        break;
      case StickerSubject.chocolateBox:
        _shape(c, _heart(), rose);
        c.save();
        c.scale(.81);
        _shape(c, _heart(), cream);
        c.restore();
        for (final offset in [const Offset(-20, -15), const Offset(20, -15), const Offset(0, 15)]) {
          _rounded(c, Rect.fromCenter(center: offset, width: 25, height: 23), const Color(0xFFAA7967), radius: 6);
          _line(c, [offset + const Offset(-6, -2), offset + const Offset(6, 2)], color: cream, width: 2);
        }
        break;
      case StickerSubject.redEnvelope:
        _rounded(c, const Rect.fromLTWH(-37, -55, 74, 111), rose, radius: 13);
        _shape(c, Path()..moveTo(-36, -35)..quadraticBezierTo(0, 2, 36, -35)..lineTo(36, -49)..lineTo(-36, -49)..close(), pink);
        _ellipse(c, const Rect.fromCircle(center: Offset(0, 6), radius: 22), gold);
        _text(c, '♥', const Offset(0, 6), 27, rose);
        _line(c, [const Offset(-22, 41), const Offset(22, 41)], color: gold, width: 3);
        break;
      case StickerSubject.mooncake:
        for (var i = 0; i < 12; i++) {
          final angle = i * math.pi / 6;
          _ellipse(c, Rect.fromCircle(center: Offset(math.cos(angle) * 35, math.sin(angle) * 35), radius: 15), orange);
        }
        _ellipse(c, const Rect.fromCircle(center: Offset.zero, radius: 38), gold);
        _ellipse(c, const Rect.fromCircle(center: Offset.zero, radius: 29), cream);
        _text(c, '♥', const Offset(0, -4), 39, orange);
        _line(c, [const Offset(-12, 17), const Offset(12, 17)], color: orange);
        break;
      case StickerSubject.trophy:
        for (final x in [-31.0, 31.0]) {
          _stroke(c, Path()..addOval(Rect.fromCenter(center: Offset(x, -19), width: 40, height: 45)), color: gold, width: 9);
        }
        _rounded(c, const Rect.fromLTWH(-7, 12, 14, 36), gold, radius: 3);
        _shape(c, Path()..moveTo(-33, -48)..lineTo(33, -48)..lineTo(27, 2)..quadraticBezierTo(0, 35, -27, 2)..close(), gold);
        _rounded(c, const Rect.fromLTWH(-30, 42, 60, 17), lilac, radius: 6);
        c.save();
        c.translate(0, -19);
        _shape(c, _star(17), cream);
        c.restore();
        break;
      default:
        break;
    }
  }

  void _festivalFace(Canvas c, Offset center) {
    for (final x in [-12.0, 12.0]) {
      _ellipse(c, Rect.fromCircle(center: center + Offset(x, -5), radius: 2.8), LivingStickerPainter.ink, border: false);
      _ellipse(c, Rect.fromCenter(center: center + Offset(x * 1.5, 4), width: 10, height: 5), LivingStickerPainter.pink, border: false);
    }
    _stroke(c, Path()..moveTo(center.dx - 5, center.dy + 3)..quadraticBezierTo(center.dx, center.dy + 10, center.dx + 5, center.dy + 3), width: 1.8);
  }
}
