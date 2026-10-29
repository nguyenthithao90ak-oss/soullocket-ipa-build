import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../views/home/tabs/pet_care/pet_care_outfit.dart';

/// Nét quần áo dùng chung cho bé trên Home, trong Trạm Mây và ô tủ đồ.
/// Tọa độ theo sprite gốc: chân (0, 0), cổ (0, -31), đỉnh đầu (0, -68).
abstract final class PetCareOutfitArt {
  static const _ink = Color(0xFF846B79);
  static const _cream = Color(0xFFFFFAED);
  static const _gold = Color(0xFFE9BC5C);

  static Color color(PetCareOutfit outfit, {required bool isBear}) =>
      switch (outfit) {
        PetCareOutfit.bare =>
          isBear ? const Color(0xFF7DAEB9) : const Color(0xFFCF718B),
        PetCareOutfit.cloud => const Color(0xFFA5CDE8),
        PetCareOutfit.strawberry => const Color(0xFFEA839C),
        PetCareOutfit.honey => const Color(0xFFE5B34D),
        PetCareOutfit.sailor => const Color(0xFF6D9CC6),
        PetCareOutfit.raincoat => const Color(0xFFF2CF58),
        PetCareOutfit.pajamas => const Color(0xFFB8A0D5),
        PetCareOutfit.royal => const Color(0xFFAF86C8),
      };

  static void paintBody(
    Canvas c,
    PetCareOutfit outfit, {
    required bool isBear,
  }) {
    if (outfit == PetCareOutfit.bare) return;
    final tone = color(outfit, isBear: isBear);
    final dress =
        outfit == PetCareOutfit.strawberry || outfit == PetCareOutfit.royal;
    if (outfit == PetCareOutfit.royal) {
      _shape(
        c,
        Path()
          ..moveTo(-13, -30)
          ..lineTo(-22, -5)
          ..quadraticBezierTo(0, 3, 22, -5)
          ..lineTo(13, -30)
          ..close(),
        const Color(0xFFE8D6F2),
      );
    }
    final body = Path()
      ..moveTo(-12, -32)
      ..quadraticBezierTo(0, -27, 12, -32)
      ..quadraticBezierTo(18, -21, dress ? 20 : 14, -6)
      ..quadraticBezierTo(0, dress ? 0 : -1, dress ? -20 : -14, -6)
      ..quadraticBezierTo(-18, -20, -12, -32)
      ..close();
    _shape(c, body, outfit == PetCareOutfit.sailor ? _cream : tone);
    if (dress) {
      _line(c, const Offset(-16, -12), const Offset(16, -12), _cream, 1.4);
      for (final x in [-9.0, 0.0, 9.0]) {
        _line(
          c,
          Offset(x, -10),
          Offset(x * 1.3, -5),
          tone.withValues(alpha: .65),
          .9,
        );
      }
    }
    switch (outfit) {
      case PetCareOutfit.bare:
        break;
      case PetCareOutfit.cloud:
        _cloud(c, const Offset(0, -17), 1);
        _line(c, const Offset(-11, -7), const Offset(11, -7), _cream, 1.4);
      case PetCareOutfit.strawberry:
        _strawberry(c, const Offset(0, -21), 1);
        for (final p in const [
          Offset(-10, -15),
          Offset(10, -16),
          Offset(-7, -7),
          Offset(8, -7),
        ]) {
          c.drawCircle(p, .9, Paint()..color = _cream);
        }
        _collar(c, const Color(0xFF8BB898));
      case PetCareOutfit.honey:
        for (final y in [-23.0, -15.0, -7.0]) {
          _line(c, Offset(-12, y), Offset(12, y), const Color(0xFF8D6A46), 3.3);
        }
        _shape(c, Path()..addOval(const Rect.fromLTWH(-6, -24, 12, 15)), _gold);
        _heart(c, const Offset(0, -17), 3.3, _cream);
      case PetCareOutfit.sailor:
        _shape(
          c,
          Path()
            ..moveTo(-13, -30)
            ..lineTo(0, -16)
            ..lineTo(13, -30)
            ..lineTo(9, -23)
            ..lineTo(0, -12)
            ..lineTo(-9, -23)
            ..close(),
          tone,
        );
        _shape(
          c,
          Path()
            ..moveTo(-3, -17)
            ..lineTo(3, -17)
            ..lineTo(2, -5)
            ..lineTo(-1, -8)
            ..lineTo(-3, -6)
            ..close(),
          const Color(0xFFE58AA0),
        );
        _line(c, const Offset(-12, -7), const Offset(12, -7), tone, 2);
      case PetCareOutfit.raincoat:
        _line(
          c,
          const Offset(0, -29),
          const Offset(0, -5),
          const Color(0xFFB49342),
          1,
        );
        for (final y in [-23.0, -17.0, -11.0]) {
          c.drawCircle(Offset(3, y), 1.2, Paint()..color = _cream);
        }
        _shape(
          c,
          Path()..addRRect(
            RRect.fromRectAndRadius(
              const Rect.fromLTWH(-11, -16, 7, 7),
              const Radius.circular(1.2),
            ),
          ),
          const Color(0xFFE4BA48),
        );
        _collar(c, _cream);
      case PetCareOutfit.pajamas:
        _line(
          c,
          const Offset(0, -28),
          const Offset(0, -5),
          const Color(0xFFE8DDF3),
          1,
        );
        for (final p in const [
          Offset(-7, -20),
          Offset(8, -11),
          Offset(8, -25),
          Offset(-7, -9),
        ]) {
          _star(c, p, 2.3, const Color(0xFFFFE0A2));
        }
        _collar(c, const Color(0xFFE9DDF5));
      case PetCareOutfit.royal:
        _collar(c, _cream);
        _line(c, const Offset(-15, -7), const Offset(15, -7), _gold, 1.6);
        _shape(
          c,
          Path()
            ..moveTo(0, -27)
            ..lineTo(3, -23)
            ..lineTo(0, -19)
            ..lineTo(-3, -23)
            ..close(),
          const Color(0xFFF9D87C),
        );
    }
  }

