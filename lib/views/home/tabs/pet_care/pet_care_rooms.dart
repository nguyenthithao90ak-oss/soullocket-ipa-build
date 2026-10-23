part of 'pet_care_scene.dart';

/// Nội thất tĩnh từng phòng (lớp nền) và phần đứng trước bé (lớp trước).
/// Màu món chính đổi theo bộ nội thất đã chọn; đồ vật chạm được nằm ở
/// `pet_care_props.dart`.
extension _PetCareRooms on _PetHousePainter {
  static const _night = Color(0xFF1C1A3A);

  void _livingBack(Canvas c, double extension) {
    // Bộ sofa giống bánh mochi; gối tựa là đồ vật chạm được.
    _shadow(c, const Rect.fromLTWH(123, 192, 176, 22));
    _round(
      c,
      const Rect.fromLTWH(127, 132, 172, 70),
      25,
      _tone == null && dark
          ? const Color(0xFF9E798F)
          : _tint(const Color(0xFFE8AFBE), (t) => t.main),
    );
    _round(
      c,
      const Rect.fromLTWH(137, 141, 73, 48),
      17,
      _tint(const Color(0xFFF1C2CD), (t) => t.light),
    );
    _round(
      c,
      const Rect.fromLTWH(214, 141, 73, 48),
      17,
      _tint(const Color(0xFFE9B4C6), (t) => Color.lerp(t.light, t.main, .4)!),
    );
    _round(
      c,
      const Rect.fromLTWH(124, 173, 178, 31),
      14,
      _tint(const Color(0xFFD794AC), (t) => t.shade),
    );
    for (final x in const [114.0, 287.0]) {
      _round(
        c,
        Rect.fromLTWH(x, 159, 25, 48),
        12,
        _tint(const Color(0xFFE9AABD), (t) => t.main),
      );
    }
    _round(c, const Rect.fromLTWH(140, 201, 9, 13), 3, _PetHousePainter._ink);
    _round(c, const Rect.fromLTWH(276, 201, 9, 13), 3, _PetHousePainter._ink);
    // Kệ treo: đài nhạc là đồ vật, chậu hoa nhỏ đứng cuối kệ.
    _round(c, const Rect.fromLTWH(262, 70, 72, 8), 4, const Color(0xFFD6AF9D));
    _flower(c, const Offset(323, 48), 5, _PetHousePainter._rose);
    _round(c, const Rect.fromLTWH(316, 58, 15, 13), 5, _PetHousePainter._cream);
    _line(
      c,
      const Offset(323, 49),
      const Offset(323, 59),
      _PetHousePainter._mint,
      2,
    );
    _rug(c, const Offset(174, 263), 1.15, _PetHousePainter._cream);
  }

  void _livingFront(Canvas c) {
    final playingNow = playing && _active;
    final roll = playingNow
        ? math.pow(math.sin(progress * math.pi), 2).toDouble()
        : 0.0;
    final x = 282 - roll * 64;
    final y = 259 - roll * math.sin(progress * math.pi * 2).abs() * 16;
    _shadow(c, Rect.fromCenter(center: Offset(x, 274), width: 36, height: 8));
    c.save();
    c.translate(x, y);
    c.rotate(-.2 - roll * 3.5);
    _circle(c, Offset.zero, 18, const Color(0xFFFFD79A));
    final left = Path()
      ..moveTo(0, -18)
      ..quadraticBezierTo(-12, -1, 0, 18)
      ..quadraticBezierTo(-29, 12, -14, -11)
      ..close();
    _path(c, left, _PetHousePainter._rose);
    _path(
      c,
      Path()
        ..moveTo(0, -18)
        ..quadraticBezierTo(13, -2, 0, 18),
      _PetHousePainter._cream,
      width: 2,
    );
    _path(
      c,
      Path()
        ..moveTo(-17, -5)
        ..quadraticBezierTo(0, -9, 17, 4),
      _PetHousePainter._cream,
      width: 2,
    );
    _circle(c, const Offset(-7, -9), 4, Colors.white.withValues(alpha: .55));
    c.restore();
    _round(c, const Rect.fromLTWH(39, 258, 46, 12), 5, _PetHousePainter._lilac);
    _round(c, const Rect.fromLTWH(43, 254, 43, 6), 3, _PetHousePainter._cream);
    _star(c, const Offset(61, 250), 9, _PetHousePainter._gold);
    if (playingNow) {
      for (var i = 0; i < 5; i++) {
        _star(
          c,
          Offset(139 + i * 23, 178 - _pulse * 32 + (i.isEven ? -9 : 9)),
          3 + _pulse * 2,
          [
            _PetHousePainter._gold,
            _PetHousePainter._rose,
            _PetHousePainter._lilac,
          ][i % 3],
        );
      }
    }
  }

