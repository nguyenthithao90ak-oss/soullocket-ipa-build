part of 'living_sticker_painter.dart';

/// Mỗi bộ có chất liệu, silhouette và bảng màu riêng; URI đã lưu giữ ổn định.
extension _LivingStickerPackArt on LivingStickerPainter {
  static const _brown = Color(0xFF654C36);
  static const _navy = Color(0xFF303953);
  static const _coral = Color(0xFFE5748E);
  static const _yellow = Color(0xFFFFD86B);
  static const _lavender = Color(0xFFB5ABD7);
  static const _teal = Color(0xFF7BC6AD);

  String get _artId => scene.artworkId ?? '';
  bool _has(String value) => _artId.contains(value);

  void _paintPackArtwork(Canvas c, double t) {
    switch (scene.artStyle!) {
      case StickerArtStyle.duck:
        _duckPack(c, t);
      case StickerArtStyle.plush:
        _plushPack(c, t);
      case StickerArtStyle.comic:
        _comicPack(c, t);
      case StickerArtStyle.watercolor:
        _cloudPack(c, t);
      case StickerArtStyle.pixel:
        _pixelPack(c, t);
      case StickerArtStyle.space:
        _spacePack(c, t);
      case StickerArtStyle.glossy:
        _glossyPack(c, t);
      case StickerArtStyle.paper:
        _paperPack(c, t);
      case StickerArtStyle.journal:
        _journalPack(c, t);
    }
  }

