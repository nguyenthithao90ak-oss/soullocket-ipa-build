import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/tarot_models.dart';

/// Artwork vector của SoulLocket; mỗi bộ và số lá có bố cục riêng.
class TarotArtwork extends StatelessWidget {
  final TarotCard? card;
  final bool back;
  final double width;
  const TarotArtwork({
    super.key,
    this.card,
    this.back = false,
    this.width = 120,
  });
  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: SizedBox(
      width: width,
      height: width * 1.54,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(width * .075),
        child: CustomPaint(
          painter: TarotIllustrationPainter(card: card, back: back),
        ),
      ),
    ),
  );
}

class TarotIllustrationPainter extends CustomPainter {
  final TarotCard? card;
  final bool back;
  const TarotIllustrationPainter({this.card, this.back = false});
  static const ink = Color(0xFF40375D), gold = Color(0xFFC29552);
  Paint line([Color color = ink, double width = 1.3]) => Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round;
  @override
  void paint(Canvas c, Size s) {
    c.save();
    c.scale(s.width / 200, s.height / 308);
    final tint = switch (card?.suit) {
      TarotSuit.cups => const Color(0xFFE5B7AD),
      TarotSuit.wands => const Color(0xFFE8C592),
      TarotSuit.swords => const Color(0xFFBDBBD7),
      TarotSuit.pentacles => const Color(0xFFB9C5A2),
      _ => const Color(0xFFD1C1E5),
    };
    const rect = Rect.fromLTWH(0, 0, 200, 308);
    c.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: back
              ? const [Color(0xFF302846), Color(0xFF655083)]
              : [const Color(0xFFF9F1E1), tint],
        ).createShader(rect),
    );
    c.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(9, 9, 182, 290),
        const Radius.circular(10),
      ),
      line(back ? const Color(0xFFE7CD9D) : gold),
    );
    c.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(14, 14, 172, 280),
        const Radius.circular(7),
      ),
      line(gold.withValues(alpha: .4), .6),
    );
    final random = math.Random((card?.number ?? 7) + 91);
    for (var i = 0; i < 14; i++) {
      final o = Offset(
        25 + random.nextDouble() * 150,
        30 + random.nextDouble() * 205,
      );
      if (i % 3 == 0) {
        spark(c, o, 3, back ? gold : tint);
      } else {
        c.drawCircle(o, .8, Paint()..color = gold.withValues(alpha: .7));
      }
    }
    if (back) {
      backArt(c);
    } else {
      final arch = Path()
        ..moveTo(28, 243)
        ..lineTo(28, 115)
        ..arcToPoint(const Offset(172, 115), radius: const Radius.circular(72))
        ..lineTo(172, 243)
        ..close();
      c.drawPath(arch, Paint()..color = Colors.white.withValues(alpha: .32));
      c.drawPath(arch, line(ink.withValues(alpha: .24), .8));
      if (card!.isMajor) {
        major(c, card!.id);
      } else {
        minor(c, card!);
      }
      branch(c, const Offset(30, 243), false);
      branch(c, const Offset(170, 243), true);
      c.drawLine(
        const Offset(24, 262),
        const Offset(176, 262),
        line(gold.withValues(alpha: .6), .7),
      );
    }
    c.restore();
  }

  void spark(Canvas c, Offset o, double r, Color color) {
    final p = Path()
      ..moveTo(o.dx, o.dy - r)
      ..quadraticBezierTo(o.dx + r * .12, o.dy - r * .12, o.dx + r, o.dy)
      ..quadraticBezierTo(o.dx + r * .12, o.dy + r * .12, o.dx, o.dy + r)
      ..quadraticBezierTo(o.dx - r * .12, o.dy + r * .12, o.dx - r, o.dy)
      ..quadraticBezierTo(o.dx - r * .12, o.dy - r * .12, o.dx, o.dy - r)
      ..close();
    c.drawPath(p, Paint()..color = color);
  }

  void moon(Canvas c, Offset o, double r) {
    c.saveLayer(Rect.fromCircle(center: o, radius: r + 2), Paint());
    c.drawCircle(o, r, Paint()..color = const Color(0xFFE8C582));
    c.drawCircle(
      o + Offset(r * .5, -r * .22),
      r * .85,
      Paint()..blendMode = BlendMode.clear,
    );
    c.restore();
  }

  void sun(Canvas c, Offset o, double r) {
    for (var i = 0; i < 12; i++) {
      final a = i * math.pi / 6;
      c.drawLine(
        o + Offset(math.cos(a), math.sin(a)) * (r + 5),
        o + Offset(math.cos(a), math.sin(a)) * (r + 14),
        line(gold),
      );
    }
    c.drawCircle(o, r, Paint()..color = const Color(0xFFEED298));
    c.drawCircle(o, r, line(gold));
    c.drawCircle(o + const Offset(-7, -2), 1.3, Paint()..color = ink);
    c.drawCircle(o + const Offset(7, -2), 1.3, Paint()..color = ink);
    c.drawArc(
      Rect.fromCenter(center: o + const Offset(0, 4), width: 16, height: 8),
      0,
      math.pi,
      false,
      line(),
    );
  }

  void heart(Canvas c, Offset o, double r) {
    final p = Path()
      ..moveTo(o.dx, o.dy + r * .7)
      ..cubicTo(
        o.dx - r * 1.4,
        o.dy - r * .15,
        o.dx - r * .85,
        o.dy - r * 1.25,
        o.dx,
        o.dy - r * .4,
      )
      ..cubicTo(
        o.dx + r * .85,
        o.dy - r * 1.25,
        o.dx + r * 1.4,
        o.dy - r * .15,
        o.dx,
        o.dy + r * .7,
      )
      ..close();
    c.drawPath(
      p,
      Paint()..color = const Color(0xFFC78F9A).withValues(alpha: .45),
    );
    c.drawPath(p, line(ink, 1.5));
  }

  void branch(Canvas c, Offset o, bool mirrored) {
    c.save();
    c.translate(o.dx, o.dy);
    if (mirrored) c.scale(-1, 1);
    c.drawPath(
      Path()
        ..moveTo(0, 0)
        ..quadraticBezierTo(20, -17, 9, -55),
      line(ink.withValues(alpha: .5), .9),
    );
    for (var i = 0; i < 5; i++) {
      final y = -8.0 - i * 9, x = math.sin(i * .5) * 9;
      c.drawOval(
        Rect.fromCenter(center: Offset(x + 3, y - 3), width: 4, height: 10),
        line(ink.withValues(alpha: .45), .8),
      );
    }
    c.restore();
  }

  void cup(Canvas c, Offset o, double r) {
    final p = Path()
      ..moveTo(o.dx - r, o.dy - r * .6)
      ..lineTo(o.dx + r, o.dy - r * .6)
      ..quadraticBezierTo(o.dx + r * .8, o.dy + r * .5, o.dx, o.dy + r * .45)
      ..quadraticBezierTo(o.dx - r * .8, o.dy + r * .5, o.dx - r, o.dy - r * .6)
      ..close();
    c.drawPath(p, Paint()..color = Colors.white.withValues(alpha: .55));
    c.drawPath(p, line());
    c.drawLine(o + Offset(0, r * .45), o + Offset(0, r), line());
    c.drawLine(o + Offset(-r * .65, r), o + Offset(r * .65, r), line());
    c.drawOval(
      Rect.fromCenter(
        center: o + Offset(0, -r * .58),
        width: r * 2,
        height: r * .35,
      ),
      line(gold),
    );
  }

  void wand(Canvas c, Offset o, double r) {
    c.drawLine(o + Offset(-r * .12, r), o + Offset(r * .12, -r), line(ink, 2));
    c.drawOval(
      Rect.fromCenter(
        center: o + Offset(r * .4, -r * .3),
        width: r * .7,
        height: r * .35,
      ),
      Paint()..color = const Color(0xFF8C9D82),
    );
    c.drawOval(
      Rect.fromCenter(
        center: o + Offset(-r * .3, r * .3),
        width: r * .6,
        height: r * .3,
      ),
      Paint()..color = const Color(0xFF8C9D82),
    );
  }

  void sword(Canvas c, Offset o, double r) {
    final p = Path()
      ..moveTo(o.dx, o.dy - r * 1.3)
      ..lineTo(o.dx + r * .23, o.dy + r * .3)
      ..lineTo(o.dx - r * .23, o.dy + r * .3)
      ..close();
    c.drawPath(p, Paint()..color = Colors.white.withValues(alpha: .8));
    c.drawPath(p, line());
    c.drawLine(
      o + Offset(-r * .5, r * .35),
      o + Offset(r * .5, r * .35),
      line(),
    );
    c.drawLine(o + Offset(0, r * .4), o + Offset(0, r * .9), line());
  }

  void coin(Canvas c, Offset o, double r) {
    c.drawCircle(o, r, Paint()..color = const Color(0xFFE6D099));
    c.drawCircle(o, r, line());
    final points = [
      for (var i = 0; i < 5; i++)
        o +
            Offset(
                  math.cos(-math.pi / 2 + i * math.pi * 2 / 5),
                  math.sin(-math.pi / 2 + i * math.pi * 2 / 5),
                ) *
                r *
                .72,
    ];
    final p = Path()..moveTo(points.first.dx, points.first.dy);
    for (final i in [2, 4, 1, 3, 0]) {
      p.lineTo(points[i].dx, points[i].dy);
    }
    c.drawPath(p, line(ink, .7));
  }

  void crown(Canvas c, Offset o, double r) {
    final p = Path()
      ..moveTo(o.dx - r, o.dy)
      ..lineTo(o.dx - r * 1.1, o.dy - r * .85)
      ..lineTo(o.dx - r * .35, o.dy - r * .3)
      ..lineTo(o.dx, o.dy - r * 1.1)
      ..lineTo(o.dx + r * .35, o.dy - r * .3)
      ..lineTo(o.dx + r * 1.1, o.dy - r * .85)
      ..lineTo(o.dx + r, o.dy)
      ..close();
    c.drawPath(p, Paint()..color = const Color(0xFFE8C582));
    c.drawPath(p, line());
  }

  void backArt(Canvas c) {
    c.drawCircle(const Offset(100, 150), 54, line(gold));
    c.drawCircle(const Offset(100, 150), 63, line(gold.withValues(alpha: .35)));
    c.drawPath(
      Path()
        ..moveTo(100, 64)
        ..lineTo(163, 150)
        ..lineTo(100, 236)
        ..lineTo(37, 150)
        ..close(),
      line(gold.withValues(alpha: .5)),
    );
    moon(c, const Offset(100, 140), 25);
    spark(c, const Offset(100, 200), 9, gold);
    for (final y in [40.0, 270.0]) {
      spark(c, Offset(100, y), 6, gold);
    }
  }

  void minor(Canvas c, TarotCard v) {
    final count = v.number > 10 ? 1 : v.number;
    if (v.number > 10) {
      crown(c, const Offset(100, 97), 20);
      spark(c, const Offset(100, 222), v.number.toDouble() - 6, gold);
    }
    final columns = count == 1
        ? 1
        : count < 5
        ? 2
        : 3;
    final rows = (count / columns).ceil();
    for (var i = 0; i < count; i++) {
      final x = columns == 1
          ? 100.0
          : 100 + (i % columns - (columns - 1) / 2) * 35;
      final y = count == 1 ? 158.0 : 156 + (i ~/ columns - (rows - 1) / 2) * 30;
      final r = count == 1 ? 28.0 : 10.5;
      final o = Offset(x, y);
      switch (v.suit) {
        case TarotSuit.cups:
          cup(c, o, r);
        case TarotSuit.wands:
          wand(c, o, r);
        case TarotSuit.swords:
          sword(c, o, r);
        case TarotSuit.pentacles:
          coin(c, o, r);
        case TarotSuit.major:
          break;
      }
    }
  }

  void major(Canvas c, String id) {
    const center = Offset(100, 149);
    switch (id) {
      case 'sun':
        sun(c, center, 32);
        break;
      case 'moon':
        moon(c, const Offset(100, 120), 30);
        for (var i = 0; i < 3; i++) {
          c.drawArc(
            Rect.fromLTWH(60, 182 + i * 12, 80, 25),
            math.pi,
            math.pi,
            false,
            line(),
          );
        }
        break;
      case 'star':
        spark(c, const Offset(100, 131), 37, gold);
        spark(c, const Offset(62, 190), 9, ink);
        spark(c, const Offset(133, 199), 12, gold);
        break;
      case 'lovers':
        heart(c, center, 37);
        c.drawCircle(const Offset(66, 209), 13, line());
        c.drawCircle(const Offset(134, 209), 13, line());
        break;
      case 'empress':
        crown(c, const Offset(100, 128), 31);
        heart(c, const Offset(100, 190), 21);
        break;
      case 'emperor':
        crown(c, const Offset(100, 111), 26);
        c.drawPath(
          Path()
            ..moveTo(69, 143)
            ..lineTo(131, 143)
            ..lineTo(131, 177)
            ..quadraticBezierTo(100, 225, 69, 177)
            ..close(),
          line(),
        );
        break;
      case 'magician':
        spark(c, const Offset(100, 109), 25, gold);
        wand(c, const Offset(100, 179), 34);
        c.drawOval(const Rect.fromLTWH(46, 221, 108, 8), line());
        break;
      case 'priestess':
        moon(c, const Offset(100, 111), 23);
        for (final x in [49.0, 139.0]) {
          c.drawRect(Rect.fromLTWH(x, 143, 12, 85), line());
        }
        spark(c, const Offset(100, 203), 21, ink);
        break;
      case 'justice':
        c.drawLine(const Offset(100, 104), const Offset(100, 224), line());
        c.drawLine(const Offset(53, 129), const Offset(147, 129), line());
        for (final x in [57.0, 143.0]) {
          c.drawLine(Offset(x, 129), Offset(x - 18, 173), line());
          c.drawLine(Offset(x, 129), Offset(x + 18, 173), line());
          c.drawArc(
            Rect.fromCenter(center: Offset(x, 173), width: 40, height: 22),
            0,
            math.pi,
            false,
            line(),
          );
        }
        break;
      case 'hermit':
        c.drawLine(const Offset(100, 95), const Offset(100, 126), line());
        c.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(73, 128, 54, 74),
            const Radius.circular(8),
          ),
          line(),
        );
        spark(c, const Offset(100, 160), 15, gold);
        break;
      case 'tower':
        c.drawRect(const Rect.fromLTWH(77, 133, 46, 92), line());
        c.drawPath(
          Path()
            ..moveTo(112, 87)
            ..lineTo(86, 126)
            ..lineTo(109, 122)
            ..lineTo(93, 163),
          line(gold, 3),
        );
        spark(c, const Offset(144, 179), 9, gold);
        break;
      case 'death':
        for (final mirrored in [false, true]) {
          c.save();
          c.translate(100, 155);
          if (mirrored) c.scale(-1, 1);
          c.drawPath(
            Path()
              ..moveTo(0, 0)
              ..cubicTo(70, -76, 56, -13, 20, 2)
              ..cubicTo(63, 27, 24, 49, 0, 10),
            line(),
          );
          c.restore();
        }
        c.drawLine(const Offset(100, 139), const Offset(100, 183), line());
        break;
      case 'temperance':
        cup(c, const Offset(74, 132), 17);
        cup(c, const Offset(126, 189), 17);
        c.drawPath(
          Path()
            ..moveTo(87, 143)
            ..quadraticBezierTo(110, 143, 119, 174),
          line(gold),
        );
        break;
      case 'devil':
        for (var i = 0; i < 5; i++) {
          c.drawOval(
            Rect.fromCenter(
              center: Offset(70 + i * 15, 117 + i * 20),
              width: 22,
              height: 34,
            ),
            line(),
          );
        }
        break;
      case 'world':
        c.drawOval(const Rect.fromLTWH(57, 91, 86, 135), line(gold));
        c.drawCircle(center, 28, line());
        c.drawOval(const Rect.fromLTWH(87, 121, 26, 56), line());
        c.drawLine(const Offset(72, 149), const Offset(128, 149), line());
        break;
      case 'wheel':
        c.drawCircle(center, 43, line());
        c.drawCircle(center, 29, line(gold));
        for (var i = 0; i < 8; i++) {
          final a = i * math.pi / 4;
          c.drawLine(
            center,
            center + Offset(math.cos(a), math.sin(a)) * 43,
            line(gold),
          );
        }
        break;
      case 'strength':
        c.drawCircle(center, 44, line(gold));
        c.drawCircle(center, 27, line());
        c.drawCircle(center + const Offset(-8, -7), 2, Paint()..color = ink);
        c.drawCircle(center + const Offset(8, -7), 2, Paint()..color = ink);
        heart(c, const Offset(100, 211), 9);
        break;
      case 'chariot':
        c.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(54, 118, 92, 64),
            const Radius.circular(9),
          ),
          line(),
        );
        c.drawCircle(const Offset(66, 191), 17, line());
        c.drawCircle(const Offset(134, 191), 17, line());
        spark(c, const Offset(100, 101), 12, gold);
        break;
      case 'hanged':
        c.drawLine(const Offset(55, 106), const Offset(145, 106), line());
        c.drawLine(const Offset(100, 106), const Offset(100, 178), line());
        c.drawCircle(const Offset(100, 199), 15, line());
        c.drawLine(const Offset(100, 136), const Offset(127, 152), line());
        break;
      case 'hierophant':
        c.drawCircle(const Offset(100, 123), 26, line(gold));
        c.drawLine(const Offset(100, 105), const Offset(100, 203), line());
        c.drawLine(const Offset(77, 126), const Offset(123, 126), line());
        for (final x in [76.0, 124.0]) {
          c.drawCircle(Offset(x, 211), 10, line());
        }
        break;
      case 'judgement':
        c.drawPath(
          Path()
            ..moveTo(54, 139)
            ..lineTo(111, 139)
            ..lineTo(151, 121)
            ..lineTo(151, 185)
            ..lineTo(111, 167)
            ..lineTo(54, 167)
            ..close(),
          line(),
        );
        spark(c, const Offset(100, 100), 12, gold);
        break;
      default:
        c.drawPath(
          Path()
            ..moveTo(44, 227)
            ..lineTo(83, 176)
            ..lineTo(110, 209)
            ..lineTo(151, 150)
            ..lineTo(157, 227)
            ..close(),
          line(),
        );
        sun(c, const Offset(85, 111), 17);
    }
  }

  @override
  bool shouldRepaint(covariant TarotIllustrationPainter old) =>
      old.card?.id != card?.id || old.back != back;
}