  void _kitchenBack(Canvas c, double extension) {
    // Ốp tường sau quầy bếp; tủ lạnh đứng riêng bên trái.
    _round(
      c,
      const Rect.fromLTWH(92, 118, 257, 68),
      5,
      dark ? const Color(0xFF526C64) : const Color(0xFFC8DFCE),
    );
    for (var i = 0; i < 6; i++) {
      _line(
        c,
        Offset(100 + i * 43.0, 119),
        Offset(100 + i * 43.0, 184),
        Colors.white.withValues(alpha: .4),
        1,
      );
    }
    _line(
      c,
      const Offset(94, 151),
      const Offset(348, 151),
      Colors.white.withValues(alpha: .4),
      1,
    );
    _shadow(c, const Rect.fromLTWH(92, 197, 252, 18));
    _round(
      c,
      const Rect.fromLTWH(96, 166, 243, 39),
      6,
      _tint(const Color(0xFF9FBDA8), (t) => t.shade),
    );
    for (var i = 0; i < 3; i++) {
      _round(
        c,
        Rect.fromLTWH(102 + i * 79.0, 172, 72, 27),
        5,
        _tint(const Color(0xFFC0D3B9), (t) => t.light),
      );
      _round(
        c,
        Rect.fromLTWH(130 + i * 79.0, 178, 16, 3),
        2,
        _PetHousePainter._cream,
      );
    }
    _round(
      c,
      const Rect.fromLTWH(92, 158, 254, 13),
      5,
      _PetHousePainter._cream,
    );
    if (_level > 0) {
      // Lò vi sóng nhỏ dưới cửa sổ.
      _round(
        c,
        const Rect.fromLTWH(170, 137, 31, 21),
        6,
        _PetHousePainter._lilac,
      );
      _round(
        c,
        const Rect.fromLTWH(174, 142, 22, 11),
        4,
        const Color(0xFF62566F),
      );
      _circle(c, const Offset(196, 155), 1.5, _PetHousePainter._cream);
    }
    if (_level > 1) {
      _jar(c, const Offset(239, 158), _PetHousePainter._mint, .85);
      _flower(c, const Offset(238, 129), 5, _PetHousePainter._gold);
    }
    if (_level > 2) {
      _bunting(c, 105, 15, 232);
    }
    _rug(c, const Offset(188, 263), .95, const Color(0xFFE7DFAF));
    // Ghế sau bé; phần bàn sẽ che chân đúng chiều sâu.
    _round(
      c,
      const Rect.fromLTWH(164, 203, 53, 40),
      16,
      const Color(0xFFD2AD91),
    );
    _round(
      c,
      const Rect.fromLTWH(174, 210, 33, 27),
      10,
      const Color(0xFFEBCDB1),
    );
    _round(
      c,
      const Rect.fromLTWH(163, 243, 56, 13),
      5,
      const Color(0xFFBC947E),
    );
  }

