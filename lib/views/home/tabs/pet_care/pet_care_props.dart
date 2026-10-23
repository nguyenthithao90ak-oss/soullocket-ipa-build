part of 'pet_care_scene.dart';

/// Vị trí đồ vật chạm được (đơn vị cảnh 360×300) và nhịp hoạt ảnh.
abstract final class _PetPropSpots {
  /// Đồ vật bật/tắt được; các món còn lại chỉ chạy một nhịp hoạt ảnh.
  static const toggles = {
    PetCareProp.livingWindow,
    PetCareProp.kitchenWindow,
    PetCareProp.bathWindow,
    PetCareProp.curtains,
    PetCareProp.radio,
    PetCareProp.sink,
    PetCareProp.bathSink,
  };

  /// Tự tắt sau ít giây để cảnh không phải vẽ lại mãi.
  static double? autoOff(PetCareProp prop) => switch (prop) {
    PetCareProp.radio => 16,
    PetCareProp.sink || PetCareProp.bathSink => 8,
    _ => null,
  };

  static double duration(PetCareProp prop) => switch (prop) {
    PetCareProp.clock => 1.8,
    PetCareProp.plant => 1.3,
    PetCareProp.basket => 1.4,
    PetCareProp.cushion => .9,
    PetCareProp.stove => 1.6,
    PetCareProp.utensils => 1.8,
    PetCareProp.jars => 1.0,
    PetCareProp.mirror => 1.4,
    PetCareProp.duck => 1.2,
    PetCareProp.towel => 1.8,
    PetCareProp.cabinet => 1.8,
    PetCareProp.mobile => 2.2,
    PetCareProp.drawer => 1.6,
    PetCareProp.books => 1.2,
    PetCareProp.slippers => 1.0,
    _ => .6,
  };

  static Rect rect(PetCareProp prop, double ext) => switch (prop) {
    PetCareProp.livingWindow => Rect.fromLTWH(34, 28 - ext * .48, 90, 118),
    PetCareProp.clock => Rect.fromCircle(
      center: Offset(198, 75 - ext * .42),
      radius: 26,
    ),
    PetCareProp.plant => const Rect.fromLTWH(20, 138, 46, 78),
    PetCareProp.radio => const Rect.fromLTWH(266, 28, 52, 44),
    PetCareProp.basket => const Rect.fromLTWH(296, 164, 46, 56),
    PetCareProp.cushion => const Rect.fromLTWH(140, 140, 146, 40),
    PetCareProp.fridge => const Rect.fromLTWH(12, 38, 78, 170),
    PetCareProp.kitchenWindow => Rect.fromLTWH(134, 18 - ext * .35, 91, 112),
    PetCareProp.jars => const Rect.fromLTWH(246, 22, 86, 40),
    PetCareProp.utensils => const Rect.fromLTWH(248, 86, 84, 42),
    PetCareProp.stove => const Rect.fromLTWH(266, 116, 62, 44),
    PetCareProp.sink => const Rect.fromLTWH(96, 124, 60, 36),
    PetCareProp.bathWindow => Rect.fromLTWH(18, 22 - ext * .4, 76, 94),
    PetCareProp.bathSink => const Rect.fromLTWH(18, 104, 72, 42),
    PetCareProp.cabinet => const Rect.fromLTWH(26, 146, 58, 62),
    PetCareProp.mirror => const Rect.fromLTWH(131, 32, 84, 108),
    PetCareProp.towel => const Rect.fromLTWH(303, 102, 42, 66),
    PetCareProp.duck => const Rect.fromLTWH(110, 202, 38, 28),
    PetCareProp.curtains => Rect.fromLTWH(18, 24 - ext * .42, 126, 128),
    PetCareProp.books => const Rect.fromLTWH(262, 20, 74, 50),
    PetCareProp.lamp => const Rect.fromLTWH(284, 122, 50, 56),
    PetCareProp.drawer => const Rect.fromLTWH(277, 178, 62, 56),
    PetCareProp.mobile => const Rect.fromLTWH(170, 6, 60, 76),
    PetCareProp.slippers => const Rect.fromLTWH(280, 252, 50, 34),
  };

  /// Chỗ hạt lấp lánh/bật ra: góc trên phải đồ vật.
  static Offset hint(PetCareProp prop, double ext) {
    final r = rect(prop, ext);
    return Offset(r.right - math.min(14, r.width * .25), r.top + 10);
  }
}

/// Đồ vật trong phòng: vẽ ở lớp riêng, chỉ vẽ lại khi đang có hoạt ảnh.
extension _PetCareProps on _PetHousePainter {
  double _tap(PetCareProp prop) => props[prop] ?? 0;
  bool _isOn(PetCareProp prop) => propsOn.contains(prop);

  /// Dao động tắt dần trong một nhịp chạm.
  double _wobble(double t, {double cycles = 3}) =>
      t <= 0 || t >= 1 ? 0 : math.sin(t * math.pi * 2 * cycles) * (1 - t);

  /// Rèm kéo: 1 là đóng kín, có trượt mềm khi vừa chạm.
  double _curtainAmount(PetCareProp prop) {
    final t = _tap(prop);
    final on = _isOn(prop);
    if (t <= 0) return on ? 1 : 0;
    final eased = Curves.easeInOutCubic.transform(t);
    return on ? eased : 1 - eased;
  }

