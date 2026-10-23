import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'pet_care_food_art.dart';
import 'pet_care_item_art.dart';
import 'pet_care_play_tools.dart';
import 'pet_care_progress.dart';

/// Đồ cầm tay dùng chung cho khay và lượt kéo, không cần thêm ảnh vào gói app.
/// [style] đổi màu/hình theo món đã mua; đồ ăn, bóng và tim bỏ qua tham số này.
class PetCareToolArt extends StatelessWidget {
  const PetCareToolArt({
    required this.tool,
    this.size = 64,
    this.style,
    this.food,
    super.key,
  });

  final PetCareTool tool;
  final double size;
  final PetCareStyle? style;

  /// Món đang cầm khi [tool] là đồ ăn.
  final PetCareFood? food;

  @override
  Widget build(BuildContext context) {
    if (tool == PetCareTool.soap) {
      return PetCareSoapArt(
        style: style?.slot == PetCareStyleSlot.soap
            ? style!
            : PetCareStyle.soapLavender,
        size: size,
      );
    }
    return ExcludeSemantics(
      child: tool == PetCareTool.food
          ? PetCareFoodArt(food: food ?? PetCareFood.carrot, size: size)
          : SizedBox.square(
              dimension: size,
              child: CustomPaint(
                painter: _ToolPainter(
                  tool,
                  style?.slot == tool.styleSlot ? style : null,
                ),
              ),
            ),
    );
  }
}

/// Món trong tiệm: đồ tắm vẽ như ở khay, điệu nhảy có biểu tượng riêng.
class PetCareStyleArt extends StatelessWidget {
  const PetCareStyleArt({required this.style, this.size = 56, super.key});

  final PetCareStyle style;
  final double size;

  @override
  Widget build(BuildContext context) => switch (style.slot) {
    PetCareStyleSlot.soap => PetCareSoapArt(style: style, size: size),
    PetCareStyleSlot.shower => PetCareToolArt(
      tool: PetCareTool.shower,
      style: style,
      size: size,
    ),
    PetCareStyleSlot.towel => PetCareToolArt(
      tool: PetCareTool.towel,
      style: style,
      size: size,
    ),
    PetCareStyleSlot.dance => ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(painter: _DancePainter(style)),
      ),
    ),
  };
}

/// Chai xà phòng dùng atlas có sẵn, đổi tông bằng ma trận màu thay vì ảnh mới.
class PetCareSoapArt extends StatelessWidget {
  const PetCareSoapArt({required this.style, this.size = 64, super.key});

  final PetCareStyle style;
  final double size;

  static List<double> _hue(double degrees) {
    final radians = degrees * math.pi / 180;
    final cos = math.cos(radians);
    final sin = math.sin(radians);
    const lr = .213, lg = .715, lb = .072;
    return [
      lr + cos * (1 - lr) + sin * -lr,
      lg + cos * -lg + sin * -lg,
      lb + cos * -lb + sin * (1 - lb),
      0,
      0,
      lr + cos * -lr + sin * .143,
      lg + cos * (1 - lg) + sin * .14,
      lb + cos * -lb + sin * -.283,
      0,
      0,
      lr + cos * -lr + sin * -(1 - lr),
      lg + cos * -lg + sin * lg,
      lb + cos * (1 - lb) + sin * lb,
      0,
      0,
      0,
      0,
      0,
      1,
      0,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final bottle = PetCareItemArt(index: 4, size: size);
    final Widget tinted = switch (style) {
      PetCareStyle.soapStrawberry => ColorFiltered(
        colorFilter: ColorFilter.matrix(_hue(62)),
        child: bottle,
      ),
      PetCareStyle.soapMint => ColorFiltered(
        colorFilter: ColorFilter.matrix(_hue(-118)),
        child: bottle,
      ),
      // srcATop chỉ tô lên phần chai, giữ nền trong suốt.
      PetCareStyle.soapRainbow => ShaderMask(
        blendMode: BlendMode.srcATop,
        shaderCallback: (rect) => const SweepGradient(
          colors: [
            Color(0x80F7A1B5),
            Color(0x80F8D27E),
            Color(0x809ED9B8),
            Color(0x808FC3EE),
            Color(0x80C3A3EC),
            Color(0x80F7A1B5),
          ],
        ).createShader(rect),
        child: bottle,
      ),
      _ => bottle,
    };
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: Stack(
          children: [
            Positioned.fill(child: tinted),
            if (!style.isFree)
              Positioned.fill(
                child: CustomPaint(painter: _SoapCharmPainter(style)),
              ),
          ],
        ),
      ),
    );
  }
}

/// Dấu nhỏ ở góc chai cho biết loại bọt sẽ tạo ra.
class _SoapCharmPainter extends CustomPainter {
  const _SoapCharmPainter(this.style);
  final PetCareStyle style;