  void _kitchenFront(Canvas c) {
    _shadow(c, const Rect.fromLTWH(102, 277, 181, 15));
    for (final x in const [126.0, 248.0]) {
      _round(c, Rect.fromLTWH(x, 244, 10, 40), 4, const Color(0xFFB18B7B));
    }
    _round(
      c,
      const Rect.fromLTWH(113, 230, 160, 25),
      9,
      const Color(0xFFCBA58C),
    );
    _round(
      c,
      const Rect.fromLTWH(105, 219, 177, 24),
      12,
      const Color(0xFFFFEDD0),
    );
    // Bàn cho hai: đĩa của bé mình có món đang chọn, đĩa bé kia để trống.
    final plate = _PetCareSceneState.plateFor(selectedPet);
    final partnerPlate = Offset(_partnerPosition.dx + 2, 228);
    _plate(c, partnerPlate);
    _plate(c, plate);
    final mid = (plate.dx + partnerPlate.dx) / 2;
    _round(
      c,
      Rect.fromLTWH(mid - 6.5, 211, 13, 17),
      4,
      const Color(0xFFB8D5D7),
    );
    _path(
      c,
      Path()
        ..moveTo(mid + 6.5, 214)
        ..quadraticBezierTo(mid + 16.5, 212, mid + 14.5, 220)
        ..quadraticBezierTo(mid + 12.5, 225, mid + 6.5, 222),
      _PetHousePainter._cream,
      width: 2,
    );
    final onPlate = plate + const Offset(0, -17);
    if (action == PetCareAction.feed && _active && !walking) {
      final reach = Curves.easeOutCubic.transform((progress / .36).clamp(0, 1));
      final mouth = _mouth;
      final point = Offset.lerp(feedFrom ?? onPlate, mouth, reach)!;
      final remaining = progress < .48
          ? 1.0
          : progress < .68
          ? .72
          : .42;
      if (progress < .86) {
        c.save();
        c.translate(point.dx, point.dy);
        c.rotate(-.18 + math.sin(progress * math.pi * 8) * .08 * _careEnvelope);
        _food(c, food, Offset.zero, .8 * remaining, bitten: progress > .48);
        c.restore();
      }
      // Hai nhịp cắn rõ, vụn rơi ngắn rồi lóe sao khi ăn xong.
      for (var bite = 0; bite < 2; bite++) {
        final t = ((progress - .46 - bite * .22) / .22).clamp(0.0, 1.0);
        if (t <= 0 || t >= 1) continue;
        for (var i = 0; i < 5; i++) {
          final side = i.isEven ? -1.0 : 1.0;
          _circle(
            c,
            mouth +
                Offset(
                  side * (8 + t * (16 + i * 3)),
                  -8 * math.sin(t * math.pi) + t * 26 + i * 2,
                ),
            (2.8 - t * 2).clamp(.5, 3),
            _PetHousePainter._gold.withValues(alpha: 1 - t),
          );
        }
      }
      if (progress > .8) {
        final t = ((progress - .8) / .2).clamp(0.0, 1.0);
        for (var i = 0; i < 4; i++) {
          _star(
            c,
            mouth + Offset((i - 1.5) * 22, -28 - t * 28 + i % 2 * 9),
            3 + math.sin(t * math.pi) * 3,
            _PetHousePainter._gold.withValues(alpha: 1 - t),
          );
        }
      }
    } else if (!(dragTool == PetCareTool.food && dragFood == food)) {
      // Món nảy nhẹ mỗi lúc để gợi ý: nhấc món trên đĩa kéo tới miệng bé.
      _food(c, food, onPlate - Offset(0, _invite(1.4) * 5), .76);
    }
    if (_level > 0) {
      final vase = Offset(mid, 205);
      _flower(c, vase, 4, _PetHousePainter._rose);
      _round(
        c,
        Rect.fromLTWH(vase.dx - 5.5, vase.dy + 6, 11, 12),
        4,
        _PetHousePainter._mint,
      );
      _line(
        c,
        vase + const Offset(0, 2),
        vase + const Offset(0, 8),
        _PetHousePainter._mint,
        2,
      );
    }
  }

  void _plate(Canvas c, Offset center) {
    _oval(
      c,
      Rect.fromCenter(
        center: center + const Offset(0, 1.5),
        width: 74,
        height: 16,
      ),
      const Color(0xFFEED5BC),
    );
    _oval(
      c,
      Rect.fromCenter(center: center, width: 58, height: 13),
      _PetHousePainter._cream,
    );
    _oval(
      c,
      Rect.fromCenter(
        center: center + const Offset(0, 1),
        width: 42,
        height: 7,
      ),
      const Color(0xFFD9C8D7),
    );
  }

  /// Nhịp nảy mời gọi (0 → 1 → 0) mỗi ~3 giây khi bé đang rảnh.
  double _invite(double offset) {
    if (!actionable || _active || walking || dragTool != null) return 0;
    final phase = ((seconds + offset) % 3.2) / 3.2;
    return phase < .16 ? math.sin(phase / .16 * math.pi) : 0;
  }