  void _props(Canvas c, double ext) {
    switch (room) {
      case PetCareRoom.living:
        _window(c, y: 37 - ext * .48);
        _sideCurtains(
          c,
          PetCareRoomArt.windowPath(
            roomLook.window,
            const Size(77, 103),
          ).getBounds().shift(Offset(78.5, 88.5 - ext * .48)),
          _curtainAmount(PetCareProp.livingWindow),
          const Color(0xFFF3C3D1),
        );
        _propClock(c, Offset(198, 75 - ext * .42));
        _plant(
          c,
          const Offset(43, 210),
          1,
          sway: _wobble(_tap(PetCareProp.plant), cycles: 2.5),
        );
        _propBloom(c);
        _propRadio(c);
        _propBasket(c);
        _propCushions(c);
      case PetCareRoom.kitchen:
        _propFridge(c);
        _window(c, x: 140, y: 25 - ext * .35, width: 79, height: 99);
        _sideCurtains(
          c,
          PetCareRoomArt.windowPath(
            roomLook.window,
            const Size(79, 99),
          ).getBounds().shift(Offset(179.5, 74.5 - ext * .35)),
          _curtainAmount(PetCareProp.kitchenWindow),
          const Color(0xFFCFE6D6),
        );
        _propJars(c);
        _propUtensils(c);
        _propStove(c);
        _propSink(c);
      case PetCareRoom.bathroom:
        _window(c, x: 25, y: 29 - ext * .4, width: 62, height: 80);
        _sideCurtains(
          c,
          PetCareRoomArt.windowPath(
            roomLook.window,
            const Size(62, 80),
          ).getBounds().shift(Offset(56, 69 - ext * .4)),
          _curtainAmount(PetCareProp.bathWindow),
          const Color(0xFFCBE6EA),
        );
        _propMirror(c);
        _propCabinet(c);
        _propBathSink(c);
        _propTowel(c);
      case PetCareRoom.bedroom:
        _propBedWindow(c, ext);
        _propBooks(c);
        _moonMobile(c, const Offset(200, 16), spin: _tap(PetCareProp.mobile));
        _propNightstand(c);
        final t = _tap(PetCareProp.slippers);
        final hop = math.sin(t * math.pi * 3).abs() * 6 * (1 - t);
        _slipper(
          c,
          Offset(294, 268 - (t > 0 ? hop : 0)),
          -.3 + _wobble(t) * .3,
        );
        _slipper(
          c,
          Offset(315, 273 - (t > .15 ? hop : 0)),
          -.12 - _wobble((t - .15).clamp(0.0, 1.0)) * .3,
        );
    }
  }

  /// Hai tấm rèm trượt vào giữa che cửa sổ; mở thì gom gọn hai bên.
  void _sideCurtains(Canvas c, Rect window, double amount, Color color) {
    final rodY = window.top - 6;
    _line(
      c,
      Offset(window.left - 10, rodY),
      Offset(window.right + 10, rodY),
      _PetHousePainter._gold,
      2.5,
    );
    final half = window.width / 2 + 6;
    final width = 9 + (half - 9) * amount;
    final shade = Color.lerp(color, const Color(0xFF856C7A), .16)!;
    for (final left in [true, false]) {
      final x0 = left ? window.left - 8 : window.right + 8 - width;
      final panel = RRect.fromRectAndCorners(
        Rect.fromLTWH(x0, rodY, width, window.height + 12),
        bottomLeft: const Radius.circular(8),
        bottomRight: const Radius.circular(8),
      );
      c.drawRRect(panel, Paint()..color = color);
      for (var i = 1; i < 4; i++) {
        final x = x0 + width * i / 4;
        _line(
          c,
          Offset(x, rodY + 3),
          Offset(x, rodY + window.height + 8),
          shade.withValues(alpha: .35),
          1.2,
        );
      }
    }
  }

  void _propClock(Canvas c, Offset p) {
    final t = _tap(PetCareProp.clock);
    final pop = t <= 0 ? 0.0 : math.sin((t / .8).clamp(0.0, 1.0) * math.pi);
    c.save();
    c.translate(p.dx, p.dy);
    c.rotate(_wobble(t, cycles: 4) * .12);
    // Chim cúc cu ló ra từ sau mặt đồng hồ.
    if (pop > 0) {
      final bird = Offset(0, -20 - pop * 16);
      _oval(
        c,
        Rect.fromCenter(center: bird, width: 16, height: 13),
        const Color(0xFFFFD98C),
      );
      _circle(c, bird + const Offset(3, -2), 1.3, _PetHousePainter._ink);
      _path(
        c,
        Path()
          ..moveTo(bird.dx + 7, bird.dy - 1)
          ..lineTo(bird.dx + 13, bird.dy + 1 - pop * 2)
          ..lineTo(bird.dx + 7, bird.dy + 2),
        const Color(0xFFECA073),
      );
      for (var i = 0; i < 2; i++) {
        c.drawArc(
          Rect.fromCircle(
            center: bird + const Offset(12, 0),
            radius: 7 + i * 5.0,
          ),
          -.7,
          1.4,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4
            ..strokeCap = StrokeCap.round
            ..color = _PetHousePainter._gold.withValues(alpha: pop),
        );
      }
    }
    _circle(
      c,
      const Offset(1, 3),
      22,
      _PetHousePainter._ink.withValues(alpha: .1),
    );
    _circle(c, Offset.zero, 22, const Color(0xFFD7B695));
    _circle(c, Offset.zero, 18, _PetHousePainter._cream);
    for (var i = 0; i < 12; i++) {
      final angle = i * math.pi / 6;
      _circle(
        c,
        Offset(math.sin(angle) * 14, math.cos(angle) * 14),
        .9,
        _PetHousePainter._ink.withValues(alpha: .5),
      );
    }
    final spin = t * math.pi * 4;
    _line(
      c,
      Offset.zero,
      Offset(math.cos(-2.3 + spin * .25) * 9, math.sin(-2.3 + spin * .25) * 9),
      _PetHousePainter._ink,
      2,
    );
    _line(
      c,
      Offset.zero,
      Offset(math.cos(-.36 + spin) * 8.5, math.sin(-.36 + spin) * 8.5),
      _PetHousePainter._ink,
      1.5,
    );
    _circle(c, Offset.zero, 2, _PetHousePainter._rose);
    c.restore();
  }

