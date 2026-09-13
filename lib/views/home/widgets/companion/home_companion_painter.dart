import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'home_companion_motion.dart';

/// Bé thỏ và bụi chỉ là lớp trang trí, không tự nhận thao tác trên Home.
class HomeCompanionPainter extends CustomPainter {
  HomeCompanionPainter({
    required this.motion,
    required this.darkMode,
    this.showEffects = true,
  }) : super(repaint: motion);

  final HomeCompanionMotion motion;
  final bool darkMode;
  final bool showEffects;

  /// Tăng đúng 20% so với nét vẽ gốc 0.52; dùng chung cho vùng an toàn của Home.
  static const double spriteScale = 0.624;
  static const double horizontalClearance = 22;
  static const double topClearance = 84;
  static const _outline = Color(0xFF956E69);
  static const _cream = Color(0xFFFFFAEF);
  static const _creamShade = Color(0xFFF3DDC8);
  static const _pink = Color(0xFFF2B4BE);
  static const _rose = Color(0xFFCF718B);
  static const _roseShade = Color(0xFFAC526F);
  static const _eye = Color(0xFF634B4B);

  @override
  void paint(Canvas canvas, Size size) {
    if (!motion.hasSurfaces || size.isEmpty) return;

    canvas.save();
    canvas.clipRect(Offset.zero & size);
    if (showEffects) _paintDust(canvas);

    // Chế độ giảm chuyển động luôn giữ tư thế nghỉ, kể cả khi tắt giữa cú nhảy.
    final phase = showEffects ? motion.phase : HomeCompanionPhase.idle;
    final walking = phase == HomeCompanionPhase.walking;
    final approaching = phase == HomeCompanionPhase.approaching;
    final sweeping = phase == HomeCompanionPhase.sweeping;
    final hopping = phase == HomeCompanionPhase.hopping;
    final moving = walking || approaching || hopping;
    final celebrating = phase == HomeCompanionPhase.celebrating;
    final stride = motion.stride * math.pi * 2;
    final step = moving ? math.sin(stride) : 0.0;
    // Chân neo theo đường đi, còn thân bay lên: không kéo bóng/chổi khỏi mặt khối.
    final hopLift = moving ? motion.hopLift.clamp(0.0, 16.0) : 0.0;
    final airborne = hopLift > 0.3;
    final liftRatio = (hopLift / 16).clamp(0.0, 1.0);
    final bounce = moving ? math.cos(stride * 2) : 0.0;
    final squash = moving && !airborne ? bounce * 0.025 : 0.0;
    final scaleX = 1 + squash - liftRatio * 0.055;
    final scaleY = 1 - squash + liftRatio * 0.065;
    final seconds = showEffects ? motion.elapsedSeconds : 0.0;
    final sweep = sweeping ? math.sin(seconds * 10) : 0.0;
    final breathe = math.sin(seconds * 2.4);
    final bodyBob = moving
        ? -step.abs() * (approaching ? 4.0 : 2.8)
        : sweeping
        ? sweep.abs() * 0.65
        : breathe * 0.55;

    // Bóng neo vào mặt khối; nhân vật luôn đứng thẳng dù đường đi là vòng tròn.
    canvas.drawOval(
      Rect.fromCenter(
        center: motion.position + const Offset(0, 1),
        width: 20.4 - liftRatio * 7.2,
        height: 3.6 - liftRatio * 1.2,
      ),
      Paint()
        ..color = (darkMode ? Colors.black : const Color(0xFF9D7079))
            .withValues(alpha: 0.15 - liftRatio * 0.07),
    );

    canvas.save();
    canvas.translate(motion.position.dx, motion.position.dy - hopLift);
    canvas.scale(
      (motion.facingRight ? spriteScale : -spriteScale) * scaleX,
      spriteScale * scaleY,
    );

    _paintTail(canvas, bodyBob, step);
    _paintFoot(canvas, -7, step * 5.5, hopping: airborne, front: false);
    _paintArm(
      canvas,
      const Offset(-12, -29) + Offset(0, bodyBob),
      airborne
          ? -0.5 - step * 0.22
          : moving
          ? step * 0.52
          : -0.15 - breathe * 0.04,
      behind: true,
    );

    canvas.save();
    canvas.translate(0, bodyBob);
    _shape(
      canvas,
      Path()
        ..moveTo(-12, -34)
        ..cubicTo(-19, -24, -18, -10, -13, -6)
        ..cubicTo(-7, -1, 11, -2, 15, -7)
        ..cubicTo(20, -15, 17, -26, 11, -34)
        ..close(),
      _cream,
      shade: _creamShade,
    );
    canvas.drawOval(
      const Rect.fromLTWH(-7, -23, 18, 16),
      Paint()..color = const Color(0xFFFFFDF7),
    );
    _paintScarfTail(canvas, moving: moving, step: step, breathe: breathe);
    _paintHead(
      canvas,
      earSway: moving ? step * 0.11 + liftRatio * 0.08 : breathe * 0.035,
      happy: celebrating,
      sweeping: sweeping,
    );
    _paintScarfCollar(canvas);
    canvas.restore();

    _paintFoot(canvas, 8, -step * 5.5, hopping: airborne, front: true);

    if (sweeping) {
      _paintBroom(canvas, sweep: sweep, bodyBob: bodyBob);
    } else {
      _paintArm(
        canvas,
        Offset(13, -29 + bodyBob),
        celebrating
            ? -2.45 + math.sin(motion.elapsedSeconds * 12) * 0.18
            : airborne
            ? -0.9 + step * 0.24
            : moving
            ? -step * 0.62
            : 0.1 + breathe * 0.045,
      );
    }
    canvas.restore();

    if (showEffects && motion.celebration > 0) _paintCleanGlints(canvas);
    canvas.restore();
  }