  void _bathroomBack(Canvas c, double extension) {
    // Vòi sen gắn tường và kệ xà phòng cạnh bồn.
    _line(
      c,
      const Offset(285, 81),
      const Offset(285, 193),
      const Color(0xFF97BAB7),
      6,
    );
    _path(
      c,
      Path()
        ..moveTo(285, 85)
        ..quadraticBezierTo(286, 65, 266, 67)
        ..lineTo(251, 67),
      _PetHousePainter._gold,
      width: 5,
    );
    c.save();
    c.translate(251, 72);
    c.rotate(.2);
    _round(c, const Rect.fromLTWH(-13, -4, 26, 9), 4, const Color(0xFFB79B82));
    _round(c, const Rect.fromLTWH(-12, 3, 24, 4), 2, _PetHousePainter._cream);
    c.restore();
    _circle(c, const Offset(285, 153), 7, _PetHousePainter._cream);
    _line(
      c,
      const Offset(281, 153),
      const Offset(289, 153),
      _PetHousePainter._gold,
      2,
    );
    _round(
      c,
      const Rect.fromLTWH(100, 212, 189, 39),
      19,
      _tint(const Color(0xFF94C1BD), (t) => t.shade),
    );
    _oval(c, const Rect.fromLTWH(105, 202, 179, 39), _PetHousePainter._cream);
    _oval(c, const Rect.fromLTWH(114, 208, 161, 29), const Color(0xFF90C4CD));
    _oval(c, const Rect.fromLTWH(119, 211, 151, 17), const Color(0xFFBCE4E4));
    _oval(
      c,
      const Rect.fromLTWH(117, 266, 164, 19),
      _PetHousePainter._lilac.withValues(alpha: .42),
    );
    for (var i = 0; i < 7; i++) {
      _line(
        c,
        Offset(135 + i * 20.0, 270),
        Offset(137 + i * 20.0, 278),
        _PetHousePainter._cream.withValues(alpha: .45),
        1,
      );
    }
    _round(
      c,
      const Rect.fromLTWH(303, 207, 34, 16),
      5,
      const Color(0xFFB6A4C3),
    );
    _round(
      c,
      const Rect.fromLTWH(306, 199, 29, 10),
      5,
      _PetHousePainter._cream,
    );
    _sponge(c, const Offset(79, 232), .6);
    if (_level > 0) {
      _plant(c, const Offset(330, 80), .45);
      _round(
        c,
        const Rect.fromLTWH(308, 80, 35, 6),
        3,
        const Color(0xFFD5B7A3),
      );
    }
    if (_level > 1) {
      _round(
        c,
        const Rect.fromLTWH(18, 236, 61, 30),
        9,
        const Color(0xFFE3D8BA),
      );
      for (var i = 0; i < 3; i++) {
        _round(
          c,
          Rect.fromLTWH(24, 230 + i * 7.0, 48, 8),
          4,
          [
            _PetHousePainter._cream,
            _PetHousePainter._mint,
            _PetHousePainter._rose,
          ][i],
        );
      }
    }
    if (_level > 2) {
      _star(c, const Offset(113, 83), 8, _PetHousePainter._gold);
      _star(c, const Offset(225, 124), 5, _PetHousePainter._gold);
    }
  }