  void _propBloom(Canvas c) {
    final t = _tap(PetCareProp.plant);
    if (t <= 0) return;
    final grow = Curves.easeOutBack.transform((t / .4).clamp(0.0, 1.0));
    final fade = 1 - ((t - .7) / .3).clamp(0.0, 1.0);
    _flower(
      c,
      const Offset(43, 136),
      6 * grow,
      _PetHousePainter._rose.withValues(alpha: fade),
    );
    for (var i = 0; i < 3; i++) {
      final u = (t * 1.2 - i * .15).clamp(0.0, 1.0);
      if (u <= 0 || u >= 1) continue;
      _oval(
        c,
        Rect.fromCenter(
          center: Offset(43 + (i - 1) * 16 + u * 10, 150 + u * 50),
          width: 6,
          height: 3.5,
        ),
        _PetHousePainter._mint.withValues(alpha: 1 - u),
      );
    }
  }

  void _note(Canvas c, Offset p, double size, Color color) {
    _oval(
      c,
      Rect.fromCenter(center: p, width: size * .9, height: size * .65),
      color,
    );
    _line(
      c,
      p + Offset(size * .4, 0),
      p + Offset(size * .4, -size * 1.5),
      color,
      1.4,
    );
    _path(
      c,
      Path()
        ..moveTo(p.dx + size * .4, p.dy - size * 1.5)
        ..quadraticBezierTo(
          p.dx + size * 1.1,
          p.dy - size * 1.2,
          p.dx + size * .9,
          p.dy - size * .7,
        ),
      color,
      width: 1.4,
    );
  }

  void _propRadio(Canvas c) {
    final on = _isOn(PetCareProp.radio);
    final t = _tap(PetCareProp.radio);
    final beat = on ? math.sin(seconds * math.pi * 3.2).abs() : 0.0;
    final hop = t > 0 ? math.sin(t * math.pi) * 5 : 0.0;
    c.save();
    c.translate(291, 70 - hop - beat * 2);
    c.scale(1 + beat * .04, 1 - beat * .04);
    c.translate(-291, -70);
    _line(
      c,
      const Offset(304, 46),
      Offset(314 + (on ? math.sin(seconds * 9) * 2 : 0), 30),
      _PetHousePainter._ink.withValues(alpha: .7),
      1.6,
    );
    _circle(
      c,
      Offset(314 + (on ? math.sin(seconds * 9) * 2 : 0), 30),
      2.2,
      _PetHousePainter._rose,
    );
    _round(c, const Rect.fromLTWH(270, 45, 42, 26), 7, const Color(0xFFF2A99A));
    _round(c, const Rect.fromLTWH(273, 48, 36, 19), 5, const Color(0xFFF8C8B9));
    _circle(
      c,
      const Offset(283, 58),
      6.5 + beat * 1.2,
      const Color(0xFFB98779),
    );
    for (var i = 0; i < 6; i++) {
      final a = i * math.pi / 3;
      _circle(
        c,
        Offset(283 + math.cos(a) * 3.4, 58 + math.sin(a) * 3.4),
        .9,
        _PetHousePainter._cream,
      );
    }
    _circle(c, const Offset(301, 54), 3.5, _PetHousePainter._gold);
    _round(
      c,
      const Rect.fromLTWH(296, 61, 10, 3),
      1.5,
      _PetHousePainter._cream,
    );
    c.restore();
    if (!on) return;
    for (var i = 0; i < 3; i++) {
      final phase = (seconds * .55 + i / 3) % 1;
      _note(
        c,
        Offset(
          282 + i * 12 + math.sin(phase * math.pi * 2) * 6,
          38 - phase * 46,
        ),
        5 + i % 2 * 1.5,
        [
          _PetHousePainter._rose,
          _PetHousePainter._lilac,
          _PetHousePainter._gold,
        ][i].withValues(alpha: math.sin(phase * math.pi)),
      );
    }
  }

  void _propBasket(Canvas c) {
    final t = _tap(PetCareProp.basket);
    if (t > 0) {
      // Đồ chơi bật lên khỏi giỏ rồi rơi lại.
      for (var i = 0; i < 2; i++) {
        final u = (t * 1.15 - i * .15).clamp(0.0, 1.0);
        if (u <= 0 || u >= 1) continue;
        final p = Offset(
          312 + i * 14 + u * (i.isEven ? -10 : 8),
          186 - math.sin(u * math.pi) * 42,
        );
        if (i == 0) {
          _circle(c, p, 7, _PetHousePainter._rose);
          _line(
            c,
            p + const Offset(-6, -2),
            p + const Offset(6, 2),
            _PetHousePainter._cream,
            1.5,
          );
        } else {
          _star(c, p, 7, _PetHousePainter._gold);
        }
      }
    }
    final squash = _wobble(t, cycles: 2) * .08;
    c.save();
    c.translate(319, 218);
    c.scale(1 + squash, 1 - squash);
    c.translate(-319, -218);
    _round(c, const Rect.fromLTWH(306, 169, 10, 24), 2, _PetHousePainter._mint);
    _round(c, const Rect.fromLTWH(318, 173, 9, 20), 2, _PetHousePainter._lilac);
    _round(
      c,
      const Rect.fromLTWH(300, 183, 38, 35),
      7,
      const Color(0xFFC9AA91),
    );
    for (var i = 0; i < 5; i++) {
      _line(
        c,
        Offset(304, 190 + i * 5.0),
        Offset(333, 190 + i * 5.0),
        const Color(0xFFEAD4B3),
        1,
      );
    }
    c.restore();
  }

