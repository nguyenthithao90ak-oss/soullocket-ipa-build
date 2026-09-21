import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import 'home_companion_motion.dart';
import 'home_companion_outfit.dart';
import 'home_companion_play.dart';
import 'home_companion_metrics.dart';

export 'home_companion_outfit.dart';

/// Cặp thỏ/gấu và bụi chỉ là lớp trang trí, không tự nhận thao tác trên Home.
class HomeCompanionPainter extends CustomPainter {
  HomeCompanionPainter({
    required this.motion,
    required this.darkMode,
    this.showEffects = true,
    this.paintOffset,
    this.character = HomeCompanionCharacter.bunny,
    this.outfit,
    this.play,
    this.socialPlay,
  }) : super(
         repaint: Listenable.merge([motion, paintOffset, play, socialPlay]),
       );

  final HomeCompanionMotion motion;
  final bool darkMode;
  final bool showEffects;
  final ValueListenable<Offset>? paintOffset;
  final HomeCompanionCharacter character;
  final HomeCompanionOutfit? outfit;
  final HomeCompanionPlay? play;
  final HomeCompanionPlay? socialPlay;
  HomeCompanionPlay? get _activePlay =>
      (socialPlay?.active ?? false) && socialPlay!.contains(character)
      ? socialPlay
      : play;
  bool get _facingRight => showEffects && (_activePlay?.active ?? false)
      ? _activePlay!.facesRight(character)
      : motion.facingRight;
  HomeCompanionOutfit get _outfit =>
      outfit ?? HomeCompanionOutfit.defaults(character);
  bool get _isBear => character == HomeCompanionCharacter.bear;
  bool get _isKuromi => character == HomeCompanionCharacter.kuromi;
  bool get _isMelody => character == HomeCompanionCharacter.melody;
  bool get _hasHood => _isKuromi || _isMelody;
  Color get _hood =>
      _isKuromi ? const Color(0xFF9D7BCD) : const Color(0xFFED91B6);
  Color get _hoodEdge => const Color(0xFF49404E);

  /// Kuromi là chuẩn; từng bộ nét vẽ có tỷ lệ riêng để cùng chiều cao thực.
  static const double spriteScale = HomeCompanionMetrics.kuromiScale;
  static const double bearSpriteScale = HomeCompanionMetrics.bearScale;
  static const double horizontalClearance = 32;
  static const double topClearance = 104;
  static const _outline = Color(0xFF956E69);
  Color get _cream => _hasHood
      ? const Color(0xFFFFFEFC)
      : _isBear
      ? const Color(0xFFD6A171)
      : const Color(0xFFFFFAEF);
  Color get _creamShade => _hasHood
      ? const Color(0xFFF4F0F5)
      : _isBear
      ? const Color(0xFFBD8159)
      : const Color(0xFFF3DDC8);
  static const _pink = Color(0xFFF2B4BE);
  Color get _rose =>
      _isBear ? const Color(0xFF6B9FAC) : const Color(0xFFCF718B);
  Color get _roseShade =>
      _isBear ? const Color(0xFF497482) : const Color(0xFFAC526F);
  static const _eye = Color(0xFF634B4B);