  void _bathroomFront(Canvas c) {
    final step = bathStage == 3 ? 0 : bathStage;
    // Xà phòng nằm trên kệ: bước xoa xà phòng thì nảy nhẹ mời kéo.
    if (dragTool != PetCareTool.soap) {
      _soap(c, Offset(321, 199 - (step == 0 ? _invite(.6) * 5 : 0)), .62);
    }
    // Bước xả nước: vòi sen nhỏ giọt gợi ý kéo vòi tới bé.
    if (step == 1 && dragTool != PetCareTool.shower && !_active) {
      for (var i = 0; i < 3; i++) {
        final t = (seconds * .9 + i / 3) % 1;
        _oval(
          c,
          Rect.fromCenter(
            center: Offset(246 + i * 4.0, 82 + t * 26),
            width: 2.6,
            height: 4,
          ),
          const Color(0xFF9FD8E6).withValues(alpha: 1 - t),
        );
      }
    }
    if (_inBath &&
        (bathStage == 1 ||
            bathStage == 2 ||
            action == PetCareAction.bath && _active)) {
      final rinsing = bathStage == 2;
      if (rinsing) {
        for (var i = 0; i < 13; i++) {
          final t = (time * 5 + i * .083) % 1;
          final x = 240 + i % 5 * 4.0 - t * 26;
          final y = 85 + t * 142;
          if (look.shower == PetCareStyle.showerPetal) {
            _heart(c, Offset(x, y), 3.2, _water(i).withValues(alpha: .85));
          } else {
            _line(
              c,
              Offset(x, y),
              Offset(x - 2, y + 8),
              (look.shower == PetCareStyle.showerClassic
                      ? const Color(0xFFB4E9F1)
                      : _water(i))
                  .withValues(alpha: .75),
              2,
            );
          }
        }
      }
      for (
        var i = 0;
        i <
            (rinsing
                ? 9
                : foam.isEmpty
                ? 23
                : 10);
        i++
      ) {
        final phase = (time * 1.5 + i * .079) % 1;
        final x =
            146 + (i * 31 % 108).toDouble() + math.sin(phase * math.pi * 2) * 4;
        final y = 235 - phase * (rinsing ? 68 : 83);
        _bubble(c, Offset(x, y), 5 + i % 4 * 2.0, .65);
      }
      // Bọt biển chỉ xuất hiện lúc đang chà, không nằm đè mặt bé khi chờ xả.
      if (!rinsing && _active && action == PetCareAction.bath) {
        _sponge(
          c,
          Offset(
            212 + math.sin(progress * math.pi * 6) * 12 * _careEnvelope,
            191 + math.sin(progress * math.pi * 4) * 5 * _careEnvelope,
          ),
          .72,
        );
      }
      if (!rinsing && foam.isEmpty) {
        _bubble(c, const Offset(184, 158), 8, .9);
        _bubble(c, const Offset(195, 157), 6, .9);
        _bubble(c, const Offset(176, 161), 5, .9);
      }
    }
    // Thành bồn che chân, không che mặt và biểu cảm.
    _shadow(c, const Rect.fromLTWH(111, 260, 177, 15));
    for (final x in const [126.0, 255.0]) {
      _round(
        c,
        Rect.fromLTWH(x, 252, 10, 17),
        4,
        _tint(const Color(0xFF8BAFAC), (t) => t.shade),
      );
    }
    _round(
      c,
      const Rect.fromLTWH(105, 227, 183, 35),
      18,
      _tint(const Color(0xFF9DCFC6), (t) => t.main),
    );
    _round(
      c,
      const Rect.fromLTWH(113, 233, 166, 22),
      11,
      _tint(const Color(0xFFBDE3D7), (t) => t.light),
    );
    _round(
      c,
      const Rect.fromLTWH(99, 223, 194, 11),
      5.5,
      _PetHousePainter._cream,
    );
    _heart(
      c,
      const Offset(198, 245),
      7,
      _tint(const Color(0xFF8DBBB3), (t) => t.shade),
    );
    _propDuck(c);
    if (bathStage == 3 && _inBath && action == PetCareAction.bath && _active) {
      final x = 191 + math.sin(progress * math.pi * 7) * 17 * _careEnvelope;
      final y = 195 + math.sin(progress * math.pi * 4) * 6 * _careEnvelope;
      c.save();
      c.translate(x, y);
      c.rotate(math.sin(progress * math.pi * 6) * .12);
      _round(
        c,
        const Rect.fromLTWH(-31, -13, 62, 27),
        9,
        const Color(0xFFFFF5DF),
      );
      _round(c, const Rect.fromLTWH(-29, 5, 58, 5), 2, _PetHousePainter._rose);
      _line(
        c,
        const Offset(-21, -7),
        const Offset(21, -7),
        _PetHousePainter._gold.withValues(alpha: .5),
        2,
      );
      c.restore();
    }
    if (bathStage == 3 && _inBath) {
      for (var i = 0; i < 5; i++) {
        _star(
          c,
          Offset(145 + i * 25, 174 - (i.isOdd ? 33 : 0) + _wave * 3),
          4.5,
          _PetHousePainter._gold,
        );
      }
    }
    if (_inBath && bathStage == 0 && vitals.isDirty) {
      _oval(
        c,
        const Rect.fromLTWH(172, 221, 40, 4),
        const Color(0xFFB19977).withValues(alpha: .38),
      );
    }
  }