  void _paintDust(Canvas canvas) {
    final color = darkMode ? const Color(0xFFD5BFA6) : const Color(0xFFAA8B77);
    for (final dust in motion.dust) {
      final remaining = dust.remaining.clamp(0.0, 1.0);
      if (remaining <= 0) continue;
      final seed = dust.seed;
      final paint = Paint()..color = color.withValues(alpha: remaining * 0.30);
      // Cụm bụi nhỏ, thưa; thu dần theo nhát quét, không phủ đục mặt khối.
      for (var i = 0; i < 5; i++) {
        final angle = (seed * 0.73 + i * 2.39) % (math.pi * 2);
        final distance = (1.8 + (i % 3) * 1.45) * remaining;
        final center =
            dust.position +
            Offset(math.cos(angle), math.sin(angle) * 0.45) * distance;
        canvas.drawOval(
          Rect.fromCenter(
            center: center,
            width: (1.7 + (i % 2) * 0.8) * remaining,
            height: (1.2 + (i % 3) * 0.3) * remaining,
          ),
          paint,
        );
      }
    }
  }

  void _paintTail(Canvas canvas, double bodyBob, double step) {
    _shape(
      canvas,
      Path()..addOval(Rect.fromLTWH(-24 - step * 0.3, -18 + bodyBob, 13, 13)),
      _cream,
      shade: _creamShade,
    );
  }

  void _paintFoot(
    Canvas canvas,
    double x,
    double step, {
    required bool hopping,
    required bool front,
  }) {
    final lift = hopping ? 4.0 : math.max(0.0, -step) * 0.47;
    final rect = Rect.fromCenter(
      center: Offset(x + step, -2.7 - lift),
      width: 13,
      height: 6.8,
    );
    _shape(
      canvas,
      Path()..addOval(rect),
      front ? _cream : _creamShade,
      lineWidth: 1.45,
    );
    _stroke(
      canvas,
      Path()
        ..moveTo(rect.right - 4, rect.center.dy + 0.9)
        ..lineTo(rect.right - 3.4, rect.center.dy + 2.1),
      width: 0.85,
      color: _outline.withValues(alpha: 0.6),
    );
  }

  void _paintScarfTail(
    Canvas canvas, {
    required bool moving,
    required double step,
    required double breathe,
  }) {
    final flutter = moving ? step * 3 : breathe;
    _shape(
      canvas,
      Path()
        ..moveTo(-8, -33)
        ..quadraticBezierTo(-19, -33, -25, -29 - flutter)
        ..lineTo(-22, -25 - flutter)
        ..lineTo(-25, -23 - flutter)
        ..quadraticBezierTo(-11, -24, -5, -30)
        ..close(),
      _rose,
      outline: _roseShade,
      lineWidth: 1.15,
    );
  }

  void _paintScarfCollar(Canvas canvas) {
    _shape(
      canvas,
      Path()
        ..moveTo(-15, -34)
        ..quadraticBezierTo(0, -29, 15, -34)
        ..lineTo(14, -29)
        ..quadraticBezierTo(0, -24, -13, -29)
        ..close(),
      _rose,
      outline: _roseShade,
      lineWidth: 1.25,
    );
    _shape(
      canvas,
      Path()..addOval(const Rect.fromLTWH(6, -31, 7, 6)),
      const Color(0xFFE99AAF),
      outline: _roseShade,
      lineWidth: 1,
    );
    _stroke(
      canvas,
      Path()
        ..moveTo(-10, -32)
        ..quadraticBezierTo(-2, -29, 5, -31),
      color: const Color(0xFFF6C9D3),
      width: 1.1,
    );
  }