  @override
  void paint(Canvas canvas, Size size) {
    if (!motion.hasSurfaces || size.isEmpty) return;

    canvas.save();
    canvas.clipRect(Offset.zero & size);
    final offset = paintOffset?.value ?? Offset.zero;
    canvas.translate(offset.dx, offset.dy);
    if (showEffects) _paintDust(canvas);
    final playPose = showEffects
        ? _activePlay?.pose(character) ?? const CompanionPlayPose()
        : const CompanionPlayPose();
    canvas.translate(playPose.offset.dx, playPose.offset.dy);

    // Giảm chuyển động giữ tư thế nghỉ; cú vượt đang dở giữ độ cao để
    // không rơi xuyên đầu bạn bên dưới. Ticker ngừng nên độ cao không đổi.
    final phase = showEffects && !(_activePlay?.active ?? false)
        ? motion.phase
        : HomeCompanionPhase.idle;
    final walking = phase == HomeCompanionPhase.walking;
    final approaching = phase == HomeCompanionPhase.approaching;
    final sweeping = phase == HomeCompanionPhase.sweeping;
    final hopping = phase == HomeCompanionPhase.hopping;
    final moving = walking || approaching || hopping;
    final celebrating = phase == HomeCompanionPhase.celebrating;
    final stride = motion.stride * math.pi * 2;
    final step = moving ? math.sin(stride) : 0.0;
    // Chân neo theo đường đi, còn thân bay lên: không kéo bóng/chổi khỏi mặt khối.
    final hopLift =
        (motion.isPassing
            ? motion.hopLift
            : moving
            ? motion.hopLift.clamp(0.0, 16.0)
            : 0.0) +
        playPose.lift;
    final airborne = hopLift > 0.3;
    final liftRatio = (hopLift / 16).clamp(0.0, 1.0);
    final bounce = moving ? math.cos(stride * 2) : 0.0;
    final squash = moving && !airborne ? bounce * 0.025 : 0.0;
    final scaleX = 1 + squash - liftRatio * 0.055;
    final scaleY = 1 - squash + liftRatio * 0.065;
    final seconds = showEffects
        ? motion.elapsedSeconds + (_activePlay?.time ?? 0)
        : 0.0;
    final affection = showEffects ? motion.affection.clamp(0.0, 1.0) : 0.0;
    final greeting = math.sin((1 - affection) * math.pi * 5) * affection;
    final sweep = sweeping ? math.sin(seconds * 10) : 0.0;
    final breathe = math.sin(seconds * 2.4);
    final bodyBob = moving
        ? -(1 - math.cos(stride * 2)) * (approaching ? 2.0 : 1.4)
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
    canvas.rotate(playPose.tilt + (moving ? step * 0.018 : 0));
    final scale = HomeCompanionMetrics.scale(character);
    canvas.scale((_facingRight ? scale : -scale) * scaleX, scale * scaleY);

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
    if (!_hasHood) {
      canvas.drawOval(
        const Rect.fromLTWH(-7, -23, 18, 16),
        Paint()
          ..color = _isBear ? const Color(0xFFF3D7B2) : const Color(0xFFFFFDF7),
      );
    }
    if (_outfit.clothes == CompanionClothes.overalls) {
      _paintBearOveralls(canvas);
    } else if (_outfit.clothes != CompanionClothes.classic) {
      _paintCoat(canvas);
    }
    _paintScarfTail(canvas, moving: moving, step: step, breathe: breathe);
    _paintHead(
      canvas,
      earSway:
          (moving ? step * 0.11 + liftRatio * 0.08 : breathe * 0.035) +
          greeting * 0.07,
      happy: celebrating,
      sweeping: sweeping,
      affection: affection,
      tilt: greeting * 0.035 + (moving ? -step * 0.028 : 0),
    );
    _paintScarfCollar(canvas);
    canvas.restore();

    _paintFoot(
      canvas,
      8 + playPose.kick * 9,
      -step * 5.5,
      hopping: airborne || playPose.kick > 0,
      front: true,
    );

    if (sweeping) {
      _paintBroom(canvas, sweep: sweep, bodyBob: bodyBob);
    } else {
      _paintArm(
        canvas,
        Offset(13, -29 + bodyBob),
        celebrating
            ? -2.45 + math.sin(motion.elapsedSeconds * 12) * 0.18
            : affection > 0.05
            ? -2.05 + greeting * 0.3
            : airborne
            ? -0.9 + step * 0.24
            : moving
            ? -step * 0.62
            : 0.1 + breathe * 0.045,
      );
    }
    if (!sweeping) _paintProp(canvas, bodyBob, seconds);
    canvas.restore();

    if (showEffects && motion.celebration > 0) _paintCleanGlints(canvas);
    if (affection > 0) _paintAffectionHearts(canvas, affection, hopLift);
    if (showEffects) _paintPlayEffects(canvas, playPose, seconds);
    canvas.restore();
  }

