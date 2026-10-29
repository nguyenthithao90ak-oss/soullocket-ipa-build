part of 'pet_care_scene.dart';

/// Dáng của bé kia trong lượt chăm chung; [none] là đứng yên như thường.
@immutable
class _MateMotion {
  const _MateMotion({
    this.rise = 0,
    this.tilt = 0,
    this.sx = 1,
    this.sy = 1,
    this.lift = 0,
    this.hopping = false,
    this.walkWeight = 0,
    this.stride = 0,
    this.cuddle = 0,
    this.cheer = 0,
    this.happy = false,
    this.chewing = false,
    this.chew = 0,
    this.reach = 0,
  });

  static const none = _MateMotion();

  /// Nhấc người lên khỏi chỗ đứng (đơn vị cảnh, dương là lên trên).
  final double rise;
  final double tilt;
  final double sx;
  final double sy;
  final double lift;
  final bool hopping;
  final double walkWeight;
  final double stride;
  final double cuddle;
  final double cheer;

  /// Mặt vui (đang được chăm).
  final bool happy;

  /// Đang nhai: vẽ miệng và má phồng, nhịp nhai [chew].
  final bool chewing;
  final double chew;

  /// Há miệng chờ món đang rê tới (0..1).
  final double reach;
}

/// Điều khiển cả hai bé cùng lúc, không cần chọn bé: kéo món tới miệng bé
/// kia thì bé kia ăn phần riêng (song song với bé mình), hai bé luôn ngồi
/// chung bồn tắm, cùng chơi bóng và nhảy mừng. Chỉ là hình; màn cha lưu chỉ
/// số cho từng bé.
extension _PetCareTogether on _PetHousePainter {
  bool get _mateJoins => mateCare && !partnerVitals.sleeping && skit == null;
  bool get _mateBusy => _mateJoins && _active;
  bool get _mateEating =>
      mateMeal > 0 &&
      mateMeal < 1 &&
      room == PetCareRoom.kitchen &&
      !partnerVitals.sleeping &&
      skit == null;

  /// Món đang rê lại gần miệng bé kia (0 → 1).
  double get _mateReach {
    final hold = holdPoint;
    if (hold == null ||
        room != PetCareRoom.kitchen ||
        partnerVitals.sleeping ||
        _mateEating) {
      return 0;
    }
    final distance = (hold - _mateMouth).distance;
    return (1 - (distance - 16) / 120).clamp(0.0, 1.0);
  }

  /// Bé kia đã ngồi hẳn trong bồn tắm chung.
  bool get _mateBathing =>
      _mateJoins && room == PetCareRoom.bathroom && together > .98;
  bool get _matePlaying => _mateBusy && playing;
  bool get _mateHugged => _mateBusy && action == PetCareAction.hug && !playing;

  bool get _mateFacingRight => _partnerPosition.dx < 180;

  double get _mateScale => small
      ? 2.65
      : _partner == PetCarePet.rabbit
      ? 2.5
      : 2.3;

  /// Miệng bé kia trong cảnh (món ăn bay tới đây).
  Offset get _mateMouth {
    final k = _PetHousePainter._spriteOf(_partner) * _mateScale * growth;
    return _partnerPosition +
        Offset(
          (_mateFacingRight ? 1 : -1) *
              (HomeCompanionPainter.usesModel(false)
                  ? HomeCompanionMetrics.modelMouthX
                  : 1.7) *
              k,
          (HomeCompanionPainter.usesModel(false)
                  ? HomeCompanionMetrics.modelMouthY
                  : -38.5) *
              k,
        );
  }

  _MateMotion get _mateMotion {
    // Nhảy qua thành bồn khi vào/ra tắm chung.
    if (room == PetCareRoom.bathroom &&
        together > 0 &&
        together < 1 &&
        !partnerVitals.sleeping) {
      final hop = math.sin(together * math.pi);
      return _MateMotion(
        rise: hop * 34,
        tilt: hop * .08,
        lift: hop * 1.2,
        hopping: true,
      );
    }
    if (_mateEating) {
      final t = mateMeal;
      final chew = t > .42 && t < .8
          ? math.sin((t - .42) / .38 * math.pi * 6) * 1.8
          : 0.0;
      final envelope = Curves.easeInOutSine.transform(
        math.min(t / .2, (1 - t) / .22).clamp(0, 1),
      );
      return _MateMotion(
        rise: chew,
        tilt: chew * .012,
        sx: 1 + chew * .012,
        sy: 1 - chew * .009,
        cuddle: envelope * .2,
        happy: t > .44,
        chewing: t > .25 && t < .84,
        chew: chew,
      );
    }
    final reach = _mateReach;
    if (reach > 0) {
      return _MateMotion(
        rise: reach * 2.5 * math.sin(seconds * 9).abs(),
        sx: 1 + reach * .03,
        sy: 1 + reach * .03,
        reach: reach,
        happy: true,
      );
    }
    // Tiệc sinh nhật: bé kia cũng nhảy mừng dù không được chăm lượt này.
    if (!_mateJoins && !(party && dance > 0)) return _MateMotion.none;
    if (_mateBathing && action == PetCareAction.bath && _active) {
      // Lắc lư theo nhịp chà, giũ nước lúc xả xong.
      return _MateMotion(
        tilt:
            math.sin(progress * math.pi * 6 + 1) * .02 * _careEnvelope + _shake,
        happy: true,
      );
    }
    if (_matePlaying) {
      final envelope = _careEnvelope;
      return _MateMotion(
        lift: envelope * math.sin(progress * math.pi + .5).abs() * 1.8,
        hopping: true,
        walkWeight: envelope * .7,
        stride: progress * .9 + .4,
        happy: true,
      );
    }
    if (_mateHugged) {
      return _MateMotion(cuddle: _careEnvelope * .65, happy: true);
    }
    if (dance > 0) {
      final jump = _danceMotion;
      return _MateMotion(
        rise: -jump.y,
        sx: jump.sx,
        sy: jump.sy,
        cheer: dance,
        happy: true,
      );
    }
    return _MateMotion.none;
  }