  static void paintAccessory(
    Canvas c,
    PetCareOutfit outfit, {
    required bool isBear,
  }) {
    final top = isBear ? -67.0 : -69.0;
    switch (outfit) {
      case PetCareOutfit.bare:
        return;
      case PetCareOutfit.cloud:
        _cloud(c, Offset(-5, top), .7);
        _star(c, Offset(6, top - 1), 3.6, _gold);
      case PetCareOutfit.strawberry:
        _strawberry(c, Offset(-10, top - 1), 1.15);
      case PetCareOutfit.honey:
        _line(c, Offset(-5, top), Offset(-8, top - 8), _ink, 1.6);
        _line(c, Offset(5, top), Offset(8, top - 8), _ink, 1.6);
        for (final x in [-8.0, 8.0]) {
          c.drawCircle(Offset(x, top - 8), 2.6, Paint()..color = _gold);
        }
      case PetCareOutfit.sailor:
        _shape(
          c,
          Path()
            ..moveTo(-14, top)
            ..quadraticBezierTo(-17, top - 9, 0, top - 10)
            ..quadraticBezierTo(17, top - 9, 14, top)
            ..close(),
          _cream,
        );
        _line(c, Offset(-14, top), Offset(14, top), const Color(0xFF628CB7), 3);
        _heart(c, Offset(0, top - 5), 2.5, const Color(0xFFDB899F));
      case PetCareOutfit.raincoat:
        _shape(
          c,
          Path()
            ..moveTo(-19, top + 2)
            ..quadraticBezierTo(-19, top - 12, 0, top - 12)
            ..quadraticBezierTo(19, top - 12, 19, top + 2)
            ..close(),
          color(outfit, isBear: isBear),
        );
        _shape(
          c,
          Path()..addOval(Rect.fromLTWH(-24, top - 1, 48, 6)),
          const Color(0xFFE5B940),
        );
      case PetCareOutfit.pajamas:
        _shape(
          c,
          Path()
            ..moveTo(-15, top)
            ..quadraticBezierTo(-10, top - 13, 4, top - 9)
            ..quadraticBezierTo(15, top - 8, 19, top - 1)
            ..quadraticBezierTo(6, top - 4, 12, top + 4)
            ..close(),
          color(outfit, isBear: isBear),
        );
        c.drawCircle(Offset(13, top + 3), 3, Paint()..color = _cream);
        _line(c, Offset(-15, top), Offset(9, top), const Color(0xFFE9DDF5), 3);
      case PetCareOutfit.royal:
        _shape(
          c,
          Path()
            ..moveTo(-13, top)
            ..lineTo(-15, top - 11)
            ..lineTo(-6, top - 6)
            ..lineTo(0, top - 15)
            ..lineTo(6, top - 6)
            ..lineTo(15, top - 11)
            ..lineTo(13, top)
            ..close(),
          _gold,
        );
        _line(c, Offset(-13, top), Offset(13, top), const Color(0xFFBE9346), 2);
        c.drawCircle(
          Offset(0, top - 6),
          2,
          Paint()..color = const Color(0xFFEB8B9F),
        );
    }
  }

