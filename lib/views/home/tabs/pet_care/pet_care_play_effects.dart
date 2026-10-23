part of 'pet_care_scene.dart';

/// Phản hồi nằm cùng hệ tọa độ với bé; số nét cố định, không sinh particle/timer.
class _PetPlayEffectsPainter extends CustomPainter {
  const _PetPlayEffectsPainter({
    required this.viewport,
    required this.bounds,
    required this.point,
    required this.held,
    required this.body,
    required this.tool,
    required this.style,
    required this.rub,
    required this.seconds,
    required this.ready,
  });
  final _PetCareViewport viewport;
  final Rect bounds;

  /// Ngón tay trên người bé (null khi ở ngoài).
  final Offset? point;

  /// Tâm hình món đang cầm, nổi phía trên ngón tay.
  final Offset? held;

  /// Kẹp một điểm vào thân bé để nước/bọt không rơi ra ngoài.
  final Offset Function(Offset point) body;
  final PetCareTool tool;
  final PetCareStyle? style;
  final double rub;
  final double seconds;
  final bool ready;

  static const _rainbow = [
    Color(0xFFF197AB),
    Color(0xFFF2C66B),
    Color(0xFF86CFA9),
    Color(0xFF86B7EC),
    Color(0xFFC3A3EC),
  ];

  Color _tint(int index) => switch (style) {
    PetCareStyle.soapStrawberry ||
    PetCareStyle.showerPetal ||
    PetCareStyle.towelCloud => const [
      Color(0xFFF2A9BF),
      Color(0xFFFFC9D7),
    ][index % 2],
    PetCareStyle.soapMint => const Color(0xFF8FD3BC),
    PetCareStyle.soapRainbow ||
    PetCareStyle.showerRainbow => _rainbow[index % _rainbow.length],
    PetCareStyle.towelStar => const Color(0xFFF0C25C),
    _ when tool == PetCareTool.shower => const Color(0xFF82CADB),
    _ when tool == PetCareTool.towel => const Color(0xFFE7BC78),
    _ => const Color(0xFFCFC2EE),
  };

  void _heart(Canvas canvas, Offset center, double radius, Paint paint) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(radius / 10);
    canvas.drawPath(
      Path()
        ..moveTo(0, 10)
        ..cubicTo(-23, -4, -8, -16, 0, -6)
        ..cubicTo(8, -16, 23, -4, 0, 10),
      paint,
    );
    canvas.restore();
  }

  void _sparkle(Canvas canvas, Offset center, double radius, Color color) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      center - Offset(radius, 0),
      center + Offset(radius, 0),
      paint,
    );
    canvas.drawLine(
      center - Offset(0, radius),
      center + Offset(0, radius),
      paint,
    );
  }

  /// Dòng nước rơi từ vòi đang cầm xuống đúng chỗ trên người bé.
  void _stream(Canvas canvas, Offset head, Offset target) {
    final impact = body(target);
    final petal = style == PetCareStyle.showerPetal;
    for (var i = 0; i < 18; i++) {
      final t = (seconds * 2.6 + i / 18) % 1;
      final spread = (i % 5 - 2) * 3.4;
      // Vòi nghiêng: nước ra ở mép dưới-trái của hình vòi sen.
      final from = head + Offset(-10 + spread * .6, 16);
      final to = impact + Offset(spread * 1.8, 2);
      final drop = Offset.lerp(from, to, t)!;
      final color = _tint(i).withValues(alpha: .85 * math.sin(t * math.pi));
      if (petal) {
        _heart(canvas, drop, 3.4, Paint()..color = color);
      } else {
        canvas.drawLine(
          drop,
          drop + (to - from) / (to - from).distance * 8,
          Paint()
            ..color = color
            ..strokeWidth = 3
            ..strokeCap = StrokeCap.round,
        );
      }
    }
    for (var i = 0; i < 3; i++) {
      final t = (seconds * 1.6 + i / 3) % 1;
      canvas.drawOval(
        Rect.fromCenter(center: impact, width: 10 + t * 30, height: 4 + t * 9),
        Paint()
          ..color = _tint(i).withValues(alpha: .6 * (1 - t))
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6,
      );
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(viewport.scaleX, viewport.scaleY);
    canvas.translate(0, viewport.wallExtension);
    final color = ready ? const Color(0xFF5FAD97) : const Color(0xFFE6AB65);
    final outline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..color = color;
    final halo = bounds.inflate(6);
    canvas.drawOval(halo, Paint()..color = color.withValues(alpha: .09));
    for (var i = 0; i < 8; i++) {
      canvas.drawArc(halo, i * math.pi / 4 + seconds * .6, .43, false, outline);
    }
    final badge = Offset(bounds.center.dx, bounds.bottom + 13);
    canvas.drawCircle(badge, 15, Paint()..color = const Color(0xFFFFFAED));
    if (tool.bathStep != null) {
      canvas.drawArc(
        Rect.fromCircle(center: badge, radius: 15),
        -math.pi / 2,
        math.pi * 2 * rub,
        false,
        outline,
      );
    }
    final mark = Path();
    if (ready) {
      mark.moveTo(badge.dx - 6, badge.dy);
      mark.lineTo(badge.dx - 1, badge.dy + 5);
      mark.lineTo(badge.dx + 7, badge.dy - 5);
    } else {
      mark.moveTo(badge.dx, badge.dy - 6);
      mark.lineTo(badge.dx, badge.dy + 6);
      mark.moveTo(badge.dx - 4, badge.dy + 2);
      mark.lineTo(badge.dx, badge.dy + 6);
      mark.lineTo(badge.dx + 4, badge.dy + 2);
    }
    canvas.drawPath(mark, outline..strokeWidth = 2.5);
    final item = held;
    if (tool == PetCareTool.shower && item != null && point != null) {
      _stream(canvas, item, point!);
    }
    final contact = point == null || item == null ? null : body(item);
    if (contact != null &&
        tool.bathStep != null &&
        tool != PetCareTool.shower) {
      for (var i = 0; i < 8; i++) {
        final angle = i * 2.4 + seconds * .7;
        final center =
            contact + Offset(math.cos(angle), math.sin(angle)) * (10 + i * 3);
        if (tool == PetCareTool.towel) {
          _sparkle(
            canvas,
            center,
            2.0 + i % 3 * 2,
            _tint(i).withValues(alpha: .85),
          );
        } else if (style == PetCareStyle.soapStrawberry && i.isEven) {
          _heart(canvas, center, 3.6, Paint()..color = _tint(i));
        } else {
          final radius = 3.0 + i % 3 * 2;
          canvas.drawCircle(
            center,
            radius,
            Paint()..color = Colors.white.withValues(alpha: .8),
          );
          canvas.drawCircle(
            center,
            radius,
            Paint()
              ..color = _tint(i).withValues(alpha: .8)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1,
          );
        }
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PetPlayEffectsPainter oldDelegate) => true;
}