  @override
  void paint(Canvas c, Size size) {
    c.save();
    c.scale(size.width / 64, size.height / 64);
    const center = Offset(51, 15);
    c.drawCircle(center, 9, Paint()..color = const Color(0xF2FFFAED));
    switch (style) {
      case PetCareStyle.soapStrawberry:
        _toolHeart(c, center, 5.5, const Color(0xFFE4728F));
      case PetCareStyle.soapMint:
        _toolStar(c, center, 6, const Color(0xFF5FB59C));
      case PetCareStyle.soapRainbow:
        for (var i = 0; i < 3; i++) {
          c.drawArc(
            Rect.fromCircle(
              center: center + const Offset(0, 3),
              radius: 6 - i * 1.8,
            ),
            math.pi,
            math.pi,
            false,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.6
              ..color = const [
                Color(0xFFEF8FA6),
                Color(0xFFF3C96E),
                Color(0xFF7FC7E8),
              ][i],
          );
        }
      default:
        break;
    }
    c.restore();
  }

  @override
  bool shouldRepaint(_SoapCharmPainter oldDelegate) =>
      oldDelegate.style != style;
}

void _toolStar(Canvas c, Offset center, double radius, Color color) {
  final shape = Path();
  for (var i = 0; i < 8; i++) {
    final angle = i * math.pi / 4 - math.pi / 2;
    final r = i.isEven ? radius : radius * .35;
    final point = center + Offset(math.cos(angle), math.sin(angle)) * r;
    if (i == 0) {
      shape.moveTo(point.dx, point.dy);
    } else {
      shape.lineTo(point.dx, point.dy);
    }
  }
  c.drawPath(shape..close(), Paint()..color = color);
}

void _toolHeart(Canvas c, Offset center, double radius, Color color) {
  c.save();
  c.translate(center.dx, center.dy);
  c.scale(radius / 10);
  c.drawPath(
    Path()
      ..moveTo(0, 10)
      ..cubicTo(-23, -4, -8, -16, 0, -6)
      ..cubicTo(8, -16, 23, -4, 0, 10),
    Paint()..color = color,
  );
  c.restore();
}

class _ToolPainter extends CustomPainter {
  const _ToolPainter(this.tool, this.style);
  final PetCareTool tool;
  final PetCareStyle? style;

  static const _ink = Color(0xFF8B747C);
  static const _mint = Color(0xFFAADBCD);
  static const _cream = Color(0xFFFFF6DF);
  static const _rose = Color(0xFFE9A5BB);
  static const _gold = Color(0xFFE6BB79);

  void _line(
    Canvas c,
    Offset from,
    Offset to,
    Color color, [
    double width = 2,
  ]) {
    c.drawLine(
      from,
      to,
      Paint()
        ..color = color
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round,
    );
  }

  void _round(Canvas c, Rect rect, double radius, Color color) {
    final shape = RRect.fromRectAndRadius(rect, Radius.circular(radius));
    c.drawRRect(shape, Paint()..color = color);
    c.drawRRect(
      shape,
      Paint()
        ..color = _ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6,
    );
  }

  void _shower(Canvas c) {
    final petal = style == PetCareStyle.showerPetal;
    final rainbow = style == PetCareStyle.showerRainbow;
    final head = petal
        ? const Color(0xFFFFE1EA)
        : rainbow
        ? const Color(0xFFEDE2FF)
        : _cream;
    final handle = petal
        ? const Color(0xFFF2B3C6)
        : rainbow
        ? const Color(0xFFC6B3EE)
        : _mint;
    c.save();
    c.translate(31, 20);
    c.rotate(-.5);
    _round(c, const Rect.fromLTWH(-4, 2, 8, 30), 4, handle);
    _round(c, const Rect.fromLTWH(-16, -10, 32, 17), 8, head);
    c.drawOval(
      const Rect.fromLTWH(-13, 0, 26, 8),
      Paint()
        ..color = petal
            ? const Color(0xFFE38FA8)
            : rainbow
            ? const Color(0xFF9C86D8)
            : const Color(0xFF78B7AD),
    );
    for (var i = 0; i < 5; i++) {
      c.drawCircle(Offset(-9 + i * 4.5, 4), .8, Paint()..color = _ink);
    }
    _line(c, const Offset(-1, 13), const Offset(-1, 25), Colors.white70, 2);
    c.restore();
    for (var i = 0; i < 4; i++) {
      final from = Offset(10 + i * 5, 34 + i * 2);
      if (petal) {
        _toolHeart(
          c,
          from + const Offset(-1, 5),
          4.2,
          [const Color(0xFFF4A8BE), const Color(0xFFFFC9D7)][i % 2],
        );
      } else {
        _line(
          c,
          from,
          Offset(7 + i * 5, 43 + i * 2),
          rainbow
              ? const [
                  Color(0xFFF197AB),
                  Color(0xFFF2C66B),
                  Color(0xFF86CFA9),
                  Color(0xFF86B7EC),
                ][i]
              : const Color(0xFF8CCAD9),
          2.8,
        );
      }
    }
    _toolStar(c, const Offset(51, 13), 5, _gold);
  }