  /// Bọt, giọt nước và nước bắn khi tắm chung: lấy theo bé mình, thu theo cỡ
  /// bé kia và lật ngang cho khác chỗ.
  void _paintMateFx(Canvas c, Offset p, PetCarePet partner) {
    if (!_mateBathing) return;
    final k =
        growth *
        _mateScale *
        _PetHousePainter._spriteOf(partner) /
        (_roomPetScale * _characterScale);
    c.save();
    c.translate(p.dx, p.dy);
    c.scale(-k, k);
    c.translate(-p.dx, -p.dy);
    _paintFoam(c, p);
    _paintDrips(c, p);
    _paintSpray(c, p);
    c.restore();
  }

  /// Mũ tiệc sinh nhật hình nón sọc, quả bông trên đỉnh; vẽ trong hệ tọa độ
  /// hình bé (chân ở 180, 260), lệch nhẹ cho tinh nghịch.
  void _paintPartyHat(
    Canvas c,
    PetCarePet pet,
    bool faceRight, {
    bool model3D = false,
  }) {
    final k = _PetHousePainter._spriteOf(pet);
    final rabbit = pet == PetCarePet.rabbit;
    c.save();
    c.translate(180, 260);
    // Bé 3D tự xoay theo hướng nhìn, không lật hình; đỉnh đầu nằm giữa.
    c.scale((model3D || faceRight ? 1 : -1) * k, k);
    c.translate(
      model3D ? 0 : (rabbit ? 1.5 : 1),
      model3D ? (rabbit ? _hat3DRabbitY : _hat3DBearY) : (rabbit ? -66 : -64),
    );
    c.rotate(-.22);
    const width = 17.0;
    const height = 23.0;
    final cone = Path()
      ..moveTo(-width / 2, 0)
      ..lineTo(0, -height)
      ..lineTo(width / 2, 0)
      ..quadraticBezierTo(0, 3, -width / 2, 0)
      ..close();
    c.save();
    c.clipPath(cone);
    c.drawPath(cone, Paint()..color = const Color(0xFFF58DAE));
    for (var i = 0; i < 4; i++) {
      final y = -4.0 - i * 6;
      c.drawPath(
        Path()
          ..moveTo(-width, y + 3)
          ..lineTo(width, y - 3)
          ..lineTo(width, y)
          ..lineTo(-width, y + 6)
          ..close(),
        Paint()..color = const Color(0xFFFFD970),
      );
    }
    c.restore();
    c.drawPath(
      cone,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = .9
        ..color = const Color(0xFFB0365F),
    );
    c.drawOval(
      Rect.fromCenter(center: const Offset(0, 1), width: width + 3, height: 4),
      Paint()..color = const Color(0xFF86B3EE),
    );
    c.drawCircle(const Offset(0, -height), 3.6, Paint()..color = Colors.white);
    c.drawCircle(
      const Offset(0, -height),
      3.6,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = .8
        ..color = const Color(0xFFE5A23C),
    );
    c.restore();
  }

  static const _hat3DRabbitY = -80.0;
  static const _hat3DBearY = -71.0;

  /// Tim bay quanh bé kia khi được ôm chung.
  void _paintMateHearts(Canvas c) {
    if (!_mateHugged) return;
    final at = _partnerPosition;
    for (var i = 0; i < 5; i++) {
      final t = (progress * 1.45 - i * .1 - .05).clamp(0.0, 1.0);
      if (t <= 0 || t >= 1) continue;
      _heart(
        c,
        Offset(
          at.dx + math.sin(i * 1.9 + 1) * (20 + t * 22),
          at.dy - 64 * growth - t * 60 + (i % 2) * 10,
        ),
        3.6 + _pulse * 2.6,
        [
          _PetHousePainter._rose,
          _PetHousePainter._lilac,
          _PetHousePainter._gold,
        ][i % 3].withValues(alpha: math.sin(t * math.pi) * .85),
      );
    }
  }
}