  static void _collar(Canvas c, Color color) {
    _shape(
      c,
      Path()
        ..moveTo(-12, -31)
        ..lineTo(-2, -26)
        ..lineTo(-6, -20)
        ..lineTo(-14, -28)
        ..close(),
      color,
    );
    _shape(
      c,
      Path()
        ..moveTo(12, -31)
        ..lineTo(2, -26)
        ..lineTo(6, -20)
        ..lineTo(14, -28)
        ..close(),
      color,
    );
  }

  static void _cloud(Canvas c, Offset p, double k) {
    c.save();
    c.translate(p.dx, p.dy);
    c.scale(k);
    _shape(
      c,
      Path()
        ..moveTo(-9, 3)
        ..cubicTo(-14, 0, -10, -6, -5, -4)
        ..cubicTo(-5, -11, 6, -11, 7, -4)
        ..cubicTo(14, -6, 16, 3, 10, 4)
        ..close(),
      _cream,
    );
    c.restore();
  }

  static void _strawberry(Canvas c, Offset p, double k) {
    c.save();
    c.translate(p.dx, p.dy);
    c.scale(k);
    _shape(
      c,
      Path()
        ..moveTo(-6, -2)
        ..quadraticBezierTo(0, -7, 6, -2)
        ..quadraticBezierTo(7, 4, 0, 8)
        ..quadraticBezierTo(-7, 4, -6, -2)
        ..close(),
      const Color(0xFFD75A78),
    );
    _shape(
      c,
      Path()
        ..moveTo(-6, -3)
        ..lineTo(-2, -6)
        ..lineTo(0, -4)
        ..lineTo(3, -6)
        ..lineTo(6, -2)
        ..lineTo(1, -2)
        ..lineTo(0, 1)
        ..lineTo(-2, -2)
        ..close(),
      const Color(0xFF8EB686),
    );
    for (final p in const [Offset(-3, 0), Offset(3, 0), Offset(0, 4)]) {
      c.drawCircle(p, .8, Paint()..color = _cream);
    }
    c.restore();
  }

  static void _star(Canvas c, Offset p, double r, Color color) {
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final a = -math.pi / 2 + i * math.pi / 5;
      final d = i.isEven ? r : r * .45;
      final x = p.dx + math.cos(a) * d, y = p.dy + math.sin(a) * d;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    _shape(c, path..close(), color, width: .6);
  }

  static void _heart(Canvas c, Offset p, double r, Color color) {
    _shape(
      c,
      Path()
        ..moveTo(p.dx, p.dy + r)
        ..cubicTo(
          p.dx - r * 2,
          p.dy,
          p.dx - r,
          p.dy - r * 1.5,
          p.dx,
          p.dy - r * .4,
        )
        ..cubicTo(p.dx + r, p.dy - r * 1.5, p.dx + r * 2, p.dy, p.dx, p.dy + r)
        ..close(),
      color,
      width: .6,
    );
  }

  static void _shape(Canvas c, Path path, Color color, {double width = 1}) {
    c.drawPath(path, Paint()..color = color);
    c.drawPath(
      path,
      Paint()
        ..color = _ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..strokeJoin = StrokeJoin.round,
    );
  }

  static void _line(Canvas c, Offset a, Offset b, Color color, double width) =>
      c.drawLine(
        a,
        b,
        Paint()
          ..color = color
          ..strokeWidth = width
          ..strokeCap = StrokeCap.round,
      );
}
