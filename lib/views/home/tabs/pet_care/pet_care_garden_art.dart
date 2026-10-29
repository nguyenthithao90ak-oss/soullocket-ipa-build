part of 'pet_care_garden.dart';

void _gr(Canvas c, Rect r, double radius, Color color) => c.drawRRect(
  RRect.fromRectAndRadius(r, Radius.circular(radius)),
  Paint()..color = color,
);
void _go(Canvas c, Rect r, Color color) =>
    c.drawOval(r, Paint()..color = color);
void _gc(Canvas c, Offset p, double r, Color color) =>
    c.drawCircle(p, r, Paint()..color = color);
void _gl(Canvas c, Offset a, Offset b, Color color, double width) => c.drawLine(
  a,
  b,
  Paint()
    ..color = color
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round,
);
void _gp(Canvas c, List<Offset> points, Color color) {
  final p = Path()..addPolygon(points, true);
  c.drawPath(p, Paint()..color = color);
}

void _gleaf(Canvas c, Offset at, double angle, double scale, Color color) {
  c.save();
  c.translate(at.dx, at.dy);
  c.rotate(angle);
  c.scale(scale);
  c.drawPath(
    Path()
      ..moveTo(0, 0)
      ..quadraticBezierTo(-24, -25, 0, -40)
      ..quadraticBezierTo(23, -18, 0, 0),
    Paint()..color = color,
  );
  _gl(
    c,
    Offset.zero,
    const Offset(0, -30),
    Colors.white.withValues(alpha: .18),
    1.4,
  );
  c.restore();
}