  void _paintCoat(Canvas canvas) {
    final night = _outfit.clothes == CompanionClothes.night;
    final rain = _outfit.clothes == CompanionClothes.raincoat;
    final sailor = _outfit.clothes == CompanionClothes.sailor;
    final color = rain
        ? const Color(0xFFF4CD6B)
        : sailor
        ? const Color(0xFFF6F5F0)
        : night
        ? const Color(0xFFB5A1D7)
        : (_isBear ? const Color(0xFF8BB4A1) : const Color(0xFFE8A8BC));
    _shape(
      canvas,
      Path()
        ..moveTo(-12, -31)
        ..quadraticBezierTo(0, -24, 12, -31)
        ..quadraticBezierTo(20, -17, 14, -6)
        ..quadraticBezierTo(0, -1, -14, -6)
        ..quadraticBezierTo(-18, -18, -12, -31)
        ..close(),
      color,
      outline: color.withValues(
        red: color.r * 0.75,
        green: color.g * 0.75,
        blue: color.b * 0.75,
      ),
    );
    if (rain) {
      _stroke(
        canvas,
        Path()
          ..moveTo(0, -29)
          ..lineTo(0, -5),
        color: const Color(0xFFB88B40),
        width: 1,
      );
      for (final y in [-23.0, -17.0, -11.0]) {
        canvas.drawCircle(
          Offset(3, y),
          1.3,
          Paint()..color = const Color(0xFFFFFAE8),
        );
      }
      _stroke(
        canvas,
        Path()
          ..moveTo(-12, -13)
          ..lineTo(-5, -13)
          ..lineTo(-5, -8)
          ..lineTo(-12, -8)
          ..close(),
        color: const Color(0xFFB88B40),
        width: 1,
      );
    } else if (sailor) {
      _shape(
        canvas,
        Path()
          ..moveTo(-13, -29)
          ..lineTo(0, -17)
          ..lineTo(13, -29)
          ..lineTo(9, -22)
          ..lineTo(0, -11)
          ..lineTo(-9, -22)
          ..close(),
        const Color(0xFF628BB0),
      );
      _shape(
        canvas,
        Path()
          ..moveTo(-3, -17)
          ..lineTo(3, -17)
          ..lineTo(1, -5)
          ..lineTo(-2, -8)
          ..close(),
        const Color(0xFFE597AA),
      );
      _stroke(
        canvas,
        Path()
          ..moveTo(-13, -7)
          ..lineTo(13, -7),
        color: const Color(0xFF628BB0),
        width: 1.5,
      );
    } else if (night) {
      for (final point in const [
        Offset(-7, -17),
        Offset(7, -10),
        Offset(8, -24),
      ]) {
        _star(canvas, point, 2, const Color(0xFFFFE2A6));
      }
    } else {
      _stroke(
        canvas,
        Path()
          ..moveTo(-7, -14)
          ..lineTo(-5, -8)
          ..lineTo(6, -8)
          ..lineTo(8, -14),
        color: Colors.white.withValues(alpha: 0.7),
        width: 1.1,
      );
    }
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
    if (_isKuromi) {
      _stroke(
        canvas,
        Path()
          ..moveTo(-13, -12 + bodyBob)
          ..quadraticBezierTo(-29, -3, -25 - step, -24),
        color: _hood,
        width: 2.8,
      );
      _shape(
        canvas,
        Path()
          ..moveTo(-25 - step, -29)
          ..lineTo(-31 - step, -21)
          ..lineTo(-21 - step, -22)
          ..close(),
        _hood,
        outline: _hoodEdge,
      );
      return;
    }
    _shape(
      canvas,
      Path()..addOval(
        _isBear
            ? Rect.fromLTWH(-21 - step * 0.3, -17 + bodyBob, 9, 9)
            : Rect.fromLTWH(-24 - step * 0.3, -18 + bodyBob, 13, 13),
      ),
      _cream,
      shade: _creamShade,
    );
  }

  void _paintBearOveralls(Canvas canvas) {
    // Yếm xanh denim và cúc mật ong giúp phân biệt ngay ở kích thước nhỏ.
    _shape(
      canvas,
      Path()
        ..moveTo(-13, -24)
        ..lineTo(-8, -24)
        ..lineTo(-6, -16)
        ..lineTo(7, -16)
        ..lineTo(10, -24)
        ..lineTo(14, -23)
        ..lineTo(14, -8)
        ..quadraticBezierTo(0, -1, -13, -8)
        ..close(),
      const Color(0xFF7DAEB9),
      outline: _roseShade,
      lineWidth: 1.2,
    );
    for (final x in [-8.0, 10.0]) {
      canvas.drawCircle(
        Offset(x, -15),
        1.45,
        Paint()..color = const Color(0xFFFFE2A5),
      );
    }
    _stroke(
      canvas,
      Path()
        ..moveTo(-3, -12)
        ..lineTo(-3, -8)
        ..quadraticBezierTo(1, -5, 5, -8)
        ..lineTo(5, -12),
      color: const Color(0xFFCCE0E4),
      width: 0.85,
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
      width: _hasHood ? 15 : 13,
      height: _hasHood ? 9 : 6.8,
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
    if (_hasHood) return;
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
    if (_hasHood) {
      _shape(
        canvas,
        _isKuromi
            ? (Path()
                ..moveTo(-16, -34)
                ..quadraticBezierTo(-22, -27, -28, -28)
                ..quadraticBezierTo(-18, -20, -9, -26)
                ..lineTo(-15, -18)
                ..quadraticBezierTo(0, -21, 2, -28)
                ..quadraticBezierTo(12, -19, 20, -23)
                ..lineTo(28, -28)
                ..quadraticBezierTo(20, -27, 15, -34)
                ..close())
            : (Path()
                ..moveTo(-17, -33)
                ..lineTo(-21, -26)
                ..quadraticBezierTo(-13, -20, -7, -24)
                ..lineTo(-4, -31)
                ..lineTo(5, -31)
                ..lineTo(9, -23)
                ..quadraticBezierTo(16, -23, 20, -27)
                ..lineTo(16, -33)
                ..close()),
        _hood,
        outline: _hoodEdge,
      );
      if (_isKuromi) {
        for (final point in const [
          Offset(-28, -28),
          Offset(28, -28),
          Offset(-15, -18),
        ]) {
          _shape(
            canvas,
            Path()..addOval(Rect.fromCircle(center: point, radius: 3.1)),
            const Color(0xFFF1A3C6),
            outline: _hoodEdge,
            lineWidth: 1.3,
          );
        }
      }
      return;
    }
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
      _isBear ? const Color(0xFFB7D9DF) : const Color(0xFFE99AAF),
      outline: _roseShade,
      lineWidth: 1,
    );
    _stroke(
      canvas,
      Path()
        ..moveTo(-10, -32)
        ..quadraticBezierTo(-2, -29, 5, -31),
      color: _isBear ? const Color(0xFFD8EEF1) : const Color(0xFFF6C9D3),
      width: 1.1,
    );
  }

