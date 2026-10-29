part of 'pet_care_scene.dart';

/// Một cụm bọt bám trên người bé, tọa độ tính từ chân để bé di chuyển vẫn đúng.
@immutable
class _PetFoam {
  const _PetFoam(this.offset, this.size, this.seed);
  final Offset offset;
  final double size;
  final int seed;

  _PetFoam grow(double amount) =>
      _PetFoam(offset, (size + amount).clamp(0.0, 1.4), seed);
}

/// Hiệu ứng quanh bé: bọt, nước, biểu cảm ăn và điệu nhảy mừng.
/// Số nét cố định theo chỉ số, không sinh particle hay timer mới.
extension _PetCareFx on _PetHousePainter {
  static const _palette = [
    Color(0xFFF197AB),
    Color(0xFFF2C66B),
    Color(0xFF86CFA9),
    Color(0xFF86B7EC),
    Color(0xFFC3A3EC),
  ];

  bool get _rinsing =>
      bathStage == 2 && action == PetCareAction.bath && _active;

  /// Bé phun nước ở cuối lượt xả: lắc nhanh rồi dừng.
  double get _shake {
    if (!_rinsing || progress < .6) return 0;
    final t = (progress - .6) / .4;
    return math.sin(progress * math.pi * 30) * .075 * math.sin(t * math.pi);
  }

  /// Mức há miệng khi món ăn tiến gần miệng (0 → 1).
  double get _reach {
    final hold = holdPoint;
    if (hold == null || room != PetCareRoom.kitchen || walking) return 0;
    final distance = (hold - _grownMouth).distance;
    return (1 - (distance - 16) / 120).clamp(0.0, 1.0);
  }

  bool get _cheerful =>
      scrubbing ||
      dance > 0 ||
      action == PetCareAction.feed && _active && progress > .44 ||
      action == PetCareAction.hug && !playing && _active;

  Color _water(int index) => switch (look.shower) {
    PetCareStyle.showerPetal => const [
      Color(0xFFF4A8BE),
      Color(0xFFFFC9D7),
    ][index % 2],
    PetCareStyle.showerRainbow => _palette[index % _palette.length],
    _ => const Color(0xFF8CCAD9),
  };

  /// Độ cao và co giãn của điệu nhảy, áp lên cả bé và lớp phủ mặt.
  ({double y, double sx, double sy}) get _danceMotion {
    if (dance <= 0) return (y: 0, sx: 1, sy: 1);
    final t = dance;
    final fade = math.sin(t * math.pi);
    switch (look.dance) {
      case PetCareStyle.danceSpin:
        final turn = math.cos(t * math.pi * 2);
        return (
          y: -math.sin(t * math.pi) * 22,
          sx: turn.abs() < .08 ? (turn < 0 ? -.08 : .08) : turn,
          sy: 1 + fade * .04,
        );
      case PetCareStyle.danceHeart:
        final hop = math.sin(t * math.pi * 2).abs();
        final land = math.pow(1 - hop, 6).toDouble() * fade;
        return (y: -hop * 13, sx: 1 + land * .1, sy: 1 - land * .09);
      case PetCareStyle.danceConfetti:
        final hop = math.sin(t * math.pi * 4).abs();
        final land = math.pow(1 - hop, 6).toDouble() * fade;
        return (y: -hop * 10, sx: 1 + land * .08, sy: 1 - land * .07);
      default:
        final hop = math.sin(t * math.pi * 3).abs();
        final land = math.pow(1 - hop, 6).toDouble() * fade;
        return (
          y: -hop * 15 * (1 - t * .25),
          sx: 1 + land * .09,
          sy: 1 - land * .08,
        );
    }
  }

