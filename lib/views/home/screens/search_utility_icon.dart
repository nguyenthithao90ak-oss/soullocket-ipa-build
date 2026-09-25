import 'package:flutter/material.dart';

/// Icon vector tĩnh: hiện ngay khung hình đầu, không tải ảnh hay chạy ticker.
class SearchUtilityIcon extends StatelessWidget {
  const SearchUtilityIcon({
    super.key,
    required this.actionId,
    required this.fallbackIcon,
    required this.fallbackColor,
  });

  final String actionId;
  final IconData fallbackIcon;
  final Color fallbackColor;

  /// Danh mục độc lập với bộ lọc quyền/chế độ của màn tìm kiếm.
  static const illustratedIds = {
    'note',
    'friendly_chat',
    'calendar',
    'vault',
    'habit',
    'local_album',
    'soul_events',
    'giftcode',
    'voice',
    'capsule',
    'finance',
    'drawing',
    'wheel',
    'surprise_maker',
    'diary_export',
    'cinema',
    'tarot',
    'collage',
    'store',
    'creative_diary',
    'health',
    'sleep_tracker',
    'couple_connect',
  };

  @override
  Widget build(BuildContext context) {
    final id = actionId.startsWith('utility:')
        ? actionId.substring('utility:'.length)
        : actionId;
    final color = switch (id) {
      'note' => const Color(0xFF258E83),
      'friendly_chat' => const Color(0xFFCD6086),
      'calendar' => const Color(0xFF8770BA),
      'vault' => const Color(0xFF8D6488),
      'habit' => const Color(0xFF428FAE),
      'local_album' || 'collage' => const Color(0xFF688BB3),
      'soul_events' || 'surprise_maker' => const Color(0xFFC46683),
      'giftcode' || 'store' => const Color(0xFFB88042),
      'voice' || 'diary_export' => const Color(0xFF428FAE),
      'capsule' || 'tarot' || 'sleep_tracker' => const Color(0xFF8770BA),
      'finance' || 'creative_diary' => const Color(0xFF258E83),
      'drawing' || 'health' => const Color(0xFFCD6086),
      'wheel' || 'cinema' => const Color(0xFFBD795B),
      'couple_connect' => const Color(0xFF8D6488),
      _ => fallbackColor,
    };
    final illustrated = illustratedIds.contains(id);
    return ExcludeSemantics(
      child: RepaintBoundary(
        child: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(17),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.lerp(Colors.white, color, .04)!,
                Color.lerp(Colors.white, color, .18)!,
              ],
            ),
            border: Border.all(color: color.withValues(alpha: .15)),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: .10),
                blurRadius: 9,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: illustrated
              ? CustomPaint(painter: _UtilityIllustration(id, color))
              : Icon(fallbackIcon, color: color, size: 26),
        ),
      ),
    );
  }
}

