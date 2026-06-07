part of '../tarot_screen.dart';

class _TarotDustPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final random = Random(7);
    final paint = Paint();
    for (var i = 0; i < 90; i++) {
      paint.color = Colors.white.withValues(alpha: random.nextDouble() * 0.16);
      final dx = random.nextDouble() * size.width;
      final dy = random.nextDouble() * size.height;
      final radius = random.nextDouble() * 1.8 + 0.4;
      canvas.drawCircle(Offset(dx, dy), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