class _GardenLandscape extends CustomPainter {
  const _GardenLandscape({required this.dark});
  final bool dark;
  @override
  void paint(Canvas c, Size size) {
    final grass = dark ? const Color(0xFF476750) : const Color(0xFFB6CE8C);
    c.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            dark ? const Color(0xFF476865) : const Color(0xFFD4E5CA),
            grass,
            dark ? const Color(0xFF3C604B) : const Color(0xFFA4C77E),
          ],
          stops: const [0, .25, 1],
        ).createShader(Offset.zero & size),
    );
    for (var i = 0; i < 7; i++) {
      _go(
        c,
        Rect.fromCenter(center: Offset(i * 170.0, 70), width: 280, height: 150),
        dark ? const Color(0xFF426557) : const Color(0xFF9FBD8B),
      );
    }
    _go(c, const Rect.fromLTWH(68, 327, 830, 672), const Color(0x1F6A964E));
    for (var i = 0; i < 70; i++) {
      final p = Offset(
        60 + (i * 149 % 850).toDouble(),
        230 + (i * 89 % 760).toDouble(),
      );
      _go(
        c,
        Rect.fromCenter(center: p, width: 24 + (i % 4) * 10, height: 8),
        Colors.white.withValues(alpha: dark ? .015 : .05),
      );
      if (i % 3 == 0) {
        _gl(c, p, p + const Offset(-3, -7), const Color(0x3363884B), 2);
        _gl(
          c,
          p + const Offset(4, 0),
          p + const Offset(6, -6),
          const Color(0x3363884B),
          2,
        );
      }
    }
    // Hàng rào và bụi hoa bao quanh khu vườn.
    for (var y = 218.0; y < 1000; y += 46) {
      for (final x in [45.0, 915.0]) {
        _gr(
          c,
          Rect.fromLTWH(x - 7, y - 44, 14, 55),
          5,
          const Color(0xFFDBC7A3),
        );
        _gl(c, Offset(x, y - 36), Offset(x, y - 4), const Color(0xFFF5E7C7), 4);
      }
    }
    for (final x in [45.0, 915.0]) {
      _gl(c, Offset(x, 196), Offset(x, 970), const Color(0xFFBAA27E), 8);
      _gl(
        c,
        Offset(x - 2, 194),
        Offset(x - 2, 968),
        const Color(0xFFEEDABB),
        4,
      );
    }
    _gl(
      c,
      const Offset(45, 185),
      const Offset(915, 185),
      const Color(0xFFC5AF88),
      9,
    );
    for (var x = 55.0; x < 920; x += 43) {
      _gr(c, Rect.fromLTWH(x - 6, 149, 12, 62), 5, const Color(0xFFE9D7B7));
      _gc(c, Offset(x, 154), 6, const Color(0xFFF9E8C7));
    }
    // Lối đá nối cửa nhà với tất cả các luống.
    final lane = Path()
      ..moveTo(350, 395)
      ..cubicTo(340, 470, 600, 440, 587, 580)
      ..cubicTo(570, 730, 580, 870, 574, 1035);
    c.drawPath(
      lane,
      Paint()
        ..color = const Color(0xFF8FA96B)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 76
        ..strokeCap = StrokeCap.round,
    );
    c.drawPath(
      lane,
      Paint()
        ..color = const Color(0xFFDACA9F)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 62
        ..strokeCap = StrokeCap.round,
    );
    for (final y in [635.0, 795.0, 955.0]) {
      _gl(c, Offset(136, y), Offset(615, y), const Color(0xFFDACA9F), 46);
      for (var x = 150.0; x < 600; x += 66) {
        _go(
          c,
          Rect.fromCenter(center: Offset(x, y - 1), width: 53, height: 29),
          const Color(0xFFEBDDFA).withValues(alpha: .45),
        );
        _go(
          c,
          Rect.fromCenter(center: Offset(x + 2, y - 3), width: 47, height: 23),
          const Color(0xFFF1E5C4),
        );
      }
    }
    for (var y = 450.0; y < 1020; y += 48) {
      final x = y < 570 ? 380 + (y - 450) * 1.65 : 580.0;
      _go(
        c,
        Rect.fromCenter(center: Offset(x, y), width: 46, height: 27),
        const Color(0xFFC8B88F),
      );
      _go(
        c,
        Rect.fromCenter(center: Offset(x - 1, y - 3), width: 44, height: 24),
        const Color(0xFFF1E5C4),
      );
    }
    _pond(c);
    _house(c);
    _tree(c, const Offset(80, 360), .85, const Color(0xFF719864));
    _tree(c, const Offset(855, 177), .9, const Color(0xFF6D965D));
    _tree(c, const Offset(95, 162), .7, const Color(0xFF7FA16C));
    // Ghế nghỉ ngoài hiên.
    _go(c, const Rect.fromLTWH(73, 426, 125, 27), const Color(0x2261764B));
    for (final y in [386.0, 401.0, 421.0]) {
      _gr(c, Rect.fromLTWH(84, y, 99, 10), 4, const Color(0xFFC29469));
      _gl(c, Offset(91, y + 2), Offset(177, y + 2), const Color(0xFFE4BB8B), 2);
    }
    for (final x in [96.0, 169.0]) {
      _gl(c, Offset(x, 395), Offset(x, 444), const Color(0xFF785F48), 6);
    }
    // Hoa viền và đá nhỏ, không đặt trên đường đi.
    for (var i = 0; i < 27; i++) {
      final p = Offset(i.isEven ? 77 : 886, 460 + i * 19.0);
      _gl(c, p, p + const Offset(0, -13), const Color(0xFF6F9559), 2.5);
      for (var j = 0; j < 5; j++) {
        final a = j * math.pi * 2 / 5;
        _gc(
          c,
          p + Offset(math.cos(a) * 5, -14 + math.sin(a) * 5),
          4.2,
          [
            const Color(0xFFF6DD99),
            const Color(0xFFE8A7B0),
            const Color(0xFFF7F1DA),
          ][i % 3],
        );
      }
      _gc(c, p + const Offset(0, -14), 2.5, const Color(0xFFC6944C));
    }
  }

  void _house(Canvas c) {
    _go(c, const Rect.fromLTWH(126, 351, 520, 113), const Color(0x25657C4D));
    // Mặt hông nghiêng và mặt trước ngôi nhà.
    _gp(c, const [
      Offset(488, 207),
      Offset(613, 140),
      Offset(613, 330),
      Offset(488, 414),
    ], const Color(0xFFD3BD9D));
    _gp(c, const [
      Offset(131, 207),
      Offset(488, 207),
      Offset(488, 414),
      Offset(131, 385),
    ], const Color(0xFFF2E4C4));
    for (var y = 239.0; y < 390; y += 31) {
      _gl(c, Offset(138, y), Offset(481, y + 20), const Color(0xFFE4D3B3), 2);
    }
    _gp(c, const [
      Offset(125, 381),
      Offset(488, 410),
      Offset(620, 327),
      Offset(620, 348),
      Offset(488, 436),
      Offset(125, 407),
    ], const Color(0xFFACAA91));
    _gl(
      c,
      const Offset(132, 387),
      const Offset(484, 418),
      const Color(0xFFD8D5B5),
      9,
    );
    // Mái ngói dốc, có cạnh và từng hàng ngói.
    _gp(c, const [
      Offset(98, 218),
      Offset(290, 84),
      Offset(520, 218),
    ], const Color(0xFFBC7C6B));
    _gp(c, const [
      Offset(290, 84),
      Offset(406, 31),
      Offset(637, 149),
      Offset(520, 218),
    ], const Color(0xFFAA6E61));
    _gl(
      c,
      const Offset(100, 220),
      const Offset(290, 84),
      const Color(0xFFF0C6A4),
      12,
    );
    _gl(
      c,
      const Offset(290, 84),
      const Offset(520, 220),
      const Color(0xFFE6B095),
      12,
    );
    _gl(
      c,
      const Offset(520, 220),
      const Offset(638, 150),
      const Color(0xFFD49A80),
      10,
    );
    for (var i = 1; i < 5; i++) {
      final y = 95 + i * 24.0;
      final left = 290 - (y - 84) * 1.44, right = 290 + (y - 84) * 1.70;
      _gl(
        c,
        Offset(left + 11, y),
        Offset(right - 11, y),
        const Color(0xFFD99D86),
        4,
      );
      for (var x = left + 30; x < right - 15; x += 48) {
        _gl(
          c,
          Offset(x, y - 12),
          Offset(x - 6, y - 1),
          const Color(0xFFC68A75),
          2,
        );
      }
    }
    _gr(c, const Rect.fromLTWH(449, 56, 38, 77), 5, const Color(0xFFBC9F89));
    _gr(c, const Rect.fromLTWH(441, 53, 53, 13), 5, const Color(0xFFE3C6AC));
    _gc(c, const Offset(292, 175), 26, const Color(0xFFF9ECCF));
    _gc(c, const Offset(292, 175), 18, const Color(0xFF96BDB2));
    _gl(
      c,
      const Offset(292, 159),
      const Offset(292, 191),
      const Color(0xFFEDE2BE),
      4,
    );
    _gl(
      c,
      const Offset(276, 175),
      const Offset(308, 175),
      const Color(0xFFEDE2BE),
      4,
    );
    // Cửa sau mở về phía hiên.
    _gr(
      c,
      const Rect.fromLTWH(297, 272, 101, 133),
      14,
      const Color(0xFFB59570),
    );
    _gr(c, const Rect.fromLTWH(306, 282, 83, 123), 10, const Color(0xFF6A775C));
    _gr(c, const Rect.fromLTWH(310, 285, 71, 119), 9, const Color(0xFF394E42));
    _gp(c, const [
      Offset(308, 284),
      Offset(349, 297),
      Offset(349, 410),
      Offset(308, 403),
    ], const Color(0xFFA6B89A));
    _gl(
      c,
      const Offset(313, 293),
      const Offset(343, 302),
      const Color(0xFFD7DDC0),
      3,
    );
    _gc(c, const Offset(341, 353), 4, const Color(0xFFF4D28A));
    for (var j = 0; j < 3; j++) {
      _gr(
        c,
        Rect.fromLTWH(286 - j * 9.0, 404 + j * 10.0, 124 + j * 18.0, 13),
        4,
        Color.lerp(const Color(0xFFD8C6A4), const Color(0xFFB5AF8F), j / 3)!,
      );
    }
    for (final x in [178.0, 429.0]) {
      _gr(c, Rect.fromLTWH(x - 35, 266, 70, 77), 10, const Color(0xFFB4A285));
      _gr(
        c,
        Rect.fromLTWH(x - 29, 272, 58, 64),
        7,
        dark ? const Color(0xFFCFBD83) : const Color(0xFF9ABBB0),
      );
      _gl(c, Offset(x, 274), Offset(x, 337), const Color(0xFFF8EBCB), 5);
      _gl(
        c,
        Offset(x - 27, 302),
        Offset(x + 27, 302),
        const Color(0xFFF8EBCB),
        5,
      );
      _gr(c, Rect.fromLTWH(x - 39, 341, 78, 12), 5, const Color(0xFFC18C6A));
      for (var i = 0; i < 5; i++) {
        _gc(
          c,
          Offset(x - 26 + i * 13.0, 337 - i % 2 * 7),
          9,
          const Color(0xFF769458),
        );
        _gc(
          c,
          Offset(x - 26 + i * 13.0, 329 - i % 2 * 7),
          5,
          const Color(0xFFE8B1A9),
        );
      }
    }
    // Đèn hiên và biển lá nhỏ.
    _gl(
      c,
      const Offset(278, 290),
      const Offset(278, 313),
      const Color(0xFF8E795B),
      4,
    );
    _gr(c, const Rect.fromLTWH(267, 309, 23, 31), 6, const Color(0xFFC5AC77));
    _gr(c, const Rect.fromLTWH(272, 314, 13, 20), 4, const Color(0xFFFFE3A2));
  }

  void _pond(Canvas c) {
    _go(c, const Rect.fromLTWH(658, 249, 220, 178), const Color(0xFF8DA782));
    _go(c, const Rect.fromLTWH(669, 246, 201, 163), const Color(0xFFCAD0AB));
    const water = Rect.fromLTWH(679, 254, 180, 141);
    c.drawOval(
      water,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF83B8BA), Color(0xFFAAD3C5)],
        ).createShader(water),
    );
    for (var i = 0; i < 4; i++) {
      c.drawArc(
        Rect.fromLTWH(703 + i * 21.0, 284 + i % 2 * 25.0, 56, 17),
        .15,
        2.5,
        false,
        Paint()
          ..color = const Color(0x70EAF6E0)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
    _go(c, const Rect.fromLTWH(790, 345, 36, 17), const Color(0xFF719D78));
    _gc(c, const Offset(809, 344), 6, const Color(0xFFF1B8B9));
    for (var i = 0; i < 9; i++) {
      final a = i * math.pi * 2 / 9;
      _go(
        c,
        Rect.fromCenter(
          center: Offset(768 + math.cos(a) * 99, 329 + math.sin(a) * 76),
          width: 24,
          height: 17,
        ),
        const Color(0xFFC7C7A6),
      );
    }
  }

  @override
  bool shouldRepaint(_GardenLandscape oldDelegate) => oldDelegate.dark != dark;
}