class _UtilityIllustration extends CustomPainter {
  const _UtilityIllustration(this.id, this.color);
  final String id;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 52, size.height / 52);
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final light = Color.lerp(Colors.white, color, .22)!;
    void line(double x, double y, double x2, double y2) =>
        canvas.drawLine(Offset(x, y), Offset(x2, y2), stroke);
    void panel(Rect rect, double radius, Color fill) {
      final shape = RRect.fromRectAndRadius(rect, Radius.circular(radius));
      canvas.drawRRect(
        shape.shift(const Offset(0, 2)),
        Paint()..color = color.withValues(alpha: .10),
      );
      canvas.drawRRect(shape, Paint()..color = fill);
      canvas.drawRRect(shape, stroke);
    }

    void heart(double x, double y, double scale) {
      canvas.save();
      canvas.translate(x, y);
      canvas.scale(scale);
      canvas.drawPath(
        Path()
          ..moveTo(0, 3)
          ..cubicTo(-9, -2, -5, -8, 0, -4)
          ..cubicTo(5, -8, 9, -2, 0, 3)
          ..close(),
        Paint()..color = color,
      );
      canvas.restore();
    }

    void circle(double x, double y, double radius, {Color? fill}) {
      canvas.drawCircle(
        Offset(x, y),
        radius,
        Paint()..color = fill ?? Colors.white,
      );
      canvas.drawCircle(Offset(x, y), radius, stroke);
    }

    void arrow(double x, double y) {
      line(x, y - 6, x, y + 5);
      line(x - 4, y + 1, x, y + 5);
      line(x, y + 5, x + 4, y + 1);
    }

    void sparkle(double x, double y, double r) {
      canvas.drawPath(
        Path()
          ..moveTo(x, y - r)
          ..lineTo(x + r * .3, y - r * .3)
          ..lineTo(x + r, y)
          ..lineTo(x + r * .3, y + r * .3)
          ..lineTo(x, y + r)
          ..lineTo(x - r * .3, y + r * .3)
          ..lineTo(x - r, y)
          ..lineTo(x - r * .3, y - r * .3)
          ..close(),
        Paint()..color = color,
      );
    }

    switch (id) {
      case 'note':
        panel(const Rect.fromLTWH(14, 12, 25, 30), 5, light);
        panel(const Rect.fromLTWH(12, 10, 25, 30), 5, Colors.white);
        line(18, 11, 18, 39);
        for (final y in [17.0, 24.0, 31.0]) {
          line(10, y, 15, y);
        }
        heart(28, 23, .75);
        line(23, 30, 31, 30);
        line(23, 34, 28, 34);
      case 'friendly_chat':
        final bubble = Path()
          ..moveTo(18, 12)
          ..lineTo(34, 12)
          ..quadraticBezierTo(41, 12, 41, 19)
          ..lineTo(41, 29)
          ..quadraticBezierTo(41, 36, 34, 36)
          ..lineTo(25, 36)
          ..lineTo(18, 41)
          ..lineTo(18, 35)
          ..quadraticBezierTo(11, 34, 11, 28)
          ..lineTo(11, 19)
          ..quadraticBezierTo(11, 12, 18, 12)
          ..close();
        canvas.drawPath(
          bubble.shift(const Offset(0, 2)),
          Paint()..color = light,
        );
        canvas.drawPath(bubble, Paint()..color = Colors.white);
        canvas.drawPath(bubble, stroke);
        heart(26, 25, .9);
        canvas.drawCircle(const Offset(17, 27), 1.3, Paint()..color = light);
        canvas.drawCircle(const Offset(35, 27), 1.3, Paint()..color = light);
      case 'calendar':
        panel(const Rect.fromLTWH(11, 13, 30, 28), 6, Colors.white);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(12, 14, 28, 9),
            const Radius.circular(4),
          ),
          Paint()..color = light,
        );
        line(12, 23, 40, 23);
        line(19, 10, 19, 17);
        line(33, 10, 33, 17);
        heart(31, 33, .7);
        for (final point in [
          const Offset(18, 29),
          const Offset(23, 29),
          const Offset(18, 35),
        ]) {
          canvas.drawCircle(
            point,
            1.4,
            Paint()..color = color.withValues(alpha: .5),
          );
        }
      case 'vault':
        panel(const Rect.fromLTWH(11, 11, 30, 30), 7, light);
        panel(const Rect.fromLTWH(16, 16, 21, 20), 4, Colors.white);
        line(10, 19, 13, 19);
        line(10, 32, 13, 32);
        canvas.drawCircle(const Offset(27, 26), 5, stroke);
        line(27, 21, 27, 24);
        line(27, 28, 27, 31);
        line(22, 26, 25, 26);
        line(29, 26, 32, 26);
        line(17, 42, 17, 44);
        line(35, 42, 35, 44);
      case 'habit':
        panel(const Rect.fromLTWH(13, 12, 26, 30), 6, Colors.white);
        panel(const Rect.fromLTWH(21, 9, 10, 6), 3, light);
        for (final y in [23.0, 32.0]) {
          canvas.drawCircle(Offset(20, y), 3.5, Paint()..color = light);
          canvas.drawPath(
            Path()
              ..moveTo(18, y)
              ..lineTo(19.5, y + 1.5)
              ..lineTo(22, y - 1.5),
            stroke,
          );
          line(27, y, 33, y);
        }
      case 'local_album':
        panel(const Rect.fromLTWH(10, 15, 28, 27), 5, light);
        panel(const Rect.fromLTWH(15, 10, 27, 28), 5, Colors.white);
        circle(33, 18, 2.5, fill: light);
        final mountain = Path()
          ..moveTo(18, 32)
          ..lineTo(24, 23)
          ..lineTo(29, 29)
          ..lineTo(33, 25)
          ..lineTo(39, 32)
          ..close();
        canvas.drawPath(mountain, Paint()..color = light);
        canvas.drawPath(mountain, stroke);
      case 'soul_events':
        panel(const Rect.fromLTWH(11, 13, 28, 28), 5, Colors.white);
        line(12, 22, 38, 22);
        line(18, 10, 18, 17);
        line(31, 10, 31, 17);
        heart(24, 32, 1);
        sparkle(40, 14, 5);
      case 'giftcode':
        final ticket = Path()
          ..moveTo(14, 15)
          ..lineTo(38, 15)
          ..quadraticBezierTo(41, 15, 41, 18)
          ..lineTo(41, 22)
          ..quadraticBezierTo(34, 26, 41, 30)
          ..lineTo(41, 34)
          ..quadraticBezierTo(41, 37, 38, 37)
          ..lineTo(14, 37)
          ..quadraticBezierTo(11, 37, 11, 34)
          ..lineTo(11, 30)
          ..quadraticBezierTo(18, 26, 11, 22)
          ..lineTo(11, 18)
          ..quadraticBezierTo(11, 15, 14, 15)
          ..close();
        canvas.drawPath(ticket, Paint()..color = Colors.white);
        canvas.drawPath(ticket, stroke);
        for (final y in [19.0, 25.0, 31.0]) {
          line(31, y, 31, y + 2);
        }
        heart(22, 28, .9);
      case 'voice':
        panel(const Rect.fromLTWH(21, 10, 12, 23), 6, Colors.white);
        canvas.drawPath(
          Path()
            ..moveTo(16, 26)
            ..lineTo(16, 28)
            ..cubicTo(16, 42, 38, 42, 38, 28)
            ..lineTo(38, 26),
          stroke,
        );
        line(27, 38, 27, 43);
        line(21, 43, 33, 43);
        line(24, 17, 29, 17);
        line(24, 22, 29, 22);
        heart(13, 17, .5);
      case 'capsule':
        panel(const Rect.fromLTWH(10, 16, 30, 23), 5, Colors.white);
        canvas.drawPath(
          Path()
            ..moveTo(12, 18)
            ..lineTo(25, 28)
            ..lineTo(38, 18),
          stroke,
        );
        line(12, 37, 20, 29);
        circle(36, 35, 8, fill: light);
        line(36, 31, 36, 35);
        line(36, 35, 39, 37);
      case 'finance':
        panel(const Rect.fromLTWH(11, 15, 28, 26), 5, light);
        panel(const Rect.fromLTWH(11, 19, 30, 22), 5, Colors.white);
        panel(const Rect.fromLTWH(30, 25, 13, 10), 3, light);
        canvas.drawCircle(const Offset(34, 30), 1.5, Paint()..color = color);
        circle(20, 14, 5, fill: light);
        line(20, 12, 20, 16);
      case 'drawing':
        final palette = Path()
          ..moveTo(30, 11)
          ..cubicTo(9, 5, 4, 34, 20, 40)
          ..cubicTo(26, 44, 32, 39, 28, 34)
          ..cubicTo(24, 29, 32, 31, 38, 26)
          ..cubicTo(46, 19, 37, 12, 30, 11)
          ..close();
        canvas.drawPath(palette, Paint()..color = Colors.white);
        canvas.drawPath(palette, stroke);
        for (final point in [
          const Offset(18, 18),
          const Offset(29, 16),
          const Offset(15, 28),
        ]) {
          canvas.drawCircle(point, 3, Paint()..color = light);
        }
        line(29, 38, 41, 20);
        canvas.drawPath(
          Path()
            ..moveTo(29, 36)
            ..quadraticBezierTo(23, 35, 23, 43)
            ..quadraticBezierTo(32, 44, 30, 38),
          stroke,
        );
      case 'wheel':
        circle(26, 25, 15);
        canvas.drawArc(
          const Rect.fromLTWH(11, 10, 30, 30),
          0,
          1.57,
          true,
          Paint()..color = light,
        );
        canvas.drawArc(
          const Rect.fromLTWH(11, 10, 30, 30),
          3.14,
          1.57,
          true,
          Paint()..color = light,
        );
        line(11, 25, 41, 25);
        line(26, 10, 26, 40);
        circle(26, 25, 4);
        line(20, 44, 32, 44);
        canvas.drawPath(
          Path()
            ..moveTo(22, 8)
            ..lineTo(30, 8)
            ..lineTo(26, 15)
            ..close(),
          Paint()..color = color,
        );
      case 'surprise_maker':
        panel(const Rect.fromLTWH(15, 10, 24, 30), 4, light);
        panel(const Rect.fromLTWH(10, 15, 27, 26), 4, Colors.white);
        heart(24, 28, 1.25);
        line(19, 35, 29, 35);
        sparkle(41, 12, 4);
      case 'diary_export':
        panel(const Rect.fromLTWH(11, 10, 25, 31), 4, Colors.white);
        line(18, 18, 29, 18);
        line(18, 24, 27, 24);
        line(18, 30, 23, 30);
        circle(36, 34, 9, fill: light);
        arrow(36, 33);
      case 'cinema':
        panel(const Rect.fromLTWH(11, 13, 30, 27), 5, Colors.white);
        panel(const Rect.fromLTWH(11, 11, 30, 9), 2, light);
        for (final x in [15.0, 25.0, 35.0]) {
          line(x, 12, x - 4, 19);
        }
        canvas.drawPath(
          Path()
            ..moveTo(23, 25)
            ..lineTo(23, 35)
            ..lineTo(32, 30)
            ..close(),
          Paint()..color = color,
        );
      case 'tarot':
        canvas.save();
        canvas.translate(26, 26);
        canvas.rotate(-.18);
        panel(const Rect.fromLTWH(-14, -14, 22, 29), 4, light);
        canvas.restore();
        panel(const Rect.fromLTWH(19, 11, 22, 31), 4, Colors.white);
        sparkle(30, 27, 7);
        canvas.drawCircle(const Offset(25, 17), 1.3, Paint()..color = color);
        canvas.drawCircle(const Offset(35, 36), 1.3, Paint()..color = color);
      case 'collage':
        panel(const Rect.fromLTWH(10, 11, 31, 30), 5, Colors.white);
        panel(const Rect.fromLTWH(14, 15, 10, 22), 2, light);
        panel(const Rect.fromLTWH(28, 15, 9, 9), 2, light);
        heart(32, 33, .6);
      case 'store':
        panel(const Rect.fromLTWH(12, 19, 28, 23), 5, Colors.white);
        canvas.drawPath(
          Path()
            ..moveTo(20, 21)
            ..lineTo(20, 16)
            ..cubicTo(20, 7, 32, 7, 32, 16)
            ..lineTo(32, 21),
          stroke,
        );
        heart(26, 32, 1);
      case 'creative_diary':
        final book = Path()
          ..moveTo(26, 14)
          ..quadraticBezierTo(18, 9, 10, 13)
          ..lineTo(10, 39)
          ..quadraticBezierTo(18, 35, 26, 40)
          ..quadraticBezierTo(34, 35, 42, 39)
          ..lineTo(42, 13)
          ..quadraticBezierTo(34, 9, 26, 14)
          ..close();
        canvas.drawPath(book, Paint()..color = Colors.white);
        canvas.drawPath(book, stroke);
        line(26, 15, 26, 39);
        line(15, 22, 21, 23);
        line(15, 28, 21, 29);
        heart(34, 25, .65);
      case 'health':
        panel(const Rect.fromLTWH(11, 17, 30, 23), 6, Colors.white);
        panel(const Rect.fromLTWH(20, 11, 12, 6), 3, light);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(23, 23, 6, 12),
            const Radius.circular(1),
          ),
          Paint()..color = color,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(20, 26, 12, 6),
            const Radius.circular(1),
          ),
          Paint()..color = color,
        );
      case 'sleep_tracker':
        final moon = Path()
          ..moveTo(29, 10)
          ..cubicTo(6, 7, 5, 42, 28, 42)
          ..quadraticBezierTo(39, 42, 42, 31)
          ..cubicTo(26, 37, 19, 20, 29, 10)
          ..close();
        canvas.drawPath(moon, Paint()..color = Colors.white);
        canvas.drawPath(moon, stroke);
        sparkle(36, 17, 5);
        sparkle(42, 25, 2);
        line(15, 28, 18, 29);
      case 'couple_connect':
        canvas.save();
        canvas.translate(26, 26);
        canvas.rotate(-.65);
        panel(const Rect.fromLTWH(-17, -7, 23, 14), 7, light);
        panel(const Rect.fromLTWH(-6, -7, 23, 14), 7, Colors.white);
        line(-5, 0, 5, 0);
        canvas.restore();
        heart(39, 14, .55);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _UtilityIllustration oldDelegate) =>
      id != oldDelegate.id || color != oldDelegate.color;
}