  void _paintFoam(Canvas c, Offset base) {
    if (foam.isEmpty || room != PetCareRoom.bathroom) return;
    final wash = _rinsing ? Curves.easeIn.transform(progress) : 0.0;
    if (wash >= .98) return;
    final alpha = (1 - wash).clamp(0.0, 1.0);
    final soap = look.soap;
    final rim = switch (soap) {
      PetCareStyle.soapStrawberry => const Color(0xFFF2A9BF),
      PetCareStyle.soapMint => const Color(0xFF9FDCC5),
      PetCareStyle.soapRainbow => const Color(0xFFC9B8EE),
      _ => const Color(0xFFD9CDF2),
    };
    final fill = switch (soap) {
      PetCareStyle.soapStrawberry => const Color(0xFFFFE6EE),
      PetCareStyle.soapMint => const Color(0xFFEBFFF7),
      _ => Colors.white,
    };
    for (final blob in foam) {
      final p =
          base +
          blob.offset +
          Offset(
            math.sin(blob.seed + seconds * 1.3) * .8,
            wash * (30 + blob.seed % 9),
          );
      final r = 9.5 * blob.size * (1 - wash * .35);
      for (var k = 0; k < 3; k++) {
        final angle = blob.seed * 1.7 + k * 2.1;
        final q =
            p +
            Offset(math.cos(angle), math.sin(angle)) * r * (k == 0 ? 0 : .72);
        final radius = r * (k == 0 ? 1 : .62);
        final color = soap == PetCareStyle.soapRainbow
            ? HSVColor.fromAHSV(
                1,
                (blob.seed * 47 + k * 40 + seconds * 40) % 360,
                .26,
                1,
              ).toColor()
            : fill;
        _circle(c, q, radius, color.withValues(alpha: .94 * alpha));
        _oval(
          c,
          Rect.fromCircle(center: q, radius: radius),
          rim.withValues(alpha: .9 * alpha),
          stroke: .9,
        );
        _circle(
          c,
          q + Offset(-radius * .35, -radius * .38),
          radius * .24,
          Colors.white.withValues(alpha: alpha),
        );
      }
      if (soap == PetCareStyle.soapStrawberry && blob.seed % 3 == 0) {
        _heart(
          c,
          p + Offset(r * .9, -r * .9),
          3.4,
          const Color(0xFFE88AA3).withValues(alpha: alpha),
        );
      } else if (soap == PetCareStyle.soapMint && blob.seed % 3 == 1) {
        _star(
          c,
          p + Offset(r, -r),
          3.2,
          const Color(0xFF6FC2A8).withValues(alpha: alpha),
        );
      }
    }
  }

  /// Bé còn ướt sau khi xả: giọt nước lăn xuống, khăn lau tới đâu khô tới đó.
  void _paintDrips(Canvas c, Offset base) {
    if (room != PetCareRoom.bathroom) return;
    final drying = bathStage == 3 && action == PetCareAction.bath && _active;
    final wet = bathStage == 2 && !_rinsing
        ? 1.0
        : drying
        ? 1 - progress
        : 0.0;
    final level = wet * (1 - dryness);
    if (level <= .02) return;
    for (var i = 0; i < 6; i++) {
      final phase = (seconds * .9 + i * .17) % 1;
      final start = base + Offset(-30 + i * 12.0, -98 + (i % 3) * 22.0);
      final p = start + Offset(0, phase * 34);
      final alpha = level * math.sin(phase * math.pi);
      _path(
        c,
        Path()
          ..moveTo(p.dx, p.dy - 4)
          ..quadraticBezierTo(p.dx + 3, p.dy, p.dx, p.dy + 2.6)
          ..quadraticBezierTo(p.dx - 3, p.dy, p.dx, p.dy - 4),
        _water(i).withValues(alpha: alpha),
      );
    }
    for (var i = 0; i < 3; i++) {
      final p = base + Offset(-16 + i * 16.0, -84 + (i.isOdd ? 18 : 0));
      _path(
        c,
        Path()
          ..moveTo(p.dx - 4, p.dy)
          ..quadraticBezierTo(p.dx, p.dy - 4, p.dx + 4, p.dy),
        Colors.white.withValues(alpha: .7 * level),
        width: 1.6,
      );
    }
  }