void _tree(
  Canvas c,
  Offset at,
  double scale,
  Color tone, {
  bool fruit = false,
}) {
  c.save();
  c.translate(at.dx, at.dy);
  c.scale(scale);
  _go(c, const Rect.fromLTWH(-61, -7, 122, 24), const Color(0x24627E44));
  _gl(c, Offset.zero, const Offset(0, -93), const Color(0xFF96764F), 18);
  _gl(
    c,
    const Offset(0, -65),
    const Offset(-29, -98),
    const Color(0xFF96764F),
    9,
  );
  _gc(c, const Offset(-31, -100), 45, Color.lerp(tone, Colors.black, .09)!);
  _gc(c, const Offset(31, -101), 47, tone);
  _gc(c, const Offset(0, -139), 47, Color.lerp(tone, Colors.white, .1)!);
  _go(
    c,
    const Rect.fromLTWH(-33, -167, 53, 20),
    Colors.white.withValues(alpha: .08),
  );
  if (fruit) {
    for (final p in [
      const Offset(-34, -111),
      const Offset(29, -134),
      const Offset(8, -87),
      const Offset(-9, -155),
      const Offset(48, -100),
    ]) {
      _gc(c, p, 10, const Color(0xFFDF886F));
      _gc(c, p + const Offset(-3, -3), 3, const Color(0xFFF4BB96));
      _gleaf(c, p - const Offset(0, 8), .8, .25, const Color(0xFF527B45));
    }
  }
  c.restore();
}