  void _propCushions(Canvas c) {
    final t = _tap(PetCareProp.cushion);
    final squash = _wobble(t, cycles: 2.5) * .16;
    final hop = t > 0 ? math.sin(t * math.pi).abs() * 6 * (1 - t) : 0.0;
    c.save();
    c.translate(163, 161 - hop);
    c.rotate(-.16);
    c.scale(1 + squash, 1 - squash);
    _round(
      c,
      const Rect.fromLTWH(-18, -18, 36, 35),
      11,
      _PetHousePainter._cream,
    );
    _heart(c, Offset.zero, 7, _PetHousePainter._rose);
    c.restore();
    c.save();
    c.translate(264, 163 - hop * .7);
    c.rotate(.19);
    c.scale(1 - squash, 1 + squash);
    _round(
      c,
      const Rect.fromLTWH(-19, -19, 37, 36),
      10,
      _PetHousePainter._mint,
    );
    for (var i = -1; i < 2; i++) {
      _line(
        c,
        Offset(-12, i * 8.0),
        Offset(12, i * 8.0),
        Colors.white.withValues(alpha: .45),
        2,
      );
    }
    c.restore();
  }

  void _propFridge(Canvas c) {
    final body = _tint(const Color(0xFFF2F6F0), (t) => t.light);
    final shade = _tint(const Color(0xFFCFE0D5), (t) => t.main);
    final open = Curves.easeOutCubic.transform(fridgeOpen.clamp(0.0, 1.0));
    _shadow(c, const Rect.fromLTWH(10, 200, 84, 14));
    _round(c, const Rect.fromLTWH(14, 40, 74, 166), 12, shade);
    _round(c, const Rect.fromLTWH(14, 40, 70, 166), 12, body);
    // Ngăn đá trên.
    _round(
      c,
      const Rect.fromLTWH(18, 44, 64, 48),
      9,
      Colors.white.withValues(alpha: .55),
    );
    _round(c, const Rect.fromLTWH(72, 56, 4, 22), 2, const Color(0xFFB8C7C0));
    _round(c, const Rect.fromLTWH(20, 202, 10, 5), 2, _PetHousePainter._ink);
    _round(c, const Rect.fromLTWH(70, 202, 10, 5), 2, _PetHousePainter._ink);
    const inside = Rect.fromLTWH(19, 97, 64, 104);
    if (open > .01) {
      // Bên trong sáng đèn, ba ngăn có đồ ăn.
      _round(c, inside, 8, const Color(0xFFFFFDF4));
      c.drawRRect(
        RRect.fromRectAndRadius(inside, const Radius.circular(8)),
        Paint()
          ..shader = RadialGradient(
            colors: [
              const Color(0xFFFFF4C8).withValues(alpha: .9 * open),
              const Color(0x00FFF4C8),
            ],
          ).createShader(inside),
      );
      for (final y in const [131.0, 165.0]) {
        _line(c, Offset(21, y), Offset(81, y), const Color(0xFFCFE0E6), 2);
      }
      const items = [
        ('🍓', Offset(33, 118)),
        ('🥛', Offset(63, 116)),
        ('🍰', Offset(35, 152)),
        ('🍙', Offset(64, 152)),
        ('🥕', Offset(34, 186)),
        ('🍎', Offset(62, 186)),
      ];
      for (final (emoji, point) in items) {
        PetCareFoodPaint.paint(c, emoji, point, 17);
      }
    }
    // Cửa chính xoay quanh bản lề trái.
    final width = 66 * (1 - open);
    if (width > 1) {
      _round(c, Rect.fromLTWH(17, 96, width, 107), 9, body);
      _round(
        c,
        Rect.fromLTWH(17 + width - 12 * (1 - open), 108, 4, 34),
        2,
        const Color(0xFFB8C7C0),
      );
      if (open < .3) {
        final fade = 1 - open / .3;
        _heart(
          c,
          const Offset(34, 120),
          6,
          _PetHousePainter._rose.withValues(alpha: fade),
        );
        _star(
          c,
          const Offset(52, 132),
          6,
          _PetHousePainter._gold.withValues(alpha: fade),
        );
        _round(
          c,
          const Rect.fromLTWH(27, 148, 20, 16),
          2,
          _PetHousePainter._cream.withValues(alpha: fade),
        );
        for (var i = 0; i < 3; i++) {
          _line(
            c,
            Offset(30, 152 + i * 4.0),
            Offset(43, 152 + i * 4.0),
            const Color(0xFFD9B8C2).withValues(alpha: fade),
            1,
          );
        }
      }
    }
    if (open > .05) {
      // Mặt trong cánh cửa nhìn nghiêng bên trái.
      _round(
        c,
        Rect.fromLTWH(17 - 16 * open, 98, 16 * open, 103),
        5,
        Color.lerp(body, shade, .35)!,
      );
    }
  }