  /// Giường nhìn ngang như My Talking Tom: đầu giường bên phải cạnh tủ đèn
  /// ngủ, mặt nệm và gối nằm sau lưng bé; thành trước/chăn ở lớp trước.
  void _bedroomBack(Canvas c, double extension) {
    final frame = _tint(const Color(0xFFC6A4B0), (t) => t.main);
    final panel = _tint(const Color(0xFFDCC2CC), (t) => t.light);
    _shadow(c, const Rect.fromLTWH(60, 252, 232, 20));
    // Đầu giường cao, bo tròn, có nút bọc nệm.
    final head = RRect.fromRectAndCorners(
      const Rect.fromLTRB(258, 128, 288, 262),
      topLeft: const Radius.circular(15),
      topRight: const Radius.circular(15),
      bottomLeft: const Radius.circular(4),
      bottomRight: const Radius.circular(4),
    );
    c.drawRRect(head, Paint()..color = frame);
    c.drawRRect(
      head.deflate(5).shift(const Offset(0, 2)),
      Paint()..color = panel,
    );
    for (var i = 0; i < 4; i++) {
      _circle(
        c,
        Offset(273, 150 + i * 18.0),
        2.2,
        _PetHousePainter._cream.withValues(alpha: .8),
      );
    }
    _circle(c, const Offset(273, 126), 6, frame);
    _circle(c, const Offset(271.5, 124.5), 2, panel);
    // Mặt nệm nhìn hơi từ trên xuống: bé nằm lên dải này.
    _round(
      c,
      const Rect.fromLTRB(84, 200, 262, 224),
      11,
      const Color(0xFFFFF6EA),
    );
    _line(
      c,
      const Offset(94, 203),
      const Offset(254, 203),
      Colors.white.withValues(alpha: .7),
      1.4,
    );
    // Gối ở đầu giường, đầu bé tựa lên.
    _round(
      c,
      Rect.fromCenter(center: const Offset(240, 206), width: 66, height: 28),
      13,
      const Color(0xFFFFE6C8),
    );
    _round(
      c,
      Rect.fromCenter(center: const Offset(241, 203), width: 56, height: 18),
      9,
      _PetHousePainter._cream,
    );
    _rug(c, const Offset(186, 288), .85, const Color(0xFFC7B6D9));
    if (_level > 1) {
      _plant(c, const Offset(36, 222), .82);
    }
    if (_level > 2) {
      _bunting(c, 150, 112, 250);
      _heart(c, const Offset(273, 141), 5, _PetHousePainter._rose);
    }
  }