  void _paintHead(
    Canvas canvas, {
    required double earSway,
    required bool happy,
    required bool sweeping,
  }) {
    _paintEar(canvas, const Offset(-10, -64), -0.16 - earSway, 28);
    _paintEar(canvas, const Offset(11, -64), 0.12 + earSway * 0.75, 30);
    _shape(
      canvas,
      Path()
        ..moveTo(-21, -57)
        ..cubicTo(-17, -68, 15, -70, 22, -57)
        ..cubicTo(29, -47, 27, -35, 15, -32)
        ..cubicTo(5, -28, -12, -29, -21, -35)
        ..cubicTo(-29, -40, -28, -50, -21, -57)
        ..close(),
      _cream,
      shade: _creamShade,
    );
    final cheekPaint = Paint()..color = _pink.withValues(alpha: 0.72);
    canvas.drawOval(const Rect.fromLTWH(-21, -44, 10, 5.5), cheekPaint);
    canvas.drawOval(const Rect.fromLTWH(14, -44, 10, 5.5), cheekPaint);

    final blinkPhase = showEffects ? motion.elapsedSeconds % 5.4 : 0.0;
    final blink = blinkPhase > 4.97 && blinkPhase < 5.11;
    final eyeY = sweeping ? -48.0 : -49.0;
    for (final eyeX in const [-7.5, 10.5]) {
      if (blink || happy) {
        _stroke(
          canvas,
          Path()
            ..moveTo(eyeX - 2.6, eyeY + 0.8)
            ..quadraticBezierTo(
              eyeX,
              happy ? eyeY - 2.8 : eyeY + 2.4,
              eyeX + 2.6,
              eyeY + 0.8,
            ),
          color: _eye,
          width: 1.55,
        );
      } else {
        canvas.drawOval(
          Rect.fromCenter(center: Offset(eyeX, eyeY), width: 3.4, height: 4.9),
          Paint()..color = _eye,
        );
        canvas.drawCircle(
          Offset(eyeX - 0.55, eyeY - 1),
          0.72,
          Paint()..color = Colors.white,
        );
      }
    }
    _shape(
      canvas,
      Path()
        ..moveTo(-0.6, -43.6)
        ..quadraticBezierTo(1.7, -45.2, 4, -43.6)
        ..quadraticBezierTo(2.8, -40.4, 1.7, -40.9)
        ..quadraticBezierTo(0.3, -41.4, -0.6, -43.6),
      _rose,
      outline: _rose,
      lineWidth: 0.75,
    );
    _stroke(
      canvas,
      Path()
        ..moveTo(1.7, -41)
        ..quadraticBezierTo(1.5, -36.7, -2.4, -38.5)
        ..moveTo(1.7, -41)
        ..quadraticBezierTo(2.5, -36.7, 5.6, -38.5),
      width: 1.05,
      color: _eye,
    );
  }

  void _paintEar(Canvas canvas, Offset base, double angle, double height) {
    canvas.save();
    canvas.translate(base.dx, base.dy);
    canvas.rotate(angle);
    _shape(
      canvas,
      Path()
        ..moveTo(-5.8, 1)
        ..cubicTo(-9, -8, -9, -height, -1, -height)
        ..cubicTo(7, -height, 9, -12, 5.6, 1)
        ..close(),
      _cream,
      lineWidth: 1.55,
    );
    canvas.drawOval(
      Rect.fromLTWH(-3.7, -height + 5, 7, height - 7),
      Paint()..color = _pink.withValues(alpha: 0.66),
    );
    canvas.restore();
  }

  void _paintArm(
    Canvas canvas,
    Offset pivot,
    double angle, {
    bool behind = false,
  }) {
    canvas.save();
    canvas.translate(pivot.dx, pivot.dy);
    canvas.rotate(angle);
    _shape(
      canvas,
      Path()
        ..moveTo(-4, -1)
        ..cubicTo(-7, 4, -5, 13, -1, 15)
        ..cubicTo(4, 17, 7, 12, 5, 8)
        ..lineTo(4, 1)
        ..close(),
      behind ? _creamShade : _cream,
      lineWidth: 1.4,
    );
    canvas.restore();
  }