  void _propJars(Canvas c) {
    final t = _tap(PetCareProp.jars);
    _round(c, const Rect.fromLTWH(248, 55, 81, 8), 4, const Color(0xFFD7BBA0));
    for (final (i, x, color, scale) in [
      (0, 264.0, _PetHousePainter._rose, 1.0),
      (1, 293.0, _PetHousePainter._gold, .85),
    ]) {
      c.save();
      c.translate(x, 55);
      c.rotate(_wobble((t - i * .1).clamp(0.0, 1.0), cycles: 2) * .22);
      c.translate(-x, -55);
      _jar(
        c,
        Offset(x, 53 - (t > 0 ? math.sin(t * math.pi) * 3 : 0)),
        color,
        scale,
      );
      c.restore();
    }
    _plant(c, const Offset(320, 54), .46, sway: _wobble(t, cycles: 2));
    if (t > 0) {
      final u = t.clamp(0.0, 1.0);
      _heart(
        c,
        Offset(279, 20 - u * 14),
        4 + math.sin(u * math.pi) * 2,
        _PetHousePainter._rose.withValues(alpha: math.sin(u * math.pi)),
      );
    }
  }

  void _propUtensils(Canvas c) {
    final t = _tap(PetCareProp.utensils);
    _line(
      c,
      const Offset(248, 89),
      const Offset(327, 89),
      _PetHousePainter._ink.withValues(alpha: .5),
      2,
    );
    for (var i = 0; i < 3; i++) {
      final x = 260 + i * 23.0;
      c.save();
      c.translate(x, 89);
      c.rotate(_wobble((t - i * .08).clamp(0.0, 1.0), cycles: 2.5) * .45);
      c.translate(-x, -89);
      _line(
        c,
        Offset(x, 89),
        Offset(x, 116),
        _PetHousePainter._ink.withValues(alpha: .65),
        2,
      );
      if (i == 1) {
        _round(c, Rect.fromLTWH(x - 5, 110, 10, 14), 3, _PetHousePainter._gold);
      } else {
        _oval(
          c,
          Rect.fromLTWH(x - 4, 111, 8, 13),
          _PetHousePainter._ink.withValues(alpha: .7),
        );
      }
      c.restore();
    }
  }

  void _propStove(Canvas c) {
    final t = _tap(PetCareProp.stove);
    _round(
      c,
      const Rect.fromLTWH(271, 140, 52, 18),
      5,
      const Color(0xFFE6D7C2),
    );
    _oval(c, const Rect.fromLTWH(279, 143, 13, 7), const Color(0xFFB9A88F));
    _oval(c, const Rect.fromLTWH(301, 143, 13, 7), const Color(0xFFB9A88F));
    final jiggle = _wobble(t, cycles: 5) * 1.5;
    final lid = t > 0 ? math.sin(t * math.pi * 4).abs() * 6 * (1 - t) : 0.0;
    _round(
      c,
      Rect.fromLTWH(287 + jiggle, 129, 25, 16),
      6,
      _PetHousePainter._rose,
    );
    _line(
      c,
      Offset(285 + jiggle, 129 - lid),
      Offset(314 + jiggle, 129 - lid),
      _PetHousePainter._cream,
      4,
    );
    _circle(c, Offset(299.5 + jiggle, 125 - lid), 2.2, _PetHousePainter._cream);
    if (t <= 0) return;
    for (var i = 0; i < 3; i++) {
      final u = (t * 1.3 - i * .18).clamp(0.0, 1.0);
      if (u <= 0 || u >= 1) continue;
      _circle(
        c,
        Offset(292 + i * 8 + math.sin(u * 6 + i) * 4, 120 - u * 40),
        4 + u * 6,
        Colors.white.withValues(alpha: .7 * (1 - u)),
      );
    }
  }

  void _tapWater(Canvas c, Offset from, Offset to, {double width = 3}) {
    final paint = Paint()
      ..color = const Color(0xFFB4E9F1).withValues(alpha: .9)
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round;
    c.drawLine(from, to, paint);
    for (var i = 0; i < 4; i++) {
      final phase = (seconds * 2.4 + i / 4) % 1;
      c.drawCircle(
        Offset.lerp(from, to, phase)! + Offset(width * .2, 0),
        width * .35,
        Paint()..color = Colors.white.withValues(alpha: .8),
      );
    }
    for (var i = 0; i < 3; i++) {
      final phase = (seconds * 3 + i / 3) % 1;
      c.drawCircle(
        to + Offset((i - 1) * 4 * phase * 2, -math.sin(phase * math.pi) * 5),
        1.4,
        Paint()..color = const Color(0xFF9ED8E4).withValues(alpha: 1 - phase),
      );
    }
  }

  void _propSink(Canvas c) {
    _round(
      c,
      const Rect.fromLTWH(100, 147, 50, 12),
      6,
      const Color(0xFF9EBDB8),
    );
    _round(c, const Rect.fromLTWH(104, 149, 42, 6), 3, const Color(0xFFC4DCDA));
    _path(
      c,
      Path()
        ..moveTo(116, 147)
        ..lineTo(116, 136)
        ..quadraticBezierTo(116, 127, 126, 131)
        ..lineTo(126, 135),
      _PetHousePainter._ink.withValues(alpha: .6),
      width: 3,
    );
    final t = _tap(PetCareProp.sink);
    _round(
      c,
      Rect.fromLTWH(111, 138 - (t > 0 ? math.sin(t * math.pi) * 2 : 0), 10, 3),
      1.5,
      _PetHousePainter._gold,
    );
    if (_isOn(PetCareProp.sink)) {
      _tapWater(c, const Offset(126, 137), const Offset(126, 151));
    }
  }