void _gardenCrop(
  Canvas c,
  Offset at,
  PetGardenCrop crop,
  double growth,
  bool ready,
) {
  c.save();
  c.translate(at.dx, at.dy);
  final size = .35 + growth * .65;
  if (crop == PetGardenCrop.apple) {
    _tree(
      c,
      Offset.zero,
      .30 + growth * .55,
      const Color(0xFF7FA168),
      fruit: ready,
    );
    c.restore();
    return;
  }
  c.scale(size);
  final stem = crop == PetGardenCrop.sunflower
      ? 57.0
      : crop == PetGardenCrop.tomato
      ? 40.0
      : 23.0;
  _gl(c, Offset.zero, Offset(0, -stem), const Color(0xFF6D9553), 4);
  _gleaf(c, const Offset(0, -8), -.9, .65, const Color(0xFF7A9E56));
  _gleaf(c, const Offset(0, -13), 1, .65, const Color(0xFF8DAE65));
  if (crop == PetGardenCrop.carrot) {
    if (growth > .5) {
      c.drawPath(
        Path()
          ..moveTo(-12, -7)
          ..quadraticBezierTo(-7, 18, 0, 26)
          ..quadraticBezierTo(10, 8, 11, -7)
          ..close(),
        Paint()..color = const Color(0xFFDF9A57),
      );
      _gl(
        c,
        const Offset(-5, 0),
        const Offset(3, 2),
        const Color(0xFFEDBE7E),
        2,
      );
    }
    for (var j = -1; j <= 1; j++) {
      _gleaf(c, const Offset(0, -7), j * .6, .7, const Color(0xFF729B50));
    }
  } else if (crop == PetGardenCrop.sunflower && growth > .45) {
    for (var j = 0; j < 10; j++) {
      final a = j * math.pi * 2 / 10;
      _go(
        c,
        Rect.fromCenter(
          center: Offset(math.cos(a) * 13, -stem + math.sin(a) * 13),
          width: 13,
          height: 16,
        ),
        const Color(0xFFF3D26D),
      );
    }
    _gc(c, Offset(0, -stem), 11, const Color(0xFF96744E));
    _gc(c, Offset(-3, -stem - 3), 3, const Color(0xFFBB965E));
  } else if (growth > .45) {
    for (var j = 0; j < 3; j++) {
      final p = Offset((j - 1) * 13.0, -15 - j % 2 * 13.0);
      if (crop == PetGardenCrop.strawberry) {
        c.drawPath(
          Path()
            ..moveTo(p.dx - 9, p.dy - 6)
            ..quadraticBezierTo(p.dx, p.dy - 14, p.dx + 9, p.dy - 6)
            ..quadraticBezierTo(p.dx + 10, p.dy + 3, p.dx, p.dy + 12)
            ..quadraticBezierTo(p.dx - 11, p.dy + 2, p.dx - 9, p.dy - 6),
          Paint()
            ..color = ready ? const Color(0xFFE38C85) : const Color(0xFFBAC180),
        );
        for (var k = 0; k < 3; k++) {
          _gc(
            c,
            p + Offset((k - 1) * 3.0, k % 2 * 4.0),
            1,
            const Color(0xFFFFE8B0),
          );
        }
        _gleaf(c, p - const Offset(0, 5), 1.2, .28, const Color(0xFF5D8B4F));
      } else {
        _gc(
          c,
          p,
          10,
          ready ? const Color(0xFFDF9273) : const Color(0xFFA3B773),
        );
        _gleaf(c, p - const Offset(0, 7), .5, .25, const Color(0xFF628C4D));
        _gc(c, p + const Offset(-3, -3), 2, const Color(0x55FFF5CD));
      }
    }
  }
  c.restore();
}