  void _paintHead(
    Canvas canvas, {
    required double earSway,
    required bool happy,
    required bool sweeping,
    required double affection,
    required double tilt,
  }) {
    canvas.save();
    // Chỉ nghiêng đầu: chân và chổi vẫn neo đúng mặt khối.
    canvas.translate(0, -38);
    canvas.rotate(tilt);
    canvas.translate(0, 38);
    if (_hasHood) {
      _paintHoodHead(
        canvas,
        earSway: earSway,
        happy: happy,
        affection: affection,
      );
      canvas.save();
      // Mắt hai bé mới rộng hơn và thấp hơn; kính vẫn phải ôm đúng mặt.
      canvas.translate(-1.8, 2.3);
      canvas.scale(1.22, 1);
      _paintGlasses(canvas);
      canvas.restore();
      _paintHat(canvas);
      canvas.restore();
      return;
    }
    if (_isBear) {
      _paintBearEar(canvas, Offset(-18, -63 + earSway * 3));
      _paintBearEar(canvas, Offset(19, -63 - earSway * 3));
    } else {
      _paintEar(canvas, const Offset(-10, -64), -0.16 - earSway, 28);
      _paintEar(canvas, const Offset(11, -64), 0.12 + earSway * 0.75, 30);
    }
    _shape(
      canvas,
      Path()
        ..moveTo(-22, -57)
        ..cubicTo(-18, -69, 16, -70, 23, -57)
        ..cubicTo(30, -48, 29, -36, 17, -31)
        ..cubicTo(6, -27, -12, -27, -22, -34)
        ..cubicTo(-30, -39, -29, -49, -22, -57)
        ..close(),
      _cream,
      shade: _creamShade,
    );
    if (_isBear) {
      canvas.drawOval(
        const Rect.fromLTWH(-9, -47, 22, 15),
        Paint()..color = const Color(0xFFF5DEBD),
      );
      _stroke(
        canvas,
        Path()
          ..moveTo(-5, -64)
          ..quadraticBezierTo(-1, -68, 1, -63)
          ..quadraticBezierTo(4, -67, 6, -63),
        width: 1.5,
        color: const Color(0xFF9F6D4C),
      );
    }
    final cheekPaint = Paint()
      ..color = _pink.withValues(alpha: 0.74 + affection * 0.16);
    canvas.drawOval(const Rect.fromLTWH(-22, -44.5, 12, 7), cheekPaint);
    canvas.drawOval(const Rect.fromLTWH(13, -44.5, 12, 7), cheekPaint);
    for (final x in const [-18.5, 16.5]) {
      _stroke(
        canvas,
        Path()
          ..moveTo(x, -42.1)
          ..lineTo(x - 0.6, -40.8)
          ..moveTo(x + 2.5, -42.1)
          ..lineTo(x + 1.9, -40.8),
        color: _rose.withValues(alpha: 0.45),
        width: 0.65,
      );
    }

    final blinkPhase = showEffects
        ? (motion.elapsedSeconds + (_isBear ? 1.3 : 0)) % 5.4
        : 0.0;
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
          Rect.fromCenter(center: Offset(eyeX, eyeY), width: 4.8, height: 6.4),
          Paint()..color = _eye,
        );
        canvas.drawCircle(
          Offset(eyeX - 0.65, eyeY - 1.3),
          1.0,
          Paint()..color = Colors.white,
        );
        canvas.drawCircle(
          Offset(eyeX + 0.75, eyeY + 1.3),
          0.5,
          Paint()..color = const Color(0xFFFFE3DC),
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
      _isBear ? _eye : _rose,
      outline: _isBear ? _eye : _rose,
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
    _paintGlasses(canvas);
    _paintHat(canvas);
    canvas.restore();
  }