  void _propMirror(Canvas c) {
    final t = _tap(PetCareProp.mirror);
    _oval(c, const Rect.fromLTWH(141, 36, 18, 41), _PetHousePainter._cream);
    _oval(c, const Rect.fromLTWH(184, 35, 18, 41), _PetHousePainter._cream);
    _round(
      c,
      const Rect.fromLTWH(133, 55, 79, 76),
      36,
      _PetHousePainter._cream,
    );
    const glass = Rect.fromLTWH(140, 62, 65, 62);
    _round(c, glass, 29, const Color(0xFFBBDDDC));
    c.save();
    c.clipRRect(RRect.fromRectAndRadius(glass, const Radius.circular(29)));
    final sweep = t > 0 ? -50 + t * 150 : 0.0;
    _path(
      c,
      Path()
        ..moveTo(150 + sweep, 90)
        ..lineTo(173 + sweep, 68)
        ..moveTo(150 + sweep, 105)
        ..lineTo(187 + sweep, 68),
      Colors.white.withValues(alpha: t > 0 ? .8 : .48),
      width: 5,
    );
    c.restore();
    _round(c, const Rect.fromLTWH(139, 132, 68, 7), 3, const Color(0xFFC6AE9A));
    _round(c, const Rect.fromLTWH(147, 117, 12, 17), 4, _PetHousePainter._rose);
    _round(c, const Rect.fromLTWH(150, 112, 8, 6), 2, _PetHousePainter._cream);
    _round(
      c,
      const Rect.fromLTWH(185, 117, 13, 17),
      4,
      _PetHousePainter._lilac,
    );
    _round(c, const Rect.fromLTWH(190, 112, 7, 6), 2, _PetHousePainter._cream);
    if (t > .5) {
      final u = (t - .5) / .5;
      for (var i = 0; i < 3; i++) {
        _star(
          c,
          Offset(150 + i * 22.0, 70 + (i.isOdd ? 18 : 0)),
          3 + math.sin(u * math.pi) * 3,
          Colors.white.withValues(alpha: math.sin(u * math.pi)),
        );
      }
    }
  }

  void _propCabinet(Canvas c) {
    final t = _tap(PetCareProp.cabinet);
    final open = t <= 0 ? 0.0 : math.sin(t * math.pi).clamp(0.0, 1.0);
    _shadow(c, const Rect.fromLTWH(23, 208, 64, 13));
    _round(
      c,
      const Rect.fromLTWH(29, 135, 51, 69),
      10,
      _tint(const Color(0xFFC6B4CE), (t) => t.main),
    );
    const door = Rect.fromLTWH(34, 143, 41, 53);
    if (open > .02) {
      _round(c, door, 7, const Color(0xFF8E7C99));
      _line(
        c,
        const Offset(36, 170),
        const Offset(73, 170),
        _PetHousePainter._cream,
        1.5,
      );
      _round(c, const Rect.fromLTWH(41, 152, 8, 16), 3, _PetHousePainter._rose);
      _round(c, const Rect.fromLTWH(54, 156, 7, 12), 3, _PetHousePainter._mint);
      _round(
        c,
        const Rect.fromLTWH(44, 178, 20, 10),
        3,
        _PetHousePainter._cream,
      );
    }
    final width = 41 * (1 - open * .82);
    _round(
      c,
      Rect.fromLTWH(34, 143, width, 53),
      7,
      _tint(const Color(0xFFE4D7E8), (t) => t.light),
    );
    _circle(c, Offset(34 + width - 7, 161), 2, _PetHousePainter._lilac);
  }

  void _propBathSink(Canvas c) {
    _oval(c, const Rect.fromLTWH(22, 125, 64, 20), _PetHousePainter._cream);
    _oval(c, const Rect.fromLTWH(32, 130, 43, 10), const Color(0xFFB7D9D8));
    final t = _tap(PetCareProp.bathSink);
    _path(
      c,
      Path()
        ..moveTo(54, 125)
        ..lineTo(54, 117)
        ..quadraticBezierTo(54, 108, 64, 112)
        ..lineTo(64, 117),
      _PetHousePainter._gold,
      width: 3,
    );
    _circle(
      c,
      Offset(48, 117 - (t > 0 ? math.sin(t * math.pi) * 2 : 0)),
      2.6,
      _PetHousePainter._gold,
    );
    if (_isOn(PetCareProp.bathSink)) {
      _tapWater(c, const Offset(64, 119), const Offset(64, 133), width: 2.6);
    }
  }

  void _propTowel(Canvas c) {
    final t = _tap(PetCareProp.towel);
    _line(
      c,
      const Offset(307, 111),
      const Offset(341, 111),
      _PetHousePainter._gold,
      3,
    );
    // Khăn đang được kéo tới bé: móc treo trống.
    if (dragTool == PetCareTool.towel) return;
    c.save();
    c.translate(324, 111);
    c.rotate(_wobble(t, cycles: 2.5) * .35);
    c.translate(-324, -111);
    _round(c, const Rect.fromLTWH(311, 111, 26, 54), 6, _PetHousePainter._rose);
    _round(
      c,
      const Rect.fromLTWH(316, 111, 21, 47),
      5,
      const Color(0xFFF1BAC7),
    );
    for (var i = 0; i < 4; i++) {
      _line(
        c,
        Offset(317, 142 + i * 4.0),
        Offset(335, 142 + i * 4.0),
        _PetHousePainter._cream.withValues(alpha: .5),
        1.5,
      );
    }
    c.restore();
  }