  /// Chăn bông phủ theo dáng người bé nằm. [cover] của từng bé đi từ 0
  /// (chăn gấp gọn ở chân giường) tới 1 (kéo lên ngang cằm) để chăn trượt
  /// lên thật sự thay vì mờ dần làm lộ người bé bên dưới.
  void _blanket(Canvas c) {
    final quilt = _tint(
      _level > 1 ? const Color(0xFFA4C5B6) : const Color(0xFFB6A3CF),
      (t) => t.main,
    );
    final fold = _tint(
      _level > 1 ? const Color(0xFFC4DECA) : const Color(0xFFD4C4E5),
      (t) => t.light,
    );
    const foot = 86.0;
    const rest = 207.0;
    const folded = 152.0;
    const front = 222.0;
    // Mỗi bé: dáng lưng (mép trên chăn) và mép gấp chạy chéo theo cổ.
    final covers = <(double Function(double), Offset, Offset)>[];
    void add(PetCarePet pet, Offset feet, double cover, double phase) {
      if (cover <= 0) return;
      final lift = Offset(0, -4 - (math.sin(seconds * 1.6 + phase) + 1) * .9);
      Offset at(double x, double y) =>
          feet + _PetHousePainter._lyingOffset(pet, Offset(x, y)) + lift;
      // Ngón chân → hông → lưng → vai → gáy.
      final points = [
        at(-14, 6) - const Offset(34, 0),
        at(-14, 6),
        at(-21, -6),
        at(-22, -20),
        at(-21, -31),
        at(-23, -34),
      ];
      points[0] = Offset(points[0].dx, rest);
      double mound(double x) {
        if (x <= points.first.dx || x >= points.last.dx) {
          return x >= points.last.dx ? points.last.dy : rest;
        }
        for (var i = 0; i < points.length - 1; i++) {
          final a = points[i];
          final b = points[i + 1];
          if (x > b.dx) continue;
          final t = (x - a.dx) / math.max(1, b.dx - a.dx);
          return math.min(
            rest,
            a.dy + (b.dy - a.dy) * (1 - math.cos(t * math.pi)) / 2,
          );
        }
        return rest;
      }

      final hx = folded + (points.last.dx - folded) * cover;
      final top = Offset(hx, mound(hx));
      final bottom = Offset.lerp(Offset(hx + 4, front), at(17, -33), cover)!;
      covers.add((mound, top, bottom));
    }

    if (_partnerSleeping) {
      add(
        _partner,
        _PetHousePainter._sleepFeet(_partner, _partnerBoth),
        1,
        _partner == PetCarePet.rabbit ? 0 : 1.7,
      );
    }
    add(
      selectedPet,
      _PetHousePainter._sleepFeet(selectedPet, _mineBoth),
      _coverProgress,
      selectedPet == PetCarePet.rabbit ? 0 : 1.7,
    );
    // Chưa ai ngủ: chăn gấp gọn ở chân giường.
    if (covers.isEmpty) {
      covers.add((
        (_) => rest,
        const Offset(folded, rest),
        const Offset(folded + 4, front),
      ));
    }
    double contour(double x) {
      var y = rest;
      for (final (mound, top, bottom) in covers) {
        if (x <= top.dx) {
          y = math.min(y, mound(x));
        } else if (x <= bottom.dx) {
          final t = (x - top.dx) / math.max(1, bottom.dx - top.dx);
          y = math.min(y, top.dy + (bottom.dy - top.dy) * t);
        }
      }
      return y;
    }

    var end = folded + 4;
    for (final cover in covers) {
      end = math.max(end, cover.$3.dx);
    }
    final path = Path()..moveTo(foot - 4, contour(foot) + 4);
    for (var x = foot; x < end; x += 2.5) {
      path.lineTo(x, contour(x));
    }
    path
      ..lineTo(end, math.min(front, contour(end)))
      ..lineTo(end, 250);
    // Mép dưới rủ qua thành nệm, lượn sóng mềm.
    final width = end - (foot - 4);
    final waves = math.max(3, (width / 26).round());
    for (var i = 0; i < waves; i++) {
      final x0 = end - width * i / waves;
      final x1 = end - width * (i + 1) / waves;
      path.quadraticBezierTo((x0 + x1) / 2, 258, x1, 250);
    }
    path.close();
    _path(c, path, quilt);
    c.save();
    c.clipPath(path);
    for (var row = 0; row < 3; row++) {
      for (var col = 0; col < 9; col++) {
        final p = Offset(
          100 + col * 22.0 + (row.isOdd ? 11 : 0),
          198 + row * 18.0,
        );
        if (p.dx > end - 14) continue;
        _star(c, p, 3.2, _PetHousePainter._cream.withValues(alpha: .55));
      }
    }
    // Bóng mềm phía dưới để chăn có khối.
    c.drawRect(
      const Rect.fromLTRB(60, 238, 300, 262),
      Paint()..color = const Color(0xFF5E4C74).withValues(alpha: .12),
    );
    // Mép gấp ở cằm chạy chéo theo cổ bé.
    for (final (_, top, bottom) in covers) {
      _line(c, top, bottom, fold, 11);
      _line(
        c,
        top + const Offset(-4, 1),
        bottom + const Offset(-4, 0),
        Colors.white.withValues(alpha: .35),
        1.4,
      );
    }
    c.restore();
    final rim = Path()..moveTo(foot, contour(foot) + 1.5);
    for (var x = foot; x < end - 6; x += 2.5) {
      rim.lineTo(x, contour(x) + 1.5);
    }
    _path(c, rim, Colors.white.withValues(alpha: .42), width: 1.4);
  }

  /// Thành nệm, khung và chân giường đứng trước bé đang ngủ; chăn rủ qua.
  void _bedroomFront(Canvas c) {
    final frame = _tint(const Color(0xFFC6A4B0), (t) => t.main);
    final shade = _tint(const Color(0xFFB78F9D), (t) => t.shade);
    _round(
      c,
      const Rect.fromLTRB(82, 216, 262, 248),
      11,
      const Color(0xFFF4E4D3),
    );
    for (var x = 96.0; x < 252; x += 9) {
      _line(
        c,
        Offset(x, 233),
        Offset(x + 4, 233),
        const Color(0xFFDCC5B4),
        1.2,
      );
    }
    _round(c, const Rect.fromLTRB(70, 242, 286, 256), 6, shade);
    _blanket(c);
    for (final x in const [80.0, 266.0]) {
      _round(c, Rect.fromLTWH(x, 254, 11, 14), 3, shade);
    }
    // Thành chân giường thấp bên trái.
    final foot = RRect.fromRectAndCorners(
      const Rect.fromLTRB(62, 178, 86, 262),
      topLeft: const Radius.circular(12),
      topRight: const Radius.circular(12),
      bottomLeft: const Radius.circular(4),
      bottomRight: const Radius.circular(4),
    );
    c.drawRRect(foot, Paint()..color = frame);
    c.drawRRect(
      foot.deflate(5).shift(const Offset(0, 2)),
      Paint()..color = _tint(const Color(0xFFDCC2CC), (t) => t.light),
    );
    _heart(c, const Offset(74, 202), 4.5, _PetHousePainter._cream);
    _circle(c, const Offset(74, 176), 5.5, frame);
  }