  /// Mũ và tai thuộc nhận diện nhân vật, không mất khi thay áo/phụ kiện.
  void _paintHoodHead(
    Canvas canvas, {
    required double earSway,
    required bool happy,
    required double affection,
  }) {
    if (_isKuromi) {
      // Tai mũ hề xòe ngang, không dùng đôi tai thỏ nhọn dựng sát nhau.
      for (final side in [-1.0, 1.0]) {
        canvas.save();
        canvas.scale(side, 1);
        canvas.translate(20, -72);
        canvas.rotate(earSway * 0.45);
        _shape(
          canvas,
          Path()
            ..moveTo(-7, -2)
            ..lineTo(-6, -12)
            ..lineTo(19, -29)
            ..lineTo(16, 1)
            ..lineTo(7, 5)
            ..close(),
          _hood,
          outline: _hoodEdge,
          lineWidth: 2.1,
        );
        _shape(
          canvas,
          Path()..addOval(const Rect.fromLTWH(15, -33, 8, 8)),
          _hood,
          outline: _hoodEdge,
          lineWidth: 2,
        );
        canvas.restore();
      }
    }
    final sway = earSway * 12;
    _shape(
      canvas,
      _isMelody
          ? (Path()
              ..moveTo(-31, -58)
              ..quadraticBezierTo(-31, -70, -24, -76)
              ..cubicTo(-20 + sway, -95, -16 + sway, -106, -8 + sway, -106)
              ..cubicTo(2 + sway, -107, 2, -94, 1, -90)
              ..cubicTo(8, -102, 25, -103, 30, -93)
              ..quadraticBezierTo(35, -85, 28, -72)
              ..cubicTo(41, -53, 40, -42, 28, -34)
              ..cubicTo(14, -24, -27, -26, -33, -41)
              ..quadraticBezierTo(-37, -48, -31, -58)
              ..close())
          : (Path()
              ..moveTo(-31, -58)
              ..cubicTo(-29, -87, 25, -88, 32, -61)
              ..cubicTo(43, -35, 22, -27, 1, -28)
              ..cubicTo(-23, -27, -41, -36, -31, -58)
              ..close()),
      _hood,
      outline: _hoodEdge,
      lineWidth: 2.2,
    );
    if (_isMelody) {
      // Nếp tai gập liền mũ, không lộ đường ráp khi nghiêng hoặc nhảy.
      _stroke(
        canvas,
        Path()
          ..moveTo(1, -90)
          ..cubicTo(-12, -75, 4 + sway * 0.2, -67, 18, -84),
        color: _hoodEdge,
        width: 1.8,
      );
    }
    // Viền mũ ôm mặt; phần đỉnh chừa chỗ cho đầu lâu/hoa đặc trưng.
    _shape(
      canvas,
      _isKuromi
          ? (Path()
              ..moveTo(-28, -46)
              ..quadraticBezierTo(-26, -54, -17, -56)
              ..lineTo(0, -50)
              ..lineTo(17, -56)
              ..quadraticBezierTo(28, -54, 29, -43)
              ..cubicTo(31, -25, -29, -25, -28, -46)
              ..close())
          : (Path()..addOval(const Rect.fromLTWH(-28, -57, 56, 28))),
      _cream,
      outline: _hoodEdge,
      lineWidth: 1.8,
    );
    if (_isKuromi) {
      const skull = Color(0xFFF2A3C7);
      canvas.drawOval(
        const Rect.fromLTWH(-10, -73, 20, 16),
        Paint()..color = skull,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(-5, -61, 10, 7),
          const Radius.circular(0.6),
        ),
        Paint()..color = skull,
      );
      for (final x in [-4.4, 4.4]) {
        canvas.drawOval(
          Rect.fromCenter(center: Offset(x, -64), width: 3.8, height: 5),
          Paint()..color = _hoodEdge,
        );
      }
      _stroke(
        canvas,
        Path()
          ..moveTo(-1.8, -58)
          ..lineTo(-1.8, -54)
          ..moveTo(1.8, -58)
          ..lineTo(1.8, -54),
        color: _hood,
        width: 0.8,
      );
    } else {
      var flower = Path();
      for (var i = 0; i < 5; i++) {
        final angle = i * math.pi * 2 / 5;
        final petal = Path()
          ..addOval(
            Rect.fromCircle(
              center: Offset(
                -25 + math.cos(angle) * 4.7,
                -73 + math.sin(angle) * 4.7,
              ),
              radius: 4.1,
            ),
          );
        flower = i == 0
            ? petal
            : Path.combine(PathOperation.union, flower, petal);
      }
      _shape(canvas, flower, _cream, outline: _hoodEdge, lineWidth: 1.4);
      _shape(
        canvas,
        Path()..addOval(const Rect.fromLTWH(-28, -76, 6, 6)),
        const Color(0xFFF5D769),
        outline: _hoodEdge,
        lineWidth: 1,
      );
    }
    final blink =
        showEffects &&
        (motion.elapsedSeconds + (_isKuromi ? 2.2 : 3.7)) % 5.4 > 5.2;
    const ink = Color(0xFF302B34);
    for (final x in [-15.0, 15.0]) {
      if (blink || happy) {
        _stroke(
          canvas,
          Path()
            ..moveTo(x - 3.2, -44)
            ..quadraticBezierTo(x, -47, x + 3.2, -44),
          color: ink,
          width: 1.6,
        );
      } else {
        if (_isKuromi) {
          final side = x.sign;
          canvas.save();
          canvas.translate(x, -44);
          canvas.scale(side, 1);
          canvas.drawPath(
            Path()
              ..moveTo(-4, -2)
              ..lineTo(4, -6)
              ..quadraticBezierTo(5, 5, 0, 5)
              ..quadraticBezierTo(-5, 5, -4, -2)
              ..close(),
            Paint()..color = ink,
          );
          canvas.restore();
        } else {
          canvas.drawOval(
            Rect.fromCenter(center: Offset(x, -46), width: 5.7, height: 8.5),
            Paint()..color = ink,
          );
        }
      }
      if (_isKuromi) {
        final side = x < 0 ? -1.0 : 1.0;
        _stroke(
          canvas,
          Path()
            ..moveTo(x + side * 3, -48)
            ..lineTo(x + side * 6, -51)
            ..moveTo(x + side * 1.5, -47)
            ..lineTo(x + side * 5, -49.5),
          color: ink,
          width: 1.2,
        );
      }
    }
    for (final x in [-22.0, 22.0]) {
      canvas.drawOval(
        Rect.fromCenter(center: Offset(x, -38), width: 6, height: 3),
        Paint()
          ..color = const Color(
            0xFFF4B6C7,
          ).withValues(alpha: 0.15 + affection * 0.5),
      );
    }
    _shape(
      canvas,
      Path()..addOval(
        _isKuromi
            ? const Rect.fromLTWH(-2.8, -40, 5.6, 4.8)
            : const Rect.fromLTWH(-2.8, -42, 5.6, 3.7),
      ),
      _isKuromi ? const Color(0xFFF0A1C4) : const Color(0xFFF2D763),
      outline: ink,
      lineWidth: 1.1,
    );
    if (_isKuromi) {
      _shape(
        canvas,
        Path()
          ..moveTo(-3.8, -33.5)
          ..quadraticBezierTo(0, -31.5, 4.5, -35)
          ..quadraticBezierTo(2, -28, -3.8, -33.5)
          ..close(),
        const Color(0xFFF0A1C4),
        outline: ink,
        lineWidth: 0.9,
      );
    } else {
      _stroke(
        canvas,
        Path()
          ..moveTo(0, -35.5)
          ..lineTo(0, -34),
        color: ink,
        width: 1,
      );
    }
  }

  void _paintGlasses(Canvas canvas) {
    final glasses = _outfit.glasses;
    if (glasses == CompanionGlasses.none) return;
    final color = glasses == CompanionGlasses.star
        ? const Color(0xFFD8A047)
        : const Color(0xFF536A7B);
    for (final x in [-8.0, 11.0]) {
      if (glasses == CompanionGlasses.monocle && x < 0) continue;
      if (glasses == CompanionGlasses.star) {
        _star(canvas, Offset(x, -49), 7.3, color, outlineOnly: true);
      } else if (glasses == CompanionGlasses.heart) {
        _stroke(
          canvas,
          Path()
            ..moveTo(x, -43)
            ..cubicTo(x - 15, -52, x - 4, -59, x, -53)
            ..cubicTo(x + 4, -59, x + 15, -52, x, -43),
          color: _rose,
          width: 1.8,
        );
      } else if (glasses == CompanionGlasses.monocle) {
        canvas.drawCircle(
          Offset(x, -49),
          7,
          Paint()
            ..color = const Color(0xFFC89A57)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.8,
        );
        _stroke(
          canvas,
          Path()
            ..moveTo(x + 6, -45)
            ..quadraticBezierTo(25, -32, 21, -25),
          color: const Color(0xFFC89A57),
          width: 1,
        );
      } else {
        final lens = Rect.fromCenter(
          center: Offset(x, -49),
          width: 15,
          height: 12,
        );
        final path = Path()
          ..addRRect(
            RRect.fromRectAndRadius(
              lens,
              Radius.circular(glasses == CompanionGlasses.round ? 7 : 3),
            ),
          );
        if (glasses == CompanionGlasses.sunglasses) {
          canvas.drawPath(path, Paint()..color = color.withValues(alpha: 0.92));
          _stroke(
            canvas,
            Path()
              ..moveTo(x - 3, -52)
              ..lineTo(x + 2, -48),
            color: const Color(0xFFCBE5EB),
            width: 1.2,
          );
        }
        _stroke(canvas, path, color: color, width: 1.7);
      }
    }
    if (glasses == CompanionGlasses.monocle) return;
    _stroke(
      canvas,
      Path()
        ..moveTo(-0.5, -49)
        ..quadraticBezierTo(1.5, -51, 3.5, -49)
        ..moveTo(-15.5, -49)
        ..lineTo(-23, -51)
        ..moveTo(18.5, -49)
        ..lineTo(25, -51),
      color: color,
      width: 1.5,
    );
  }

  void _paintHat(Canvas canvas) {
    switch (_outfit.hat) {
      case CompanionHat.none:
        return;
      case CompanionHat.bow:
        _shape(
          canvas,
          Path()
            ..moveTo(8, -63)
            ..lineTo(-1, -70)
            ..quadraticBezierTo(-6, -62, -1, -57)
            ..close(),
          _rose,
        );
        _shape(
          canvas,
          Path()
            ..moveTo(8, -63)
            ..lineTo(19, -70)
            ..quadraticBezierTo(24, -62, 19, -57)
            ..close(),
          _rose,
        );
        canvas.drawCircle(
          const Offset(8, -63),
          3.4,
          Paint()..color = const Color(0xFFFFD9DE),
        );
      case CompanionHat.cap:
        _shape(
          canvas,
          Path()
            ..moveTo(-18, -63)
            ..quadraticBezierTo(-16, -80, 5, -76)
            ..quadraticBezierTo(18, -74, 20, -62)
            ..close(),
          const Color(0xFF82AFC1),
          outline: const Color(0xFF527F95),
        );
        _shape(
          canvas,
          Path()
            ..moveTo(-3, -64)
            ..quadraticBezierTo(14, -69, 29, -61)
            ..quadraticBezierTo(15, -57, -3, -61)
            ..close(),
          const Color(0xFF648DA4),
        );
      case CompanionHat.crown:
        _shape(
          canvas,
          Path()
            ..moveTo(-14, -66)
            ..lineTo(-17, -80)
            ..lineTo(-7, -75)
            ..lineTo(0, -85)
            ..lineTo(7, -75)
            ..lineTo(17, -80)
            ..lineTo(14, -66)
            ..close(),
          const Color(0xFFFFD984),
          outline: const Color(0xFFC8974D),
        );
        canvas.drawCircle(const Offset(0, -71), 2.4, Paint()..color = _rose);
      case CompanionHat.beret:
        _shape(
          canvas,
          Path()
            ..moveTo(-19, -65)
            ..cubicTo(-30, -77, 4, -87, 20, -74)
            ..quadraticBezierTo(29, -63, -19, -65)
            ..close(),
          const Color(0xFFBCA5D6),
        );
        _stroke(
          canvas,
          Path()
            ..moveTo(0, -78)
            ..lineTo(2, -83),
          color: const Color(0xFF78618F),
          width: 3,
        );
        _stroke(
          canvas,
          Path()
            ..moveTo(-17, -65)
            ..quadraticBezierTo(0, -62, 17, -66),
          color: const Color(0xFF78618F),
          width: 2,
        );
      case CompanionHat.beanie:
        _shape(
          canvas,
          Path()
            ..moveTo(-19, -64)
            ..quadraticBezierTo(-21, -79, 0, -79)
            ..quadraticBezierTo(22, -78, 20, -64)
            ..close(),
          const Color(0xFF97C7B2),
        );
        _shape(
          canvas,
          Path()..addRRect(
            RRect.fromRectAndRadius(
              const Rect.fromLTWH(-20, -69, 41, 7),
              const Radius.circular(3),
            ),
          ),
          const Color(0xFFC6E3D4),
        );
        canvas.drawCircle(
          const Offset(0, -81),
          4,
          Paint()..color = const Color(0xFFC6E3D4),
        );
        for (final x in [-10.0, 0.0, 10.0]) {
          _stroke(
            canvas,
            Path()
              ..moveTo(x, -76)
              ..lineTo(x, -71),
            color: const Color(0xFF629D85),
            width: 1,
          );
        }
    }
  }

  void _paintProp(Canvas canvas, double bob, double seconds) {
    final prop = _outfit.prop;
    if (prop == CompanionProp.none) return;
    canvas.save();
    canvas.translate(24, -27 + bob);
    canvas.rotate(math.sin(seconds * 2) * 0.04);
    _stroke(
      canvas,
      Path()
        ..moveTo(0, 8)
        ..lineTo(0, -10),
      color: _roseShade,
      width: 3,
    );
    switch (prop) {
      case CompanionProp.none:
        break;
      case CompanionProp.mirror:
        _shape(
          canvas,
          Path()..addOval(const Rect.fromLTWH(-8, -25, 16, 21)),
          const Color(0xFFD7F0F3),
          outline: const Color(0xFFC89A57),
          lineWidth: 2.4,
        );
        _stroke(
          canvas,
          Path()
            ..moveTo(-4, -17)
            ..lineTo(3, -22)
            ..moveTo(-2, -10)
            ..lineTo(5, -17),
          color: Colors.white,
          width: 1.7,
        );
      case CompanionProp.flower:
        for (var i = 0; i < 5; i++) {
          final angle = i * math.pi * 2 / 5;
          canvas.drawCircle(
            Offset(math.cos(angle) * 5, -17 + math.sin(angle) * 5),
            4,
            Paint()..color = const Color(0xFFF3B0C5),
          );
        }
        canvas.drawCircle(
          const Offset(0, -17),
          3.5,
          Paint()..color = const Color(0xFFFFD780),
        );
      case CompanionProp.wand:
        _star(canvas, const Offset(0, -17), 9, const Color(0xFFFFD980));
      case CompanionProp.balloon:
        _stroke(
          canvas,
          Path()
            ..moveTo(0, 6)
            ..quadraticBezierTo(-4, -7, 0, -14),
          color: const Color(0xFF987A91),
          width: 1,
        );
        _shape(
          canvas,
          Path()..addOval(const Rect.fromLTWH(-8, -35, 16, 21)),
          const Color(0xFFEEA4C6),
        );
        _shape(
          canvas,
          Path()
            ..moveTo(0, -14)
            ..lineTo(-2, -11)
            ..lineTo(2, -11)
            ..close(),
          const Color(0xFFEEA4C6),
        );
        _stroke(
          canvas,
          Path()
            ..moveTo(-4, -29)
            ..quadraticBezierTo(-6, -25, -4, -23),
          color: Colors.white,
          width: 1.5,
        );
      case CompanionProp.book:
        _shape(
          canvas,
          Path()..addRRect(
            RRect.fromRectAndRadius(
              const Rect.fromLTWH(-10, -20, 18, 23),
              const Radius.circular(2),
            ),
          ),
          const Color(0xFF9DBDD3),
        );
        _stroke(
          canvas,
          Path()
            ..moveTo(-7, -19)
            ..lineTo(-7, 2)
            ..moveTo(-4, -3)
            ..lineTo(5, -3),
          color: const Color(0xFFFFF7E8),
          width: 1.4,
        );
        _star(canvas, const Offset(0, -11), 3.5, const Color(0xFFFFDC91));
    }
    _shape(canvas, Path()..addOval(const Rect.fromLTWH(-5, -1, 9, 7)), _cream);
    canvas.restore();
  }

  void _paintPlayEffects(
    Canvas canvas,
    CompanionPlayPose pose,
    double seconds,
  ) {
    final center = motion.position - Offset(0, 50 + pose.lift);
    if (pose.impact > 0.01) {
      final side = _facingRight ? 1.0 : -1.0;
      canvas.save();
      canvas.translate(center.dx + side * 20, center.dy + 15);
      canvas.scale(side, 1);
      canvas.drawPath(
        Path()
          ..moveTo(-2, -15)
          ..lineTo(7, -15)
          ..lineTo(1, -3)
          ..lineTo(9, -3)
          ..lineTo(-6, 13)
          ..lineTo(-2, 1)
          ..lineTo(-9, 1)
          ..close(),
        Paint()..color = const Color(0xFFFFC957).withValues(alpha: pose.impact),
      );
      canvas.restore();
    }
    if (pose.dizzy > 0.01) {
      for (var i = 0; i < 3; i++) {
        final angle = seconds * 5 + i * math.pi * 2 / 3;
        _star(
          canvas,
          center + Offset(math.cos(angle) * 20, -8 + math.sin(angle) * 5),
          3.2,
          const Color(0xFFFFD985).withValues(alpha: pose.dizzy),
        );
      }
    }
  }

  void _star(
    Canvas canvas,
    Offset center,
    double radius,
    Color color, {
    bool outlineOnly = false,
  }) {
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final angle = -math.pi / 2 + i * math.pi / 5;
      final r = radius * (i.isEven ? 1 : 0.46);
      final p = center + Offset(math.cos(angle), math.sin(angle)) * r;
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = outlineOnly ? PaintingStyle.stroke : PaintingStyle.fill
        ..strokeWidth = 1.5
        ..strokeJoin = StrokeJoin.round,
    );
  }

  void _paintBearEar(Canvas canvas, Offset center) {
    _shape(
      canvas,
      Path()..addOval(Rect.fromCircle(center: center, radius: 10)),
      _cream,
      shade: _creamShade,
      lineWidth: 1.55,
    );
    canvas.drawCircle(center, 5.5, Paint()..color = const Color(0xFFEFC3A1));
  }

  void _paintAffectionHearts(Canvas canvas, double affection, double hopLift) {
    final progress = 1 - affection;
    final opacity = math.sin(progress * math.pi).clamp(0.0, 1.0);
    if (opacity < 0.02) return;
    // Hai trái tim gọn bên má, không bay ra ngoài khoảng an toàn của thỏ.
    for (var i = 0; i < 2; i++) {
      final side = i == 0 ? -1.0 : 1.0;
      final center =
          motion.position +
          Offset(side * 17, -45 - i * 8 - progress * 6 - hopLift);
      final radius = (i == 0 ? 2.5 : 2.9) * (0.8 + opacity * 0.2);
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(side * 0.18);
      canvas.scale(radius);
      canvas.drawPath(
        Path()
          ..moveTo(0, 0.85)
          ..cubicTo(-0.35, 0.5, -1, 0.05, -1, -0.42)
          ..cubicTo(-1, -1.12, -0.23, -1.3, 0, -0.65)
          ..cubicTo(0.23, -1.3, 1, -1.12, 1, -0.42)
          ..cubicTo(1, 0.05, 0.35, 0.5, 0, 0.85)
          ..close(),
        Paint()..color = _rose.withValues(alpha: opacity * 0.88),
      );
      canvas.restore();
    }
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
    Color? outline,
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

  void _stroke(Canvas canvas, Path path, {Color? color, double width = 1.65}) {
    canvas.drawPath(
      path,
      Paint()
        ..color = color ?? (_hasHood ? _hoodEdge : _outline)
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant HomeCompanionPainter oldDelegate) =>
      oldDelegate.motion != motion ||
      oldDelegate.character != character ||
      oldDelegate.outfit != outfit ||
      oldDelegate.play != play ||
      oldDelegate.socialPlay != socialPlay ||
      oldDelegate.paintOffset != paintOffset ||
      oldDelegate.darkMode != darkMode ||
      oldDelegate.showEffects != showEffects;
}