  void _towel(Canvas c) {
    final cloud = style == PetCareStyle.towelCloud;
    final star = style == PetCareStyle.towelStar;
    final body = cloud
        ? const Color(0xFFFFDDE7)
        : star
        ? const Color(0xFFFFE6A6)
        : _cream;
    final fold = cloud
        ? const Color(0xFFFFC7D7)
        : star
        ? const Color(0xFFF7CF72)
        : const Color(0xFFFFE9C1);
    c.save();
    c.translate(32, 32);
    c.rotate(-.12);
    _round(c, const Rect.fromLTWH(-23, -15, 46, 34), 7, body);
    _round(c, const Rect.fromLTWH(-23, -16, 46, 10), 5, fold);
    c.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-21, 10, 42, 5),
        const Radius.circular(2),
      ),
      Paint()..color = star ? const Color(0xFFE09A55) : _rose,
    );
    for (var i = 0; i < 7; i++) {
      _line(c, Offset(-18 + i * 6, 18), Offset(-18 + i * 6, 22), _ink, 1.2);
    }
    if (cloud) {
      final puff = Paint()..color = Colors.white;
      for (final p in const [Offset(-6, 2), Offset(0, -2), Offset(6, 2)]) {
        c.drawCircle(p, 5.5, puff);
      }
      c.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(-11, 1, 22, 6),
          const Radius.circular(3),
        ),
        puff,
      );
    } else {
      _toolStar(c, const Offset(0, 1), 8, star ? Colors.white : _gold);
    }
    c.restore();
    _toolStar(c, const Offset(54, 11), 5, cloud ? _rose : _mint);
  }

  @override
  void paint(Canvas c, Size size) {
    c.save();
    c.scale(size.width / 64, size.height / 64);
    c.drawOval(
      const Rect.fromLTWH(9, 53, 45, 5),
      Paint()..color = _ink.withValues(alpha: .12),
    );
    switch (tool) {
      case PetCareTool.shower:
        _shower(c);
      case PetCareTool.towel:
        _towel(c);
      case PetCareTool.ball:
        const circle = Rect.fromLTWH(9, 7, 46, 46);
        c.drawOval(
          circle,
          Paint()
            ..shader = const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFC7EDDB), Color(0xFF8AC6B9)],
            ).createShader(circle),
        );
        final seam = Paint()
          ..color = _cream
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3;
        c.drawPath(
          Path()
            ..moveTo(29, 8)
            ..cubicTo(42, 23, 17, 35, 29, 52),
          seam,
        );
        c.drawPath(
          Path()
            ..moveTo(10, 25)
            ..quadraticBezierTo(31, 40, 54, 25),
          seam,
        );
        c.drawOval(
          circle,
          Paint()
            ..color = _ink
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.8,
        );
        c.drawOval(
          const Rect.fromLTWH(17, 14, 10, 5),
          Paint()..color = Colors.white54,
        );
        _toolStar(c, const Offset(53, 10), 5, _gold);
      case PetCareTool.cuddle:
        final heart = Path()
          ..moveTo(32, 53)
          ..cubicTo(27, 49, 7, 35, 7, 22)
          ..cubicTo(7, 7, 24, 7, 32, 19)
          ..cubicTo(40, 7, 57, 7, 57, 22)
          ..cubicTo(57, 35, 37, 49, 32, 53)
          ..close();
        c.drawPath(
          heart,
          Paint()
            ..shader = const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFF4C1D2), Color(0xFFD98DA7)],
            ).createShader(const Rect.fromLTWH(7, 10, 50, 43)),
        );
        c.drawPath(
          heart,
          Paint()
            ..color = _ink
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.8,
        );
        _line(c, const Offset(15, 23), const Offset(20, 18), Colors.white70, 3);
        _toolStar(c, const Offset(53, 45), 5, _gold);
      default:
        break;
    }
    c.restore();
  }

  @override
  bool shouldRepaint(_ToolPainter oldDelegate) =>
      oldDelegate.tool != tool || oldDelegate.style != style;
}

/// Biểu tượng tĩnh của điệu nhảy; tiệm không chạy ticker khi đang mở.
class _DancePainter extends CustomPainter {
  const _DancePainter(this.style);
  final PetCareStyle style;

  static const _ink = Color(0xFF8B747C);

