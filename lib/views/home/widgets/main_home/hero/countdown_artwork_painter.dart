part of 'countdown_artwork_surface.dart';

/// Tọa độ chuẩn hóa giúp giữ hình và nét ở Home, editor và thumbnail.
class CountdownArtworkPainter extends CustomPainter {
  CountdownArtworkPainter({
    required this.design,
    this.phase,
    this.ornaments = false,
    this.dark = false,
    this.transparent = false,
    this.progress,
  }) : super(repaint: phase);

  final CountdownArtworkDesign design;
  final Animation<double>? phase;
  final bool ornaments;
  final bool dark;
  final bool transparent;
  final double? progress;
  double get t => phase?.value ?? 0;
  double get sway => math.sin(t * math.pi * 2);
  Color get ink => design.ink;
  Color get accent => design.accent;
  static const cream = Color(0xFFFFFBEB);
  static const gold = Color(0xFFE6BB76);
  static const sage = Color(0xFF8AB29A);

  static Path silhouette(String key) => switch (key) {
    'ribbon_garden' =>
      Path()
        ..moveTo(.22, .16)
        ..lineTo(.78, .16)
        ..quadraticBezierTo(.91, .16, .91, .30)
        ..lineTo(.91, .76)
        ..quadraticBezierTo(.91, .88, .80, .88)
        ..quadraticBezierTo(.72, .95, .64, .88)
        ..quadraticBezierTo(.56, .95, .48, .88)
        ..quadraticBezierTo(.40, .95, .32, .88)
        ..quadraticBezierTo(.09, .91, .09, .76)
        ..lineTo(.09, .30)
        ..quadraticBezierTo(.09, .16, .22, .16)
        ..close(),
    'moon_pearl' => Path.combine(
      PathOperation.union,
      Path.combine(
        PathOperation.difference,
        Path()..addOval(const Rect.fromLTWH(.06, .06, .87, .87)),
        Path()..addOval(const Rect.fromLTWH(.34, -.03, .78, .80)),
      ),
      Path()..addRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(.29, .27, .62, .58),
          const Radius.circular(.14),
        ),
      ),
    ),
    'botanical' =>
      Path()
        ..moveTo(.13, .12)
        ..cubicTo(.58, -.02, .99, .20, .90, .58)
        ..cubicTo(.87, .87, .46, .99, .15, .85)
        ..cubicTo(.05, .59, .19, .38, .13, .12)
        ..close(),
    'floating_hearts' => _heart(const Rect.fromLTWH(.10, .04, .80, .77)),
    'glass' =>
      Path()
        ..moveTo(.27, .13)
        ..lineTo(.72, .13)
        ..quadraticBezierTo(.86, .14, .87, .28)
        ..lineTo(.90, .77)
        ..quadraticBezierTo(.90, .90, .77, .91)
        ..lineTo(.22, .91)
        ..quadraticBezierTo(.09, .90, .10, .77)
        ..lineTo(.13, .29)
        ..quadraticBezierTo(.14, .17, .27, .13)
        ..close(),
    'glow' => _softStar(const Offset(.5, .5), .45, .35, 8),
    'candy' => _petals(const Offset(.445, .415), .348, .008, 10),
    'galaxy' => Path()..addOval(const Rect.fromLTWH(.14, .10, .72, .80)),
    'aurora' =>
      Path()
        ..moveTo(.11, .22)
        ..cubicTo(.34, .05, .49, .22, .72, .09)
        ..quadraticBezierTo(.93, .08, .91, .28)
        ..cubicTo(.85, .47, .95, .63, .84, .87)
        ..cubicTo(.66, 1.01, .40, .81, .20, .91)
        ..quadraticBezierTo(.05, .94, .09, .77)
        ..cubicTo(.16, .52, .03, .38, .11, .22)
        ..close(),
    'crystal' =>
      Path()
        ..moveTo(.27, .08)
        ..lineTo(.74, .08)
        ..lineTo(.94, .31)
        ..lineTo(.87, .70)
        ..lineTo(.50, .95)
        ..lineTo(.13, .70)
        ..lineTo(.06, .31)
        ..close(),
    'fireworks' => Path.combine(
      PathOperation.difference,
      Path()..addRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(.05, .16, .9, .68),
          const Radius.circular(.075),
        ),
      ),
      Path()
        ..addOval(Rect.fromCircle(center: const Offset(.045, .5), radius: .065))
        ..addOval(
          Rect.fromCircle(center: const Offset(.955, .5), radius: .065),
        ),
    ),
    'lava' =>
      Path()
        ..moveTo(.22, .13)
        ..cubicTo(.42, .00, .56, .18, .76, .12)
        ..cubicTo(1.01, .05, .88, .48, .93, .69)
        ..cubicTo(.98, .94, .83, .90, .79, .79)
        ..cubicTo(.76, .93, .64, 1.00, .58, .87)
        ..cubicTo(.44, .79, .44, .99, .33, .91)
        ..cubicTo(.29, .76, .16, .94, .11, .74)
        ..cubicTo(.02, .49, .06, .24, .22, .13)
        ..close(),
    'cherry_blossom' => _cherryFlower(),
    'meteor_shower' =>
      Path()
        ..moveTo(.35, .13)
        ..lineTo(.71, .07)
        ..quadraticBezierTo(.84, .05, .91, .21)
        ..lineTo(.97, .54)
        ..quadraticBezierTo(1, .68, .86, .77)
        ..lineTo(.55, .90)
        ..quadraticBezierTo(.39, .95, .30, .81)
        ..lineTo(.17, .49)
        ..quadraticBezierTo(.11, .31, .35, .13)
        ..close(),
    'deep_ocean' =>
      Path()
        ..moveTo(.14, .73)
        ..cubicTo(.00, .64, .06, .31, .20, .34)
        ..cubicTo(.13, .11, .34, .05, .39, .20)
        ..cubicTo(.39, .01, .63, .01, .62, .20)
        ..cubicTo(.77, .02, .92, .20, .81, .34)
        ..cubicTo(.96, .23, 1.00, .60, .86, .74)
        ..lineTo(.69, .89)
        ..quadraticBezierTo(.50, 1, .31, .89)
        ..close(),
    'golden_sunset' =>
      Path()
        ..moveTo(.08, .89)
        ..lineTo(.08, .45)
        ..cubicTo(.08, -.04, .92, -.04, .92, .45)
        ..lineTo(.92, .89)
        ..quadraticBezierTo(.5, .96, .08, .89)
        ..close(),
    'neon_pulse' =>
      Path()
        ..addRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(.05, .14, .90, .72),
            const Radius.circular(.075),
          ),
        )
        ..addRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(.23, .81, .54, .10),
            const Radius.circular(.03),
          ),
        ),
    'default' =>
      Path()
        ..moveTo(.09, .29)
        ..lineTo(.45, .055)
        ..quadraticBezierTo(.50, .025, .55, .055)
        ..lineTo(.91, .29)
        ..lineTo(.91, .86)
        ..quadraticBezierTo(.91, .91, .86, .91)
        ..lineTo(.14, .91)
        ..quadraticBezierTo(.09, .91, .09, .86)
        ..close(),
    _ => Path()..addOval(const Rect.fromLTWH(.06, .06, .88, .88)),
  };

  static Path _cherryFlower() {
    var flower = Path()
      ..addOval(Rect.fromCircle(center: const Offset(.5, .5), radius: .28));
    for (var i = 0; i < 5; i++) {
      final angle = -math.pi / 2 + i * math.pi * 2 / 5;
      final center = Offset(
        .5 + math.cos(angle) * .22,
        .5 + math.sin(angle) * .22,
      );
      flower = Path.combine(
        PathOperation.union,
        flower,
        Path()..addOval(Rect.fromCircle(center: center, radius: .23)),
      );
    }
    return flower;
  }

  static Path _heart(Rect r) {
    final p = Path()
      ..moveTo(.5, .20)
      ..cubicTo(.17, -.19, -.20, .23, .15, .56)
      ..quadraticBezierTo(.26, .70, .5, .97)
      ..quadraticBezierTo(.74, .70, .85, .56)
      ..cubicTo(1.20, .23, .83, -.19, .5, .20)
      ..close();
    return p.transform(
      Matrix4.identity().storage
        ..[0] = r.width
        ..[5] = r.height
        ..[12] = r.left
        ..[13] = r.top,
    );
  }

  static Path _petals(Offset c, double radius, double depth, int count) {
    final p = Path();
    for (var i = 0; i <= 160; i++) {
      final a = i / 160 * math.pi * 2 - math.pi / 2;
      final r = radius + depth * math.cos((a + math.pi / 2) * count);
      final x = c.dx + math.cos(a) * r;
      final y = c.dy + math.sin(a) * r;
      if (i == 0) {
        p.moveTo(x, y);
      } else {
        p.lineTo(x, y);
      }
    }
    return p..close();
  }

  static Path _softStar(Offset c, double outer, double inner, int points) {
    final p = Path();
    final nodes = <Offset>[];
    for (var i = 0; i < points * 2; i++) {
      final a = -math.pi / 2 + math.pi * i / points;
      final r = i.isEven ? outer : inner;
      nodes.add(c + Offset(math.cos(a) * r, math.sin(a) * r));
    }
    Offset midpoint(Offset a, Offset b) => (a + b) / 2;
    final start = midpoint(nodes.last, nodes.first);
    p.moveTo(start.dx, start.dy);
    for (var i = 0; i < nodes.length; i++) {
      final next = midpoint(nodes[i], nodes[(i + 1) % nodes.length]);
      p.quadraticBezierTo(nodes[i].dx, nodes[i].dy, next.dx, next.dy);
    }
    return p..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final edge = math.min(size.width, size.height);
    canvas.save();
    canvas.translate((size.width - edge) / 2, (size.height - edge) / 2);
    canvas.scale(edge);
    if (ornaments) {
      _paintOrnaments(canvas);
    } else {
      _paintSurface(canvas);
    }
    canvas.restore();
  }

  void _paintSurface(Canvas c) {
    if (design.key == 'candy') {
      _line(
        c,
        const Offset(.46, .58),
        const Offset(.78, .94),
        const Color(0xFFE1C3AE),
        .042,
      );
      _line(c, const Offset(.46, .58), const Offset(.77, .935), cream, .028);
      for (var i = 0; i < 4; i++) {
        final p = Offset(.625 + i * .034, .776 + i * .038);
        _line(
          c,
          p - const Offset(.010, -.005),
          p + const Offset(.014, -.014),
          design.wash,
          .013,
        );
      }
    }
    if (design.key == 'galaxy') {
      c.save();
      // Quỹ đạo nằm ở mép dưới để không cắt nhãn "ngày yêu" ở giữa mặt.
      c.translate(.5, .78);
      c.rotate(-.25);
      c.drawOval(
        const Rect.fromLTWH(-.47, -.12, .94, .24),
        Paint()
          ..color = accent.withValues(alpha: .30)
          ..style = PaintingStyle.stroke
          ..strokeWidth = .055,
      );
      c.drawOval(
        const Rect.fromLTWH(-.48, -.12, .96, .24),
        Paint()
          ..color = gold.withValues(alpha: .65)
          ..style = PaintingStyle.stroke
          ..strokeWidth = .009,
      );
      c.restore();
    }
    if (design.key == 'meteor_shower') {
      for (var i = 0; i < 3; i++) {
        final end = Offset(.48, .58 + i * .08);
        final begin = Offset(.03 + i * .03, .85 + i * .04);
        _line(
          c,
          begin,
          end,
          i == 1 ? gold : accent.withValues(alpha: .5),
          .022 - i * .004,
        );
      }
    }
    final path = silhouette(design.key);
    c.save();
    c.translate(0, .016);
    c.drawPath(
      path,
      Paint()
        ..color = ink.withValues(alpha: dark ? .16 : .09)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, .023),
    );
    c.restore();
    final paper = design.night ? design.ink : design.paper;
    final fill = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        paper.withValues(alpha: transparent ? .82 : 1),
        design.wash.withValues(alpha: transparent ? .72 : 1),
      ],
    );
    c.drawPath(
      path,
      Paint()..shader = fill.createShader(const Rect.fromLTWH(0, 0, 1, 1)),
    );
    c.drawPath(
      path,
      Paint()
        ..color = design.night
            ? accent.withValues(alpha: .60)
            : ink.withValues(alpha: .22)
        ..style = PaintingStyle.stroke
        ..strokeWidth = .005,
    );

    switch (design.key) {
      case 'ribbon_garden':
        _rrect(
          c,
          const Rect.fromLTWH(.135, .205, .73, .63),
          .095,
          Colors.white.withValues(alpha: .35),
          stroke: ink.withValues(alpha: .15),
        );
        for (final x in [.14, .86]) {
          for (var i = 0; i < 4; i++) {
            _dot(c, Offset(x, .36 + i * .10), .004, accent);
          }
        }
      case 'moon_pearl':
        final crescent = Path.combine(
          PathOperation.difference,
          Path()..addOval(const Rect.fromLTWH(.07, .06, .86, .86)),
          Path()..addOval(const Rect.fromLTWH(.32, -.05, .76, .79)),
        );
        c.drawPath(
          crescent,
          Paint()
            ..shader = const LinearGradient(
              colors: [Color(0xFFFFE7B5), Color(0xFFF1CC85)],
            ).createShader(const Rect.fromLTWH(0, 0, 1, 1)),
        );
        _rrect(
          c,
          const Rect.fromLTWH(.27, .265, .65, .585),
          .14,
          design.paper.withValues(alpha: .70),
          stroke: accent.withValues(alpha: .28),
        );
        _curve(
          c,
          const Offset(.10, .39),
          const Offset(.12, .69),
          const Offset(.32, .79),
          cream.withValues(alpha: .80),
          .012,
        );
      case 'botanical':
        _curve(
          c,
          const Offset(.21, .22),
          const Offset(.25, .64),
          const Offset(.78, .86),
          sage.withValues(alpha: .16),
          .009,
        );
        for (var i = 0; i < 4; i++) {
          final p = Offset(.18 + i * .12, .47 + i * .09);
          _line(
            c,
            p,
            p + Offset(-.01, -.11 + i * .01),
            sage.withValues(alpha: .12),
            .004,
          );
        }
        _curve(
          c,
          const Offset(.79, .83),
          const Offset(.90, .93),
          const Offset(.94, .92),
          ink.withValues(alpha: .6),
          .012,
        );
      case 'floating_hearts':
        _curve(
          c,
          const Offset(.15, .26),
          const Offset(.11, .09),
          const Offset(.34, .11),
          Colors.white.withValues(alpha: .85),
          .022,
        );
        _line(c, const Offset(.39, .74), const Offset(.42, .85), accent, .005);
        _line(c, const Offset(.61, .74), const Offset(.58, .85), accent, .005);
        _rrect(
          c,
          const Rect.fromLTWH(.38, .83, .24, .115),
          .025,
          const Color(0xFFECCAA6),
          stroke: const Color(0xFFBC9875),
        );
        for (var i = 0; i < 4; i++) {
          _line(
            c,
            Offset(.41 + i * .055, .84),
            Offset(.41 + i * .055, .94),
            const Color(0xFFCEAC8D),
            .003,
          );
        }
      case 'glass':
        c.save();
        c.clipPath(path);
        final sheen = Path()
          ..moveTo(.12, .19)
          ..lineTo(.33, .13)
          ..lineTo(.07, .77)
          ..close();
        c.drawPath(sheen, Paint()..color = Colors.white.withValues(alpha: .68));
        c.drawPath(
          Path()
            ..moveTo(.82, .24)
            ..lineTo(.90, .79)
            ..lineTo(.66, .92)
            ..close(),
          Paint()..color = accent.withValues(alpha: .20),
        );
        c.restore();
        _dot(c, const Offset(.51, .19), .025, const Color(0xFFB5D8E2));
        _dot(c, const Offset(.51, .19), .013, design.paper);
        _curve(
          c,
          const Offset(.505, .17),
          const Offset(.44, .005),
          const Offset(.61, .05),
          gold,
          .011,
        );
      case 'glow':
        c.drawPath(
          _softStar(const Offset(.5, .5), .36, .32, 8),
          Paint()
            ..color = Colors.white.withValues(alpha: .4)
            ..style = PaintingStyle.stroke
            ..strokeWidth = .008,
        );
        _dot(
          c,
          const Offset(.17, .34),
          .012,
          Colors.white.withValues(alpha: .82),
        );
      case 'candy':
        c.save();
        c.clipPath(path);
        const center = Offset(.445, .415);
        for (var i = 0; i < 7; i++) {
          final a = i * math.pi * 2 / 7;
          final p = Path()
            ..moveTo(
              center.dx + .265 * math.cos(a),
              center.dy + .265 * math.sin(a),
            )
            ..cubicTo(
              center.dx + .34 * math.cos(a - .24),
              center.dy + .34 * math.sin(a - .24),
              center.dx + .48 * math.cos(a + .43),
              center.dy + .48 * math.sin(a + .43),
              center.dx + .42 * math.cos(a + .6),
              center.dy + .42 * math.sin(a + .6),
            );
          c.drawPath(
            p,
            Paint()
              ..color = (i.isEven ? accent : const Color(0xFFF0A2BD))
                  .withValues(alpha: .72)
              ..style = PaintingStyle.stroke
              ..strokeWidth = .052
              ..strokeCap = StrokeCap.round,
          );
        }
        c.restore();
        _dot(c, center, .278, design.paper.withValues(alpha: .78));
        c.drawCircle(
          center,
          .294,
          Paint()
            ..color = Colors.white.withValues(alpha: .75)
            ..style = PaintingStyle.stroke
            ..strokeWidth = .008,
        );
        _curve(
          c,
          const Offset(.19, .28),
          const Offset(.25, .13),
          const Offset(.40, .12),
          Colors.white.withValues(alpha: .88),
          .016,
        );
      case 'galaxy':
        c.save();
        c.clipPath(path);
        for (var i = 0; i < 3; i++) {
          _curve(
            c,
            Offset(.06, .71 + i * .035),
            Offset(.46, .88 + i * .03),
            Offset(.98, .71 + i * .025),
            accent.withValues(alpha: .22),
            .018,
          );
        }
        c.restore();
      case 'aurora':
        c.save();
        c.clipPath(path);
        for (var i = 0; i < 5; i++) {
          final p = Path()
            ..moveTo(.05 + i * .028, .21)
            ..cubicTo(.33, .10, .57, .34, .94, .16 + i * .025);
          c.drawPath(
            p,
            Paint()
              ..color = (i.isEven ? accent : const Color(0xFFB5ABD8))
                  .withValues(alpha: .4)
              ..style = PaintingStyle.stroke
              ..strokeWidth = .027,
          );
        }
        c.restore();
      case 'crystal':
        final corners = [
          const Offset(.27, .08),
          const Offset(.74, .08),
          const Offset(.94, .31),
          const Offset(.87, .70),
          const Offset(.5, .95),
          const Offset(.13, .70),
          const Offset(.06, .31),
        ];
        final inner = [
          const Offset(.30, .19),
          const Offset(.71, .19),
          const Offset(.82, .33),
          const Offset(.76, .65),
          const Offset(.5, .81),
          const Offset(.24, .65),
          const Offset(.18, .33),
        ];
        for (var i = 0; i < corners.length; i++) {
          final next = (i + 1) % corners.length;
          final facet = Path()
            ..moveTo(corners[i].dx, corners[i].dy)
            ..lineTo(corners[next].dx, corners[next].dy)
            ..lineTo(inner[next].dx, inner[next].dy)
            ..lineTo(inner[i].dx, inner[i].dy)
            ..close();
          c.drawPath(
            facet,
            Paint()
              ..color = (i.isEven ? accent : Colors.white).withValues(
                alpha: .50,
              ),
          );
          _line(c, corners[i], inner[i], ink.withValues(alpha: .15), .004);
        }
      case 'fireworks':
        for (final x in [.145, .855]) {
          for (var i = 0; i < 9; i++) {
            _line(
              c,
              Offset(x, .22 + i * .064),
              Offset(x, .246 + i * .064),
              ink.withValues(alpha: .25),
              .004,
            );
          }
        }
        _line(
          c,
          const Offset(.23, .20),
          const Offset(.77, .20),
          Colors.white.withValues(alpha: .8),
          .009,
        );
      case 'lava':
        _curve(
          c,
          const Offset(.15, .41),
          const Offset(.10, .20),
          const Offset(.33, .17),
          Colors.white.withValues(alpha: .8),
          .021,
        );
        _dot(c, const Offset(.18, .47), .012, cream);
      case 'cherry_blossom':
        for (var i = 0; i < 5; i++) {
          final a = -math.pi / 2 + i * math.pi * 2 / 5;
          final start = Offset(.5 + math.cos(a) * .34, .5 + math.sin(a) * .34);
          final end = Offset(.5 + math.cos(a) * .435, .5 + math.sin(a) * .435);
          _line(c, start, end, accent.withValues(alpha: .65), .009);
          _dot(c, start, .008, gold);
        }
      case 'meteor_shower':
        _curve(
          c,
          const Offset(.35, .16),
          const Offset(.66, .03),
          const Offset(.85, .19),
          Colors.white.withValues(alpha: .75),
          .015,
        );
        _line(
          c,
          const Offset(.76, .82),
          const Offset(.93, .68),
          accent.withValues(alpha: .6),
          .014,
        );
      case 'deep_ocean':
        for (var i = 0; i < 7; i++) {
          final a = math.pi + .28 + i * (math.pi - .56) / 6;
          final end = Offset(.5 + math.cos(a) * .39, .49 + math.sin(a) * .38);
          final begin = Offset(.5 + math.cos(a) * .29, .49 + math.sin(a) * .28);
          _curve(
            c,
            begin,
            (begin + end) / 2 - const Offset(0, .015),
            end,
            accent.withValues(alpha: .65),
            .009,
          );
        }
        _curve(
          c,
          const Offset(.20, .81),
          const Offset(.5, .96),
          const Offset(.80, .81),
          Colors.white.withValues(alpha: .65),
          .015,
        );
      case 'golden_sunset':
        c.save();
        c.clipPath(path);
        c.drawPath(
          Path()
            ..moveTo(.07, .82)
            ..quadraticBezierTo(.24, .72, .47, .84)
            ..quadraticBezierTo(.74, .68, .93, .79)
            ..lineTo(.94, .96)
            ..lineTo(.06, .96)
            ..close(),
          Paint()..color = accent.withValues(alpha: .36),
        );
        _line(
          c,
          const Offset(.14, .85),
          const Offset(.85, .85),
          Colors.white.withValues(alpha: .6),
          .006,
        );
        _line(
          c,
          const Offset(.31, .90),
          const Offset(.64, .90),
          ink.withValues(alpha: .20),
          .004,
        );
        c.restore();
      case 'neon_pulse':
        _rrect(
          c,
          const Rect.fromLTWH(.105, .195, .79, .59),
          .045,
          const Color(0xFF514056).withValues(alpha: .5),
          stroke: accent.withValues(alpha: .3),
        );
        for (final x in [.105, .895]) {
          for (final y in [.20, .80]) {
            _dot(c, Offset(x, y), .010, const Color(0xFF85718C));
            _line(
              c,
              Offset(x - .005, y),
              Offset(x + .005, y),
              design.paper.withValues(alpha: .6),
              .002,
            );
          }
        }
        _rrect(
          c,
          const Rect.fromLTWH(.31, .825, .38, .05),
          .01,
          const Color(0xFF291F34),
          stroke: accent.withValues(alpha: .20),
        );
      case 'default':
        // Lá thư đứng trong phong bì; các đường gấp nằm ngoài vùng chữ.
        _rrect(
          c,
          const Rect.fromLTWH(.17, .15, .66, .665),
          .028,
          design.paper.withValues(alpha: transparent ? .82 : 1),
          stroke: ink.withValues(alpha: .17),
        );
        for (final left in [true, false]) {
          final fold = Path()
            ..moveTo(left ? .09 : .91, .31)
            ..lineTo(left ? .23 : .77, .79)
            ..lineTo(.5, .895)
            ..lineTo(left ? .09 : .91, .895)
            ..close();
          c.drawPath(fold, Paint()..color = design.wash.withValues(alpha: .88));
          _line(
            c,
            Offset(left ? .09 : .91, .31),
            Offset(left ? .23 : .77, .79),
            accent.withValues(alpha: .55),
            .003,
          );
        }
        _curve(
          c,
          const Offset(.16, .88),
          const Offset(.5, .78),
          const Offset(.84, .88),
          ink.withValues(alpha: .20),
          .004,
        );
        if (progress != null) {
          _line(
            c,
            const Offset(.18, .902),
            const Offset(.82, .902),
            accent.withValues(alpha: .2),
            .007,
          );
          _line(
            c,
            const Offset(.18, .902),
            Offset(.18 + .64 * progress!.clamp(0, 1), .902),
            gold,
            .007,
          );
        }
      default:
        break;
    }
  }

  void _paintOrnaments(Canvas c) {
    // Lớp ambient rất nhẹ nằm quanh silhouette. Các điểm được đặt ở mép
    // artwork để giữ vùng số/nhãn sạch, nhưng vẫn tạo cảm giác mỗi kiểu có
    // một bầu không khí riêng khi người dùng nhìn vào vòng đếm.
    _paintAmbientEffects(c);
    switch (design.key) {
      case 'ribbon_garden':
        _bow(c, const Offset(.5, .13), .24, -.04 + sway * .035, accent, ink);
        _sprig(c, const Offset(.13, .74), .19, -.3, sage);
        _flower(c, const Offset(.13, .80), .039, design.wash, gold);
        _butterfly(
          c,
          Offset(.85, .24 + sway * .014),
          .10,
          -.22 + sway * .09,
          gold,
        );
      case 'moon_pearl':
        _spark(
          c,
          const Offset(.75, .11),
          .045,
          gold,
          .65 + .25 * math.cos(t * math.pi * 2),
        );
        _spark(
          c,
          const Offset(.91, .23),
          .025,
          accent,
          .65 - .25 * math.cos(t * math.pi * 2),
        );
        _cloud(c, Offset(.15, .84 + sway * .008), .19, cream, smile: true);
        final pearl = Offset(.24 + sway * .012, .64);
        _curve(
          c,
          const Offset(.22, .30),
          const Offset(.23, .43),
          pearl,
          gold.withValues(alpha: .7),
          .004,
        );
        _dot(c, pearl, .031, cream);
        _dot(c, pearl - const Offset(.008, .008), .008, Colors.white);
      case 'botanical':
        _sprig(c, const Offset(.80, .80), .19, .7 + sway * .07, sage);
        _ladybug(c, Offset(.77, .15 + sway * .007), .102, .45 + sway * .04);
        _leaf(c, const Offset(.13, .72), .07, -.7 + sway * .08, accent);
      case 'floating_hearts':
        _cloud(c, Offset(.14, .71 + sway * .02), .19, cream);
        _cloud(c, Offset(.87, .62 - sway * .012), .16, cream);
        final heart = _heart(
          Rect.fromCenter(
            center: Offset(.82, .23 + sway * .025),
            width: .105,
            height: .11,
          ),
        );
        _sticker(c, heart, accent, ink.withValues(alpha: .25));
        for (var i = 0; i < 3; i++) {
          final p = Offset(.425 + i * .075, .855);
          final triangle = Path()
            ..moveTo(p.dx - .023, p.dy)
            ..lineTo(p.dx + .023, p.dy)
            ..lineTo(p.dx, p.dy + .036)
            ..close();
          c.drawPath(triangle, Paint()..color = i.isEven ? accent : cream);
        }
      case 'glass':
        // Một vệt phản sáng chậm ở mép thẻ, tránh chạy qua phần chữ.
        final y = .30 + t * .45;
        _line(
          c,
          Offset(.84, y),
          Offset(.857, y + .10),
          Colors.white.withValues(alpha: math.sin(t * math.pi).abs() * .7),
          .012,
        );
        _jellyfish(c, Offset(.83, .83 + sway * .015), .14, accent);
        for (var i = 0; i < 3; i++) {
          final p = Offset(.11 + i * .044, .62 - ((t + i * .28) % 1) * .25);
          c.drawCircle(
            p,
            .014 + i * .005,
            Paint()
              ..color = accent.withValues(alpha: .6)
              ..style = PaintingStyle.stroke
              ..strokeWidth = .004,
          );
        }
      case 'glow':
        final halo = Paint()
          ..color = gold.withValues(alpha: .13 + .07 * sway)
          ..style = PaintingStyle.stroke
          ..strokeWidth = .015
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, .02);
        c.drawPath(_softStar(const Offset(.5, .5), .46, .36, 8), halo);
        _littleStar(
          c,
          Offset(.80, .78 + sway * .008),
          .12,
          -.15,
          gold,
          sleepy: true,
        );
        _spark(c, const Offset(.11, .27), .034, gold, .7 + .25 * sway);
        _spark(c, const Offset(.86, .16), .024, accent, .7 - .25 * sway);
      case 'candy':
        _bow(
          c,
          const Offset(.63, .77),
          .19,
          -.67 + sway * .06,
          accent,
          const Color(0xFF4C949E),
        );
        _wrappedCandy(
          c,
          Offset(.83, .18 + sway * .016),
          .14,
          .38 + sway * .08,
          accent,
        );
        for (var i = 0; i < 3; i++) {
          final p = Offset(.12 + i * .037, .84 - i * .03 + sway * .006);
          _line(
            c,
            p,
            p + const Offset(.014, -.012),
            i.isEven ? accent : gold,
            .009,
          );
        }
      case 'galaxy':
        c.save();
        c.translate(.5, .78);
        c.rotate(-.25);
        c.drawArc(
          const Rect.fromLTWH(-.47, -.12, .94, .24),
          .04,
          math.pi - .08,
          false,
          Paint()
            ..color = accent.withValues(alpha: .48)
            ..style = PaintingStyle.stroke
            ..strokeWidth = .047,
        );
        c.drawArc(
          const Rect.fromLTWH(-.47, -.12, .94, .24),
          .04,
          math.pi - .08,
          false,
          Paint()
            ..color = gold.withValues(alpha: .72)
            ..style = PaintingStyle.stroke
            ..strokeWidth = .006,
        );
        c.restore();
        _ufo(c, Offset(.81, .13 + sway * .014), .16);
        _spark(c, const Offset(.13, .18), .031, gold, .65 + .25 * sway);
        _dot(
          c,
          Offset(
            .20 + .016 * math.cos(t * math.pi * 2),
            .84 + .014 * math.sin(t * math.pi * 2),
          ),
          .017,
          accent,
        );
      case 'aurora':
        for (var i = 0; i < 3; i++) {
          final x = .15 + i * .055;
          _curve(
            c,
            Offset(x, .37),
            Offset(x + .06 + sway * .015, .55),
            Offset(x - .02, .77),
            accent.withValues(alpha: .13),
            .015,
          );
        }
        _fox(c, Offset(.84, .81 + sway * .009), .16);
        _spark(c, const Offset(.82, .22), .024, gold, .65 + .2 * sway);
      case 'crystal':
        final end = Offset(.81, .12 + t * .14);
        _line(
          c,
          const Offset(.74, .08),
          end,
          Colors.white.withValues(alpha: .55),
          .010,
        );
        _gem(c, Offset(.82, .85 + sway * .01), .12, accent);
        _line(
          c,
          const Offset(.88, .70),
          Offset(.82, .83 + sway * .01),
          gold,
          .004,
        );
        _spark(c, const Offset(.13, .24), .028, gold, .7 + .2 * sway);
      case 'fireworks':
        for (var i = 0; i < 3; i++) {
          final p = Offset(.17 + i * .34, .12 + (i == 1 ? -.045 : .0));
          _burst(
            c,
            p,
            .046 + i * .003,
            (t + i * .30) % 1,
            i.isEven ? gold : accent,
          );
        }
        _partyPopper(c, const Offset(.13, .84), .18, -.33);
      case 'lava':
        _flame(c, Offset(.85, .77 + sway * .008), .18);
        for (var i = 0; i < 3; i++) {
          final rise = (t + i * .31) % 1;
          _dot(
            c,
            Offset(.16 + i * .024, .79 - rise * .18),
            .012 * (1 - rise * .5),
            accent.withValues(alpha: .5),
          );
        }
      case 'cherry_blossom':
        _curve(
          c,
          const Offset(.68, .83),
          const Offset(.87, .95),
          const Offset(.95, .84),
          const Color(0xFFA67F6C),
          .008,
        );
        _bird(c, Offset(.84, .84 + sway * .004), .13, -.10);
        for (var i = 0; i < 3; i++) {
          final f = (t + i * .31) % 1;
          _petal(
            c,
            Offset(.09 + .027 * math.sin(f * math.pi * 2 + i), .23 + f * .5),
            .04,
            i * .7 + f,
            accent,
          );
        }
      case 'meteor_shower':
        for (var i = 0; i < 3; i++) {
          final f = (t + i * .3) % 1;
          final p = Offset(.04 + f * .18, .90 - f * .13 + i * .025);
          _line(
            c,
            p,
            p + const Offset(.085, -.05),
            accent.withValues(alpha: math.sin(f * math.pi) * .7),
            .004,
          );
        }
        _rocket(c, Offset(.81, .12 + sway * .009), .16, .55);
        _spark(c, const Offset(.17, .16), .023, gold, .65 + .25 * sway);
      case 'deep_ocean':
        _pearlShell(c, const Offset(.5, .91), .17);
        _fish(c, Offset(.13, .75 + sway * .025), .13, sway * .10);
        for (var i = 0; i < 3; i++) {
          final f = (t + i * .33) % 1;
          final p = Offset(.87 + .02 * math.sin(f * math.pi), .80 - f * .25);
          c.drawCircle(
            p,
            .012 + i * .005,
            Paint()
              ..color = accent.withValues(alpha: .7)
              ..style = PaintingStyle.stroke
              ..strokeWidth = .004,
          );
        }
      case 'golden_sunset':
        _cloud(c, Offset(.23 + sway * .028, .18), .15, cream);
        _sailboat(c, Offset(.84, .85 + sway * .004), .16);
        _curve(
          c,
          const Offset(.81, .28),
          const Offset(.83, .23),
          const Offset(.86, .28),
          ink.withValues(alpha: .5),
          .005,
        );
        _curve(
          c,
          const Offset(.86, .28),
          const Offset(.89, .23),
          const Offset(.91, .28),
          ink.withValues(alpha: .5),
          .005,
        );
      case 'neon_pulse':
        final light = Color.lerp(
          accent,
          const Color(0xFFE5AFD3),
          .5 + .5 * sway,
        )!;
        for (var i = 0; i < 11; i++) {
          final h =
              .012 + .017 * (.5 + .5 * math.sin(t * math.pi * 2 + i * .7));
          _line(
            c,
            Offset(.33 + i * .034, .85 - h),
            Offset(.33 + i * .034, .85 + h),
            light,
            .006,
          );
        }
        _headphones(c, const Offset(.82, .19), .17, light);
        _musicNote(
          c,
          Offset(.13, .78 + sway * .007),
          .09,
          const Color(0xFFE8B7D9),
        );
      case 'default':
        _sticker(
          c,
          _petals(const Offset(.5, .862), .040, .005, 9),
          accent,
          ink,
        );
        c.drawPath(
          _heart(const Rect.fromLTWH(.481, .846, .038, .035)),
          Paint()..color = design.paper,
        );
        _local(
          c,
          Offset(.85 + sway * .012, .13 - sway * .009),
          .14,
          -.18 + sway * .055,
          () {
            final plane = Path()
              ..moveTo(-.5, -.22)
              ..lineTo(.5, -.32)
              ..lineTo(.13, .4)
              ..lineTo(-.04, .08)
              ..close();
            _sticker(c, plane, cream, ink.withValues(alpha: .5));
            _line(
              c,
              const Offset(-.04, .08),
              const Offset(.5, -.32),
              accent,
              .03,
            );
          },
        );
      default:
        break;
    }
  }

  void _paintAmbientEffects(Canvas c) {
    final pulse = .5 + .5 * math.sin(t * math.pi * 2);
    final breathe = .5 + .5 * math.cos(t * math.pi * 2);
    final soft = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = .008
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, .018);

    switch (design.key) {
      case 'ribbon_garden':
        // Bụi phấn hoa và ánh lấp lánh quanh chiếc nơ.
        for (var i = 0; i < 4; i++) {
          final f = (t + i * .23) % 1;
          final p = Offset(.08 + i * .035, .25 - f * .12);
          _spark(c, p, .014 + i * .003, gold, .18 + .18 * (1 - f));
        }
        _ambientHalo(
          c,
          const Offset(.50, .14),
          .13,
          accent,
          .06 + .035 * pulse,
        );
      case 'moon_pearl':
        // Quầng trăng mỏng và bụi sao trôi theo cung cong bên ngoài.
        c.drawCircle(
          const Offset(.19, .45),
          .39 + .012 * pulse,
          soft..color = gold.withValues(alpha: .12 + .04 * pulse),
        );
        for (var i = 0; i < 3; i++) {
          final a = -.9 + (t + i * .32) * math.pi * 2;
          final p = Offset(.19 + math.cos(a) * .40, .45 + math.sin(a) * .40);
          _spark(c, p, .014 + i * .004, i.isEven ? gold : accent, .28);
        }
      case 'botanical':
        // Hạt sáng như phấn hoa, chuyển động dọc theo đường chéo của lá.
        for (var i = 0; i < 4; i++) {
          final f = (t + i * .25) % 1;
          final p = Offset(.08 + f * .10, .25 + i * .16 - f * .05);
          _dot(c, p, .008 + .004 * (1 - f), accent.withValues(alpha: .24));
        }
        _ambientHalo(
          c,
          const Offset(.86, .78),
          .11,
          sage,
          .05 + .025 * breathe,
        );
      case 'default':
        // Ánh sáng giấy mờ quanh phong thư, không phủ lên chữ ở giữa.
        _ambientHalo(
          c,
          const Offset(.50, .50),
          .46,
          accent,
          .035 + .025 * pulse,
        );
        for (var i = 0; i < 3; i++) {
          final f = (t + i * .34) % 1;
          _dot(
            c,
            Offset(.11 + i * .39, .18 + f * .08),
            .006 + i * .002,
            cream.withValues(alpha: .28),
          );
        }
      case 'floating_hearts':
        // Nhịp tim lan thành hai vòng mờ ở ngoài mép trái/phải.
        for (var i = 0; i < 2; i++) {
          final p = Offset(i == 0 ? .13 : .87, .30 + i * .26);
          final heart = _heart(
            Rect.fromCenter(
              center: p,
              width: .065 + .012 * pulse,
              height: .068 + .012 * pulse,
            ),
          );
          c.drawPath(
            heart,
            Paint()
              ..color = accent.withValues(alpha: .22 - i * .04)
              ..style = PaintingStyle.stroke
              ..strokeWidth = .006,
          );
        }
      case 'glass':
        // Bọt khí trong veo nổi lên ở ngoài thẻ.
        for (var i = 0; i < 4; i++) {
          final f = (t + i * .22) % 1;
          final p = Offset(.08 + i * .04, .82 - f * .30);
          c.drawCircle(
            p,
            .010 + i * .004,
            Paint()
              ..color = Colors.white.withValues(alpha: .20 + .10 * (1 - f))
              ..style = PaintingStyle.stroke
              ..strokeWidth = .004,
          );
        }
        _ambientHalo(
          c,
          const Offset(.88, .31),
          .12,
          accent,
          .045 + .02 * pulse,
        );
      case 'glow':
        // Quầng sao thở nhẹ, giữ độ sáng thấp để không chói mắt.
        _ambientHalo(c, const Offset(.50, .50), .48, gold, .07 + .045 * pulse);
        for (var i = 0; i < 4; i++) {
          final a = -math.pi / 2 + i * math.pi / 2 + t * .25;
          _spark(
            c,
            Offset(.50 + math.cos(a) * .43, .50 + math.sin(a) * .43),
            .014,
            i.isEven ? gold : accent,
            .25 + .15 * breathe,
          );
        }
      case 'candy':
        // Hạt đường li ti và tia lấp lánh quanh que kẹo nghiêng.
        for (var i = 0; i < 5; i++) {
          final a = -.8 + i * .46 + t * .22;
          final p = Offset(.47 + math.cos(a) * .43, .48 + math.sin(a) * .43);
          _spark(c, p, .012 + i * .002, i.isEven ? accent : gold, .22);
        }
      case 'galaxy':
        // Các sao nhỏ chạy quanh quỹ đạo, tách khỏi mặt số hành tinh.
        for (var i = 0; i < 4; i++) {
          final a = t * math.pi * 2 + i * math.pi / 2;
          final p = Offset(.50 + math.cos(a) * .43, .76 + math.sin(a) * .12);
          _spark(c, p, .013 + i * .002, i.isEven ? gold : accent, .30);
        }
        _ambientHalo(
          c,
          const Offset(.82, .14),
          .09,
          accent,
          .045 + .02 * pulse,
        );
      case 'aurora':
        // Hai dải sáng mềm trôi ở ngoài mép trên, cùng nhịp với cực quang.
        for (var i = 0; i < 2; i++) {
          _curve(
            c,
            Offset(.04, .13 + i * .045 + sway * .012),
            Offset(.34, .02 + i * .02 + sway * .018),
            Offset(.96, .13 + i * .038 - sway * .012),
            accent.withValues(alpha: .12 - i * .025),
            .018 - i * .004,
          );
        }
        _spark(c, const Offset(.12, .22), .016, gold, .25 + .12 * pulse);
      case 'crystal':
        // Một vệt sáng quét qua các mặt cắt và hai tia phản chiếu ở góc.
        final f = (t * .8) % 1;
        _line(
          c,
          Offset(.15 + f * .70, .10),
          Offset(.22 + f * .70, .17),
          Colors.white.withValues(alpha: .26),
          .012,
        );
        _spark(c, const Offset(.12, .69), .017, accent, .24 + .12 * breathe);
        _spark(c, const Offset(.87, .28), .015, gold, .24 + .12 * pulse);
      case 'fireworks':
        // Vòng sáng nhỏ sau pháo hoa, chỉ nhấn nhẹ các góc.
        for (var i = 0; i < 3; i++) {
          final p = Offset(.17 + i * .34, .12 + (i == 1 ? -.045 : 0));
          c.drawCircle(
            p,
            .065 + .012 * ((t + i * .3) % 1),
            Paint()
              ..color = (i.isEven ? gold : accent).withValues(alpha: .10)
              ..style = PaintingStyle.stroke
              ..strokeWidth = .006,
          );
        }
      case 'lava':
        // Hơi ấm mờ và vài hạt than bay lên ở hai bên.
        _ambientHalo(
          c,
          const Offset(.83, .75),
          .15,
          accent,
          .07 + .035 * pulse,
        );
        for (var i = 0; i < 4; i++) {
          final f = (t + i * .27) % 1;
          _dot(
            c,
            Offset(.09 + i * .03, .80 - f * .22),
            .009 * (1 - f * .4),
            gold.withValues(alpha: .24 * (1 - f)),
          );
        }
      case 'cherry_blossom':
        // Cánh hoa rơi ngoài viền, mỗi cánh có đường bay riêng.
        for (var i = 0; i < 4; i++) {
          final f = (t + i * .24) % 1;
          _petal(
            c,
            Offset(
              .08 + i * .27 + .025 * math.sin(f * math.pi * 2),
              .12 + f * .66,
            ),
            .022,
            i * .8 + f,
            accent.withValues(alpha: .42),
          );
        }
      case 'meteor_shower':
        // Sao băng mảnh lướt qua vùng trống phía trên, không cắt số.
        for (var i = 0; i < 3; i++) {
          final f = (t + i * .33) % 1;
          final p = Offset(.06 + f * .24, .08 + i * .07);
          _line(
            c,
            p,
            p + const Offset(.055, -.028),
            accent.withValues(alpha: .35 * math.sin(f * math.pi)),
            .005,
          );
        }
      case 'deep_ocean':
        // Gợn nước lan chậm quanh vỏ sò và bọt khí ở mép phải.
        c.drawArc(
          const Rect.fromLTWH(.28, .79, .44, .18),
          math.pi,
          math.pi,
          false,
          Paint()
            ..color = accent.withValues(alpha: .18 + .04 * pulse)
            ..style = PaintingStyle.stroke
            ..strokeWidth = .008,
        );
        for (var i = 0; i < 3; i++) {
          final f = (t + i * .31) % 1;
          c.drawCircle(
            Offset(.88 + .018 * math.sin(f * math.pi), .78 - f * .20),
            .009 + i * .003,
            Paint()
              ..color = Colors.white.withValues(alpha: .24 * (1 - f))
              ..style = PaintingStyle.stroke
              ..strokeWidth = .004,
          );
        }
      case 'golden_sunset':
        // Tia nắng khuếch tán ở vòm trời và hạt bụi vàng trôi ngang.
        _ambientHalo(c, const Offset(.25, .20), .18, gold, .07 + .025 * pulse);
        for (var i = 0; i < 4; i++) {
          final a = -.9 + i * .32;
          _line(
            c,
            Offset(.25 + math.cos(a) * .16, .20 + math.sin(a) * .16),
            Offset(.25 + math.cos(a) * .23, .20 + math.sin(a) * .23),
            gold.withValues(alpha: .20),
            .006,
          );
        }
      case 'neon_pulse':
        // Viền neon mờ co giãn theo nhịp nhạc, nằm ngoài mặt cassette.
        final glow = Paint()
          ..color = accent.withValues(alpha: .11 + .08 * pulse)
          ..style = PaintingStyle.stroke
          ..strokeWidth = .014 + .004 * pulse
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, .025);
        c.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(.035, .125, .93, .75),
            const Radius.circular(.09),
          ),
          glow,
        );
        for (var i = 0; i < 3; i++) {
          _spark(
            c,
            Offset(.10 + i * .40, .10),
            .014,
            i.isEven ? accent : const Color(0xFFE5AFD3),
            .20 + .10 * breathe,
          );
        }
      default:
        break;
    }
  }

  void _ambientHalo(
    Canvas c,
    Offset center,
    double radius,
    Color color,
    double opacity,
  ) {
    c.drawCircle(
      center,
      radius,
      Paint()
        ..color = color.withValues(alpha: opacity.clamp(0, 1))
        ..style = PaintingStyle.stroke
        ..strokeWidth = .012
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, .024),
    );
  }

  void _line(Canvas c, Offset a, Offset b, Color color, double width) =>
      c.drawLine(
        a,
        b,
        Paint()
          ..color = color
          ..strokeWidth = width
          ..strokeCap = StrokeCap.round,
      );
  void _dot(Canvas c, Offset p, double r, Color color) =>
      c.drawCircle(p, r, Paint()..color = color);
  void _curve(
    Canvas c,
    Offset a,
    Offset control,
    Offset b,
    Color color,
    double width,
  ) => c.drawPath(
    Path()
      ..moveTo(a.dx, a.dy)
      ..quadraticBezierTo(control.dx, control.dy, b.dx, b.dy),
    Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round,
  );
  void _rrect(Canvas c, Rect r, double radius, Color fill, {Color? stroke}) {
    final rr = RRect.fromRectAndRadius(r, Radius.circular(radius));
    c.drawRRect(rr, Paint()..color = fill);
    if (stroke != null) {
      c.drawRRect(
        rr,
        Paint()
          ..color = stroke
          ..style = PaintingStyle.stroke
          ..strokeWidth = .004,
      );
    }
  }

  void _sticker(Canvas c, Path p, Color fill, Color border) {
    c.drawPath(
      p,
      Paint()
        ..color = Colors.white.withValues(alpha: .94)
        ..style = PaintingStyle.stroke
        ..strokeWidth = .015
        ..strokeJoin = StrokeJoin.round,
    );
    c.drawPath(p, Paint()..color = fill);
    c.drawPath(
      p,
      Paint()
        ..color = border
        ..style = PaintingStyle.stroke
        ..strokeWidth = .003,
    );
  }

  void _local(Canvas c, Offset p, double s, double a, VoidCallback draw) {
    c.save();
    c.translate(p.dx, p.dy);
    c.rotate(a);
    c.scale(s);
    draw();
    c.restore();
  }

  void _face(
    Canvas c,
    Offset p,
    double size, {
    bool sleepy = false,
    Color? color,
  }) {
    final faceColor = color ?? const Color(0xFF6D535B);
    for (final x in [-.18, .18]) {
      final eye = p + Offset(x * size, -.035 * size);
      if (sleepy) {
        _curve(
          c,
          eye - Offset(.065 * size, 0),
          eye + Offset(0, .065 * size),
          eye + Offset(.065 * size, 0),
          faceColor,
          .027 * size,
        );
      } else {
        _dot(c, eye, .030 * size, faceColor);
      }
      _dot(
        c,
        eye + Offset(x.sign * .035 * size, .11 * size),
        .065 * size,
        const Color(0xFFEBA1AF).withValues(alpha: .65),
      );
    }
    _curve(
      c,
      p + Offset(-.05 * size, .09 * size),
      p + Offset(0, .17 * size),
      p + Offset(.05 * size, .09 * size),
      faceColor,
      .018 * size,
    );
  }

  void _spark(Canvas c, Offset p, double size, Color color, double opacity) {
    c.drawPath(
      _softStar(p, size, size * .15, 4),
      Paint()..color = color.withValues(alpha: opacity.clamp(0, 1)),
    );
  }

  void _bow(
    Canvas c,
    Offset p,
    double s,
    double angle,
    Color color,
    Color edge,
  ) => _local(c, p, s, angle, () {
    final tails = Path()
      ..moveTo(-.09, .08)
      ..lineTo(-.35, .57)
      ..lineTo(-.11, .48)
      ..lineTo(.03, .65)
      ..lineTo(.12, .11)
      ..moveTo(.09, .08)
      ..lineTo(.35, .57)
      ..lineTo(.11, .48)
      ..lineTo(-.03, .65)
      ..lineTo(-.12, .11);
    _sticker(
      c,
      tails,
      Color.lerp(color, cream, .22)!,
      edge.withValues(alpha: .5),
    );
    final loops = Path()
      ..moveTo(0, 0)
      ..cubicTo(-.69, -.70, -.71, .36, 0, .14)
      ..cubicTo(.71, .36, .69, -.70, 0, 0)
      ..close();
    _sticker(c, loops, color, edge.withValues(alpha: .6));
    _curve(
      c,
      const Offset(-.43, -.14),
      const Offset(-.30, -.02),
      const Offset(-.05, .03),
      cream.withValues(alpha: .5),
      .026,
    );
    _curve(
      c,
      const Offset(.43, -.14),
      const Offset(.30, -.02),
      const Offset(.05, .03),
      cream.withValues(alpha: .5),
      .026,
    );
    _rrect(
      c,
      const Rect.fromLTWH(-.1, -.11, .2, .28),
      .07,
      Color.lerp(color, edge, .13)!,
    );
  });
  void _leaf(Canvas c, Offset p, double s, double angle, Color color) =>
      _local(c, p, s, angle, () {
        final leaf = Path()
          ..moveTo(0, -.55)
          ..cubicTo(.7, -.1, .5, .45, 0, .53)
          ..cubicTo(-.5, .45, -.7, -.1, 0, -.55)
          ..close();
        c.drawPath(leaf, Paint()..color = color);
        _line(
          c,
          const Offset(0, -.32),
          const Offset(0, .56),
          cream.withValues(alpha: .7),
          .035,
        );
      });
  void _sprig(Canvas c, Offset p, double s, double angle, Color color) =>
      _local(c, p, s, angle, () {
        _curve(
          c,
          const Offset(0, .5),
          const Offset(-.20, 0),
          const Offset(0, -.6),
          color,
          .028,
        );
        for (var i = 0; i < 3; i++) {
          _leaf(c, Offset(-.17, -.26 + i * .24), .34, -.8, color);
          _leaf(c, Offset(.08, -.37 + i * .24), .30, .8, color);
        }
      });
  void _flower(Canvas c, Offset p, double s, Color color, Color center) {
    _sticker(c, _petals(p, s, s * .16, 5), color, color.withValues(alpha: .65));
    _dot(c, p, s * .28, center);
  }

  void _butterfly(Canvas c, Offset p, double s, double angle, Color color) =>
      _local(c, p, s, angle, () {
        final wings = Path()
          ..moveTo(0, .1)
          ..cubicTo(-1, -.75, -.73, -1, 0, -.1)
          ..cubicTo(.73, -1, 1, -.75, 0, .1)
          ..cubicTo(.83, .76, .45, .81, 0, .1)
          ..cubicTo(-.45, .81, -.83, .76, 0, .1)
          ..close();
        _sticker(c, wings, color, const Color(0xFFC28F56));
        _line(c, const Offset(0, -.28), const Offset(0, .35), ink, .05);
        _curve(
          c,
          const Offset(0, -.25),
          const Offset(-.2, -.66),
          const Offset(-.26, -.53),
          ink,
          .025,
        );
        _curve(
          c,
          const Offset(0, -.25),
          const Offset(.2, -.66),
          const Offset(.26, -.53),
          ink,
          .025,
        );
      });
  void _cloud(
    Canvas c,
    Offset p,
    double s,
    Color color, {
    bool smile = false,
  }) => _local(c, p, s, 0, () {
    final cloud = Path()
      ..moveTo(-.6, .2)
      ..cubicTo(-.95, .0, -.55, -.50, -.3, -.25)
      ..cubicTo(-.35, -.80, .45, -.78, .45, -.25)
      ..cubicTo(.90, -.4, 1.0, .35, .45, .4)
      ..lineTo(-.5, .4)
      ..close();
    _sticker(c, cloud, color, const Color(0xFFC9BAC8));
    if (smile) _face(c, const Offset(.03, .02), .85, sleepy: true);
  });
  void _ladybug(Canvas c, Offset p, double s, double angle) =>
      _local(c, p, s, angle, () {
        _sticker(
          c,
          Path()..addOval(const Rect.fromLTWH(-.45, -.48, .9, 1.0)),
          const Color(0xFFE99790),
          const Color(0xFF986A60),
        );
        _dot(c, const Offset(0, -.48), .22, const Color(0xFF655D54));
        _line(c, const Offset(0, -.25), const Offset(0, .50), cream, .04);
        for (final x in [-.23, .23]) {
          for (final y in [-.11, .23]) {
            _dot(c, Offset(x, y), .075, const Color(0xFF7B5F53));
          }
        }
        _dot(c, const Offset(-.07, -.49), .03, cream);
        _dot(c, const Offset(.07, -.49), .03, cream);
      });
  void _jellyfish(Canvas c, Offset p, double s, Color color) =>
      _local(c, p, s, 0, () {
        final head = Path()
          ..moveTo(-.48, .04)
          ..cubicTo(-.58, -.72, .60, -.72, .48, .04)
          ..quadraticBezierTo(.24, .25, 0, .07)
          ..quadraticBezierTo(-.22, .25, -.48, .04)
          ..close();
        _sticker(
          c,
          head,
          Color.lerp(color, cream, .4)!,
          ink.withValues(alpha: .3),
        );
        for (var i = 0; i < 3; i++) {
          _curve(
            c,
            Offset(-.3 + i * .3, .1),
            Offset(-.15 + i * .3 + sway * .10, .62),
            Offset(-.32 + i * .3, .8),
            color,
            .06,
          );
        }
        _face(c, const Offset(0, -.12), .72);
      });
  void _littleStar(
    Canvas c,
    Offset p,
    double s,
    double angle,
    Color color, {
    bool sleepy = false,
  }) => _local(c, p, s, angle, () {
    _sticker(
      c,
      _softStar(Offset.zero, .64, .3, 5),
      color,
      const Color(0xFFD3A56C),
    );
    _face(c, const Offset(0, .03), .78, sleepy: sleepy);
  });
  void _wrappedCandy(Canvas c, Offset p, double s, double angle, Color color) =>
      _local(c, p, s, angle, () {
        final wrapper = Path()
          ..moveTo(-.28, 0)
          ..lineTo(-.67, -.29)
          ..lineTo(-.60, .02)
          ..lineTo(-.72, .28)
          ..close()
          ..moveTo(.28, 0)
          ..lineTo(.67, -.29)
          ..lineTo(.60, .02)
          ..lineTo(.72, .28)
          ..close();
        _sticker(
          c,
          wrapper,
          Color.lerp(color, cream, .3)!,
          ink.withValues(alpha: .25),
        );
        _sticker(
          c,
          Path()..addOval(const Rect.fromLTWH(-.38, -.29, .76, .58)),
          design.wash,
          accent,
        );
        _curve(
          c,
          const Offset(-.17, -.27),
          const Offset(.02, 0),
          const Offset(-.07, .28),
          cream,
          .14,
        );
        _line(c, const Offset(.23, -.24), const Offset(.30, .19), cream, .10);
      });
  void _ufo(Canvas c, Offset p, double s) => _local(c, p, s, 0, () {
    _sticker(
      c,
      Path()..addOval(const Rect.fromLTWH(-.32, -.5, .64, .63)),
      const Color(0xFFB6DCD0),
      const Color(0xFF698E83),
    );
    _face(c, const Offset(0, -.17), .60);
    _sticker(
      c,
      Path()..addOval(const Rect.fromLTWH(-.65, -.03, 1.3, .35)),
      accent,
      ink.withValues(alpha: .5),
    );
    for (final x in [-.4, 0.0, .4]) {
      _dot(c, Offset(x, .15), .05, gold);
    }
  });
  void _fox(Canvas c, Offset p, double s) => _local(c, p, s, -.07, () {
    final head = Path()
      ..moveTo(-.45, .23)
      ..lineTo(-.57, -.55)
      ..lineTo(-.12, -.26)
      ..quadraticBezierTo(0, -.36, .14, -.26)
      ..lineTo(.57, -.55)
      ..lineTo(.45, .23)
      ..quadraticBezierTo(0, .72, -.45, .23)
      ..close();
    _sticker(c, head, cream, const Color(0xFF94B3A3));
    final muzzle = Path()
      ..moveTo(-.39, -.01)
      ..quadraticBezierTo(-.24, .45, 0, .20)
      ..quadraticBezierTo(.24, .45, .39, -.01)
      ..quadraticBezierTo(0, .70, -.39, -.01)
      ..close();
    c.drawPath(muzzle, Paint()..color = accent.withValues(alpha: .45));
    _face(c, const Offset(0, .06), .80, sleepy: true);
    _dot(c, const Offset(0, .20), .05, const Color(0xFF63897E));
  });
  void _gem(Canvas c, Offset p, double s, Color color) => _local(
    c,
    p,
    s,
    .13,
    () {
      final pth = Path()
        ..moveTo(-.55, -.17)
        ..lineTo(-.25, -.5)
        ..lineTo(.25, -.5)
        ..lineTo(.55, -.17)
        ..lineTo(0, .56)
        ..close();
      _sticker(c, pth, color, ink.withValues(alpha: .55));
      _line(c, const Offset(-.55, -.17), const Offset(.55, -.17), cream, .035);
      _line(c, const Offset(-.25, -.5), const Offset(0, .56), cream, .035);
      _line(c, const Offset(.25, -.5), const Offset(0, .56), cream, .035);
    },
  );
  void _burst(Canvas c, Offset p, double s, double phase, Color color) {
    final pulse = .58 + .42 * math.sin(phase * math.pi).abs();
    for (var i = 0; i < 8; i++) {
      final a = i * math.pi / 4;
      final axis = Offset(math.cos(a), math.sin(a));
      _line(
        c,
        p + axis * s * .34,
        p + axis * s * pulse,
        color.withValues(alpha: .8),
        .005,
      );
    }
    _dot(c, p, .009, cream);
  }

  void _partyPopper(Canvas c, Offset p, double s, double angle) =>
      _local(c, p, s, angle, () {
        final cone = Path()
          ..moveTo(-.1, .50)
          ..lineTo(-.43, -.26)
          ..lineTo(.46, .12)
          ..close();
        _sticker(c, cone, accent, ink.withValues(alpha: .6));
        _line(c, const Offset(-.21, .23), const Offset(.14, .23), cream, .075);
        _line(c, const Offset(-.32, -.08), const Offset(.34, .08), gold, .065);
        _curve(
          c,
          const Offset(.12, -.17),
          const Offset(.18, -.72),
          const Offset(.65, -.54),
          gold,
          .035,
        );
        _curve(
          c,
          const Offset(-.11, -.29),
          const Offset(-.60, -.70),
          const Offset(-.45, -.88),
          accent,
          .028,
        );
        _dot(c, const Offset(.65, -.24), .075, gold);
        _dot(c, const Offset(.15, -.75), .055, accent);
      });
  void _flame(Canvas c, Offset p, double s) => _local(c, p, s, 0, () {
    final flame = Path()
      ..moveTo(0, -.68)
      ..cubicTo(.05, -.31, .69, .0, .43, .43)
      ..cubicTo(.19, .73, -.60, .55, -.46, .07)
      ..quadraticBezierTo(-.35, -.12, -.20, -.34)
      ..quadraticBezierTo(-.17, .01, 0, -.68)
      ..close();
    _sticker(c, flame, const Color(0xFFF0B172), const Color(0xFFCE8656));
    c.drawPath(
      Path()
        ..moveTo(0, -.02)
        ..cubicTo(.30, .25, .17, .59, -.09, .48)
        ..quadraticBezierTo(-.32, .31, 0, -.02)
        ..close(),
      Paint()..color = cream,
    );
    _face(c, const Offset(0, .12), .75, sleepy: true);
  });
  void _petal(Canvas c, Offset p, double s, double a, Color color) =>
      _local(c, p, s, a, () {
        final petal = Path()
          ..moveTo(0, .65)
          ..cubicTo(-.70, -.15, -.3, -.65, 0, -.3)
          ..cubicTo(.3, -.65, .70, -.15, 0, .65)
          ..close();
        c.drawPath(petal, Paint()..color = color.withValues(alpha: .75));
      });
  void _bird(Canvas c, Offset p, double s, double angle) =>
      _local(c, p, s, angle, () {
        final bird = Path()
          ..moveTo(-.36, .26)
          ..cubicTo(-.74, -.64, .35, -.63, .36, -.07)
          ..lineTo(.60, .09)
          ..lineTo(.38, .17)
          ..quadraticBezierTo(.17, .7, -.36, .26)
          ..lineTo(-.77, .20)
          ..lineTo(-.62, .04)
          ..close();
        _sticker(c, bird, const Color(0xFFF4D6C8), ink.withValues(alpha: .4));
        c.drawOval(
          const Rect.fromLTWH(-.35, -.04, .50, .43),
          Paint()..color = accent.withValues(alpha: .65),
        );
        _dot(c, const Offset(.22, -.07), .035, ink);
        _dot(c, const Offset(.28, .08), .06, const Color(0xFFE9A1AF));
        _line(c, const Offset(-.09, .40), const Offset(-.13, .53), ink, .026);
      });
  void _rocket(Canvas c, Offset p, double s, double angle) =>
      _local(c, p, s, angle, () {
        final wings = Path()
          ..moveTo(-.12, .10)
          ..lineTo(-.47, .54)
          ..lineTo(-.07, .42)
          ..moveTo(.12, .10)
          ..lineTo(.47, .54)
          ..lineTo(.07, .42);
        _sticker(c, wings, accent, ink.withValues(alpha: .5));
        final body = Path()
          ..moveTo(0, -.68)
          ..cubicTo(-.41, -.33, -.31, .24, -.15, .47)
          ..lineTo(.15, .47)
          ..cubicTo(.31, .24, .41, -.33, 0, -.68)
          ..close();
        _sticker(c, body, cream, ink.withValues(alpha: .5));
        _dot(c, const Offset(0, -.08), .14, accent);
        _dot(c, const Offset(-.04, -.12), .04, Colors.white);
        _line(c, const Offset(0, .55), Offset(0, .68 + sway * .08), gold, .08);
      });
  void _pearlShell(Canvas c, Offset p, double s) => _local(c, p, s, 0, () {
    final shell = Path()
      ..moveTo(-.66, 0)
      ..quadraticBezierTo(0, .75, .66, 0)
      ..quadraticBezierTo(0, -.14, -.66, 0)
      ..close();
    _sticker(c, shell, accent, ink.withValues(alpha: .4));
    _sticker(
      c,
      Path()..addOval(const Rect.fromLTWH(-.27, -.53, .54, .55)),
      cream,
      accent,
    );
    _dot(c, const Offset(-.085, -.38), .045, Colors.white);
    _face(c, const Offset(0, -.19), .48);
  });
  void _fish(Canvas c, Offset p, double s, double angle) =>
      _local(c, p, s, angle, () {
        final fish = Path()
          ..addOval(const Rect.fromLTWH(-.35, -.26, .85, .52))
          ..moveTo(-.25, 0)
          ..lineTo(-.68, -.29)
          ..lineTo(-.68, .29)
          ..close();
        _sticker(c, fish, const Color(0xFFF1C391), ink.withValues(alpha: .3));
        _curve(
          c,
          const Offset(-.05, -.23),
          const Offset(-.15, 0),
          const Offset(-.05, .23),
          cream,
          .043,
        );
        _dot(c, const Offset(.27, -.07), .035, ink);
      });
  void _sailboat(Canvas c, Offset p, double s) => _local(c, p, s, 0, () {
    final hull = Path()
      ..moveTo(-.66, .22)
      ..lineTo(.66, .22)
      ..lineTo(.39, .54)
      ..lineTo(-.37, .54)
      ..close();
    _sticker(c, hull, accent, ink.withValues(alpha: .4));
    final sail = Path()
      ..moveTo(-.02, -.67)
      ..lineTo(-.02, .13)
      ..lineTo(-.54, .13)
      ..close()
      ..moveTo(.06, -.49)
      ..lineTo(.53, .13)
      ..lineTo(.06, .13)
      ..close();
    _sticker(c, sail, cream, ink.withValues(alpha: .25));
    _line(c, const Offset(.02, -.70), const Offset(.02, .23), ink, .025);
  });
  void _headphones(Canvas c, Offset p, double s, Color color) =>
      _local(c, p, s, .20, () {
        c.drawArc(
          const Rect.fromLTWH(-.48, -.54, .96, 1.04),
          math.pi,
          math.pi,
          false,
          Paint()
            ..color = cream
            ..style = PaintingStyle.stroke
            ..strokeWidth = .14
            ..strokeCap = StrokeCap.round,
        );
        c.drawArc(
          const Rect.fromLTWH(-.48, -.54, .96, 1.04),
          math.pi,
          math.pi,
          false,
          Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = .08
            ..strokeCap = StrokeCap.round,
        );
        for (final x in [-.43, .43]) {
          _rrect(
            c,
            Rect.fromCenter(center: Offset(x, .20), width: .25, height: .48),
            .10,
            color,
            stroke: cream,
          );
        }
      });
  void _musicNote(
    Canvas c,
    Offset p,
    double s,
    Color color,
  ) => _local(c, p, s, -.16, () {
    _line(c, const Offset(-.19, .33), const Offset(-.19, -.40), color, .085);
    _line(c, const Offset(-.19, -.40), const Offset(.32, -.50), color, .13);
    _line(c, const Offset(.32, -.50), const Offset(.32, .21), color, .085);
    c.drawOval(
      const Rect.fromLTWH(-.48, .18, .33, .24),
      Paint()..color = color,
    );
    c.drawOval(const Rect.fromLTWH(.04, .07, .33, .24), Paint()..color = color);
  });

  @override
  bool shouldRepaint(CountdownArtworkPainter old) =>
      old.design != design ||
      old.ornaments != ornaments ||
      old.dark != dark ||
      old.transparent != transparent ||
      old.progress != progress ||
      old.phase != phase;
}