  void _paintBroom(
    Canvas canvas, {
    required double sweep,
    required double bodyBob,
  }) {
    // Quay cán quanh đầu chổi, không quanh tay: lông chổi luôn chạm đúng
    // motion.position, kể cả khi lật hướng bé. Không dùng lớp xóa nền Home.
    final brushX = sweep * 3;
    final handleTop = Offset(18 + sweep * 7, -40 + bodyBob);
    final brushTop = Offset(brushX + 2, -10);
    _stroke(
      canvas,
      Path()
        ..moveTo(handleTop.dx, handleTop.dy)
        ..lineTo(brushTop.dx, brushTop.dy),
      color: const Color(0xFF997353),
      width: 3.1,
    );
    _stroke(
      canvas,
      Path()
        ..moveTo(handleTop.dx - 0.5, handleTop.dy + 1.5)
        ..lineTo(brushTop.dx - 0.5, brushTop.dy),
      color: const Color(0xFFE3BD8E),
      width: 1.2,
    );
    _shape(
      canvas,
      Path()
        ..moveTo(brushX - 2.4, -11.2)
        ..lineTo(brushX + 5.5, -11.2)
        ..quadraticBezierTo(brushX + 8, -5, brushX + 11, 0.2)
        ..quadraticBezierTo(brushX + 1, 2.1, brushX - 9, 0)
        ..quadraticBezierTo(brushX - 5.5, -5.6, brushX - 2.4, -11.2)
        ..close(),
      const Color(0xFFE0BE84),
      outline: const Color(0xFFAE8759),
      lineWidth: 1,
    );
    for (var i = -2; i <= 2; i++) {
      _stroke(
        canvas,
        Path()
          ..moveTo(brushX + 1.4 + i * 1.1, -8)
          ..lineTo(brushX + 1 + i * 3.6, -0.9),
        color: const Color(0xFFAE8759),
        width: 0.75,
      );
    }
    _stroke(
      canvas,
      Path()
        ..moveTo(brushX - 2.5, -9.6)
        ..lineTo(brushX + 5.7, -9.6),
      color: _roseShade,
      width: 2.7,
    );

    final grip = Offset.lerp(handleTop, brushTop, 0.39)!;
    _stroke(
      canvas,
      Path()
        ..moveTo(14, -26 + bodyBob)
        ..quadraticBezierTo(23, -19 + bodyBob, grip.dx, grip.dy),
      color: _outline,
      width: 8,
    );
    _stroke(
      canvas,
      Path()
        ..moveTo(14, -26 + bodyBob)
        ..quadraticBezierTo(23, -19 + bodyBob, grip.dx, grip.dy),
      color: _cream,
      width: 5.4,
    );
    _shape(
      canvas,
      Path()..addOval(Rect.fromCenter(center: grip, width: 8, height: 6.5)),
      _cream,
      lineWidth: 1.15,
    );
  }

  void _paintCleanGlints(Canvas canvas) {
    final progress = motion.celebration.clamp(0.0, 1.0);
    final strength = math.sin(progress * math.pi).clamp(0.0, 1.0);
    if (strength < 0.02) return;
    final color = darkMode ? const Color(0xFFFFD9A2) : const Color(0xFFDFA958);
    for (var i = 0; i < 3; i++) {
      final x = (i - 1) * 15.6;
      final y = i == 1 ? -62.4 : -38.4;
      final radius = (i == 1 ? 3.1 : 2.3) * strength;
      final center = motion.position + Offset(x, y - progress * 5);
      canvas.drawPath(
        Path()
          ..moveTo(center.dx, center.dy - radius)
          ..quadraticBezierTo(
            center.dx + radius * 0.2,
            center.dy - radius * 0.2,
            center.dx + radius,
            center.dy,
          )
          ..quadraticBezierTo(
            center.dx + radius * 0.2,
            center.dy + radius * 0.2,
            center.dx,
            center.dy + radius,
          )
          ..quadraticBezierTo(
            center.dx - radius * 0.2,
            center.dy + radius * 0.2,
            center.dx - radius,
            center.dy,
          )
          ..quadraticBezierTo(
            center.dx - radius * 0.2,
            center.dy - radius * 0.2,
            center.dx,
            center.dy - radius,
          )
          ..close(),
        Paint()..color = color.withValues(alpha: strength * 0.9),
      );
    }
  }

  void _shape(
    Canvas canvas,
    Path path,
    Color color, {
    Color? shade,
    Color outline = _outline,
    double lineWidth = 1.65,
  }) {
    final paint = Paint()..color = color;
    if (shade != null) {
      paint.shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [color, shade],
      ).createShader(path.getBounds());
    }
    canvas.drawPath(path, paint);
    _stroke(canvas, path, color: outline, width: lineWidth);
  }

  void _stroke(
    Canvas canvas,
    Path path, {
    Color color = _outline,
    double width = 1.65,
  }) {
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant HomeCompanionPainter oldDelegate) =>
      oldDelegate.motion != motion ||
      oldDelegate.darkMode != darkMode ||
      oldDelegate.showEffects != showEffects;
}