class _GardenPlants extends CustomPainter {
  const _GardenPlants({required this.garden, required this.now, this.selected});
  final PetCareGarden garden;
  final DateTime now;
  final int? selected;
  @override
  void paint(Canvas c, Size size) {
    for (var i = 0; i < PetGardenMap.plots.length; i++) {
      final at = PetGardenMap.plots[i], plant = garden.plots[i];
      final bed = i < 6;
      _go(
        c,
        Rect.fromCenter(
          center: at + const Offset(3, 8),
          width: bed ? 167 : 113,
          height: bed ? 105 : 66,
        ),
        const Color(0x23607A43),
      );
      if (bed) {
        _gr(
          c,
          Rect.fromCenter(
            center: at + const Offset(0, 6),
            width: 160,
            height: 103,
          ),
          22,
          const Color(0xFFAD8964),
        );
        _gr(
          c,
          Rect.fromCenter(center: at, width: 160, height: 97),
          22,
          const Color(0xFFD3B48A),
        );
        _gr(
          c,
          Rect.fromCenter(center: at, width: 143, height: 80),
          17,
          plant?.wateredAt != null
              ? const Color(0xFF91745B)
              : const Color(0xFFAC8A66),
        );
        for (var row = -1; row <= 1; row++) {
          _gl(
            c,
            at + Offset(-55, row * 21.0),
            at + Offset(55, row * 21.0),
            const Color(0x33715C43),
            4,
          );
        }
      } else {
        _go(
          c,
          Rect.fromCenter(center: at, width: 93, height: 49),
          const Color(0xFFA4A474),
        );
      }
      if (selected == i) {
        c.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: at,
              width: bed ? 172 : 120,
              height: bed ? 110 : 78,
            ),
            const Radius.circular(24),
          ),
          Paint()
            ..color = const Color(0xFFEADB9A)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 4,
        );
      }
      if (plant != null) {
        if (bed) {
          for (var x = -1; x <= 1; x++) {
            _gardenCrop(
              c,
              at + Offset(x * 43.0, x.isEven ? 12 : -4),
              plant.crop,
              plant.growth(now),
              plant.ready(now),
            );
          }
        } else {
          _gardenCrop(c, at, plant.crop, plant.growth(now), plant.ready(now));
        }
        if (plant.wateredAt == null || plant.ready(now)) {
          final p = at + Offset(bed ? 66 : 38, bed ? -38 : -115);
          _gc(c, p + const Offset(0, 3), 16, const Color(0x17637B4B));
          _gc(c, p, 16, const Color(0xFFFDF7DB));
          if (plant.wateredAt == null) {
            c.drawPath(
              Path()
                ..moveTo(p.dx, p.dy - 10)
                ..cubicTo(
                  p.dx - 14,
                  p.dy + 5,
                  p.dx - 6,
                  p.dy + 11,
                  p.dx,
                  p.dy + 9,
                )
                ..cubicTo(p.dx + 11, p.dy + 9, p.dx + 9, p.dy, p.dx, p.dy - 10),
              Paint()..color = const Color(0xFF77ACBA),
            );
          } else {
            _gl(
              c,
              p + const Offset(-7, 0),
              p + const Offset(-2, 5),
              const Color(0xFF76965A),
              3,
            );
            _gl(
              c,
              p + const Offset(-2, 5),
              p + const Offset(8, -6),
              const Color(0xFF76965A),
              3,
            );
          }
        }
      } else {
        _gl(
          c,
          at - const Offset(7, 0),
          at + const Offset(7, 0),
          const Color(0x80F7E8BE),
          2.5,
        );
        _gl(
          c,
          at - const Offset(0, 7),
          at + const Offset(0, 7),
          const Color(0x80F7E8BE),
          2.5,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_GardenPlants old) =>
      old.garden != garden || old.now != now || old.selected != selected;
}