  void _pet(Canvas c, Offset center, double scale, {double alpha = 1}) {
    final body = Paint()
      ..color = const Color(0xFFFFF4E6).withValues(alpha: alpha);
    final line = Paint()
      ..color = _ink.withValues(alpha: alpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    for (final ear in const [Offset(-5, -15), Offset(5, -15)]) {
      final rect = Rect.fromCenter(
        center: center + ear * scale,
        width: 6 * scale,
        height: 13 * scale,
      );
      c.drawOval(rect, body);
      c.drawOval(rect, line);
    }
    final head = Rect.fromCenter(
      center: center,
      width: 22 * scale,
      height: 19 * scale,
    );
    c.drawOval(head, body);
    c.drawOval(head, line);
    final eye = Paint()
      ..color = _ink.withValues(alpha: alpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round;
    for (final x in const [-4.5, 4.5]) {
      c.drawArc(
        Rect.fromCenter(
          center: center + Offset(x, -1) * scale,
          width: 4 * scale,
          height: 3.4 * scale,
        ),
        math.pi,
        math.pi,
        false,
        eye,
      );
    }
    c.drawCircle(
      center + const Offset(-7.5, 3) * scale,
      2.2 * scale,
      Paint()..color = const Color(0xFFF4B3C2).withValues(alpha: alpha),
    );
    c.drawCircle(
      center + const Offset(7.5, 3) * scale,
      2.2 * scale,
      Paint()..color = const Color(0xFFF4B3C2).withValues(alpha: alpha),
    );
  }

  @override
  void paint(Canvas c, Size size) {
    c.save();
    c.scale(size.width / 64, size.height / 64);
    c.drawOval(
      const Rect.fromLTWH(14, 54, 36, 5),
      Paint()..color = _ink.withValues(alpha: .14),
    );
    switch (style) {
      case PetCareStyle.danceHop:
        final arc = Paint()
          ..color = const Color(0xFFE7BC78)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round;
        c.drawArc(
          const Rect.fromLTWH(8, 18, 48, 40),
          math.pi * 1.1,
          math.pi * .8,
          false,
          arc,
        );
        _pet(c, const Offset(18, 44), .55, alpha: .35);
        _pet(c, const Offset(32, 30), .8);
        _toolStar(c, const Offset(52, 18), 4.5, const Color(0xFFE7BC78));
      case PetCareStyle.danceSpin:
        final ring = Paint()
          ..color = const Color(0xFF9F8AD8)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4
          ..strokeCap = StrokeCap.round;
        c.drawArc(
          const Rect.fromLTWH(7, 9, 50, 46),
          -.3,
          math.pi * .8,
          false,
          ring,
        );
        c.drawArc(
          const Rect.fromLTWH(7, 9, 50, 46),
          math.pi - .3,
          math.pi * .8,
          false,
          ring,
        );
        final head = Path()
          ..moveTo(55, 32)
          ..lineTo(57, 25)
          ..lineTo(50, 27);
        c.drawPath(head, ring);
        _pet(c, const Offset(32, 33), .85);
        _toolStar(c, const Offset(12, 14), 4, const Color(0xFFE7BC78));
        _toolStar(c, const Offset(52, 50), 3.5, const Color(0xFFAADBCD));
      case PetCareStyle.danceHeart:
        _toolHeart(c, const Offset(32, 30), 26, const Color(0xFFF6B9CB));
        for (var i = 0; i < 6; i++) {
          final angle = i * math.pi / 3;
          final from =
              const Offset(32, 30) +
              Offset(math.cos(angle), math.sin(angle)) * 24;
          final to =
              const Offset(32, 30) +
              Offset(math.cos(angle), math.sin(angle)) * 29;
          c.drawLine(
            from,
            to,
            Paint()
              ..color = const Color(0xFFE38FA8)
              ..strokeWidth = 2
              ..strokeCap = StrokeCap.round,
          );
        }
        _pet(c, const Offset(32, 33), .75);
      case PetCareStyle.danceConfetti:
        const colors = [
          Color(0xFFF197AB),
          Color(0xFFF2C66B),
          Color(0xFF86CFA9),
          Color(0xFF86B7EC),
          Color(0xFFC3A3EC),
        ];
        for (var i = 0; i < 14; i++) {
          final p = Offset(
            8 + (i * 37 % 48).toDouble(),
            6 + (i * 23 % 30).toDouble(),
          );
          c.save();
          c.translate(p.dx, p.dy);
          c.rotate(i * .7);
          c.drawRRect(
            RRect.fromRectAndRadius(
              const Rect.fromLTWH(-2.5, -1.4, 5, 2.8),
              const Radius.circular(1),
            ),
            Paint()..color = colors[i % colors.length],
          );
          c.restore();
        }
        _pet(c, const Offset(32, 40), .8);
      default:
        break;
    }
    c.restore();
  }

  @override
  bool shouldRepaint(_DancePainter oldDelegate) => oldDelegate.style != style;
}