  /// Vịt cao su trên thành bồn (vẽ ở lớp trước); chạm thì nảy và kêu.
  void _propDuck(Canvas c) {
    final t = _tap(PetCareProp.duck);
    final hop = t > 0 ? math.sin(t * math.pi * 2).abs() * 10 * (1 - t) : 0.0;
    final squash = _wobble(t, cycles: 2) * .12;
    c.save();
    c.translate(128, 222);
    c.scale(1 + squash, 1 - squash);
    c.translate(-128, -222);
    _duck(c, Offset(128, 218 + _wave * 1.4 - hop), .6);
    c.restore();
    if (t <= 0) return;
    for (var i = 0; i < 2; i++) {
      c.drawArc(
        Rect.fromCircle(center: Offset(143, 210 - hop), radius: 5 + i * 5.0),
        -.8,
        1.6,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.3
          ..strokeCap = StrokeCap.round
          ..color = _PetHousePainter._gold.withValues(alpha: 1 - t),
      );
    }
    for (var i = 0; i < 3; i++) {
      final u = (t * 1.2 - i * .15).clamp(0.0, 1.0);
      if (u <= 0 || u >= 1) continue;
      _bubble(c, Offset(120 + i * 8.0, 212 - u * 30), 3 + i.toDouble(), 1 - u);
    }
  }

  void _propBedWindow(Canvas c, double ext) {
    c.save();
    c.translate(0, -ext * .42);
    _window(c, night: true, x: 43, y: 37, width: 78, height: 93);
    _line(
      c,
      const Offset(28, 28),
      const Offset(132, 28),
      _PetHousePainter._gold,
      3,
    );
    final a = _curtainAmount(PetCareProp.curtains);
    final curtain = dark ? const Color(0xFF8D7FA5) : const Color(0xFFC3B5DD);
    Offset l(Offset open, Offset closed) => Offset.lerp(open, closed, a)!;
    _path(
      c,
      Path()
        ..moveTo(34, 29)
        ..lineTo(l(const Offset(58, 29), const Offset(84, 29)).dx, 29)
        ..quadraticBezierTo(
          l(const Offset(66, 80), const Offset(86, 80)).dx,
          80,
          l(const Offset(46, 105), const Offset(84, 105)).dx,
          105,
        )
        ..lineTo(l(const Offset(34, 148), const Offset(84, 148)).dx, 148)
        ..quadraticBezierTo(
          l(const Offset(20, 138), const Offset(58, 152)).dx,
          l(const Offset(20, 138), const Offset(58, 152)).dy,
          24,
          126 + a * 22,
        )
        ..close(),
      curtain,
    );
    _path(
      c,
      Path()
        ..moveTo(l(const Offset(110, 29), const Offset(82, 29)).dx, 29)
        ..lineTo(132, 29)
        ..lineTo(140, 140)
        ..quadraticBezierTo(
          l(const Offset(128, 151), const Offset(110, 152)).dx,
          151,
          l(const Offset(117, 144), const Offset(82, 148)).dx,
          l(const Offset(117, 144), const Offset(82, 148)).dy,
        )
        ..lineTo(l(const Offset(112, 108), const Offset(82, 108)).dx, 108)
        ..quadraticBezierTo(
          l(const Offset(97, 79), const Offset(80, 79)).dx,
          79,
          l(const Offset(110, 29), const Offset(82, 29)).dx,
          29,
        )
        ..close(),
      curtain,
    );
    final tie = (1 - a * 2).clamp(0.0, 1.0);
    if (tie > 0) {
      _line(
        c,
        const Offset(34, 106),
        const Offset(47, 106),
        _PetHousePainter._gold.withValues(alpha: tie),
        4,
      );
      _line(
        c,
        const Offset(117, 105),
        const Offset(130, 105),
        _PetHousePainter._gold.withValues(alpha: tie),
        4,
      );
    }
    for (var i = 0; i < 3; i++) {
      _path(
        c,
        Path()
          ..moveTo(34 + i * 7, 34)
          ..quadraticBezierTo(30 + i * 6, 82, 36 + i * 3, 102),
        Colors.white.withValues(alpha: .2),
        width: 1.5,
      );
    }
    c.restore();
  }

  void _propBooks(Canvas c) {
    final t = _tap(PetCareProp.books);
    _round(c, const Rect.fromLTWH(264, 60, 68, 8), 4, const Color(0xFFD2B8A2));
    for (final (i, rect, color) in [
      (0, const Rect.fromLTWH(273, 43, 12, 17), _PetHousePainter._rose),
      (1, const Rect.fromLTWH(289, 35, 10, 25), _PetHousePainter._mint),
      (2, const Rect.fromLTWH(303, 39, 10, 21), _PetHousePainter._lilac),
    ]) {
      final u = (t * 1.3 - i * .14).clamp(0.0, 1.0);
      final hop = u > 0 && u < 1 ? math.sin(u * math.pi) * 7 : 0.0;
      _round(c, rect.shift(Offset(0, -hop)), 3, color);
    }
    c.save();
    c.translate(316, 31);
    c.rotate(t * math.pi * 2);
    _star(c, Offset.zero, 8, _PetHousePainter._gold);
    c.restore();
  }