class _GardenActors extends CustomPainter {
  _GardenActors({
    required this.motions,
    required this.frame,
    required this.progress,
    required this.dark,
    required this.animate,
    required this.effect,
  }) : super(repaint: frame);
  final List<_GardenPetMotion> motions;
  final ValueNotifier<double> frame;
  final PetCareProgress progress;
  final bool dark, animate;
  final (int, _GardenTool, double)? effect;
  @override
  void paint(Canvas c, Size size) {
    final order = [0, 1]
      ..sort((a, b) => motions[a].feet.dy.compareTo(motions[b].feet.dy));
    for (final i in order) {
      final pet = PetCarePet.values[i];
      if (progress.vitalsFor(pet).sleeping) continue;
      final motion = motions[i];
      final scale = 2.1 * petCareGrowth(progress.bondPoints).clamp(.70, 1.15);
      c.save();
      c.translate(motion.feet.dx, motion.feet.dy);
      c.scale(scale);
      c.translate(-motion.feet.dx, -motion.feet.dy);
      HomeCompanionPainter(
        motion: motion,
        darkMode: dark,
        showEffects: animate,
        bodyYaw: motion.yaw,
        character: pet == PetCarePet.rabbit
            ? HomeCompanionCharacter.bunny
            : HomeCompanionCharacter.bear,
        care: progress.vitalsFor(pet),
        petOutfit: progress.outfitFor(pet),
      ).paint(c, size);
      c.restore();
    }
    final fx = effect;
    if (fx == null || !animate) return;
    final t = (frame.value - fx.$3) / 1.6;
    if (t < 0 || t > 1) return;
    final at = PetGardenMap.plots[fx.$1];
    if (fx.$2 == _GardenTool.water) {
      c.save();
      c.translate(at.dx + 55, at.dy - 65);
      c.rotate(-.4);
      _gr(c, const Rect.fromLTWH(-18, -11, 41, 34), 9, const Color(0xFF7FAEB4));
      _gp(c, const [
        Offset(-17, -5),
        Offset(-39, -13),
        Offset(-44, -3),
        Offset(-17, 13),
      ], const Color(0xFF90BDC0));
      c.drawArc(
        const Rect.fromLTWH(8, -18, 31, 35),
        -1.5,
        3.8,
        false,
        Paint()
          ..color = const Color(0xFF6F979D)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5,
      );
      c.restore();
      for (var i = 0; i < 11; i++) {
        final f = (t * 2 + i / 11) % 1;
        final p = at + Offset(10 - f * 28 + i % 3 * 7, -68 + f * 66);
        _go(
          c,
          Rect.fromCenter(center: p, width: 4, height: 9),
          const Color(0xCBA4D8DC),
        );
      }
    } else {
      for (var i = 0; i < 8; i++) {
        final a = i * math.pi * 2 / 8;
        final p =
            at +
            Offset(
              math.cos(a) * (20 + t * 45),
              -30 + math.sin(a) * 25 - t * 38,
            );
        _gc(c, p, 3.5 * (1 - t), const Color(0xFFF9E5A3));
      }
    }
  }

