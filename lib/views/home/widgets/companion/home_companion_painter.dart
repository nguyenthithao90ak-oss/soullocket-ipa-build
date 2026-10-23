import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import 'home_companion_motion.dart';
import 'home_companion_outfit.dart';
import 'home_companion_play.dart';
import 'home_companion_metrics.dart';
import 'home_companion_mood.dart';
import '../../tabs/pet_care/pet_care_progress.dart' as pet_care;

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
    this.mood,
    this.care,
    this.careListenable,
  }) : super(
         repaint: Listenable.merge([
           motion,
           paintOffset,
           play,
           socialPlay,
           mood,
           careListenable,
         ]),
       );

  final HomeCompanionMotion motion;
  final bool darkMode;
  final bool showEffects;
  final ValueListenable<Offset>? paintOffset;
  final HomeCompanionCharacter character;
  final HomeCompanionOutfit? outfit;
  final HomeCompanionPlay? play;
  final HomeCompanionPlay? socialPlay;
  final HomeCompanionMood? mood;

  /// Chỉ dùng cho hai bé chính trên Home. Khách Mèo Mây/Chuột Phô Mai luôn bỏ qua.
  /// Trạng thái null giữ nguyên artwork Home cũ.
  final pet_care.PetCareVitals? care;
  final ValueListenable<
    Map<pet_care.PetCarePet, pet_care.PetCareVitals>
  >? careListenable;
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
  pet_care.PetCarePet? get _carePet => switch (character) {
    HomeCompanionCharacter.bunny => pet_care.PetCarePet.rabbit,
    HomeCompanionCharacter.bear => pet_care.PetCarePet.bear,
    _ => null,
  };
  pet_care.PetCareVitals? get _care =>
      care ?? (careListenable == null || _carePet == null
          ? null
          : careListenable!.value[_carePet]);
  bool get _hasCare => _care != null && _carePet != null;
  bool get _careDirty => _hasCare && _care!.isDirty;
  bool get _careHungry => _hasCare && _care!.isHungry;
  bool get _careCrying => _hasCare && _care!.isCrying;
  bool get _careAngry => _hasCare && _care!.mood == pet_care.PetCareMood.angry;
  bool get _careSleepy =>
      _hasCare &&
      (_care!.sleeping ||
          _care!.mood == pet_care.PetCareMood.sleepy ||
          _care!.mood == pet_care.PetCareMood.sleeping);
  bool get _careHappy =>
      _hasCare &&
      (_care!.mood == pet_care.PetCareMood.happy || _care!.joy >= 82);

  /// Ngủ gật chỉ khi đang đứng yên, không giữa cú nhảy hoặc trò chơi.
  bool get _dozing =>
      showEffects &&
      (mood?.dozing ?? false) &&
      motion.phase == HomeCompanionPhase.idle &&
      !(_activePlay?.active ?? false);
  // Hai bé riêng của SoulLocket dùng lại ô ID cũ (xem HomeCompanionCharacter):
  // Mèo Mây lông tím khói, sao vàng trên trán; Chuột Phô Mai lông sữa nâu,
  // tai tròn to lòng hồng, răng cửa và đuôi hồng dài.
  bool get _isCat => character == HomeCompanionCharacter.kuromi;
  bool get _isMouse => character == HomeCompanionCharacter.melody;

  /// Cỡ chuẩn chung; từng bộ nét vẽ có tỷ lệ riêng để cùng chiều cao thực.
  static const double spriteScale = HomeCompanionMetrics.referenceScale;
  static const double bearSpriteScale = HomeCompanionMetrics.bearScale;
  static const double horizontalClearance = 32;
  static const double topClearance = 104;
  Color get _outline => _isCat
      ? const Color(0xFF7A6E9C)
      : _isMouse
      ? const Color(0xFF8D6C5A)
      : const Color(0xFF956E69);
  Color get _cream => _isBear
      ? const Color(0xFFD6A171)
      : _isMouse
      ? const Color(0xFFE6D0BC)
      : _isCat
      ? const Color(0xFFC9C2EA)
      : const Color(0xFFFFFAEF);
  Color get _creamShade => _isBear
      ? const Color(0xFFBD8159)
      : _isMouse
      ? const Color(0xFFCBB09A)
      : _isCat
      ? const Color(0xFFA79ED3)
      : const Color(0xFFF3DDC8);
  Color get _belly => _isBear
      ? const Color(0xFFF3D7B2)
      : _isMouse
      ? const Color(0xFFFFF8F0)
      : _isCat
      ? const Color(0xFFF8F5FF)
      : const Color(0xFFFFFDF7);
  static const _pink = Color(0xFFF2B4BE);
  Color get _rose => _isBear
      ? const Color(0xFF6B9FAC)
      : _isMouse
      ? const Color(0xFF74BE96)
      : _isCat
      ? const Color(0xFFEDB94A)
      : const Color(0xFFCF718B);
  Color get _roseShade => _isBear
      ? const Color(0xFF497482)
      : _isMouse
      ? const Color(0xFF4E9270)
      : _isCat
      ? const Color(0xFFBE8E2A)
      : const Color(0xFFAC526F);
  Color get _scarfDot => _isBear
      ? const Color(0xFFB7D9DF)
      : _isMouse
      ? const Color(0xFFC5EBD5)
      : _isCat
      ? const Color(0xFFFFE6A2)
      : const Color(0xFFE99AAF);
  Color get _scarfShine => _isBear
      ? const Color(0xFFD8EEF1)
      : _isMouse
      ? const Color(0xFFE0F5E9)
      : _isCat
      ? const Color(0xFFFFF1C9)
      : const Color(0xFFF6C9D3);
  static const _eye = Color(0xFF634B4B);

  @override
  void paint(Canvas canvas, Size size) {
    if (!character.isAvailable || !motion.hasSurfaces || size.isEmpty) return;

    canvas.save();
    canvas.clipRect(Offset.zero & size);
    final offset = paintOffset?.value ?? Offset.zero;
    canvas.translate(offset.dx, offset.dy);
    if (showEffects) _paintDust(canvas);
    final playPose = showEffects
        ? _activePlay?.pose(character) ?? const CompanionPlayPose()
        : const CompanionPlayPose();
    canvas.translate(playPose.offset.dx, playPose.offset.dy);

    // Đè lên chữ/khối nội dung thì mờ bớt; thu nhỏ cả bé lẫn hiệu ứng quanh chân.
    final feet = motion.position;
    final opacity = (mood?.opacity ?? 1.0) * (mood?.visibility ?? 1.0);
    if (opacity <= 0.01) {
      canvas.restore();
      return;
    }
    final faded = opacity < 0.99;
    if (faded) {
      canvas.saveLayer(
        Rect.fromLTRB(feet.dx - 72, feet.dy - 150, feet.dx + 72, feet.dy + 14),
        Paint()..color = Color.fromRGBO(0, 0, 0, opacity),
      );
    }
    canvas.save();
    canvas.translate(feet.dx, feet.dy);
    canvas.scale(HomeCompanionMetrics.displayScale);
    canvas.translate(-feet.dx, -feet.dy);

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
    final dozing = _dozing;
    final breathe = dozing
        ? math.sin(seconds * 1.3) * 1.6
        : math.sin(seconds * 2.4);
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
    canvas.drawOval(
      const Rect.fromLTWH(-7, -23, 18, 16),
      Paint()..color = _belly,
    );
    if (_outfit.clothes == CompanionClothes.overalls) {
      _paintBearOveralls(canvas);
    } else if (_outfit.clothes != CompanionClothes.classic) {
      _paintCoat(canvas);
    }
    _paintCareBody(canvas);
    _paintScarfTail(canvas, moving: moving, step: step, breathe: breathe);
    _paintHead(
      canvas,
      earSway:
          (moving ? step * 0.11 + liftRatio * 0.08 : breathe * 0.035) +
          greeting * 0.07,
      happy: celebrating || _careHappy,
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
    if (!sweeping) {
      if (mood?.carryingLetter ?? false) {
        _paintLetter(canvas, bodyBob, seconds);
      } else {
        _paintProp(canvas, bodyBob, seconds);
      }
    }
    canvas.restore();

    if (showEffects && motion.celebration > 0) _paintCleanGlints(canvas);
    if (affection > 0) _paintAffectionHearts(canvas, affection, hopLift);
    if (showEffects) _paintPlayEffects(canvas, playPose, seconds);
    if (dozing) _paintSleepZ(canvas, seconds);
    canvas.restore();
    if (faded) canvas.restore();
    _paintBubble(canvas, size, playPose.offset + offset, hopLift);
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
    if (_isMouse) {
      // Đuôi hồng mảnh, dài, cuộn một vòng nhỏ ở chóp; lắc theo bước chân.
      final sway = step * 1.8;
      final tail = Path()
        ..moveTo(-11, -8 + bodyBob)
        ..cubicTo(-24, -4 + bodyBob, -33 - sway, -10, -31 - sway, -21)
        ..cubicTo(-30 - sway, -28, -22 - sway, -28, -23 - sway, -22)
        ..quadraticBezierTo(-24 - sway, -18, -27 - sway, -20);
      _stroke(canvas, tail, color: _outline, width: 3.4);
      _stroke(canvas, tail, color: const Color(0xFFF4B3C0), width: 1.9);
      return;
    }
    if (_isCat) {
      // Đuôi dài cong chữ S có ba khoanh sọc tím đậm.
      final sway = step * 1.6;
      final tail = Path()
        ..moveTo(-11, -9 + bodyBob)
        ..cubicTo(-25, -8 + bodyBob, -32 - sway, -18, -26 - sway, -30)
        ..quadraticBezierTo(-23 - sway, -36, -27 - sway, -40);
      _stroke(canvas, tail, color: _outline, width: 6.6);
      _stroke(canvas, tail, color: _cream, width: 4.4);
      for (final metric in tail.computeMetrics()) {
        for (final t in const [0.42, 0.62, 0.82]) {
          final tangent = metric.getTangentForOffset(metric.length * t);
          if (tangent == null) continue;
          final normal = Offset(-tangent.vector.dy, tangent.vector.dx) * 2.2;
          _stroke(
            canvas,
            Path()
              ..moveTo(
                tangent.position.dx - normal.dx,
                tangent.position.dy - normal.dy,
              )
              ..lineTo(
                tangent.position.dx + normal.dx,
                tangent.position.dy + normal.dy,
              ),
            color: _creamShade,
            width: 1.6,
          );
        }
      }
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

  /// Lớp chăm bé chỉ phủ lên nét gốc, nhờ vậy khi chưa có snapshot Home vẫn
  /// giữ nguyên artwork hiện tại. Các đốm là hình vẽ vector nhỏ, không dùng
  /// emoji hay asset ngoài.
  void _paintCareBody(Canvas canvas) {
    if (!_hasCare) return;
    if (_careDirty) {
      final mud = Paint()..color = const Color(0xFF9A765D).withValues(alpha: 0.78);
      final mudLight = Paint()..color = const Color(0xFFC19B76).withValues(alpha: 0.68);
      for (final spot in const [
        Offset(-8, -21),
        Offset(6, -16),
        Offset(-3, -9),
        Offset(10, -8),
      ]) {
        canvas.drawOval(
          Rect.fromCenter(center: spot, width: 4.5, height: 3.2),
          mud,
        );
      }
      for (final spot in const [Offset(-11, -13), Offset(3, -26)]) {
        canvas.drawCircle(spot, 1.8, mudLight);
      }
      // Mùi bụi nhỏ phía vai: đủ nhận ra bẩn nhưng không che mất áo.
      _stroke(
        canvas,
        Path()
          ..moveTo(-17, -28)
          ..quadraticBezierTo(-20, -31, -17, -34)
          ..moveTo(15, -25)
          ..quadraticBezierTo(18, -29, 16, -32),
        color: const Color(0xFF9A765D).withValues(alpha: 0.58),
        width: 1.15,
      );
    }
    if (_careHungry) {
      // Một nhịp bụng nhỏ báo đói, tránh thêm chữ cứng lên Home.
      _stroke(
        canvas,
        Path()
          ..moveTo(-4, -13)
          ..quadraticBezierTo(-1, -10, 2, -13)
          ..quadraticBezierTo(5, -16, 7, -13),
        color: const Color(0xFFB47E76).withValues(alpha: 0.72),
        width: 1.05,
      );
    }
    if (_careHappy) {
      for (final point in const [Offset(-20, -25), Offset(18, -21)]) {
        _paintCareSparkle(canvas, point, 2.8);
      }
    }
  }

  void _paintCareSparkle(Canvas canvas, Offset center, double radius) {
    final paint = Paint()..color = const Color(0xFFFFD978).withValues(alpha: 0.9);
    canvas.drawLine(
      center - Offset(radius, 0),
      center + Offset(radius, 0),
      paint..strokeWidth = 1.1,
    );
    canvas.drawLine(
      center - Offset(0, radius),
      center + Offset(0, radius),
      paint..strokeWidth = 1.1,
    );
    canvas.drawCircle(center, 0.8, paint);
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
      _scarfDot,
      outline: _roseShade,
      lineWidth: 1,
    );
    _stroke(
      canvas,
      Path()
        ..moveTo(-10, -32)
        ..quadraticBezierTo(-2, -29, 5, -31),
      color: _scarfShine,
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
    if (_isBear) {
      _paintBearEar(canvas, Offset(-18, -63 + earSway * 3));
      _paintBearEar(canvas, Offset(19, -63 - earSway * 3));
    } else if (_isMouse) {
      _paintMouseEar(canvas, Offset(-20, -60 + earSway * 3));
      _paintMouseEar(canvas, Offset(21, -60 - earSway * 3));
    } else if (_isCat) {
      _paintCatEar(canvas, -1, earSway);
      _paintCatEar(canvas, 1, earSway);
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
    if (_isCat) {
      // Dấu sao trên trán là nhận diện riêng của Mèo Mây.
      _star(canvas, const Offset(1.6, -60.5), 3.8, const Color(0xFFFFD66B));
      _star(
        canvas,
        const Offset(1.6, -60.5),
        3.8,
        const Color(0xFFD9A23B),
        outlineOnly: true,
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
    if (_isCat) _paintWhiskers(canvas, const [-2.0, 0.6, 3.2]);
    if (_isMouse) _paintWhiskers(canvas, const [-1.2, 1.8]);

    final blinkPhase = showEffects
        ? (motion.elapsedSeconds +
                  (_isBear
                      ? 1.3
                      : _isMouse
                      ? 2.2
                      : _isCat
                      ? 3.7
                      : 0)) %
              5.4
        : 0.0;
    final blink = blinkPhase > 4.97 && blinkPhase < 5.11;
    final eyeY = sweeping ? -48.0 : -49.0;
    for (final eyeX in const [-7.5, 10.5]) {
      if (blink || happy || _dozing || _careSleepy) {
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
      _noseColor,
      outline: _noseColor,
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
    if (_isMouse) _paintMouseTeeth(canvas);
    _paintGlasses(canvas);
    _paintHat(canvas);
    _paintCareFace(canvas);
    canvas.restore();
  }

  void _paintCareFace(Canvas canvas) {
    if (!_hasCare) return;
    if (_careDirty) {
      final mud = Paint()..color = const Color(0xFF8E6B55).withValues(alpha: 0.78);
      canvas.drawOval(const Rect.fromLTWH(-20, -55, 6, 4), mud);
      canvas.drawOval(const Rect.fromLTWH(15, -38, 5, 3.5), mud);
      canvas.drawCircle(const Offset(-13, -35), 1.6, mud);
    }
    if (_careAngry) {
      _stroke(
        canvas,
        Path()
          ..moveTo(-11, -53)
          ..lineTo(-4, -50)
          ..moveTo(8, -50)
          ..lineTo(15, -53),
        color: const Color(0xFF6C3F4A),
        width: 1.8,
      );
      _stroke(
        canvas,
        Path()
          ..moveTo(21, -62)
          ..lineTo(24, -58)
          ..moveTo(24, -62)
          ..lineTo(21, -58),
        color: const Color(0xFFE98C88).withValues(alpha: 0.9),
        width: 1.2,
      );
    }
    if (_careCrying) {
      final tear = Paint()..color = const Color(0xFF73BCE5).withValues(alpha: 0.9);
      for (final eyeX in const [-7.5, 10.5]) {
        canvas.drawOval(
          Rect.fromCenter(center: Offset(eyeX, -44), width: 2.8, height: 6.8),
          tear,
        );
        canvas.drawCircle(Offset(eyeX, -39.8), 1.45, tear);
      }
    }
    if (_careHungry || _careCrying || _careAngry) {
      _stroke(
        canvas,
        Path()
          ..moveTo(-3, -37.5)
          ..quadraticBezierTo(1.5, -34.5, 6, -37.5),
        color: _careAngry ? const Color(0xFF8E4854) : const Color(0xFF9D6670),
        width: 1.25,
      );
    }
  }

  Color get _noseColor => _isBear
      ? _eye
      : _isMouse
      ? const Color(0xFFEF97AE)
      : _isCat
      ? const Color(0xFFEF97AE)
      : _rose;

  /// Tai chuột tròn to hơn tai gấu, viền mảnh và lòng hồng gần kín tai.
  void _paintMouseEar(Canvas canvas, Offset center) {
    _shape(
      canvas,
      Path()..addOval(Rect.fromCircle(center: center, radius: 12)),
      _cream,
      shade: _creamShade,
      lineWidth: 1.45,
    );
    canvas.drawCircle(
      center + const Offset(0, 0.8),
      8.2,
      Paint()..color = const Color(0xFFF6BFCB),
    );
  }

  /// Tai mèo tam giác bo tròn, lòng tai hồng, đứng hơi chếch ra hai bên.
  void _paintCatEar(Canvas canvas, double side, double earSway) {
    canvas.save();
    canvas.translate(side * 15.5, -60.5);
    canvas.rotate(side * 0.34 + earSway * 0.3);
    _shape(
      canvas,
      Path()
        ..moveTo(-8, 3)
        ..quadraticBezierTo(-7.4, -8.5, -1.4, -14.6)
        ..quadraticBezierTo(0.3, -16, 1.8, -14.4)
        ..quadraticBezierTo(7.2, -7, 8, 3)
        ..close(),
      _cream,
      shade: _creamShade,
      lineWidth: 1.55,
    );
    canvas.drawPath(
      Path()
        ..moveTo(-4.4, 1.2)
        ..quadraticBezierTo(-4, -5.6, -0.7, -9.6)
        ..quadraticBezierTo(3.6, -4.4, 4.4, 1.2)
        ..close(),
      Paint()..color = const Color(0xFFF6B7C8),
    );
    canvas.restore();
  }

  /// Hai răng cửa trắng nhỏ dưới miệng, dấu hiệu nhận ra chuột ở cỡ nhỏ.
  void _paintMouseTeeth(Canvas canvas) {
    final teeth = RRect.fromRectAndRadius(
      const Rect.fromLTWH(-0.6, -38.6, 4.6, 3.4),
      const Radius.circular(0.9),
    );
    canvas.drawRRect(teeth, Paint()..color = Colors.white);
    _stroke(canvas, Path()..addRRect(teeth), color: _eye, width: 0.7);
    _stroke(
      canvas,
      Path()
        ..moveTo(1.7, -38.4)
        ..lineTo(1.7, -35.4),
      color: _eye,
      width: 0.6,
    );
  }

  /// Ria mỗi bên, mảnh và nhạt để không làm rối mặt khi thu nhỏ.
  void _paintWhiskers(Canvas canvas, List<double> offsets) {
    final paintColor = _outline.withValues(alpha: 0.7);
    for (final side in const [-1.0, 1.0]) {
      final x0 = side < 0 ? -19.0 : 22.4;
      for (final dy in offsets) {
        _stroke(
          canvas,
          Path()
            ..moveTo(x0, -41.6 + dy * 0.4)
            ..quadraticBezierTo(
              x0 + side * 5,
              -42.4 + dy * 0.7,
              x0 + side * 9.5,
              -43 + dy,
            ),
          color: paintColor,
          width: 0.8,
        );
      }
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

  /// Phong thư nhỏ trên tay: người ấy vừa để lại lời nhắn chưa đọc.
  void _paintLetter(Canvas canvas, double bob, double seconds) {
    canvas.save();
    canvas.translate(19, -25 + bob);
    canvas.rotate(-0.12 + math.sin(seconds * 2.2) * 0.06);
    final body = RRect.fromRectAndRadius(
      const Rect.fromLTWH(-9, -6.5, 18, 13),
      const Radius.circular(2.2),
    );
    canvas.drawRRect(body, Paint()..color = const Color(0xFFFFFBF4));
    canvas.drawRRect(
      body,
      Paint()
        ..color = const Color(0xFFCF718B)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3,
    );
    _stroke(
      canvas,
      Path()
        ..moveTo(-8.2, -5.6)
        ..lineTo(0, 0.8)
        ..lineTo(8.2, -5.6),
      color: const Color(0xFFCF718B),
      width: 1.2,
    );
    canvas.save();
    canvas.translate(0, 1.6);
    canvas.scale(2.6);
    canvas.drawPath(
      Path()
        ..moveTo(0, 0.85)
        ..cubicTo(-0.35, 0.5, -1, 0.05, -1, -0.42)
        ..cubicTo(-1, -1.12, -0.23, -1.3, 0, -0.65)
        ..cubicTo(0.23, -1.3, 1, -1.12, 1, -0.42)
        ..cubicTo(1, 0.05, 0.35, 0.5, 0, 0.85)
        ..close(),
      Paint()..color = const Color(0xFFE0457F),
    );
    canvas.restore();
    canvas.restore();
  }

  /// Ba chữ "z" bay chậm lên cạnh đầu khi bé ngủ gật.
  void _paintSleepZ(Canvas canvas, double seconds) {
    final paint = Paint()
      ..color = _eye
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (var i = 0; i < 3; i++) {
      final t = (seconds * 0.35 + i / 3) % 1;
      final alpha = math.sin(t * math.pi).clamp(0.0, 1.0);
      if (alpha < 0.05) continue;
      final half = 2.6 + t * 2.4;
      final center = motion.position + Offset(16 + t * 12, -70 - t * 26);
      canvas.drawPath(
        Path()
          ..moveTo(center.dx - half, center.dy - half)
          ..lineTo(center.dx + half, center.dy - half)
          ..lineTo(center.dx - half, center.dy + half)
          ..lineTo(center.dx + half, center.dy + half),
        paint..color = _eye.withValues(alpha: 0.75 * alpha),
      );
    }
  }

  /// Bong bóng chữ ngắn trên đầu, không thu nhỏ để luôn đọc rõ.
  void _paintBubble(Canvas canvas, Size size, Offset shift, double hopLift) {
    final text = mood?.bubble;
    final opacity = mood?.bubbleOpacity ?? 0;
    if (!showEffects || text == null || text.isEmpty || opacity < 0.02) {
      return;
    }
    final style = mood!.bubbleStyle;
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: style.copyWith(
          color: (style.color ?? const Color(0xFF6B3A4C)).withValues(
            alpha: opacity,
          ),
        ),
      ),
      textDirection: mood!.bubbleDirection,
      maxLines: 2,
      ellipsis: '…',
      textAlign: TextAlign.center,
    )..layout(maxWidth: math.min(200, size.width - 32));
    const padX = 10.0, padY = 6.0, tail = 6.0;
    final width = painter.width + padX * 2;
    final height = painter.height + padY * 2;
    final feet = motion.position;
    final bottom =
        feet.dy - (74 + hopLift) * HomeCompanionMetrics.displayScale - tail;
    // Giữ bong bóng trong khung nhìn theo trục ngang.
    final minLeft = 8 - shift.dx;
    final maxLeft = size.width - 8 - width - shift.dx;
    final left = (feet.dx - width / 2)
        .clamp(minLeft, math.max(minLeft, maxLeft))
        .toDouble();
    final rect = Rect.fromLTWH(left, bottom - height, width, height);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(12));
    final tailX = feet.dx
        .clamp(rect.left + 12, math.max(rect.left + 12, rect.right - 12))
        .toDouble();
    final shape = Path()
      ..addRRect(rrect)
      ..moveTo(tailX - 5, rect.bottom - 0.5)
      ..lineTo(tailX, rect.bottom + tail)
      ..lineTo(tailX + 5, rect.bottom - 0.5)
      ..close();
    canvas.drawShadow(
      shape,
      const Color(0xFF9D7079).withValues(alpha: 0.4 * opacity),
      3,
      false,
    );
    canvas.drawPath(
      shape,
      Paint()
        ..color = (darkMode ? const Color(0xFF3A2C33) : Colors.white)
            .withValues(alpha: 0.97 * opacity),
    );
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = const Color(0xFFCF718B).withValues(alpha: 0.35 * opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    painter.paint(canvas, Offset(rect.left + padX, rect.top + padY));
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
        ..color = color ?? _outline
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
      oldDelegate.mood != mood ||
      oldDelegate.paintOffset != paintOffset ||
      oldDelegate.darkMode != darkMode ||
      oldDelegate.showEffects != showEffects;
}