  void _paintSpray(Canvas c, Offset base) {
    if (!_rinsing || progress < .62) return;
    final t = ((progress - .62) / .38).clamp(0.0, 1.0);
    final center = base + const Offset(0, -62);
    for (var i = 0; i < 10; i++) {
      final angle = i * math.pi / 5 + .3;
      final p =
          center +
          Offset(math.cos(angle), math.sin(angle) * .8) * (30 + t * 46);
      _circle(c, p, 2.4 * (1 - t * .5), _water(i).withValues(alpha: 1 - t));
    }
  }

  /// Miệng há theo khoảng cách món ăn; dùng cùng hệ tọa độ lớp phủ khi nhai.
  void _paintMouthOpen(Canvas c, double reach, {PetCarePet? pet}) {
    final patch = (pet ?? selectedPet) == PetCarePet.rabbit
        ? const Color(0xFFFFFAEF)
        : const Color(0xFFF3D7B2);
    _oval(c, const Rect.fromLTWH(-3.8, -41.2, 11, 6.7), patch);
    _oval(
      c,
      Rect.fromCenter(
        center: const Offset(1.7, -38.2),
        width: 6.5 + reach * 3,
        height: 1.5 + reach * 7,
      ),
      const Color(0xFF79564E),
    );
    _oval(
      c,
      Rect.fromCenter(
        center: Offset(1.7, -36.6 + reach * 1.6),
        width: 3.5 + reach * 1.5,
        height: 1.4 + reach * 1.2,
      ),
      const Color(0xFFEBA0AC),
    );
  }

  /// Miệng đang nhai và má phồng của [pet], vẽ trong hệ tọa độ hình bé
  /// (chân ở 180, 260); dùng chung cho bé mình và bé kia khi ăn cùng.
  void _paintChewMouth(
    Canvas c,
    PetCarePet pet,
    bool faceRight,
    double chew, {
    double? t,
  }) {
    final progress = t ?? this.progress;
    final k = _PetHousePainter._spriteOf(pet);
    c.save();
    c.translate(180, 260);
    c.scale((faceRight ? 1 : -1) * k, k);
    _oval(
      c,
      const Rect.fromLTWH(-3.8, -41.2, 11, 6.7),
      pet == PetCarePet.rabbit
          ? const Color(0xFFFFFAEF)
          : const Color(0xFFF3D7B2),
    );
    final opening = progress < .45 ? 6.0 : 3 + chew.abs() * 1.8;
    _oval(
      c,
      Rect.fromCenter(
        center: const Offset(1.7, -38.6),
        width: 7.5 + chew.abs(),
        height: opening,
      ),
      const Color(0xFF79564E),
    );
    _oval(
      c,
      Rect.fromCenter(center: const Offset(1.7, -37.1), width: 4.5, height: 2),
      const Color(0xFFEBA0AC),
    );
    _paintCheeks(
      c,
      progress > .46 && progress < .82 ? .6 + chew.abs() * .22 : 0,
      pet: pet,
    );
    c.restore();
  }

  /// Má phồng khi nhai, vẽ chồng lên viền mặt để nhìn như đang nhồm nhoàm.
  void _paintCheeks(Canvas c, double puff, {PetCarePet? pet}) {
    if (puff <= 0) return;
    final face = (pet ?? selectedPet) == PetCarePet.rabbit
        ? const Color(0xFFFFFAEF)
        : const Color(0xFFD6A171);
    for (final x in const [-23.5, 25.5]) {
      final rect = Rect.fromCenter(
        center: Offset(x, -39.5),
        width: 4 + 7 * puff,
        height: 4 + 5.5 * puff,
      );
      _oval(c, rect, face);
      c.drawArc(
        rect,
        x < 0 ? math.pi * .55 : -math.pi * .45,
        math.pi * .9,
        false,
        Paint()
          ..color = const Color(0xFF956E69)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.1
          ..strokeCap = StrokeCap.round,
      );
      _oval(
        c,
        rect.deflate(rect.width * .25),
        const Color(0xFFF2B4BE).withValues(alpha: .8),
      );
    }
  }