  @override
  bool shouldRepaint(_GardenActors old) =>
      old.progress != progress ||
      old.animate != animate ||
      old.effect != effect ||
      old.dark != dark;
}

class _GardenSeedIcon extends CustomPainter {
  const _GardenSeedIcon(this.crop);
  final PetGardenCrop crop;
  @override
  void paint(Canvas c, Size size) {
    c.save();
    c.translate(size.width / 2, size.height * .83);
    final scale = size.shortestSide / (crop.isTree ? 175 : 83);
    c.scale(scale);
    _gardenCrop(c, Offset.zero, crop, 1, true);
    c.restore();
  }

  @override
  bool shouldRepaint(_GardenSeedIcon old) => old.crop != crop;
}

class _GardenMapSurroundings extends CustomPainter {
  const _GardenMapSurroundings();
  @override
  void paint(Canvas c, Size size) {
    c.drawRect(Offset.zero & size, Paint()..color = const Color(0xFFA7C47D));
    c.save();
    c.translate(-PetGardenMap.bounds.left, -PetGardenMap.bounds.top);
    c.drawOval(
      const Rect.fromLTWH(-250, -190, 1460, 1430),
      Paint()
        ..color = const Color(0xFFD4C69D)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 90,
    );
    _gl(
      c,
      const Offset(579, 1030),
      const Offset(620, 1220),
      const Color(0xFFD4C69D),
      100,
    );
    _gl(
      c,
      const Offset(940, 605),
      const Offset(1210, 605),
      const Color(0xFFD4C69D),
      100,
    );
    for (var i = 0; i < 54; i++) {
      final a = i * math.pi * 2 / 54;
      final p = Offset(
        480 + math.cos(a) * (830 + i % 3 * 34),
        520 + math.sin(a) * (800 + i % 4 * 28),
      );
      _tree(
        c,
        p,
        1 + i % 3 * .12,
        i.isEven ? const Color(0xFF6C9864) : const Color(0xFF86A969),
      );
    }
    c.restore();
  }

  @override
  bool shouldRepaint(_GardenMapSurroundings old) => false;
}
