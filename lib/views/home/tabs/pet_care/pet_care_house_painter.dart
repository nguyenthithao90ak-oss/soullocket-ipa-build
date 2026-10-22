part of 'pet_care_scene.dart';

enum _PetHouseLayer { background, foreground }

/// Décor vector theo lớp: tường → nội thất sau → bé → đồ dùng phía trước.
/// Không chèn chữ vào artwork để nhãn hỗ trợ đủ ngôn ngữ ở màn cha.
class _PetHousePainter extends CustomPainter {
  const _PetHousePainter({
    required this.motion,
    required this.layer,
    required this.seconds,
    required this.strideCycles,
    required this.walkWeight,
    required this.sleepBlend,
    required this.room,
    required this.selectedPet,
    required this.partnerVitals,
    required this.food,
    required this.upgrades,
    required this.vitals,
    required this.time,
    required this.progress,
    required this.action,
    required this.decoration,
    required this.small,
    required this.fillRoom,
    required this.dark,
    required this.position,
    required this.walking,
    required this.walkProgress,
    required this.facingRight,
    required this.playing,
    required this.bathStage,
    required this.touch,
    required this.actionable,
  });

  final _PetSceneMotion motion;
  final _PetHouseLayer layer;
  final double seconds;
  final double strideCycles;
  final double walkWeight;
  final double sleepBlend;
  final PetCareRoom room;
  final PetCarePet selectedPet;
  final PetCareVitals partnerVitals;
  final PetCareFood food;
  final Map<PetCareUpgrade, int> upgrades;
  final PetCareVitals vitals;
  final double time;
  final double progress;
  final PetCareAction? action;
  final PetCareDecor? decoration;
  final bool small;
  final bool fillRoom;
  final bool dark;
  final Offset position;
  final bool walking;
  final double walkProgress;
  final bool facingRight;
  final bool playing;
  final int bathStage;
  final Offset? touch;
  final bool actionable;