  void _artPath(
    Canvas c,
    Path path,
    Color fill, {
    Color? stroke,
    double width = 3,
  }) {
    c.drawPath(path, Paint()..color = fill);
    if (stroke != null) {
      c.drawPath(
        path,
        Paint()
          ..color = stroke
          ..style = PaintingStyle.stroke
          ..strokeWidth = width
          ..strokeJoin = StrokeJoin.round
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  void _artOval(
    Canvas c,
    Rect rect,
    Color fill, {
    Color? stroke,
    double width = 3,
  }) {
    c.drawOval(rect, Paint()..color = fill);
    if (stroke != null) {
      c.drawOval(
        rect,
        Paint()
          ..color = stroke
          ..style = PaintingStyle.stroke
          ..strokeWidth = width,
      );
    }
  }

  void _artLine(
    Canvas c,
    List<Offset> points,
    Color color, {
    double width = 3,
  }) {
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    c.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  void _artRound(
    Canvas c,
    Rect rect,
    Color fill, {
    double radius = 8,
    Color? stroke,
    double width = 3,
  }) {
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius)));
    _artPath(c, path, fill, stroke: stroke, width: width);
  }

  void _artHeart(
    Canvas c,
    Offset p,
    double size,
    Color color, {
    bool shine = false,
  }) {
    c.save();
    c.translate(p.dx, p.dy);
    c.scale(size / 100);
    final path = Path()
      ..moveTo(0, 42)
      ..cubicTo(-16, 29, -57, 3, -48, -21)
      ..cubicTo(-40, -44, -13, -42, 0, -23)
      ..cubicTo(16, -45, 43, -42, 49, -20)
      ..cubicTo(58, 7, 16, 29, 0, 42)
      ..close();
    if (shine) {
      c.drawPath(
        path,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFC7D4), Color(0xFFE66489), Color(0xFFBC4076)],
          ).createShader(path.getBounds()),
      );
      final highlight = Path()
        ..moveTo(-29, -22)
        ..quadraticBezierTo(-21, -29, -15, -22);
      c.drawPath(
        highlight,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.86)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6
          ..strokeCap = StrokeCap.round,
      );
    } else {
      _artPath(c, path, color);
    }
    c.restore();
  }

  void _artStar(
    Canvas c,
    Offset p,
    double r,
    Color color, {
    double rotation = 0,
  }) {
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final a = -math.pi / 2 + i * math.pi / 5 + rotation;
      final radius = i.isEven ? r : r * 0.48;
      final x = p.dx + math.cos(a) * radius;
      final y = p.dy + math.sin(a) * radius;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    _artPath(c, path..close(), color);
  }

  void _artFace(
    Canvas c,
    Offset p,
    double spread,
    double t, {
    Color ink = _brown,
    bool beak = false,
    bool pixel = false,
  }) {
    final angry = scene.gesture == StickerGesture.angry || _has('grumpy');
    final sad =
        scene.gesture == StickerGesture.sad ||
        scene.gesture == StickerGesture.sorry ||
        _has('missing') ||
        _has('anxious');
    final closed =
        scene.gesture == StickerGesture.sleep ||
        scene.gesture == StickerGesture.hug ||
        scene.gesture == StickerGesture.heal;
    final laugh =
        scene.gesture == StickerGesture.laugh ||
        scene.gesture == StickerGesture.celebrate;
    final blink = t > 0.44 && t < 0.49;
    for (final side in [-1, 1]) {
      final x = p.dx + side * spread;
      if (pixel) {
        c.drawRect(
          Rect.fromLTWH(x - 3, p.dy - 4, 6, closed || blink ? 3 : 7),
          Paint()..color = ink,
        );
      } else if (closed || laugh || blink) {
        final eye = Path()
          ..moveTo(x - 4, p.dy + 1)
          ..quadraticBezierTo(x, p.dy + (laugh ? -5 : 5), x + 4, p.dy + 1);
        c.drawPath(
          eye,
          Paint()
            ..color = ink
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.8
            ..strokeCap = StrokeCap.round,
        );
      } else {
        _artOval(
          c,
          Rect.fromCenter(
            center: Offset(x, p.dy),
            width: 5.5,
            height: sad ? 5 : 8,
          ),
          ink,
        );
      }
      if (angry) {
        _artLine(c, [
          Offset(x - 5, p.dy - 11 + side * 3),
          Offset(x + 5, p.dy - 11 - side * 3),
        ], ink);
      }
      _artOval(
        c,
        Rect.fromCenter(
          center: Offset(x + side * 6, p.dy + 12),
          width: 13,
          height: 6,
        ),
        _coral.withValues(alpha: 0.34),
      );
    }
    if (beak) {
      _artOval(
        c,
        Rect.fromCenter(center: Offset(p.dx, p.dy + 13), width: 21, height: 12),
        const Color(0xFFF9A542),
      );
      _artLine(
        c,
        [Offset(p.dx - 5, p.dy + 13), Offset(p.dx + 5, p.dy + 13)],
        _brown.withValues(alpha: 0.4),
        width: 1.5,
      );
    } else if (scene.gesture == StickerGesture.pout) {
      _artLine(c, [
        Offset(p.dx - 5, p.dy + 16),
        Offset(p.dx, p.dy + 13),
        Offset(p.dx + 5, p.dy + 16),
      ], ink);
    } else if (laugh) {
      _artOval(
        c,
        Rect.fromCenter(center: Offset(p.dx, p.dy + 16), width: 14, height: 16),
        ink,
      );
      _artOval(
        c,
        Rect.fromCenter(center: Offset(p.dx, p.dy + 21), width: 9, height: 5),
        _coral,
      );
    } else if (sad) {
      final mouth = Path()
        ..moveTo(p.dx - 5, p.dy + 18)
        ..quadraticBezierTo(p.dx, p.dy + 12, p.dx + 5, p.dy + 18);
      c.drawPath(
        mouth,
        Paint()
          ..color = ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.3
          ..strokeCap = StrokeCap.round,
      );
    } else {
      final mouth = Path()
        ..moveTo(p.dx - 6, p.dy + 12)
        ..quadraticBezierTo(p.dx, p.dy + 23, p.dx + 6, p.dy + 12);
      c.drawPath(
        mouth,
        Paint()
          ..color = ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  void _artSparkles(Canvas c, Color color, double t) {
    for (var i = 0; i < 3; i++) {
      final p = [
        const Offset(33, 58),
        const Offset(163, 42),
        const Offset(171, 129),
      ][i];
      final r = 4 + math.sin((t + i / 3) * math.pi * 2).abs() * 3;
      _artLine(c, [p - Offset(r, 0), p + Offset(r, 0)], color, width: 2);
      _artLine(c, [p - Offset(0, r), p + Offset(0, r)], color, width: 2);
    }
  }

  void _artProp(Canvas c, double t, Color ink, {bool pixel = false}) {
    final prop = scene.prop;
    if (_has('letter') || prop == StickerSubject.letter) {
      _artRound(
        c,
        const Rect.fromLTWH(71, 130, 58, 36),
        const Color(0xFFFFF9E9),
        stroke: ink,
        radius: pixel ? 0 : 5,
        width: 2,
      );
      _artLine(
        c,
        [const Offset(72, 133), const Offset(100, 151), const Offset(128, 133)],
        ink,
        width: 2,
      );
      _artHeart(c, const Offset(100, 145), 14, _coral);
    } else if (_has('coffee') || prop == StickerSubject.coffee) {
      _artOval(
        c,
        const Rect.fromLTWH(120, 139, 17, 18),
        const Color(0xFFFFF8E9),
        stroke: ink,
        width: 2,
      );
      _artRound(
        c,
        const Rect.fromLTWH(80, 133, 44, 33),
        const Color(0xFFFFF8E9),
        stroke: ink,
        radius: pixel ? 0 : 8,
        width: 2,
      );
      _artHeart(c, const Offset(102, 147), 14, _coral);
      _artLine(
        c,
        [
          const Offset(96, 122),
          Offset(93 + math.sin(t * 6) * 2, 114),
          const Offset(98, 106),
        ],
        ink.withValues(alpha: 0.4),
        width: 2,
      );
    } else if (_has('cake') || _has('snack') || prop == StickerSubject.cake) {
      _artRound(
        c,
        const Rect.fromLTWH(70, 141, 60, 27),
        _coral,
        radius: pixel ? 0 : 5,
        stroke: ink,
        width: 2,
      );
      _artRound(
        c,
        const Rect.fromLTWH(68, 137, 64, 11),
        const Color(0xFFFFF3D8),
        radius: 5,
      );
      _artLine(
        c,
        [const Offset(100, 136), const Offset(100, 124)],
        ink,
        width: 3,
      );
      _artOval(c, const Rect.fromLTWH(97, 117, 6, 9), _yellow);
    } else if (_has('flower') || prop == StickerSubject.flower) {
      for (var i = 0; i < 3; i++) {
        final x = 87 + i * 13.0;
        _artLine(
          c,
          [const Offset(100, 171), Offset(x, 138)],
          const Color(0xFF6E9C74),
          width: 3,
        );
        for (var j = 0; j < 5; j++) {
          final a = j * math.pi * 2 / 5;
          _artOval(
            c,
            Rect.fromCircle(
              center: Offset(x + math.cos(a) * 6, 133 + math.sin(a) * 6),
              radius: 5,
            ),
            i.isEven ? _coral : _yellow,
          );
        }
        _artOval(
          c,
          Rect.fromCircle(center: Offset(x, 133), radius: 3),
          const Color(0xFFFFF4CB),
        );
      }
    } else if (_has('camera') ||
        _has('photo') ||
        prop == StickerSubject.camera) {
      _artRound(
        c,
        const Rect.fromLTWH(72, 135, 56, 33),
        _lavender,
        stroke: ink,
        radius: pixel ? 0 : 5,
        width: 2,
      );
      _artRound(
        c,
        const Rect.fromLTWH(79, 130, 15, 7),
        _lavender,
        stroke: ink,
        radius: 1,
        width: 2,
      );
      _artOval(
        c,
        Rect.fromCircle(center: const Offset(104, 152), radius: 10),
        const Color(0xFFFCF9FA),
        stroke: ink,
        width: 2,
      );
      _artOval(
        c,
        Rect.fromCircle(center: const Offset(104, 152), radius: 6),
        _navy,
      );
    } else if (_has('game') || prop == StickerSubject.game) {
      _artRound(
        c,
        const Rect.fromLTWH(69, 139, 62, 27),
        _lavender,
        stroke: ink,
        radius: pixel ? 0 : 12,
        width: 2,
      );
      _artLine(c, [const Offset(80, 152), const Offset(94, 152)], ink);
      _artLine(c, [const Offset(87, 145), const Offset(87, 159)], ink);
      _artOval(
        c,
        Rect.fromCircle(center: const Offset(114, 150), radius: 3),
        _coral,
      );
      _artOval(
        c,
        Rect.fromCircle(center: const Offset(121, 156), radius: 3),
        _yellow,
      );
    } else if (_has('shopping') || prop == StickerSubject.bag) {
      _artRound(
        c,
        const Rect.fromLTWH(77, 137, 46, 37),
        _yellow,
        stroke: ink,
        radius: pixel ? 0 : 5,
        width: 2,
      );
      final handle = Path()
        ..moveTo(89, 138)
        ..cubicTo(89, 120, 111, 120, 111, 138);
      c.drawPath(
        handle,
        Paint()
          ..color = ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    } else if (_has('sing') ||
        prop == StickerSubject.microphone ||
        prop == StickerSubject.music) {
      _artLine(
        c,
        [const Offset(109, 150), const Offset(97, 172)],
        ink,
        width: 6,
      );
      _artOval(
        c,
        const Rect.fromLTWH(103, 136, 16, 21),
        _lavender,
        stroke: ink,
        width: 2,
      );
      _artLine(
        c,
        [const Offset(153, 83), const Offset(153, 66), const Offset(163, 63)],
        ink,
        width: 3,
      );
      _artOval(c, const Rect.fromLTWH(145, 80, 9, 6), ink);
    } else if (_has('movie') || prop == StickerSubject.film) {
      _artRound(
        c,
        const Rect.fromLTWH(72, 137, 56, 34),
        _navy,
        radius: pixel ? 0 : 4,
      );
      for (var i = 0; i < 5; i++) {
        _artLine(
          c,
          [Offset(77 + i * 11.0, 136), Offset(71 + i * 11.0, 145)],
          Colors.white,
          width: 4,
        );
      }
      _artHeart(c, const Offset(100, 158), 17, _coral);
    } else if (_has('locket') || prop == StickerSubject.lock) {
      _artRound(
        c,
        const Rect.fromLTWH(86, 138, 28, 28),
        _yellow,
        radius: 7,
        stroke: ink,
        width: 2,
      );
      final loop = Path()
        ..moveTo(92, 139)
        ..cubicTo(90, 116, 110, 116, 108, 139);
      c.drawPath(
        loop,
        Paint()
          ..color = ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5,
      );
      _artHeart(c, const Offset(100, 151), 12, _coral);
    } else if (prop == StickerSubject.heart ||
        _has('heart') ||
        _has('hug') ||
        _has('cuddle') ||
        _has('hold') ||
        _has('make_up')) {
      _artHeart(c, const Offset(100, 147), _has('big_heart') ? 65 : 36, _coral);
    }
  }

  void _duckPack(Canvas c, double t) {
    _artOval(c, const Rect.fromLTWH(52, 173, 96, 9), const Color(0xFFF6DEAA));
    final paired = _has('high_five');
    final centers = paired
        ? [const Offset(64, 116), const Offset(136, 116)]
        : [const Offset(100, 111)];
    for (final p in centers) {
      c.save();
      c.translate(p.dx, p.dy);
      c.scale(paired ? 0.7 : 1.0);
      _artOval(
        c,
        const Rect.fromLTWH(-39, 10, 78, 54),
        _yellow,
        stroke: _brown,
        width: 2.5,
      );
      _artOval(
        c,
        const Rect.fromLTWH(-39, -47, 78, 74),
        const Color(0xFFFFE995),
        stroke: _brown,
        width: 2.5,
      );
      final tuft = Path()
        ..moveTo(-4, -47)
        ..quadraticBezierTo(-20, -62, -8, -65)
        ..quadraticBezierTo(0, -64, 3, -48);
      _artPath(c, tuft, _yellow, stroke: _brown, width: 2.5);
      final wing = Path()
        ..moveTo(-31, 19)
        ..quadraticBezierTo(
          -66,
          _has('wave') || _has('dance') || paired
              ? -10 - math.sin(t * 6) * 7
              : 33,
          -38,
          40,
        );
      _artPath(c, wing, _yellow, stroke: _brown, width: 2.5);
      c.save();
      c.scale(-1, 1);
      _artPath(c, wing, _yellow, stroke: _brown, width: 2.5);
      c.restore();
      _artFace(c, const Offset(0, -14), 15, t, beak: true);
      for (final x in [-15.0, 15.0]) {
        _artOval(
          c,
          Rect.fromCenter(center: Offset(x, 64), width: 25, height: 9),
          const Color(0xFFF6A045),
        );
      }
      c.restore();
    }
    _artProp(c, t, _brown);
    if (_has('confetti') || _has('dance')) {
      for (var i = 0; i < 7; i++) {
        _artStar(
          c,
          Offset(24 + i * 24.0, 28 + (i % 3) * 9 + math.sin(t * 6 + i) * 4),
          4 + i % 3,
          [_coral, _teal, _yellow][i % 3],
        );
      }
    }
    if (_has('send_hearts')) {
      for (var i = 0; i < 3; i++) {
        _artHeart(
          c,
          Offset(139 + i * 10.0, 65 - i * 14.0 - math.sin(t * 6) * 4),
          15 - i * 2.0,
          _coral,
        );
      }
    }
  }

  void _plushPack(Canvas c, double t) {
    final paired =
        _has('kiss') || _has('pinky') || _has('cuddle') || _has('dance');
    void rabbit(Offset p, double scale, Color color, bool second) {
      c.save();
      c.translate(p.dx, p.dy);
      c.scale(scale);
      final shadow = Paint()
        ..color = const Color(0xFFC7A8AE).withValues(alpha: 0.2)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
      c.drawOval(const Rect.fromLTWH(-36, 55, 72, 14), shadow);
      for (final x in [-17.0, 17.0]) {
        _artOval(
          c,
          Rect.fromCenter(center: Offset(x, -59), width: 20, height: 57),
          color,
          stroke: Color.lerp(color, _brown, 0.3),
          width: 2,
        );
        _artOval(
          c,
          Rect.fromCenter(center: Offset(x, -58), width: 7, height: 33),
          _coral.withValues(alpha: 0.23),
        );
      }
      _artOval(c, const Rect.fromLTWH(-30, 9, 60, 53), color);
      _artOval(
        c,
        const Rect.fromLTWH(-40, -47, 80, 68),
        color,
        stroke: Color.lerp(color, _brown, 0.25),
        width: 1.8,
      );
      _artOval(
        c,
        const Rect.fromLTWH(-33, -40, 65, 52),
        Colors.white.withValues(alpha: 0.22),
      );
      _artFace(c, const Offset(0, -18), 14, t, ink: const Color(0xFF886368));
      _artOval(c, const Rect.fromLTWH(-39, 16, 22, 30), color);
      _artOval(c, Rect.fromLTWH(17, 15 - math.sin(t * 6) * 3, 22, 30), color);
      for (final x in [-17.0, 17.0]) {
        _artOval(
          c,
          Rect.fromCenter(center: Offset(x, 57), width: 27, height: 17),
          color,
        );
      }
      // Đường khâu thưa tạo chất liệu vải, không dịch chuyển cả nhân vật.
      for (var i = 0; i < 5; i++) {
        _artLine(
          c,
          [Offset(-17 + i * 8.0, 42), Offset(-15 + i * 8.0, 45)],
          const Color(0xFFA78289).withValues(alpha: 0.3),
          width: 1,
        );
      }
      c.restore();
    }

    if (paired) {
      rabbit(const Offset(65, 119), 0.78, const Color(0xFFFFE7E1), false);
      rabbit(const Offset(137, 119), 0.78, const Color(0xFFE9DFEF), true);
      _artHeart(c, const Offset(102, 45), 22, _coral);
    } else {
      rabbit(const Offset(100, 116), 1, const Color(0xFFF8DADB), false);
    }
    if (_has('umbrella')) {
      final canopy = Path()
        ..moveTo(42, 75)
        ..quadraticBezierTo(100, -3, 158, 75)
        ..quadraticBezierTo(141, 63, 125, 75)
        ..quadraticBezierTo(106, 63, 91, 75)
        ..quadraticBezierTo(66, 63, 42, 75)
        ..close();
      _artPath(
        c,
        canopy,
        const Color(0xFFA9C9BA),
        stroke: const Color(0xFF71988A),
        width: 2,
      );
      _artLine(
        c,
        [const Offset(100, 70), const Offset(100, 135)],
        const Color(0xFF71988A),
        width: 3,
      );
    }
    _artProp(c, t, const Color(0xFF886368));
    if (_has('big_heart')) _artHeart(c, const Offset(100, 147), 76, _coral);
    if (_has('letter') || _has('flowers') || _has('locket')) {
      _artSparkles(c, _coral.withValues(alpha: 0.7), t);
    }
  }

  void _comicPack(Canvas c, double t) {
    final furious = _has('furious');
    final peace = _has('peace') || _has('make_up') || _has('sorry');
    final coat = peace ? const Color(0xFFD0DBF5) : const Color(0xFFFFB17B);
    final sticker = Path()
      ..moveTo(42, 87)
      ..lineTo(38, 41)
      ..lineTo(77, 62)
      ..quadraticBezierTo(100, 55, 126, 62)
      ..lineTo(162, 40)
      ..lineTo(158, 89)
      ..cubicTo(180, 145, 136, 166, 101, 165)
      ..cubicTo(45, 168, 23, 130, 42, 87)
      ..close();
    c.drawPath(
      sticker,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 12
        ..strokeJoin = StrokeJoin.round,
    );
    c.drawPath(
      sticker.shift(const Offset(3, 4)),
      Paint()..color = _navy.withValues(alpha: 0.13),
    );
    _artPath(c, sticker, coat, stroke: _navy, width: 4.5);
    _artPath(
      c,
      Path()
        ..moveTo(48, 53)
        ..lineTo(52, 78)
        ..lineTo(68, 68)
        ..close(),
      const Color(0xFFF69393),
    );
    _artPath(
      c,
      Path()
        ..moveTo(152, 53)
        ..lineTo(149, 77)
        ..lineTo(135, 68)
        ..close(),
      const Color(0xFFF69393),
    );
    _artOval(c, const Rect.fromLTWH(66, 108, 68, 46), const Color(0xFFFFE8CB));
    _artFace(c, Offset(_has('jealous') ? 108 : 100, 102), 23, t, ink: _navy);
    for (final side in [-1, 1]) {
      _artLine(
        c,
        [Offset(100 + side * 42.0, 111), Offset(100 + side * 60.0, 107)],
        _navy,
        width: 2,
      );
      _artLine(
        c,
        [Offset(100 + side * 42.0, 119), Offset(100 + side * 60.0, 121)],
        _navy,
        width: 2,
      );
    }
    if (_has('crossed') || _has('sulking')) {
      _artLine(
        c,
        [const Offset(63, 143), const Offset(118, 154)],
        _navy,
        width: 7,
      );
      _artLine(
        c,
        [const Offset(137, 143), const Offset(82, 154)],
        _navy,
        width: 7,
      );
    }
    if (_has('angry') || furious) {
      _artLine(
        c,
        [const Offset(166, 63), const Offset(177, 55), const Offset(176, 42)],
        _coral,
        width: furious ? 6 : 4,
      );
      _artLine(
        c,
        [const Offset(168, 45), const Offset(162, 38)],
        _coral,
        width: 4,
      );
      if (furious) {
        for (final x in [20.0, 180.0]) {
          _artPath(
            c,
            Path()
              ..moveTo(x - 8, 95)
              ..lineTo(x + 2, 79)
              ..lineTo(x + 1, 92)
              ..lineTo(x + 10, 90)
              ..lineTo(x - 4, 111)
              ..close(),
            _yellow,
            stroke: _navy,
            width: 2,
          );
        }
      }
    } else if (_has('sorry')) {
      _artOval(
        c,
        Rect.fromCenter(
          center: Offset(132, 118 + math.sin(t * 6) * 3),
          width: 8,
          height: 13,
        ),
        const Color(0xFF83CDEB),
      );
    } else if (_has('pout') || _has('jealous')) {
      _artLine(
        c,
        [const Offset(42, 22), const Offset(45, 33)],
        _navy,
        width: 3,
      );
      _artLine(
        c,
        [const Offset(32, 30), const Offset(37, 36)],
        _navy,
        width: 3,
      );
    }
    _artProp(c, t, _navy);
    if (peace) _artSparkles(c, _coral, t);
    if (_has('sulking')) {
      _artRound(
        c,
        const Rect.fromLTWH(22, 156, 37, 22),
        const Color(0xFFFFFCF3),
        radius: 10,
        stroke: _navy,
        width: 2,
      );
      for (var i = 0; i < 3; i++) {
        _artOval(
          c,
          Rect.fromCircle(center: Offset(31 + i * 8.0, 167), radius: 1.6),
          _navy,
        );
      }
    }
  }

  void _cloudPack(Canvas c, double t) {
    final cloud = Path()
      ..moveTo(49, 147)
      ..cubicTo(8, 143, 22, 103, 46, 98)
      ..cubicTo(36, 61, 77, 49, 94, 73)
      ..cubicTo(108, 40, 150, 54, 151, 89)
      ..cubicTo(191, 83, 195, 142, 159, 147)
      ..close();
    for (var i = 4; i > 0; i--) {
      c.drawPath(
        cloud.shift(Offset(i * 0.7, i * 1.5)),
        Paint()
          ..color = const Color(0xFF9FA9D5).withValues(alpha: 0.045)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 2 + i * 1.2),
      );
    }
    c.drawPath(
      cloud,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF1F2FF), Color(0xFFCBD9EE), Color(0xFFABAEDB)],
        ).createShader(cloud.getBounds()),
    );
    for (var i = 0; i < 12; i++) {
      _artOval(
        c,
        Rect.fromCircle(
          center: Offset(
            51 + (i * 19 % 107).toDouble(),
            92 + (i * 13 % 42).toDouble(),
          ),
          radius: 5 + (i % 3).toDouble(),
        ),
        Colors.white.withValues(alpha: 0.08),
      );
    }
    _artFace(c, const Offset(100, 107), 21, t, ink: const Color(0xFF6B718E));
    if (_has('blanket')) {
      final blanket = Path()
        ..moveTo(36, 128)
        ..quadraticBezierTo(100, 112, 164, 129)
        ..lineTo(160, 166)
        ..quadraticBezierTo(99, 179, 41, 165)
        ..close();
      _artPath(c, blanket, const Color(0xFF9FC4BF));
      for (var i = 0; i < 6; i++) {
        _artStar(
          c,
          Offset(55 + i * 18.0, 145 + i % 2 * 13.0),
          3,
          const Color(0xFFDCEAE5),
        );
      }
    } else if (_has('goodnight')) {
      _artOval(
        c,
        Rect.fromCircle(center: const Offset(156, 48), radius: 20),
        const Color(0xFFF4DCA4),
      );
      _artOval(
        c,
        Rect.fromCircle(center: const Offset(165, 39), radius: 18),
        const Color(0xFFFFF9F5),
      );
      _artStar(c, const Offset(36, 46), 7, _lavender);
    } else if (_has('rain') || _has('tissues')) {
      for (var i = 0; i < 4; i++) {
        final x = 47 + i * 35.0;
        final y = 158 + math.sin(t * 6 + i) * 4;
        _artPath(
          c,
          Path()
            ..moveTo(x, y - 5)
            ..quadraticBezierTo(x - 8, y + 6, x, y + 8)
            ..quadraticBezierTo(x + 8, y + 6, x, y - 5)
            ..close(),
          const Color(0xFFA9CFE5),
        );
      }
      if (_has('tissues')) {
        _artRound(
          c,
          const Rect.fromLTWH(69, 145, 62, 27),
          const Color(0xFFF3C8C5),
          radius: 4,
        );
        _artPath(
          c,
          Path()
            ..moveTo(91, 149)
            ..lineTo(84, 124)
            ..lineTo(101, 128)
            ..lineTo(116, 122)
            ..lineTo(112, 149)
            ..close(),
          const Color(0xFFFFFDFA),
        );
      }
    } else if (_has('healing')) {
      _artRound(
        c,
        const Rect.fromLTWH(83, 131, 34, 16),
        const Color(0xFFEFCCA5),
        radius: 6,
      );
      for (var i = 0; i < 3; i++) {
        _artOval(
          c,
          Rect.fromCircle(center: Offset(94 + i * 6.0, 139), radius: 1),
          const Color(0xFFB1937D),
        );
      }
      _artStar(c, const Offset(156, 60), 8, const Color(0xFFF4DCA4));
    } else {
      _artProp(c, t, const Color(0xFF7F839A));
    }
    if (_has('hug') || _has('hold')) {
      _artHeart(c, const Offset(100, 154), 32, const Color(0xFFD9A7BE));
      _artLine(
        c,
        [const Offset(49, 135), const Offset(82, 152)],
        const Color(0xFF9AAACC),
        width: 8,
      );
      _artLine(
        c,
        [const Offset(151, 135), const Offset(118, 152)],
        const Color(0xFF9AAACC),
        width: 8,
      );
    }
    if (_has('holding_hands')) {
      _artOval(
        c,
        const Rect.fromLTWH(68, 146, 28, 17),
        const Color(0xFFB0BCE1),
      );
      _artOval(
        c,
        const Rect.fromLTWH(104, 146, 28, 17),
        const Color(0xFFD7B4D0),
      );
      _artLine(
        c,
        [const Offset(86, 157), const Offset(114, 157)],
        const Color(0xFF8F9BBD),
        width: 3,
      );
    }
  }

  void _pixelPack(Canvas c, double t) {
    const step = 8.0;
    const rows = [
      '000011111110000',
      '001111111111100',
      '011111111111110',
      '111111111111111',
      '111111111111111',
      '111111111111111',
      '111111111111111',
      '011111111111110',
      '001111111111100',
    ];
    for (var y = 0; y < rows.length; y++) {
      for (var x = 0; x < rows[y].length; x++) {
        if (rows[y][x] != '1') continue;
        final edge =
            x == 0 ||
            x == rows[y].length - 1 ||
            y == 0 ||
            y == rows.length - 1 ||
            rows[y][x - 1] != '1' ||
            rows[y][x + 1] != '1';
        c.drawRect(
          Rect.fromLTWH(40 + x * step, 72 + y * step, step, step),
          Paint()
            ..color = edge ? const Color(0xFF376E65) : const Color(0xFF89D7B1),
        );
      }
    }
    for (final x in [64.0, 112.0]) {
      c.drawRect(
        Rect.fromLTWH(x, 143, 24, 16),
        Paint()..color = const Color(0xFF5DAF92),
      );
    }
    c.drawRect(
      const Rect.fromLTWH(60, 91, 16, 8),
      Paint()..color = const Color(0xFFBCF3D0),
    );
    _artFace(
      c,
      const Offset(100, 110),
      21,
      t,
      ink: const Color(0xFF284D47),
      pixel: true,
    );
    if (_has('tease') || _has('faces')) {
      c.drawRect(
        const Rect.fromLTWH(96, 127, 12, 12),
        Paint()..color = const Color(0xFFFF7E99),
      );
    }
    if (_has('peekaboo')) {
      c.drawRect(
        const Rect.fromLTWH(38, 137, 124, 33),
        Paint()..color = const Color(0xFFD6B494),
      );
      c.drawRect(
        const Rect.fromLTWH(38, 137, 124, 8),
        Paint()..color = const Color(0xFF9A7355),
      );
    }
    _artProp(c, t, const Color(0xFF345A53), pixel: true);
    for (var i = 0; i < 3; i++) {
      final x = 26 + i * 69.0;
      final y = 46 + (i % 2) * 12.0;
      final color = i.isEven
          ? const Color(0xFFFFCE71)
          : const Color(0xFFFF95BA);
      c.drawRect(Rect.fromLTWH(x, y, 6, 18), Paint()..color = color);
      c.drawRect(Rect.fromLTWH(x - 6, y + 6, 18, 6), Paint()..color = color);
    }
    if (_has('faces')) {
      c.drawRect(
        const Rect.fromLTWH(128, 91, 14, 14),
        Paint()..color = const Color(0xFFFF93B2),
      );
      c.drawRect(
        const Rect.fromLTWH(131, 94, 8, 8),
        Paint()..color = const Color(0xFFFFD2DD),
      );
      c.drawRect(
        const Rect.fromLTWH(48, 96, 8, 16),
        Paint()..color = const Color(0xFF5AA890),
      );
    }
  }

  void _spacePack(Canvas c, double t) {
    final subject = scene.subject;
    const body = Color(0xFFABA2EC);
    if (subject == StickerSubject.star) {
      c.save();
      c.translate(100, 108);
      final p = _star(67, inner: 0.6);
      c.drawPath(
        p,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 10,
      );
      _artPath(c, p, _yellow, stroke: _navy, width: 2.5);
      c.restore();
    } else if (subject == StickerSubject.planet ||
        subject == StickerSubject.moon) {
      _artOval(
        c,
        const Rect.fromLTWH(51, 58, 98, 98),
        body,
        stroke: _navy,
        width: 2.5,
      );
      c.save();
      c.translate(100, 110);
      c.rotate(-0.3);
      if (subject == StickerSubject.planet) {
        c.drawOval(
          const Rect.fromLTWH(-80, -20, 160, 39),
          Paint()
            ..color = const Color(0xFFF3C496)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 10,
        );
        _artOval(c, const Rect.fromLTWH(-44, -37, 88, 47), body);
      } else {
        for (final p in [
          const Offset(-28, -19),
          const Offset(30, 17),
          const Offset(-8, 31),
        ]) {
          _artOval(
            c,
            Rect.fromCircle(center: p, radius: 9),
            const Color(0xFF9185CF),
          );
        }
      }
      c.restore();
    } else if (subject == StickerSubject.robot ||
        subject == StickerSubject.game) {
      _artRound(
        c,
        const Rect.fromLTWH(47, 63, 106, 79),
        body,
        radius: 18,
        stroke: _navy,
        width: 2.5,
      );
      _artRound(
        c,
        const Rect.fromLTWH(60, 82, 80, 44),
        const Color(0xFF434269),
        radius: 10,
      );
      _artLine(c, [
        const Offset(100, 63),
        Offset(100 + math.sin(t * 6) * 6, 44),
      ], _navy);
      _artOval(
        c,
        Rect.fromCircle(
          center: Offset(100 + math.sin(t * 6) * 6, 40),
          radius: 7,
        ),
        _coral,
      );
      for (final x in [43.0, 143.0]) {
        _artRound(
          c,
          Rect.fromLTWH(x, 91, 14, 24),
          const Color(0xFFF2BE99),
          radius: 5,
          stroke: _navy,
          width: 2,
        );
      }
      _artFace(c, const Offset(100, 100), 20, t, ink: const Color(0xFFDDECCC));
    } else if (subject == StickerSubject.ghost) {
      final p = Path()
        ..moveTo(47, 160)
        ..lineTo(47, 103)
        ..cubicTo(47, 39, 153, 39, 153, 103)
        ..lineTo(153, 160)
        ..lineTo(133, 145)
        ..lineTo(114, 160)
        ..lineTo(95, 145)
        ..lineTo(76, 160)
        ..lineTo(61, 149)
        ..close();
      _artPath(c, p, const Color(0xFFEDE6FF), stroke: _navy, width: 2.5);
    } else if (subject == StickerSubject.mushroom) {
      _artRound(
        c,
        const Rect.fromLTWH(76, 101, 48, 60),
        const Color(0xFFFFF2D8),
        radius: 13,
        stroke: _navy,
        width: 2.5,
      );
      final cap = Path()
        ..moveTo(30, 104)
        ..cubicTo(40, 24, 160, 24, 170, 104)
        ..quadraticBezierTo(100, 135, 30, 104)
        ..close();
      _artPath(c, cap, body, stroke: _navy, width: 2.5);
      for (final p in [
        const Offset(68, 77),
        const Offset(122, 66),
        const Offset(143, 95),
      ]) {
        _artOval(
          c,
          Rect.fromCircle(center: p, radius: 8),
          const Color(0xFFF4DAA1),
        );
      }
    } else if (subject == StickerSubject.coffee) {
      _artOval(
        c,
        const Rect.fromLTWH(139, 91, 30, 43),
        body,
        stroke: _navy,
        width: 3,
      );
      _artRound(
        c,
        const Rect.fromLTWH(48, 73, 98, 85),
        const Color(0xFFFFF2D8),
        radius: 24,
        stroke: _navy,
        width: 2.5,
      );
      _artOval(
        c,
        const Rect.fromLTWH(50, 66, 94, 22),
        const Color(0xFF97716B),
        stroke: _navy,
        width: 2.5,
      );
    } else if (subject == StickerSubject.letter) {
      final plane = Path()
        ..moveTo(24, 81)
        ..lineTo(178, 46)
        ..lineTo(135, 162)
        ..lineTo(94, 116)
        ..lineTo(64, 144)
        ..lineTo(62, 104)
        ..close();
      _artPath(c, plane, const Color(0xFFEAE0FF), stroke: _navy, width: 2.5);
      _artLine(
        c,
        [const Offset(63, 104), const Offset(178, 46), const Offset(94, 116)],
        _navy,
        width: 2,
      );
    } else {
      _artOval(
        c,
        const Rect.fromLTWH(44, 61, 112, 98),
        body,
        stroke: _navy,
        width: 2.5,
      );
      if (subject == StickerSubject.music) {
        c.drawArc(
          const Rect.fromLTWH(37, 49, 127, 119),
          math.pi,
          math.pi,
          false,
          Paint()
            ..color = _navy
            ..style = PaintingStyle.stroke
            ..strokeWidth = 9,
        );
        for (final x in [33.0, 149.0]) {
          _artRound(c, Rect.fromLTWH(x, 93, 18, 37), _coral, radius: 7);
        }
      }
    }
    if (subject != StickerSubject.robot && subject != StickerSubject.game) {
      _artFace(
        c,
        Offset(100, subject == StickerSubject.mushroom ? 135 : 107),
        18,
        t,
        ink: _navy,
      );
    }
    _artSparkles(c, const Color(0xFFF2C570), t);
    _artHeart(c, const Offset(151, 154), 20, _coral);
    if (subject == StickerSubject.game) {
      _artLine(
        c,
        [const Offset(74, 153), const Offset(88, 153)],
        _navy,
        width: 4,
      );
      _artLine(
        c,
        [const Offset(81, 146), const Offset(81, 160)],
        _navy,
        width: 4,
      );
      _artOval(
        c,
        Rect.fromCircle(center: const Offset(121, 151), radius: 4),
        _coral,
      );
      _artOval(
        c,
        Rect.fromCircle(center: const Offset(130, 158), radius: 4),
        _yellow,
      );
    }
  }

  void _glossyPack(Canvas c, double t) {
    c.drawOval(
      const Rect.fromLTWH(43, 169, 114, 15),
      Paint()
        ..color = const Color(0xFFB5507B).withValues(alpha: 0.13)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
    _artHeart(c, const Offset(100, 108), 136, _coral, shine: true);
    if (_has('glass')) {
      c.drawOval(
        const Rect.fromLTWH(60, 49, 50, 83),
        Paint()..color = Colors.white.withValues(alpha: 0.14),
      );
      _artSparkles(c, const Color(0xFFFFCDE6), t);
    } else if (_has('plush') || _has('thread') || _has('scrapbook')) {
      for (var i = 0; i < 9; i++) {
        final y = 67 + i * 9.0;
        _artLine(
          c,
          [Offset(94, y), Offset(103, y + 3)],
          const Color(0xFFFFD6DF),
          width: 1.6,
        );
      }
      if (_has('scrapbook')) {
        _artRound(
          c,
          const Rect.fromLTWH(48, 39, 40, 14),
          const Color(0xFFF2D797),
          radius: 2,
        );
        _artRound(
          c,
          const Rect.fromLTWH(121, 139, 35, 13),
          const Color(0xFFD4BADB),
          radius: 2,
        );
      }
    } else if (_has('healing')) {
      c.save();
      c.translate(100, 133);
      c.rotate(-0.3);
      _artRound(
        c,
        const Rect.fromLTWH(-24, -10, 48, 20),
        const Color(0xFFFFDEAA),
        radius: 8,
      );
      for (var i = 0; i < 3; i++) {
        _artOval(
          c,
          Rect.fromCircle(center: Offset(-8 + i * 8.0, 0), radius: 1.3),
          const Color(0xFFCA9B70),
        );
      }
      c.restore();
    } else if (_has('gift')) {
      _artLine(
        c,
        [const Offset(44, 95), const Offset(155, 95)],
        const Color(0xFFFFE8B6),
        width: 8,
      );
      _artLine(
        c,
        [const Offset(101, 53), const Offset(101, 160)],
        const Color(0xFFFFE8B6),
        width: 8,
      );
      _artOval(c, const Rect.fromLTWH(69, 77, 32, 16), const Color(0xFFFFE8B6));
      _artOval(
        c,
        const Rect.fromLTWH(101, 77, 32, 16),
        const Color(0xFFFFE8B6),
      );
    } else if (_has('calendar')) {
      _artRound(
        c,
        const Rect.fromLTWH(77, 128, 47, 40),
        const Color(0xFFFFF5EA),
        radius: 6,
      );
      _artRound(c, const Rect.fromLTWH(77, 128, 47, 10), _lavender, radius: 3);
      _artHeart(c, const Offset(100, 151), 20, _coral);
    } else if (_has('heartbeat')) {
      _artLine(
        c,
        [
          const Offset(41, 114),
          const Offset(67, 114),
          const Offset(80, 95),
          const Offset(92, 135),
          const Offset(111, 98),
          const Offset(127, 114),
          const Offset(159, 114),
        ],
        Colors.white,
        width: 3,
      );
    }
    if (!_has('heartbeat') && !_has('gift')) {
      _artFace(c, const Offset(100, 99), 21, t, ink: const Color(0xFF8B3F62));
    }
    if (_has('letter') || _has('locket')) {
      _artProp(c, t, const Color(0xFF914C66));
    }
    if (_has('celebrate')) {
      for (var i = 0; i < 6; i++) {
        _artStar(
          c,
          Offset(28 + i * 29.0, 28 + i % 2 * 15.0),
          6,
          [_yellow, _lavender][i % 2],
        );
      }
    }
  }

  void _paperPack(Canvas c, double t) {
    void bird(Offset p, Color color, bool mirror) {
      c.save();
      c.translate(p.dx, p.dy);
      if (mirror) c.scale(-1, 1);
      final shape = Path()
        ..moveTo(-36, -4)
        ..lineTo(-49, -25)
        ..lineTo(-9, -12)
        ..lineTo(2, -52)
        ..lineTo(34, -43)
        ..lineTo(29, -8)
        ..quadraticBezierTo(49, 31, 8, 37)
        ..quadraticBezierTo(-36, 34, -36, -4)
        ..close();
      c.drawPath(
        shape.shift(const Offset(2, 3)),
        Paint()..color = _brown.withValues(alpha: 0.1),
      );
      _artPath(c, shape, color);
      _artPath(
        c,
        Path()
          ..moveTo(-35, -2)
          ..lineTo(13, -6)
          ..lineTo(2 + math.sin(t * 6) * 3, 26)
          ..close(),
        Color.lerp(color, Colors.white, 0.35)!,
      );
      _artPath(
        c,
        Path()
          ..moveTo(30, -29)
          ..lineTo(47, -23)
          ..lineTo(29, -17)
          ..close(),
        const Color(0xFFD9AE71),
      );
      _artOval(
        c,
        Rect.fromCircle(center: const Offset(17, -28), radius: 2.6),
        const Color(0xFF53685C),
      );
      _artLine(
        c,
        [const Offset(-1, 37), const Offset(-3, 48)],
        const Color(0xFFAA8A6B),
        width: 2,
      );
      c.restore();
    }

    final sleep = _has('sleep');
    bird(
      Offset(_has('kiss') ? 68 : 57, sleep ? 123 : 115),
      const Color(0xFF8FB4A4),
      false,
    );
    bird(
      Offset(_has('kiss') ? 132 : 143, sleep ? 123 : 115),
      const Color(0xFFD3AAA6),
      true,
    );
    if (_has('missing') || _has('send_love')) {
      final dashes = Paint()
        ..color = const Color(0xFFBD978F)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.7;
      for (var i = 0; i < 7; i++) {
        c.drawLine(
          Offset(61 + i * 11.0, 60 + math.sin(i / 6 * math.pi) * -15),
          Offset(66 + i * 11.0, 60 + math.sin(i / 6 * math.pi) * -15),
          dashes,
        );
      }
      _artHeart(c, const Offset(100, 44), 21, _coral);
    } else if (_has('sleep')) {
      _artPath(
        c,
        Path()
          ..moveTo(22, 151)
          ..quadraticBezierTo(100, 180, 178, 151)
          ..quadraticBezierTo(168, 186, 100, 188)
          ..quadraticBezierTo(26, 180, 22, 151)
          ..close(),
        const Color(0xFFD8C4AC),
      );
      _artStar(c, const Offset(100, 38), 12, const Color(0xFFDDC791));
    } else if (_has('celebrate') || _has('dance')) {
      for (var i = 0; i < 5; i++) {
        _artStar(
          c,
          Offset(39 + i * 30.0, 44 + i % 2 * 15.0),
          5,
          i.isEven ? const Color(0xFFDEBA74) : const Color(0xFFD5A89B),
        );
      }
    } else {
      _artHeart(c, const Offset(100, 69), 26, const Color(0xFFD18D94));
    }
    if (_has('comfort') || _has('cuddle')) {
      _artPath(
        c,
        Path()
          ..moveTo(83, 130)
          ..lineTo(119, 131)
          ..lineTo(103, 155)
          ..close(),
        const Color(0xFFCBD1AF),
      );
    }
    if (_has('comfort')) {
      _artPath(
        c,
        Path()
          ..moveTo(45, 163)
          ..lineTo(72, 150)
          ..lineTo(95, 163)
          ..lineTo(95, 177)
          ..lineTo(45, 177)
          ..close(),
        const Color(0xFFF5E7CD),
      );
      _artHeart(c, const Offset(72, 163), 16, const Color(0xFFB1C9AF));
    }
    if (_has('send_love')) {
      _artPath(
        c,
        Path()
          ..moveTo(76, 83)
          ..lineTo(122, 70)
          ..lineTo(107, 105)
          ..lineTo(99, 89)
          ..close(),
        const Color(0xFFE4C5B1),
      );
    }
    if (_has('dance')) {
      _artLine(
        c,
        [
          const Offset(169, 46),
          const Offset(169, 28),
          const Offset(182, 24),
          const Offset(182, 41),
        ],
        const Color(0xFF9DAB8F),
        width: 3,
      );
      _artOval(c, const Rect.fromLTWH(161, 43, 9, 6), const Color(0xFF9DAB8F));
      _artOval(c, const Rect.fromLTWH(174, 38, 9, 6), const Color(0xFF9DAB8F));
    }
  }

  void _journalPack(Canvas c, double t) {
    c.save();
    c.translate(100, 111);
    c.rotate(_has('playful') ? -0.1 : 0.04);
    _artRound(
      c,
      const Rect.fromLTWH(-55, -67, 111, 139),
      const Color(0xFFE4CEC0),
      radius: 8,
    );
    _artRound(
      c,
      const Rect.fromLTWH(-58, -71, 109, 137),
      const Color(0xFFFFF7E8),
      radius: 5,
      stroke: const Color(0xFF8E7668),
      width: 1.5,
    );
    for (var i = 0; i < 7; i++) {
      _artLine(
        c,
        [Offset(-59, -55 + i * 17.0), Offset(-48, -55 + i * 17.0)],
        const Color(0xFF947B72),
        width: 2.2,
      );
    }
    _artRound(
      c,
      const Rect.fromLTWH(-24, -78, 54, 16),
      const Color(0xFFCBD8BE),
      radius: 1,
    );
    _artLine(
      c,
      [const Offset(-38, 34), const Offset(29, 34)],
      const Color(0xFFD9C6B8),
      width: 1,
    );
    _artLine(
      c,
      [const Offset(-38, 46), const Offset(18, 46)],
      const Color(0xFFD9C6B8),
      width: 1,
    );
    _artLine(
      c,
      [const Offset(-38, 56), const Offset(32, 56)],
      const Color(0xFFD9C6B8),
      width: 1,
    );
    _artFace(c, const Offset(-3, -14), 22, t, ink: const Color(0xFF8E7668));
    if (_has('proud')) {
      _artStar(c, const Offset(26, 23), 18, const Color(0xFFECCB77));
      _artLine(
        c,
        [const Offset(18, 25), const Offset(23, 30), const Offset(32, 17)],
        const Color(0xFF9D7B42),
        width: 2,
      );
    } else if (_has('anxious')) {
      for (var i = 0; i < 3; i++) {
        _artLine(
          c,
          [Offset(-28 + i * 11.0, -43), Offset(-23 + i * 11.0, -51)],
          _lavender,
          width: 2,
        );
      }
    } else if (_has('reflective')) {
      _artOval(
        c,
        Rect.fromCircle(center: const Offset(31, -47), radius: 7),
        const Color(0xFFE3DACF),
      );
      _artOval(
        c,
        Rect.fromCircle(center: const Offset(21, -35), radius: 3),
        const Color(0xFFE3DACF),
      );
    } else {
      _artHeart(
        c,
        const Offset(26, 23),
        24,
        _has('healing') ? const Color(0xFF98B49E) : const Color(0xFFD99DAD),
      );
    }
    c.restore();
    // Bút chì và trang giấy giúp bộ nhật ký có hình dáng riêng.
    _artLine(
      c,
      [const Offset(146, 178), const Offset(169, 118)],
      const Color(0xFFE2B97B),
      width: 10,
    );
    _artLine(
      c,
      [const Offset(169, 118), const Offset(174, 106)],
      const Color(0xFF8E7668),
      width: 5,
    );
    if (_has('missing') || _has('shy')) {
      _artHeart(c, const Offset(31, 64), 20, const Color(0xFFDAADBA));
    }
  }
}