  void _paintDanceBack(Canvas c, Offset base) {
    if (dance <= 0) return;
    final t = dance;
    _oval(
      c,
      Rect.fromCenter(
        center: base + const Offset(0, 2),
        width: 58 - (-_danceMotion.y).clamp(0, 30),
        height: 7,
      ),
      _PetHousePainter._ink.withValues(alpha: .12),
    );
    if (look.dance != PetCareStyle.danceHeart || t >= .52) return;
    final grow = Curves.easeOutBack.transform((t / .5).clamp(0.0, 1.0));
    final center = base + Offset(0, -86 - grow * 8);
    final radius = 54 * grow + math.sin(seconds * 9) * 1.6;
    _heart(c, center, radius + 4, Colors.white.withValues(alpha: .8));
    _heart(c, center, radius, const Color(0xFFF6A9C0).withValues(alpha: .75));
  }

  void _paintDanceFront(Canvas c, Offset base) {
    if (dance <= 0) return;
    final t = dance;
    final center = base + const Offset(0, -64);
    if (t > .2) {
      final u = ((t - .2) / .8).clamp(0.0, 1.0);
      for (var i = 0; i < 6; i++) {
        final angle = i * math.pi / 3 + t * 3;
        _star(
          c,
          center + Offset(math.cos(angle) * 58, math.sin(angle) * 46),
          3.6 * math.sin(u * math.pi),
          (i.isEven ? _PetHousePainter._gold : _PetHousePainter._rose)
              .withValues(alpha: math.sin(u * math.pi)),
        );
      }
    }
    switch (look.dance) {
      case PetCareStyle.danceHeart when t >= .5:
        final u = ((t - .5) / .5).clamp(0.0, 1.0);
        for (var i = 0; i < 10; i++) {
          final angle = i * math.pi / 5;
          _heart(
            c,
            center + Offset(math.cos(angle), math.sin(angle)) * (30 + u * 84),
            9 - u * 3,
            _palette[i % _palette.length].withValues(alpha: 1 - u),
          );
        }
      case PetCareStyle.danceConfetti:
        for (var i = 0; i < 26; i++) {
          final u = (t * 1.25 - (i % 7) * .05).clamp(0.0, 1.0);
          if (u <= 0 || u >= 1) continue;
          final p = Offset(
            base.dx + ((i * 53) % 180) - 90 + math.sin(u * 6 + i) * 6,
            base.dy - 172 + u * 190,
          );
          c.save();
          c.translate(p.dx, p.dy);
          c.rotate(i + u * 8);
          _round(
            c,
            const Rect.fromLTWH(-3, -1.6, 6, 3.2),
            1,
            _palette[i % _palette.length].withValues(
              alpha: math.min(1, (1 - u) * 3),
            ),
          );
          c.restore();
        }
      case PetCareStyle.danceSpin:
        final u = math.sin(t * math.pi);
        for (var i = 0; i < 3; i++) {
          c.drawArc(
            Rect.fromCenter(
              center: base + const Offset(0, -8),
              width: 70 + i * 14.0,
              height: 16 + i * 4.0,
            ),
            t * math.pi * 4 + i,
            math.pi * .9,
            false,
            Paint()
              ..color = _PetHousePainter._lilac.withValues(alpha: .7 * u)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2
              ..strokeCap = StrokeCap.round,
          );
        }
      default:
        break;
    }
  }

  /// Ăn ớt: run nhẹ khi cay xè.
  double get _spicyShake {
    if (!food.spicy || progress < .5 || progress > .96) return 0;
    return math.sin(progress * math.pi * 40) * .03;
  }