  void _propNightstand(Canvas c) {
    final drawer = _tap(PetCareProp.drawer);
    final lamp = _tap(PetCareProp.lamp);
    final out = drawer <= 0 ? 0.0 : math.sin(drawer * math.pi);
    _round(
      c,
      const Rect.fromLTWH(280, 180, 54, 51),
      9,
      _tint(const Color(0xFFCBB3BD), (t) => t.main),
    );
    if (out > .02) {
      _round(
        c,
        const Rect.fromLTWH(285, 186, 43, 6),
        2,
        const Color(0xFF8E7480),
      );
    }
    c.save();
    c.translate(306.5, 200 + out * 6);
    c.scale(1 + out * .1);
    _round(
      c,
      const Rect.fromLTWH(-21.5, -12, 43, 24),
      6,
      _tint(const Color(0xFFE6D6DC), (t) => t.light),
    );
    _circle(c, const Offset(.5, -1), 2.4, _PetHousePainter._gold);
    c.restore();
    _round(
      c,
      const Rect.fromLTWH(277, 176, 61, 9),
      4.5,
      _PetHousePainter._cream,
    );
    _line(
      c,
      const Offset(308, 150),
      const Offset(308, 175),
      _PetHousePainter._gold,
      4,
    );
    _oval(c, const Rect.fromLTWH(293, 170, 30, 6), _PetHousePainter._gold);
    // Đèn ngủ là công tắc: tắt ngay khi bé mình đi ngủ.
    final lit = !vitals.sleeping;
    if (lit) {
      const glow = Offset(308, 147);
      c.drawCircle(
        glow,
        46,
        Paint()
          ..shader = RadialGradient(
            colors: [
              const Color(0xFFFFE0A8).withValues(alpha: dark ? .32 : .26),
              const Color(0x00FFE0A8),
            ],
          ).createShader(Rect.fromCircle(center: glow, radius: 46)),
      );
    }
    c.save();
    c.translate(308, 153);
    c.rotate(_wobble(lamp, cycles: 3) * .12);
    c.translate(-308, -153);
    _path(
      c,
      Path()
        ..moveTo(293, 128)
        ..lineTo(321, 128)
        ..lineTo(329, 153)
        ..quadraticBezierTo(309, 160, 286, 153)
        ..close(),
      lit
          ? (_level > 0 ? const Color(0xFFFFE2A8) : const Color(0xFFFFE6C2))
          : (_level > 0 ? const Color(0xFFE8C88C) : const Color(0xFFE8C4B6)),
    );
    _line(
      c,
      const Offset(289, 153),
      const Offset(327, 153),
      _PetHousePainter._cream,
      2,
    );
    c.restore();
  }

  /// Gợi ý hạt giấu: lấp lánh nhẹ ở đồ vật còn hạt hôm nay.
  void _paintSeedHints(Canvas c, double ext) {
    if (small || seedProps.isEmpty) return;
    var i = 0;
    for (final prop in seedProps) {
      if (prop.room != room || prop == seedPop) continue;
      final p = _PetPropSpots.hint(prop, ext);
      final twinkle = (math.sin(seconds * 2.6 + i * 2.1) + 1) / 2;
      i++;
      if (twinkle < .35) continue;
      final u = (twinkle - .35) / .65;
      _star(c, p, 2.5 + u * 3.5, Colors.white.withValues(alpha: .95 * u));
      _star(c, p, 1.5 + u * 2, const Color(0xFFFFD86B).withValues(alpha: u));
      _circle(
        c,
        p + const Offset(-7, 6),
        1.2 * u,
        const Color(0xFFFFE9A8).withValues(alpha: u),
      );
    }
  }

  /// Hạt vừa tìm thấy: bật lên khỏi đồ vật rồi bay về ví Hạt góc trên.
  void _paintSeedPop(Canvas c, double ext) {
    final prop = seedPop;
    final t = seedPopProgress;
    if (prop == null || t <= 0 || t >= 1 || prop.room != room) return;
    final start = _PetPropSpots.hint(prop, ext);
    final Offset p;
    final double scale;
    if (t < .4) {
      final u = t / .4;
      p = start + Offset(0, -34 * Curves.easeOutCubic.transform(u));
      scale = Curves.easeOutBack.transform(u) * 1.25;
    } else {
      final u = Curves.easeInCubic.transform((t - .4) / .6);
      final top = start + const Offset(0, -34);
      p =
          Offset.lerp(top, Offset(338, 8 - ext), u)! +
          Offset(0, -math.sin(u * math.pi) * 30);
      scale = 1.25 - u * .65;
    }
    if (t < .5) {
      final ring = t / .5;
      for (var i = 0; i < 8; i++) {
        final a = i * math.pi / 4;
        _star(
          c,
          start +
              const Offset(0, -24) +
              Offset(math.cos(a), math.sin(a)) * (10 + ring * 26),
          3 * (1 - ring),
          const Color(0xFFFFD86B).withValues(alpha: 1 - ring),
        );
      }
    }
    c.save();
    c.translate(p.dx, p.dy);
    c.scale(scale);
    c.drawCircle(
      Offset.zero,
      10,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF7C35F), Color(0xFFD9922F)],
        ).createShader(Rect.fromCircle(center: Offset.zero, radius: 10)),
    );
    _circle(c, Offset.zero, 10.8, Colors.white.withValues(alpha: .0));
    for (final side in const [-1.0, 1.0]) {
      c.save();
      c.rotate(side * .55);
      _oval(c, const Rect.fromLTWH(-2.2, -8, 4.4, 9), Colors.white);
      c.restore();
    }
    _line(c, const Offset(0, -1), const Offset(0, 5), Colors.white, 1.6);
    c.restore();
  }
}