  static const _ink = Color(0xFF856C7A);
  static const _cream = Color(0xFFFFF8E8);
  static const _mint = Color(0xFFABD5C3);
  static const _rose = Color(0xFFECA6B9);
  static const _lilac = Color(0xFFB9A7D9);
  static const _gold = Color(0xFFE7BC78);
  double get _wave => math.sin(time * math.pi * 2);
  double get _pulse => math.sin(progress * math.pi);
  double get _careEnvelope => Curves.easeInOutSine.transform(
    math.min(progress / .2, (1 - progress) / .22).clamp(0, 1),
  );
  bool get _active => progress > 0 && progress < 1;
  bool get _inPlace =>
      !walking &&
      (position - _PetCareSceneState._destination(room)).distance < 12;
  bool get _inBath => room == PetCareRoom.bathroom && _inPlace;
  bool get _inBed =>
      room == PetCareRoom.bedroom && sleepBlend > .001 && !walking;
  int get _level => switch (room) {
    PetCareRoom.living => 0,
    PetCareRoom.kitchen => upgrades[PetCareUpgrade.kitchen] ?? 0,
    PetCareRoom.bathroom => upgrades[PetCareUpgrade.bathroom] ?? 0,
    PetCareRoom.bedroom => upgrades[PetCareUpgrade.bedroom] ?? 0,
  };

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    final viewport = _PetCareViewport(size, fillRoom: fillRoom);
    final extension = viewport.wallExtension;
    final floorExtension = fillRoom ? 52.0 : 0.0;
    canvas.scale(viewport.scaleX, viewport.scaleY);
    canvas.translate(0, extension);
    canvas.clipRect(
      Rect.fromLTWH(0, -extension, 360, 300 + extension + floorExtension),
    );
    if (layer == _PetHouseLayer.background) {
      _shell(canvas, extension, floorExtension);
      switch (room) {
        case PetCareRoom.living:
          _livingBack(canvas, extension);
        case PetCareRoom.kitchen:
          _kitchenBack(canvas, extension);
        case PetCareRoom.bathroom:
          _bathroomBack(canvas, extension);
        case PetCareRoom.bedroom:
          _bedroomBack(canvas, extension);
      }
      _decoration(canvas);
      canvas.restore();
      return;
    }
    if (touch != null && walking) {
      _oval(
        canvas,
        Rect.fromCenter(center: touch!, width: 29, height: 10),
        _lilac.withValues(alpha: .25),
      );
      _oval(
        canvas,
        Rect.fromCenter(center: touch!, width: 14, height: 5),
        _cream.withValues(alpha: .9),
      );
    }
    // Hai bé luôn ở chung một căn nhà. Chỉ bé đang thuộc vai người dùng
    // mới nhận lệnh đi/chăm; bé còn lại vẫn hiện diện và có mood riêng.
    _partnerPet(canvas);
    _pet(canvas);
    switch (room) {
      case PetCareRoom.living:
        _livingFront(canvas);
      case PetCareRoom.kitchen:
        _kitchenFront(canvas);
      case PetCareRoom.bathroom:
        _bathroomFront(canvas);
      case PetCareRoom.bedroom:
        _bedroomFront(canvas);
    }
    _affection(canvas);
    if (actionable &&
        !small &&
        !walking &&
        !(_active || playing || bathStage == 1 || bathStage == 2)) {
      final point = switch (room) {
        PetCareRoom.living => const Offset(299, 228),
        PetCareRoom.kitchen => const Offset(257, 201),
        PetCareRoom.bathroom => const Offset(276, 213),
        PetCareRoom.bedroom => const Offset(270, 207),
      };
      _circle(
        canvas,
        point,
        12 + _wave * .7,
        Colors.white.withValues(alpha: .85),
      );
      _circle(canvas, point, 8, _lilac);
      _path(
        canvas,
        Path()
          ..moveTo(point.dx - 3, point.dy)
          ..lineTo(point.dx + 3, point.dy)
          ..moveTo(point.dx, point.dy - 3)
          ..lineTo(point.dx, point.dy + 3),
        Colors.white,
        width: 1.7,
      );
    }
    canvas.restore();
  }

  void _shell(Canvas c, double extension, double floorExtension) {
    final wall = switch (room) {
      PetCareRoom.living => const Color(0xFFF7E3E8),
      PetCareRoom.kitchen => const Color(0xFFEAF0DA),
      PetCareRoom.bathroom => const Color(0xFFE1F1EF),
      PetCareRoom.bedroom => const Color(0xFFECE5F6),
    };
    final wallDark = switch (room) {
      PetCareRoom.living => const Color(0xFF493746),
      PetCareRoom.kitchen => const Color(0xFF38473F),
      PetCareRoom.bathroom => const Color(0xFF35474D),
      PetCareRoom.bedroom => const Color(0xFF37354F),
    };
    _gradient(c, Rect.fromLTWH(0, -extension, 360, 206 + extension), [
      dark ? wallDark : wall,
      dark ? wallDark.withValues(alpha: .92) : _cream,
    ]);
    if (room == PetCareRoom.bathroom) {
      for (var row = (-extension / 42).floor(); row < 5; row++) {
        for (var col = 0; col < 9; col++) {
          final r = Rect.fromLTWH(
            col * 44 - (row.isOdd ? 22 : 0),
            row * 42 - 9,
            42,
            40,
          );
          _round(
            c,
            r,
            5,
            (row + col).isEven
                ? Colors.white.withValues(alpha: dark ? .035 : .42)
                : _mint.withValues(alpha: .11),
          );
          if ((row + col) % 5 == 0) {
            _diamond(c, r.center, 3, _mint.withValues(alpha: .35));
          }
        }
      }
    } else {
      for (var row = (-extension / 39).floor(); row < 5; row++) {
        for (var col = 0; col < 10; col++) {
          final p = Offset(col * 39 + (row.isOdd ? 17 : 0), row * 39 + 14);
          if (room == PetCareRoom.bedroom) {
            _star(c, p, 2.7, _lilac.withValues(alpha: dark ? .14 : .24));
          } else if (room == PetCareRoom.kitchen) {
            _path(
              c,
              Path()
                ..moveTo(p.dx - 3, p.dy)
                ..lineTo(p.dx, p.dy + 3)
                ..lineTo(p.dx + 3, p.dy),
              _mint.withValues(alpha: .3),
              width: 1.2,
            );
          } else {
            _flower(c, p, 2.2, _rose.withValues(alpha: dark ? .16 : .22));
          }
        }
      }
    }
    final floor = room == PetCareRoom.bathroom
        ? const Color(0xFFB5D5D0)
        : const Color(0xFFE7C7AA);
    _gradient(c, Rect.fromLTWH(0, 194, 360, 106 + floorExtension), [
      dark ? const Color(0xFF5D535A) : floor,
      dark ? const Color(0xFF433D4C) : const Color(0xFFF4DEBF),
    ]);
    _round(
      c,
      const Rect.fromLTWH(-2, 188, 364, 12),
      3,
      dark ? const Color(0xFF65525E) : _cream,
    );
    _line(
      c,
      const Offset(0, 201),
      const Offset(360, 201),
      dark ? const Color(0xFF443D47) : const Color(0xFFCDAF9C),
      2,
    );
    if (room == PetCareRoom.bathroom) {
      for (var i = -3; i < 10; i++) {
        _line(
          c,
          Offset(i * 53, 199),
          Offset(i * 53 + 60 + floorExtension * .6, 300 + floorExtension),
          Colors.white.withValues(alpha: .25),
          1,
        );
      }
      for (var y = 224.0; y < 300 + floorExtension; y += 34) {
        _line(
          c,
          Offset(0, y),
          Offset(360, y),
          Colors.white.withValues(alpha: .28),
          1,
        );
      }
    } else {
      for (var row = 0; row < 4 + (floorExtension / 26).ceil(); row++) {
        final y = 208 + row * 26.0;
        _line(
          c,
          Offset(0, y),
          Offset(360, y),
          const Color(0xFFB58E7F).withValues(alpha: .23),
          1,
        );
        for (var col = 0; col < 5; col++) {
          final x = col * 84 + (row.isOdd ? 36.0 : 0.0);
          _line(
            c,
            Offset(x, y),
            Offset(x, y + 26),
            const Color(0xFFB58E7F).withValues(alpha: .17),
            1,
          );
          _path(
            c,
            Path()
              ..moveTo(x + 12, y + 12)
              ..quadraticBezierTo(x + 27, y + 7, x + 42, y + 11),
            const Color(0xFFC29A84).withValues(alpha: .2),
            width: .7,
          );
        }
      }
    }
    _oval(
      c,
      const Rect.fromLTWH(34, 259, 300, 42),
      Colors.white.withValues(alpha: dark ? .02 : .08),
    );
  }

  void _window(
    Canvas c, {
    bool night = false,
    double x = 40,
    double y = 37,
    double width = 77,
    double height = 103,
  }) {
    c.save();
    c.translate(x + width / 2, y + height / 2);
    c.rotate(-.055);
    final rect = Rect.fromCenter(
      center: Offset.zero,
      width: width,
      height: height,
    );
    _round(c, rect.shift(const Offset(2, 4)), 29, _ink.withValues(alpha: .1));
    _round(c, rect, 29, _cream);
    final pane = rect.deflate(7);
    c.save();
    c.clipRRect(RRect.fromRectAndRadius(pane, const Radius.circular(23)));
    _gradient(
      c,
      pane,
      night || dark
          ? const [Color(0xFF6E79A3), Color(0xFFB4ABC9)]
          : const [Color(0xFFA9D4E0), Color(0xFFE4F1E1)],
    );
    if (night || dark) {
      _circle(c, const Offset(12, -23), 13, const Color(0xFFFFE5A3));
      _circle(c, const Offset(17, -27), 11, const Color(0xFF8790B4));
      for (final p in [
        const Offset(-21, -24),
        const Offset(22, 12),
        const Offset(-14, 4),
      ]) {
        _star(c, p, 2.5, _cream);
      }
    } else {
      _circle(c, const Offset(18, -26), 14, const Color(0xFFFFE6AA));
      _cloud(
        c,
        Offset(-12 + _wave * 3, 1),
        .55,
        Colors.white.withValues(alpha: .85),
      );
      _cloud(
        c,
        Offset(24 - _wave * 2, 28),
        .7,
        Colors.white.withValues(alpha: .7),
      );
    }
    c.restore();
    _line(c, Offset(0, pane.top), Offset(0, pane.bottom), _cream, 5);
    _line(c, Offset(pane.left, 7), Offset(pane.right, 7), _cream, 5);
    _round(
      c,
      Rect.fromLTWH(-width / 2 - 7, height / 2 - 3, width + 14, 10),
      5,
      const Color(0xFFE1BCA4),
    );
    c.restore();
  }

  void _livingBack(Canvas c, double extension) {
    _window(c, y: 37 - extension * .48);
    // Bộ sofa giống bánh mochi, gối hình tim và đường chỉ may.
    _shadow(c, const Rect.fromLTWH(123, 192, 176, 22));
    _round(
      c,
      const Rect.fromLTWH(127, 132, 172, 70),
      25,
      dark ? const Color(0xFF9E798F) : const Color(0xFFE8AFBE),
    );
    _round(
      c,
      const Rect.fromLTWH(137, 141, 73, 48),
      17,
      const Color(0xFFF1C2CD),
    );
    _round(
      c,
      const Rect.fromLTWH(214, 141, 73, 48),
      17,
      const Color(0xFFE9B4C6),
    );
    _round(
      c,
      const Rect.fromLTWH(124, 173, 178, 31),
      14,
      const Color(0xFFD794AC),
    );
    _round(
      c,
      const Rect.fromLTWH(114, 159, 25, 48),
      12,
      const Color(0xFFE9AABD),
    );
    _round(
      c,
      const Rect.fromLTWH(287, 159, 25, 48),
      12,
      const Color(0xFFE9AABD),
    );
    _round(c, const Rect.fromLTWH(140, 201, 9, 13), 3, _ink);
    _round(c, const Rect.fromLTWH(276, 201, 9, 13), 3, _ink);
    c.save();
    c.translate(163, 161);
    c.rotate(-.16);
    _round(c, const Rect.fromLTWH(-18, -18, 36, 35), 11, _cream);
    _heart(c, const Offset(0, 0), 7, _rose);
    c.restore();
    c.save();
    c.translate(264, 163);
    c.rotate(.19);
    _round(c, const Rect.fromLTWH(-19, -19, 37, 36), 10, _mint);
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
    _round(c, const Rect.fromLTWH(267, 70, 60, 8), 4, const Color(0xFFD6AF9D));
    for (var i = 0; i < 3; i++) {
      _round(
        c,
        Rect.fromLTWH(273 + i * 10, 43 - i * 3, 8, 27 + i * 3),
        2,
        [_mint, _lilac, _rose][i],
      );
    }
    _flower(c, const Offset(313, 46), 5, _rose);
    _round(c, const Rect.fromLTWH(306, 56, 15, 15), 5, _cream);
    _line(c, const Offset(313, 47), const Offset(313, 58), _mint, 2);
    _clock(c, Offset(198, 75 - extension * .42));
    _plant(c, const Offset(43, 210), 1.0);
    // Giỏ và sách nhỏ ở góc chơi.
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
    _round(c, const Rect.fromLTWH(306, 169, 10, 24), 2, _mint);
    _round(c, const Rect.fromLTWH(318, 173, 9, 20), 2, _lilac);
    _rug(c, const Offset(174, 263), 1.15, _cream);
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
    _path(c, left, _rose);
    _path(
      c,
      Path()
        ..moveTo(0, -18)
        ..quadraticBezierTo(13, -2, 0, 18),
      _cream,
      width: 2,
    );
    _path(
      c,
      Path()
        ..moveTo(-17, -5)
        ..quadraticBezierTo(0, -9, 17, 4),
      _cream,
      width: 2,
    );
    _circle(c, const Offset(-7, -9), 4, Colors.white.withValues(alpha: .55));
    c.restore();
    _round(c, const Rect.fromLTWH(39, 258, 46, 12), 5, _lilac);
    _round(c, const Rect.fromLTWH(43, 254, 43, 6), 3, _cream);
    _star(c, const Offset(61, 250), 9, _gold);
    if (playingNow) {
      for (var i = 0; i < 5; i++) {
        _star(
          c,
          Offset(139 + i * 23, 178 - _pulse * 32 + (i.isEven ? -9 : 9)),
          3 + _pulse * 2,
          [_gold, _rose, _lilac][i % 3],
        );
      }
    }
  }

  void _kitchenBack(Canvas c, double extension) {
    _window(c, x: 140, y: 25 - extension * .35, width: 79, height: 99);
    // Tủ bếp, kệ và dụng cụ có tay nắm, gạch ốp riêng.
    _round(
      c,
      const Rect.fromLTWH(13, 118, 336, 68),
      5,
      dark ? const Color(0xFF526C64) : const Color(0xFFC8DFCE),
    );
    for (var i = 0; i < 8; i++) {
      _line(
        c,
        Offset(15 + i * 43.0, 119),
        Offset(15 + i * 43.0, 184),
        Colors.white.withValues(alpha: .4),
        1,
      );
    }
    _line(
      c,
      const Offset(15, 151),
      const Offset(348, 151),
      Colors.white.withValues(alpha: .4),
      1,
    );
    _shadow(c, const Rect.fromLTWH(16, 197, 328, 18));
    _round(
      c,
      const Rect.fromLTWH(21, 166, 318, 39),
      6,
      const Color(0xFF9FBDA8),
    );
    for (var i = 0; i < 4; i++) {
      _round(
        c,
        Rect.fromLTWH(26 + i * 77, 172, 70, 27),
        5,
        const Color(0xFFC0D3B9),
      );
      _round(c, Rect.fromLTWH(54 + i * 77, 178, 16, 3), 2, _cream);
    }
    _round(c, const Rect.fromLTWH(15, 158, 331, 13), 5, _cream);
    _round(c, const Rect.fromLTWH(25, 28, 88, 78), 14, const Color(0xFFB7C8AF));
    _round(c, const Rect.fromLTWH(32, 35, 72, 63), 10, const Color(0xFFD8E3CB));
    _line(
      c,
      const Offset(68, 38),
      const Offset(68, 96),
      const Color(0xFFB7C8AF),
      2,
    );
    _circle(c, const Offset(60, 67), 2, _ink);
    _circle(c, const Offset(76, 67), 2, _ink);
    _round(c, const Rect.fromLTWH(248, 55, 81, 8), 4, const Color(0xFFD7BBA0));
    _jar(c, const Offset(264, 53), _rose, 1);
    _jar(c, const Offset(293, 53), _gold, .85);
    _plant(c, const Offset(320, 54), .46);
    _line(
      c,
      const Offset(248, 89),
      const Offset(327, 89),
      _ink.withValues(alpha: .5),
      2,
    );
    for (var i = 0; i < 3; i++) {
      final x = 260 + i * 23.0;
      _line(c, Offset(x, 89), Offset(x, 116), _ink.withValues(alpha: .65), 2);
      if (i == 1) {
        _round(c, Rect.fromLTWH(x - 5, 110, 10, 14), 3, _gold);
      } else {
        _oval(c, Rect.fromLTWH(x - 4, 111, 8, 13), _ink.withValues(alpha: .7));
      }
    }
    _round(c, const Rect.fromLTWH(35, 145, 50, 13), 6, const Color(0xFF9EBDB8));
    _path(
      c,
      Path()
        ..moveTo(55, 144)
        ..lineTo(55, 135)
        ..quadraticBezierTo(55, 126, 64, 131)
        ..lineTo(64, 136),
      _ink.withValues(alpha: .6),
      width: 3,
    );
    _round(
      c,
      const Rect.fromLTWH(271, 140, 52, 18),
      5,
      const Color(0xFFE6D7C2),
    );
    _oval(c, const Rect.fromLTWH(279, 143, 13, 7), const Color(0xFFB9A88F));
    _oval(c, const Rect.fromLTWH(301, 143, 13, 7), const Color(0xFFB9A88F));
    _round(c, const Rect.fromLTWH(287, 129, 25, 16), 6, _rose);
    _line(c, const Offset(285, 129), const Offset(314, 129), _cream, 4);
    if (_level > 0) {
      _round(c, const Rect.fromLTWH(91, 137, 31, 21), 6, _lilac);
      _round(
        c,
        const Rect.fromLTWH(95, 142, 22, 11),
        4,
        const Color(0xFF62566F),
      );
      _circle(c, const Offset(116, 155), 1.5, _cream);
    }
    if (_level > 1) {
      _jar(c, const Offset(239, 158), _mint, .85);
      _flower(c, const Offset(238, 129), 5, _gold);
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
    _round(
      c,
      const Rect.fromLTWH(126, 244, 10, 40),
      4,
      const Color(0xFFB18B7B),
    );
    _round(
      c,
      const Rect.fromLTWH(248, 244, 10, 40),
      4,
      const Color(0xFFB18B7B),
    );
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
    _oval(c, const Rect.fromLTWH(139, 221, 105, 17), const Color(0xFFEED5BC));
    _oval(c, const Rect.fromLTWH(155, 219, 74, 14), _cream);
    _oval(c, const Rect.fromLTWH(164, 221, 56, 8), const Color(0xFFD9C8D7));
    _round(
      c,
      const Rect.fromLTWH(125, 211, 13, 17),
      4,
      const Color(0xFFB8D5D7),
    );
    _path(
      c,
      Path()
        ..moveTo(138, 214)
        ..quadraticBezierTo(148, 212, 146, 220)
        ..quadraticBezierTo(144, 225, 138, 222),
      _cream,
      width: 2,
    );
    _line(
      c,
      const Offset(249, 211),
      const Offset(249, 229),
      _ink.withValues(alpha: .55),
      1.7,
    );
    _oval(c, const Rect.fromLTWH(247, 207, 5, 9), _ink.withValues(alpha: .55));
    _line(
      c,
      const Offset(258, 207),
      const Offset(258, 229),
      _ink.withValues(alpha: .55),
      1.7,
    );
    for (var i = 0; i < 3; i++) {
      _line(
        c,
        Offset(256 + i * 2, 207),
        Offset(256 + i * 2, 213),
        _ink.withValues(alpha: .55),
        1,
      );
    }
    if (action == PetCareAction.feed && _active && _inPlace) {
      final reach = progress < .38
          ? Curves.easeInOutSine.transform(((progress - .08) / .3).clamp(0, 1))
          : progress < .78
          ? 1.0
          : 1 -
                Curves.easeInOutSine.transform(
                  ((progress - .78) / .22).clamp(0, 1),
                );
      final point = Offset.lerp(
        const Offset(192, 211),
        const Offset(188, 170),
        reach,
      )!;
      c.save();
      c.translate(point.dx, point.dy);
      c.rotate(-.12 + math.sin(progress * math.pi * 6) * .04 * _careEnvelope);
      _food(c, food, Offset.zero, .74, bitten: progress > .64);
      c.restore();
      for (var i = 0; i < 3; i++) {
        _circle(c, Offset(176 + i * 12, 201 + _pulse * 8 + i * 4), 1.5, _gold);
      }
    } else {
      _food(c, food, const Offset(192, 211), .76);
    }
    if (_level > 0) {
      _flower(c, const Offset(273, 207), 4, _rose);
      _round(c, const Rect.fromLTWH(267, 213, 11, 12), 4, _mint);
      _line(c, const Offset(273, 209), const Offset(273, 215), _mint, 2);
    }
  }

  void _bathroomBack(Canvas c, double extension) {
    _window(c, x: 25, y: 29 - extension * .4, width: 62, height: 80);
    _shadow(c, const Rect.fromLTWH(23, 208, 64, 13));
    _round(
      c,
      const Rect.fromLTWH(29, 135, 51, 69),
      10,
      const Color(0xFFC6B4CE),
    );
    _round(c, const Rect.fromLTWH(34, 143, 41, 53), 7, const Color(0xFFE4D7E8));
    _circle(c, const Offset(55, 161), 2, _lilac);
    _oval(c, const Rect.fromLTWH(22, 125, 64, 20), _cream);
    _oval(c, const Rect.fromLTWH(32, 130, 43, 10), const Color(0xFFB7D9D8));
    _path(
      c,
      Path()
        ..moveTo(54, 125)
        ..lineTo(54, 117)
        ..quadraticBezierTo(54, 108, 64, 112)
        ..lineTo(64, 117),
      _gold,
      width: 3,
    );
    // Gương tai thỏ là hình vẽ trang trí, không dùng camera.
    _oval(c, const Rect.fromLTWH(141, 36, 18, 41), _cream);
    _oval(c, const Rect.fromLTWH(184, 35, 18, 41), _cream);
    _round(c, const Rect.fromLTWH(133, 55, 79, 76), 36, _cream);
    _round(
      c,
      const Rect.fromLTWH(140, 62, 65, 62),
      29,
      const Color(0xFFBBDDDC),
    );
    _path(
      c,
      Path()
        ..moveTo(150, 90)
        ..lineTo(173, 68)
        ..moveTo(150, 105)
        ..lineTo(187, 68),
      Colors.white.withValues(alpha: .48),
      width: 5,
    );
    _round(c, const Rect.fromLTWH(139, 132, 68, 7), 3, const Color(0xFFC6AE9A));
    _round(c, const Rect.fromLTWH(147, 117, 12, 17), 4, _rose);
    _round(c, const Rect.fromLTWH(150, 112, 8, 6), 2, _cream);
    _round(c, const Rect.fromLTWH(185, 117, 13, 17), 4, _lilac);
    _round(c, const Rect.fromLTWH(190, 112, 7, 6), 2, _cream);
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
      _gold,
      width: 5,
    );
    c.save();
    c.translate(251, 72);
    c.rotate(.2);
    _round(c, const Rect.fromLTWH(-13, -4, 26, 9), 4, const Color(0xFFB79B82));
    _round(c, const Rect.fromLTWH(-12, 3, 24, 4), 2, _cream);
    c.restore();
    _circle(c, const Offset(285, 153), 7, _cream);
    _line(c, const Offset(281, 153), const Offset(289, 153), _gold, 2);
    _line(c, const Offset(307, 111), const Offset(341, 111), _gold, 3);
    _round(c, const Rect.fromLTWH(311, 111, 26, 54), 6, _rose);
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
        _cream.withValues(alpha: .5),
        1.5,
      );
    }
    _round(
      c,
      const Rect.fromLTWH(100, 212, 189, 39),
      19,
      const Color(0xFF94C1BD),
    );
    _oval(c, const Rect.fromLTWH(105, 202, 179, 39), _cream);
    _oval(c, const Rect.fromLTWH(114, 208, 161, 29), const Color(0xFF90C4CD));
    _oval(
      c,
      Rect.fromLTWH(119, 211 + _wave * 1.4, 151, 17),
      const Color(0xFFBCE4E4),
    );
    _oval(
      c,
      const Rect.fromLTWH(117, 266, 164, 19),
      _lilac.withValues(alpha: .42),
    );
    for (var i = 0; i < 7; i++) {
      _line(
        c,
        Offset(135 + i * 20.0, 270),
        Offset(137 + i * 20.0, 278),
        _cream.withValues(alpha: .45),
        1,
      );
    }
    _round(
      c,
      const Rect.fromLTWH(303, 207, 34, 16),
      5,
      const Color(0xFFB6A4C3),
    );
    _round(c, const Rect.fromLTWH(306, 199, 29, 10), 5, _cream);
    _soap(c, const Offset(321, 196), .6);
    _sponge(c, const Offset(79, 224), .6);
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
          [_cream, _mint, _rose][i],
        );
      }
    }
    if (_level > 2) {
      _star(c, const Offset(113, 83), 8, _gold);
      _star(c, const Offset(225, 124), 5, _gold);
    }
  }

  void _bathroomFront(Canvas c) {
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
          _line(
            c,
            Offset(x, y),
            Offset(x - 2, y + 8),
            const Color(0xFFB4E9F1).withValues(alpha: .7),
            2,
          );
        }
      }
      for (var i = 0; i < (rinsing ? 9 : 23); i++) {
        final phase = (time * 1.5 + i * .079) % 1;
        final x =
            146 + (i * 31 % 108).toDouble() + math.sin(phase * math.pi * 2) * 4;
        final y = 235 - phase * (rinsing ? 68 : 83);
        _bubble(c, Offset(x, y), 5 + i % 4 * 2.0, .65);
      }
      if (!rinsing) {
        _sponge(
          c,
          Offset(
            212 +
                (_active
                    ? math.sin(progress * math.pi * 6) * 12 * _careEnvelope
                    : 0),
            191 +
                (_active
                    ? math.sin(progress * math.pi * 4) * 5 * _careEnvelope
                    : 0),
          ),
          .72,
        );
        _bubble(c, const Offset(184, 158), 8, .9);
        _bubble(c, const Offset(195, 157), 6, .9);
        _bubble(c, const Offset(176, 161), 5, .9);
      }
    }
    // Thành bồn che chân, không che mặt và biểu cảm.
    _shadow(c, const Rect.fromLTWH(111, 260, 177, 15));
    _round(
      c,
      const Rect.fromLTWH(126, 252, 10, 17),
      4,
      const Color(0xFF8BAFAC),
    );
    _round(
      c,
      const Rect.fromLTWH(255, 252, 10, 17),
      4,
      const Color(0xFF8BAFAC),
    );
    _round(
      c,
      const Rect.fromLTWH(105, 227, 183, 35),
      18,
      const Color(0xFF9DCFC6),
    );
    _round(
      c,
      const Rect.fromLTWH(113, 233, 166, 22),
      11,
      const Color(0xFFBDE3D7),
    );
    _round(c, const Rect.fromLTWH(99, 223, 194, 11), 5.5, _cream);
    _heart(c, const Offset(198, 245), 7, const Color(0xFF8DBBB3));
    _duck(c, Offset(128, 218 + _wave * 1.4), .6);
    if (bathStage == 3 && _inBath) {
      for (var i = 0; i < 5; i++) {
        _star(
          c,
          Offset(145 + i * 25, 174 - (i.isOdd ? 33 : 0) + _wave * 3),
          4.5,
          _gold,
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

  void _bedroomBack(Canvas c, double extension) {
    c.save();
    c.translate(0, -extension * .42);
    _window(c, night: true, x: 43, y: 37, width: 78, height: 93);
    _line(c, const Offset(28, 28), const Offset(132, 28), _gold, 3);
    final curtain = dark ? const Color(0xFF8D7FA5) : const Color(0xFFC3B5DD);
    _path(
      c,
      Path()
        ..moveTo(34, 29)
        ..lineTo(58, 29)
        ..quadraticBezierTo(66, 80, 46, 105)
        ..lineTo(34, 148)
        ..quadraticBezierTo(20, 138, 24, 126)
        ..close(),
      curtain,
    );
    _path(
      c,
      Path()
        ..moveTo(110, 29)
        ..lineTo(132, 29)
        ..lineTo(140, 140)
        ..quadraticBezierTo(128, 151, 117, 144)
        ..lineTo(112, 108)
        ..quadraticBezierTo(97, 79, 110, 29)
        ..close(),
      curtain,
    );
    _line(c, const Offset(34, 106), const Offset(47, 106), _gold, 4);
    _line(c, const Offset(117, 105), const Offset(130, 105), _gold, 4);
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
    _round(c, const Rect.fromLTWH(264, 60, 68, 8), 4, const Color(0xFFD2B8A2));
    _round(c, const Rect.fromLTWH(273, 43, 12, 17), 3, _rose);
    _round(c, const Rect.fromLTWH(289, 35, 10, 25), 3, _mint);
    _round(c, const Rect.fromLTWH(303, 39, 10, 21), 3, _lilac);
    _star(c, const Offset(316, 31), 8, _gold);
    _round(
      c,
      const Rect.fromLTWH(280, 180, 54, 51),
      9,
      const Color(0xFFCBB3BD),
    );
    _round(
      c,
      const Rect.fromLTWH(285, 188, 43, 24),
      6,
      const Color(0xFFE6D6DC),
    );
    _circle(c, const Offset(307, 199), 2.4, _gold);
    _round(c, const Rect.fromLTWH(277, 176, 61, 9), 4.5, _cream);
    _line(c, const Offset(308, 150), const Offset(308, 175), _gold, 4);
    _oval(c, const Rect.fromLTWH(293, 170, 30, 6), _gold);
    if (vitals.sleeping || dark) {
      _circle(
        c,
        const Offset(308, 147),
        32,
        const Color(0xFFFFE0A8).withValues(alpha: .13),
      );
    }
    _path(
      c,
      Path()
        ..moveTo(293, 128)
        ..lineTo(321, 128)
        ..lineTo(329, 153)
        ..quadraticBezierTo(309, 160, 286, 153)
        ..close(),
      _level > 0 ? const Color(0xFFFFD79C) : const Color(0xFFE8C4B6),
    );
    _line(c, const Offset(289, 153), const Offset(327, 153), _cream, 2);
    _shadow(c, const Rect.fromLTWH(82, 264, 193, 17));
    _round(
      c,
      const Rect.fromLTWH(82, 169, 191, 93),
      24,
      const Color(0xFFC6A4B0),
    );
    _round(
      c,
      const Rect.fromLTWH(90, 177, 175, 55),
      18,
      const Color(0xFFDCC2CC),
    );
    for (var i = 0; i < 4; i++) {
      _circle(c, Offset(115 + i * 42, 192), 2.5, _cream.withValues(alpha: .7));
    }
    _round(c, const Rect.fromLTWH(91, 208, 177, 57), 20, _cream);
    _round(
      c,
      const Rect.fromLTWH(100, 210, 63, 33),
      14,
      const Color(0xFFFFE9CB),
    );
    _round(c, const Rect.fromLTWH(104, 214, 55, 24), 11, _cream);
    _rug(c, const Offset(186, 280), .85, const Color(0xFFC7B6D9));
    _moonMobile(c, const Offset(200, 16));
    if (_level > 1) {
      _plant(c, const Offset(39, 219), .82);
    }
    if (_level > 2) {
      _bunting(c, 133, 123, 260);
      _heart(c, const Offset(250, 190), 8, _rose);
    }
  }

  void _bedroomFront(Canvas c) {
    if (_inBed) {
      if (sleepBlend < .999) {
        c.saveLayer(
          const Rect.fromLTRB(70, 130, 300, 285),
          Paint()..color = Colors.white.withValues(alpha: sleepBlend),
        );
      }
      _round(
        c,
        const Rect.fromLTWH(156, 211, 113, 49),
        18,
        _level > 1 ? const Color(0xFFA4C5B6) : const Color(0xFFB6A3CF),
      );
      _round(
        c,
        const Rect.fromLTWH(155, 210, 20, 48),
        8,
        _level > 1 ? const Color(0xFFC4DECA) : const Color(0xFFD4C4E5),
      );
      for (var row = 0; row < 2; row++) {
        for (var col = 0; col < 3; col++) {
          _star(
            c,
            Offset(190 + col * 25, 224 + row * 21),
            3.7,
            _cream.withValues(alpha: .65),
          );
        }
      }
      // Sao ngủ thay cho chữ, không phụ thuộc phông hoặc ngôn ngữ.
      for (var i = 0; i < 3; i++) {
        final phase = (time + i * .28) % 1;
        _star(
          c,
          Offset(103 - phase * 19, 195 - phase * 51),
          3 + phase * 2,
          _gold.withValues(alpha: (1 - phase) * .8),
        );
      }
      if (sleepBlend < .999) c.restore();
    }
    if (sleepBlend < .999) {
      if (sleepBlend > .001) {
        c.saveLayer(
          const Rect.fromLTRB(200, 210, 280, 270),
          Paint()..color = Colors.white.withValues(alpha: 1 - sleepBlend),
        );
      }
      // Chăn gấp ở chân giường khi bé thức, không che chuyển động trên sàn.
      _round(
        c,
        const Rect.fromLTWH(219, 225, 48, 35),
        8,
        const Color(0xFFB6A3CF),
      );
      _line(
        c,
        const Offset(227, 230),
        const Offset(227, 255),
        _cream.withValues(alpha: .5),
        2,
      );
      _star(c, const Offset(246, 244), 5, _cream);
      if (sleepBlend > .001) c.restore();
    }
    _round(c, const Rect.fromLTWH(92, 259, 177, 9), 4, const Color(0xFFB78F9D));
    _round(
      c,
      const Rect.fromLTWH(105, 266, 10, 12),
      3,
      const Color(0xFFB78F9D),
    );
    _round(
      c,
      const Rect.fromLTWH(248, 266, 10, 12),
      3,
      const Color(0xFFB78F9D),
    );
    _slipper(c, const Offset(294, 268), -.3);
    _slipper(c, const Offset(315, 273), -.12);
  }

  Offset get _partnerPosition {
    final onRight = selectedPet == PetCarePet.rabbit;
    return switch (room) {
      PetCareRoom.living =>
        onRight ? const Offset(258, 260) : const Offset(104, 260),
      PetCareRoom.kitchen =>
        onRight ? const Offset(270, 254) : const Offset(112, 254),
      PetCareRoom.bathroom =>
        onRight ? const Offset(284, 254) : const Offset(108, 254),
      PetCareRoom.bedroom =>
        onRight ? const Offset(248, 252) : const Offset(116, 252),
    };
  }

  void _partnerPet(Canvas c) {
    final partner = selectedPet == PetCarePet.rabbit
        ? PetCarePet.bear
        : PetCarePet.rabbit;
    final sleeping = room == PetCareRoom.bedroom && partnerVitals.sleeping;
    final p = sleeping ? Offset(_partnerPosition.dx, 237) : _partnerPosition;
    final bob = sleeping ? _wave * .45 : _wave * .85;
    c.save();
    c.translate(p.dx, p.dy + bob);
    c.rotate(
      sleeping
          ? -math.pi / 2 + .07
          : action == PetCareAction.hug && !playing && _active
          ? -_careEnvelope * .025
          : 0,
    );
    final scale = small
        ? 2.65
        : partner == PetCarePet.rabbit
        ? 2.5
        : 2.3;
    c.scale(scale, scale);
    c.translate(-180, -260);
    motion
      ..walking = false
      ..hopping = false
      ..walkWeight = 0
      ..strideCycles = 0
      ..cuddle = action == PetCareAction.hug && !playing && _active
          ? _careEnvelope * .35
          : 0
      ..lift = 0
      ..gameFacingRight = _partnerPosition.dx < 180
      ..seconds = seconds * .78 + 1.8;
    HomeCompanionPainter(
      motion: motion,
      darkMode: dark,
      character: partner == PetCarePet.rabbit
          ? HomeCompanionCharacter.bunny
          : HomeCompanionCharacter.bear,
      showEffects: true,
      care: partnerVitals,
    ).paint(c, const Size(360, 300));
    c.restore();
  }

  void _pet(Canvas c) {
    final p = Offset.lerp(position, const Offset(216, 237), sleepBlend)!;
    final hugging = action == PetCareAction.hug && !playing && _active;
    final feeding = action == PetCareAction.feed && _active;
    final playEnvelope = playing && _active ? _careEnvelope : 0.0;
    final bob = walking ? 0.0 : math.sin(seconds * 1.7) * .3 * (1 - sleepBlend);
    final chew = feeding && progress > .42 && progress < .8
        ? math.sin((progress - .42) / .38 * math.pi * 6) * .55
        : 0.0;
    if (walking) {
      for (var i = 0; i < 2; i++) {
        final offset = (facingRight ? -1 : 1) * (17 + i * 11.0);
        _oval(
          c,
          Rect.fromCenter(
            center: p + Offset(offset, 1 + (i.isOdd ? 3 : -2)),
            width: 4,
            height: 2,
          ),
          _cream.withValues(alpha: (.45 - i * .15) * walkWeight),
        );
      }
    }
    c.save();
    c.translate(p.dx, p.dy + bob - chew);
    c.rotate(
      (-math.pi / 2 + .07) * sleepBlend + (hugging ? _careEnvelope * .035 : 0),
    );
    final scale = small
        ? 3.2
        : selectedPet == PetCarePet.rabbit
        ? 2.85
        : 2.55;
    c.scale(scale, scale);
    c.translate(-180, -260);
    motion
      ..walking = walking && !_inBed
      ..hopping = playEnvelope > 0 && !walking
      ..gameFacingRight = facingRight || _inBed
      ..strideCycles = walking ? strideCycles : progress * .9
      ..walkWeight = walking ? walkWeight : playEnvelope * .7
      ..seconds = seconds * .78
      ..cuddle = hugging
          ? _careEnvelope * .65
          : feeding
          ? _careEnvelope * .2
          : 0
      ..lift = playEnvelope * math.sin(progress * math.pi) * 1.8;
    HomeCompanionPainter(
      motion: motion,
      darkMode: dark,
      character: selectedPet == PetCarePet.rabbit
          ? HomeCompanionCharacter.bunny
          : HomeCompanionCharacter.bear,
      showEffects: true,
      care: vitals,
    ).paint(c, const Size(360, 300));
    c.restore();
    if (vitals.isDirty && !_inBath && !_inBed) {
      for (var i = 0; i < 3; i++) {
        final x = p.dx - 23 + i * 22;
        final y = p.dy - 91 - (i.isOdd ? 12 : 0) + _wave * 2;
        _path(
          c,
          Path()
            ..moveTo(x, y)
            ..quadraticBezierTo(x - 4, y - 5, x, y - 10)
            ..quadraticBezierTo(x + 4, y - 16, x, y - 20),
          const Color(0xFF9B997B).withValues(alpha: .5),
          width: 1.7,
        );
      }
    }
  }

  void _affection(Canvas c) {
    if (action != PetCareAction.hug || playing || !_active) {
      return;
    }
    for (var i = 0; i < 6; i++) {
      final t = (progress * 1.45 - i * .09).clamp(0.0, 1.0);
      if (t <= 0 || t >= 1) continue;
      final x = position.dx + math.sin(i * 1.4) * (24 + t * 27);
      final y = position.dy - 72 - t * 65 + (i % 2) * 11;
      _heart(
        c,
        Offset(x, y),
        4 + _pulse * 3,
        [
          _rose,
          _lilac,
          _gold,
        ][i % 3].withValues(alpha: math.sin(t * math.pi) * .85),
      );
    }
  }

  void _decoration(Canvas c) {
    switch (decoration) {
      case PetCareDecor.moon:
        _moonMobile(c, const Offset(181, -24));
      case PetCareDecor.planet:
        c.save();
        c.translate(238, 37 + _wave * 2);
        c.rotate(-.3);
        _circle(c, Offset.zero, 14, _lilac);
        _oval(c, const Rect.fromLTWH(-23, -5, 46, 10), _cream, stroke: 3);
        _star(c, const Offset(26, -16), 3, _gold);
        c.restore();
      case PetCareDecor.garden:
        _plant(c, const Offset(19, 254), .72);
        _plant(c, const Offset(345, 249), .75);
      case null:
        break;
    }
  }

  void _food(
    Canvas c,
    PetCareFood type,
    Offset p,
    double scale, {
    bool bitten = false,
  }) {
    c.save();
    c.translate(p.dx, p.dy);
    c.scale(scale);
    switch (type) {
      case PetCareFood.carrot:
        c.rotate(-.48);
        _path(
          c,
          Path()
            ..moveTo(-11, -12)
            ..quadraticBezierTo(0, -18, 11, -12)
            ..quadraticBezierTo(10, 2, 0, bitten ? 13 : 25)
            ..quadraticBezierTo(-9, 3, -11, -12)
            ..close(),
          const Color(0xFFF2A05E),
        );
        for (var i = 0; i < 3; i++) {
          _line(
            c,
            Offset(-7.0 + i, -7 + i * 8.0),
            Offset(-1.0 + i, -9 + i * 8.0),
            const Color(0xFFD98048),
            1.5,
          );
        }
        for (var i = -1; i < 2; i++) {
          _path(
            c,
            Path()
              ..moveTo(0, -12)
              ..quadraticBezierTo(i * 14, -30, i * 8, -31)
              ..quadraticBezierTo(i * 15, -22, 0, -12),
            _mint,
            width: 4,
          );
        }
      case PetCareFood.apple:
        _path(
          c,
          Path()
            ..moveTo(0, -13)
            ..cubicTo(-18, -25, -25, -5, -16, 10)
            ..quadraticBezierTo(-8, 22, 0, 16)
            ..quadraticBezierTo(9, 22, 18, 8)
            ..cubicTo(27, -10, 14, -24, 0, -13)
            ..close(),
          const Color(0xFFE88F9D),
        );
        _path(
          c,
          Path()
            ..moveTo(0, -12)
            ..quadraticBezierTo(-3, -24, 4, -27),
          const Color(0xFF94745D),
          width: 3,
        );
        _oval(c, const Rect.fromLTWH(4, -26, 14, 7), _mint);
        _oval(
          c,
          const Rect.fromLTWH(-14, -10, 6, 11),
          Colors.white.withValues(alpha: .5),
        );
        if (bitten) {
          _circle(c, const Offset(17, -2), 7, _cream);
        }
      case PetCareFood.soup:
        _oval(c, const Rect.fromLTWH(-29, -4, 58, 13), const Color(0xFFC8DDCF));
        _path(
          c,
          Path()
            ..moveTo(-25, -8)
            ..quadraticBezierTo(-24, 17, 0, 17)
            ..quadraticBezierTo(24, 17, 25, -8)
            ..close(),
          _cream,
        );
        _oval(
          c,
          const Rect.fromLTWH(-25, -15, 50, 16),
          const Color(0xFFBBD3CF),
        );
        _oval(
          c,
          const Rect.fromLTWH(-21, -13, 42, 12),
          const Color(0xFFEFC174),
        );
        _circle(c, const Offset(-8, -7), 3, _mint);
        _circle(c, const Offset(9, -9), 2.5, _rose);
        _round(c, const Rect.fromLTWH(-1, -6, 5, 3), 1, _cream);
        for (var i = -1; i < 2; i++) {
          _path(
            c,
            Path()
              ..moveTo(i * 12, -20)
              ..quadraticBezierTo(i * 12 - 4, -25 - _wave * 2, i * 12, -32),
            _cream.withValues(alpha: .6),
            width: 2,
          );
        }
      case PetCareFood.cake:
        _oval(c, const Rect.fromLTWH(-28, 9, 56, 11), const Color(0xFFD9CBDF));
        _round(
          c,
          const Rect.fromLTWH(-22, -14, 44, 28),
          7,
          const Color(0xFFF4D39E),
        );
        _round(c, const Rect.fromLTWH(-22, -5, 44, 6), 2, _rose);
        _round(c, const Rect.fromLTWH(-23, -16, 46, 11), 6, _cream);
        for (var i = 0; i < 4; i++) {
          _circle(c, Offset(-17 + i * 11, -7), 4, _cream);
        }
        _heart(c, const Offset(0, -19), 7, const Color(0xFFE08292));
        _oval(c, const Rect.fromLTWH(-2, -29, 8, 4), _mint);
        if (bitten) {
          _circle(c, const Offset(22, -4), 8, _cream);
        }
    }
    c.restore();
  }

  void _soap(Canvas c, Offset p, double scale) {
    c.save();
    c.translate(p.dx, p.dy);
    c.scale(scale);
    c.rotate(-.12);
    _round(
      c,
      const Rect.fromLTWH(-23, -9, 46, 22),
      10,
      const Color(0xFFAB96C4),
    );
    _round(
      c,
      const Rect.fromLTWH(-22, -13, 44, 21),
      10,
      const Color(0xFFCEBCE2),
    );
    _flower(c, const Offset(0, -3), 4, _cream.withValues(alpha: .75));
    _bubble(c, const Offset(-18, -17), 5, .8);
    c.restore();
  }

  void _sponge(Canvas c, Offset p, double scale) {
    c.save();
    c.translate(p.dx, p.dy);
    c.scale(scale);
    c.rotate(
      .12 +
          (bathStage == 1 && _active
              ? math.sin(progress * math.pi * 6) * .16 * _careEnvelope
              : 0),
    );
    _round(
      c,
      const Rect.fromLTWH(-23, -12, 46, 26),
      10,
      const Color(0xFF7EAA99),
    );
    _round(
      c,
      const Rect.fromLTWH(-23, -17, 46, 25),
      10,
      const Color(0xFFC0DFB9),
    );
    for (var i = 0; i < 7; i++) {
      _circle(
        c,
        Offset(-15 + (i * 13 % 34), -9 + i % 2 * 9),
        1.7,
        const Color(0xFF87B595),
      );
    }
    c.restore();
  }

  void _duck(Canvas c, Offset p, double scale) {
    c.save();
    c.translate(p.dx, p.dy);
    c.scale(scale);
    _oval(c, const Rect.fromLTWH(-15, -5, 31, 18), const Color(0xFFFFD98C));
    _circle(c, const Offset(9, -8), 10, const Color(0xFFFFD98C));
    _path(
      c,
      Path()
        ..moveTo(17, -8)
        ..lineTo(27, -4)
        ..lineTo(17, -1)
        ..close(),
      const Color(0xFFECA073),
    );
    _circle(c, const Offset(12, -10), 1.6, _ink);
    _oval(c, const Rect.fromLTWH(-10, -2, 15, 8), const Color(0xFFFFE6B0));
    c.restore();
  }

  void _slipper(Canvas c, Offset p, double angle) {
    c.save();
    c.translate(p.dx, p.dy);
    c.rotate(angle);
    _oval(c, const Rect.fromLTWH(-9, -14, 19, 28), _rose);
    _round(c, const Rect.fromLTWH(-9, -14, 19, 17), 8, const Color(0xFFF1C3CF));
    _heart(c, const Offset(0, -7), 3, _cream);
    c.restore();
  }

  void _moonMobile(Canvas c, Offset p) {
    _line(c, p, p + const Offset(0, 37), _gold, 1.3);
    _circle(c, p + Offset(0, 51 + _wave * 1.2), 14, const Color(0xFFFFDCA1));
    _circle(
      c,
      p + Offset(6, 46 + _wave * 1.2),
      12,
      dark ? const Color(0xFF57516F) : const Color(0xFFECE5F6),
    );
    _line(c, p + const Offset(-22, 6), p + const Offset(-22, 41), _gold, 1);
    _star(c, p + Offset(-22, 47 + _wave), 6, _gold);
    _line(c, p + const Offset(25, 10), p + const Offset(25, 53), _gold, 1);
    _star(c, p + Offset(25, 59 - _wave), 4, _gold);
  }

  void _clock(Canvas c, Offset p) {
    _circle(c, p + const Offset(1, 3), 22, _ink.withValues(alpha: .1));
    _circle(c, p, 22, const Color(0xFFD7B695));
    _circle(c, p, 18, _cream);
    for (var i = 0; i < 12; i++) {
      final angle = i * math.pi / 6;
      _circle(
        c,
        p + Offset(math.sin(angle) * 14, math.cos(angle) * 14),
        .9,
        _ink.withValues(alpha: .5),
      );
    }
    _line(c, p, p + const Offset(-6, -7), _ink, 2);
    _line(c, p, p + const Offset(8, -3), _ink, 1.5);
    _circle(c, p, 2, _rose);
  }

  void _plant(Canvas c, Offset p, double scale) {
    c.save();
    c.translate(p.dx, p.dy);
    c.scale(scale);
    _shadow(c, const Rect.fromLTWH(-20, -2, 40, 8));
    _path(
      c,
      Path()
        ..moveTo(-15, -25)
        ..lineTo(-11, 0)
        ..quadraticBezierTo(0, 5, 11, 0)
        ..lineTo(15, -25)
        ..close(),
      const Color(0xFFD6AA93),
    );
    _round(c, const Rect.fromLTWH(-17, -29, 34, 9), 4, const Color(0xFFE9C5AB));
    _line(
      c,
      const Offset(0, -28),
      const Offset(0, -69),
      const Color(0xFF7FA98B),
      2,
    );
    for (var i = 0; i < 5; i++) {
      c.save();
      c.translate(i.isEven ? -5 : 6, -39 - i * 7.0);
      c.rotate(i.isEven ? -.8 : .8);
      _oval(
        c,
        const Rect.fromLTWH(-5, -16, 12, 23),
        i.isEven ? _mint : const Color(0xFF8EB49B),
      );
      _line(
        c,
        const Offset(1, 4),
        const Offset(1, -12),
        _cream.withValues(alpha: .35),
        1,
      );
      c.restore();
    }
    c.restore();
  }

  void _jar(Canvas c, Offset p, Color color, double scale) {
    c.save();
    c.translate(p.dx, p.dy);
    c.scale(scale);
    _round(
      c,
      const Rect.fromLTWH(-11, -27, 22, 27),
      6,
      _cream.withValues(alpha: .9),
    );
    _round(
      c,
      const Rect.fromLTWH(-8, -17, 16, 14),
      4,
      color.withValues(alpha: .7),
    );
    _round(c, const Rect.fromLTWH(-12, -30, 24, 6), 3, const Color(0xFFD6B592));
    _line(
      c,
      const Offset(-7, -23),
      const Offset(-7, -9),
      Colors.white.withValues(alpha: .65),
      2,
    );
    c.restore();
  }

  void _bunting(Canvas c, double start, double y, double end) {
    _path(
      c,
      Path()
        ..moveTo(start, y)
        ..quadraticBezierTo((start + end) / 2, y + 22, end, y),
      _ink.withValues(alpha: .4),
      width: 1,
    );
    for (var i = 0; i < 6; i++) {
      final x = start + 10 + (end - start - 20) / 5 * i;
      final dy = math.sin(i / 5 * math.pi) * 9;
      _path(
        c,
        Path()
          ..moveTo(x - 5, y + dy + 1)
          ..lineTo(x + 5, y + dy + 1)
          ..lineTo(x, y + dy + 15)
          ..close(),
        [_rose, _mint, _gold][i % 3],
      );
    }
  }

  void _rug(Canvas c, Offset p, double scale, Color color) {
    c.save();
    c.translate(p.dx, p.dy);
    c.scale(scale, scale * .28);
    _cloud(c, const Offset(0, 0), 2.0, color);
    _path(
      c,
      Path()
        ..moveTo(-62, 10)
        ..quadraticBezierTo(-13, 30, 57, 11),
      _rose.withValues(alpha: .25),
      width: 3,
    );
    c.restore();
  }

  void _cloud(Canvas c, Offset p, double scale, Color color) {
    c.save();
    c.translate(p.dx, p.dy);
    c.scale(scale);
    _oval(c, const Rect.fromLTWH(-37, -6, 76, 30), color);
    _circle(c, const Offset(-20, -2), 19, color);
    _circle(c, const Offset(3, -12), 24, color);
    _circle(c, const Offset(26, -1), 18, color);
    c.restore();
  }

  void _flower(Canvas c, Offset p, double radius, Color color) {
    for (var i = 0; i < 5; i++) {
      final angle = i * math.pi * 2 / 5;
      _circle(
        c,
        p + Offset(math.cos(angle), math.sin(angle)) * radius,
        radius * .7,
        color,
      );
    }
    _circle(c, p, radius * .55, _gold.withValues(alpha: color.a));
  }

  void _bubble(Canvas c, Offset p, double radius, double opacity) {
    _circle(c, p, radius, Colors.white.withValues(alpha: opacity * .6));
    _oval(
      c,
      Rect.fromCircle(center: p, radius: radius),
      Colors.white.withValues(alpha: opacity),
      stroke: .9,
    );
    _circle(
      c,
      p + Offset(-radius * .3, -radius * .35),
      radius * .22,
      Colors.white.withValues(alpha: opacity),
    );
  }

  void _diamond(Canvas c, Offset p, double r, Color color) => _path(
    c,
    Path()
      ..moveTo(p.dx, p.dy - r)
      ..lineTo(p.dx + r, p.dy)
      ..lineTo(p.dx, p.dy + r)
      ..lineTo(p.dx - r, p.dy)
      ..close(),
    color,
  );

  void _star(Canvas c, Offset p, double r, Color color) {
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final a = i * math.pi / 5 - math.pi / 2;
      final size = i.isEven ? r : r * .47;
      final point = p + Offset(math.cos(a), math.sin(a)) * size;
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    _path(c, path..close(), color);
  }

  void _heart(Canvas c, Offset p, double r, Color color) {
    c.save();
    c.translate(p.dx, p.dy);
    c.scale(r / 10);
    _path(
      c,
      Path()
        ..moveTo(0, 10)
        ..cubicTo(-23, -4, -8, -16, 0, -6)
        ..cubicTo(8, -16, 23, -4, 0, 10),
      color,
    );
    c.restore();
  }

  void _shadow(Canvas c, Rect rect) => _oval(
    c,
    rect,
    const Color(0xFF78656D).withValues(alpha: dark ? .15 : .10),
  );
  void _gradient(Canvas c, Rect rect, List<Color> colors) => c.drawRect(
    rect,
    Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: colors,
      ).createShader(rect),
  );
  void _round(Canvas c, Rect rect, double radius, Color color) => c.drawRRect(
    RRect.fromRectAndRadius(rect, Radius.circular(radius)),
    Paint()..color = color,
  );
  void _oval(Canvas c, Rect rect, Color color, {double? stroke}) => c.drawOval(
    rect,
    Paint()
      ..color = color
      ..style = stroke == null ? PaintingStyle.fill : PaintingStyle.stroke
      ..strokeWidth = stroke ?? 1,
  );
  void _circle(Canvas c, Offset center, double radius, Color color) =>
      c.drawCircle(center, radius, Paint()..color = color);
  void _line(Canvas c, Offset a, Offset b, Color color, double width) =>
      c.drawLine(
        a,
        b,
        Paint()
          ..color = color
          ..strokeWidth = width
          ..strokeCap = StrokeCap.round,
      );
  void _path(Canvas c, Path path, Color color, {double? width}) => c.drawPath(
    path,
    Paint()
      ..color = color
      ..style = width == null ? PaintingStyle.fill : PaintingStyle.stroke
      ..strokeWidth = width ?? 1
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round,
  );

  @override
  bool shouldRepaint(covariant _PetHousePainter oldDelegate) {
    if (layer == _PetHouseLayer.foreground) return true;
    return oldDelegate.layer != layer ||
        oldDelegate.room != room ||
        oldDelegate.dark != dark ||
        oldDelegate.decoration != decoration ||
        oldDelegate.small != small ||
        oldDelegate.fillRoom != fillRoom ||
        oldDelegate.vitals.sleeping != vitals.sleeping ||
        !mapEquals(oldDelegate.upgrades, upgrades);
  }
}