  /// Vị món ăn trên mặt bé (hệ tọa độ nhân vật): mắt tim với món ruột,
  /// má đỏ bừng khi ăn ớt.
  void _paintTasteFace(Canvas c) {
    if (progress < .48) return;
    final t = ((progress - .48) / .52).clamp(0.0, 1.0);
    final show = math.sin(t * math.pi).clamp(0.0, 1.0);
    if (food.lovedBy(selectedPet)) {
      for (final x in const [-7.5, 10.5]) {
        _heart(
          c,
          Offset(x, -49.5),
          4.6 * (.7 + show * .3),
          const Color(0xFFE85A7A).withValues(alpha: show),
        );
      }
    }
    if (food.spicy) {
      for (final x in const [-21.0, 23.0]) {
        _oval(
          c,
          Rect.fromCenter(center: Offset(x, -38), width: 12, height: 7),
          const Color(0xFFFF6B5E).withValues(alpha: .7 * show),
        );
      }
    }
  }

  /// Hiệu ứng quanh bé sau khi ăn: hơi nóng và lửa nhỏ khi ăn ớt,
  /// tim bay khi ăn món ruột.
  void _paintTaste(Canvas c, Offset base) {
    if (progress < .5) return;
    final t = ((progress - .5) / .5).clamp(0.0, 1.0);
    if (food.spicy) {
      final head = base + Offset(0, -128 * (_roomPetScale / 2.85));
      for (var i = 0; i < 4; i++) {
        final u = (t * 1.4 - i * .12).clamp(0.0, 1.0);
        if (u <= 0 || u >= 1) continue;
        final side = i.isEven ? -1.0 : 1.0;
        _circle(
          c,
          head + Offset(side * (22 + u * 10), -u * 30),
          4 + u * 5,
          Colors.white.withValues(alpha: .75 * (1 - u)),
        );
      }
      final mouth = _mouth;
      final dir = facingRight ? 1.0 : -1.0;
      final flame = math.sin(t * math.pi);
      for (var i = 0; i < 3; i++) {
        final len = (22 + i * 8) * flame;
        final tip =
            mouth + Offset(dir * (8 + len), math.sin(seconds * 20 + i) * 3);
        _path(
          c,
          Path()
            ..moveTo(mouth.dx + dir * 4, mouth.dy - 4 + i * 2)
            ..quadraticBezierTo(
              (mouth.dx + tip.dx) / 2,
              mouth.dy - 9 + i * 3,
              tip.dx,
              tip.dy,
            )
            ..quadraticBezierTo(
              (mouth.dx + tip.dx) / 2,
              mouth.dy + 6 + i * 2,
              mouth.dx + dir * 4,
              mouth.dy + 2 + i * 2,
            ),
          [
            const Color(0xFFFF8A3D),
            const Color(0xFFFFC34D),
            const Color(0xFFFFE08A),
          ][i].withValues(alpha: .9 * flame),
        );
      }
    } else if (food.lovedBy(selectedPet)) {
      for (var i = 0; i < 5; i++) {
        final u = (t * 1.3 - i * .1).clamp(0.0, 1.0);
        if (u <= 0 || u >= 1) continue;
        _heart(
          c,
          base + Offset(math.sin(i * 1.7) * (22 + u * 26), -110 - u * 56),
          4 + math.sin(u * math.pi) * 3,
          _PetHousePainter._rose.withValues(alpha: math.sin(u * math.pi)),
        );
      }
    }
  }

  /// Món ăn đang cầm làm bé chồm tới, mắt sáng lên.
  void _paintCraving(Canvas c, Offset base, double reach) {
    if (reach < .55) return;
    final u = ((reach - .55) / .45).clamp(0.0, 1.0);
    for (final side in const [-1.0, 1.0]) {
      _star(
        c,
        base + Offset(side * 26, -128 - u * 6 + math.sin(seconds * 8) * 2),
        2.5 + u * 2,
        _PetHousePainter._gold.withValues(alpha: u),
      );
    }
  }
}