  /// Tắt đèn khi bé ngủ: phòng tối xanh đêm, chỉ còn ánh trăng qua cửa sổ
  /// rọi lên giường, sao trên trần và chữ "z" bay lên từ đầu bé.
  void _nightOverlay(Canvas c, double extension, double floorExtension) {
    final mine = _inBed ? _PetHousePainter._phase(sleepBlend, .3, 1) : 0.0;
    // Chỉ bé kia ngủ: phòng hơi tối, đèn ngủ vẫn sáng cho bé mình chơi.
    final level = math.max(mine, _partnerSleeping ? .55 : 0.0);
    if (level <= .001) return;
    final rect = Rect.fromLTWH(
      0,
      -extension - 4,
      360,
      308 + extension + floorExtension,
    );
    c.drawRect(
      rect,
      Paint()..color = _night.withValues(alpha: (dark ? .66 : .8) * level),
    );
    final window = Offset(82, 84 - extension * .42);
    final moon = mine;
    // Quầng trăng ở cửa sổ và vệt sáng chéo rọi xuống giường.
    c.drawCircle(
      window,
      78,
      Paint()
        ..blendMode = BlendMode.plus
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFB9C4FF).withValues(alpha: .3 * level),
            const Color(0x00B9C4FF),
          ],
        ).createShader(Rect.fromCircle(center: window, radius: 78)),
    );
    if (moon > .01) {
      const bed = Offset(186, 214);
      c.drawOval(
        Rect.fromCenter(center: bed, width: 250, height: 120),
        Paint()
          ..blendMode = BlendMode.plus
          ..shader = RadialGradient(
            colors: [
              const Color(0xFFAFC0FF).withValues(alpha: .13 * moon),
              const Color(0x00AFC0FF),
            ],
          ).createShader(Rect.fromCenter(center: bed, width: 250, height: 120)),
      );
    }
    // Đèn ngủ còn bật khi chỉ bé kia ngủ.
    if (!vitals.sleeping) {
      const lamp = Offset(308, 146);
      c.drawCircle(
        lamp,
        64,
        Paint()
          ..blendMode = BlendMode.plus
          ..shader = RadialGradient(
            colors: [
              const Color(0xFFFFD99A).withValues(alpha: .3 * level),
              const Color(0x00FFD99A),
            ],
          ).createShader(Rect.fromCircle(center: lamp, radius: 64)),
      );
    }
    final heads = [
      if (_coverProgress > .5)
        _PetHousePainter._sleepHead(selectedPet, _mineBoth),
      if (_partnerSleeping) _PetHousePainter._sleepHead(_partner, _partnerBoth),
    ];
    for (var s = 0; s < heads.length; s++) {
      final head = heads[s] + const Offset(18, -50);
      for (var i = 0; i < 3; i++) {
        final phase = (seconds * .3 + i / 3 + s * .17) % 1;
        _zee(
          c,
          head + Offset(phase * 24 + i * 3, -phase * 44),
          6 + phase * 6,
          Colors.white.withValues(alpha: math.sin(phase * math.pi) * .92),
        );
      }
    }
    // Sao lấp lánh nhẹ trên trần khi tắt đèn.
    for (var i = 0; i < 9; i++) {
      final twinkle = (math.sin(seconds * 2 + i * 1.9) + 1) / 2;
      _star(
        c,
        Offset(24 + i * 40.0, 16 + (i.isOdd ? 30 : 0) - extension * .3),
        2 + twinkle * 1.8,
        const Color(0xFFFFE9B0).withValues(alpha: (.3 + twinkle * .6) * level),
      );
    }
  }
}
