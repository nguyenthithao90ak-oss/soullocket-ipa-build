import 'dart:math' as math;

import 'package:flutter/material.dart';

enum DiaryStickerMotif {
  pressedFlower,
  leafySprig,
  washiTape,
  camera,
  envelope,
  polaroid,
  paperClip,
  postage,
  memoryBox,
  photoCorners,
  daisy,
  wildflower,
  coffee,
  openBook,
  letter,
  seal,
  ribbon,
  ticket,
  sun,
  sparkle,
}

@immutable
class DiaryStickerPlacement {
  final int design;
  final int edge;
  final double position;
  final double angle;

  const DiaryStickerPlacement({
    required this.design,
    required this.edge,
    required this.position,
    required this.angle,
  });

  factory DiaryStickerPlacement.forMemory(String identity) {
    var hash = 2166136261;
    for (final code in identity.codeUnits) {
      hash = ((hash ^ code) * 16777619) & 0xffffffff;
    }
    final random = math.Random(hash);
    return DiaryStickerPlacement(
      design: random.nextInt(DiaryScrapbookSticker.designCount),
      edge: random.nextInt(4),
      position: 0.22 + random.nextDouble() * 0.56,
      angle: (random.nextDouble() - 0.5) * 0.45,
    );
  }

  Alignment get alignment => switch (edge) {
    0 => Alignment(position * 2 - 1, -1),
    1 => Alignment(1, position * 2 - 1),
    2 => Alignment(position * 2 - 1, 1),
    _ => Alignment(-1, position * 2 - 1),
  };
}

class DiaryScrapbookFrame extends StatelessWidget {
  final String memoryIdentity;
  final Widget child;

  const DiaryScrapbookFrame({
    super.key,
    required this.memoryIdentity,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final placement = DiaryStickerPlacement.forMemory(memoryIdentity);
    return Stack(
      fit: StackFit.passthrough,
      children: [
        child,
        Positioned.fill(
          child: IgnorePointer(
            child: ExcludeSemantics(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final extent = (constraints.maxWidth * 0.29).clamp(
                    24.0,
                    38.0,
                  );
                  return Align(
                    alignment: placement.alignment,
                    child: Transform.rotate(
                      angle: placement.angle,
                      child: DiaryScrapbookSticker(
                        design: placement.design,
                        size: extent,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class DiaryScrapbookSticker extends StatelessWidget {
  static const designCount = 100;
  final int design;
  final double size;

  const DiaryScrapbookSticker({super.key, required this.design, this.size = 38})
    : assert(design >= 0 && design < designCount);

  @override
  Widget build(BuildContext context) {
    final motif =
        DiaryStickerMotif.values[design % DiaryStickerMotif.values.length];
    final imageAsset = switch (motif) {
      DiaryStickerMotif.pressedFlower ||
      DiaryStickerMotif.daisy ||
      DiaryStickerMotif.wildflower =>
        'assets/images/diary_scrapbook/floral_cluster.webp',
      DiaryStickerMotif.leafySprig =>
        'assets/images/diary_scrapbook/leafy_sprig.webp',
      _ => null,
    };

    return ExcludeSemantics(
      child: RepaintBoundary(
        child: imageAsset == null
            ? CustomPaint(
                size: Size.square(size),
                painter: DiaryStickerPainter(design),
              )
            : Image.asset(
                imageAsset,
                width: size,
                height: size,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.medium,
                gaplessPlayback: true,
              ),
      ),
    );
  }
}

class DiaryStickerPainter extends CustomPainter {
  final int design;
  const DiaryStickerPainter(this.design);

  static const _palettes = [
    [Color(0xFFCC8190), Color(0xFFE9A17A)],
    [Color(0xFF9DB7A4), Color(0xFFF6D6A8)],
    [Color(0xFFC88B78), Color(0xFFF4B7A8)],
    [Color(0xFFB1A897), Color(0xFFDEB47C)],
    [Color(0xFFBC9AA8), Color(0xFFE9D5BA)],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 64, size.height / 64);
    final palette = _palettes[design ~/ DiaryStickerMotif.values.length];
    final main = palette[0];
    final accent = palette[1];
    final paint = Paint()..isAntiAlias = true;
    void oval(
      double left,
      double top,
      double width,
      double height,
      Color color,
    ) {
      paint.color = color;
      canvas.drawOval(Rect.fromLTWH(left, top, width, height), paint);
    }

    void shape(Path path, Color color) {
      canvas.drawPath(
        path,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeJoin = StrokeJoin.round
          ..strokeWidth = 3,
      );
      canvas.drawPath(path, Paint()..color = color);
    }

    void box(
      double left,
      double top,
      double width,
      double height,
      Color color,
    ) {
      shape(
        Path()..addRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(left, top, width, height),
            const Radius.circular(7),
          ),
        ),
        color,
      );
    }

    void line(Offset from, Offset to, Color color, [double width = 2]) {
      canvas.drawLine(
        from,
        to,
        Paint()
          ..color = color
          ..strokeWidth = width
          ..strokeCap = StrokeCap.round,
      );
    }

    Path star(double centerX, double centerY, double radius) {
      final path = Path();
      for (var point = 0; point < 10; point++) {
        final angle = -math.pi / 2 + point * math.pi / 5;
        final distance = point.isEven ? radius : radius * 0.48;
        final offset = Offset(
          centerX + math.cos(angle) * distance,
          centerY + math.sin(angle) * distance,
        );
        if (point == 0) {
          path.moveTo(offset.dx, offset.dy);
        } else {
          path.lineTo(offset.dx, offset.dy);
        }
      }
      return path..close();
    }

    final motif =
        DiaryStickerMotif.values[design % DiaryStickerMotif.values.length];
    const paper = Color(0xFFFFF8F0);
    const sage = Color(0xFF6F8A78);
    const cocoa = Color(0xFF70534A);
    const terracotta = Color(0xFFC47764);
    void drawFlower(Offset center, double radius, Color petal) {
      for (var petalIndex = 0; petalIndex < 6; petalIndex++) {
        final angle = petalIndex * math.pi / 3;
        oval(
          center.dx + math.cos(angle) * radius * 0.52 - radius * 0.34,
          center.dy + math.sin(angle) * radius * 0.52 - radius * 0.28,
          radius * 0.68,
          radius * 0.56,
          petal,
        );
      }
      oval(
        center.dx - radius * 0.22,
        center.dy - radius * 0.22,
        radius * 0.44,
        radius * 0.44,
        accent,
      );
    }

    switch (motif) {
      case DiaryStickerMotif.pressedFlower:
        line(const Offset(31, 58), const Offset(34, 31), sage, 3);
        line(const Offset(31, 48), const Offset(18, 39), sage, 2.5);
        oval(12, 34, 15, 8, sage);
        drawFlower(const Offset(35, 25), 25, main);
      case DiaryStickerMotif.leafySprig:
        line(const Offset(12, 56), const Offset(47, 9), sage, 3);
        for (final leaf in <({double x, double y, double a})>[
          (x: 18, y: 45, a: -0.8),
          (x: 25, y: 37, a: 0.6),
          (x: 32, y: 28, a: -0.8),
          (x: 39, y: 20, a: 0.6),
          (x: 45, y: 12, a: -0.7),
        ]) {
          canvas.save();
          canvas.translate(leaf.x, leaf.y);
          canvas.rotate(leaf.a);
          oval(-8, -4, 16, 8, main);
          canvas.restore();
        }
      case DiaryStickerMotif.washiTape:
        box(7, 19, 50, 27, main);
        for (var stripe = 0; stripe < 5; stripe++) {
          line(
            Offset(14 + stripe * 10, 20),
            Offset(17 + stripe * 10, 45),
            accent.withValues(alpha: 0.58),
            3,
          );
        }
      case DiaryStickerMotif.camera:
        box(10, 22, 44, 30, main);
        box(21, 16, 15, 8, accent);
        oval(22, 28, 20, 20, paper);
        oval(27, 33, 10, 10, cocoa);
        oval(30, 36, 4, 4, accent);
        oval(45, 27, 4, 4, accent);
      case DiaryStickerMotif.envelope:
        box(7, 19, 50, 32, paper);
        line(const Offset(9, 22), const Offset(32, 40), terracotta, 2);
        line(const Offset(55, 22), const Offset(32, 40), terracotta, 2);
        oval(27, 35, 10, 9, main);
      case DiaryStickerMotif.polaroid:
        box(11, 7, 42, 51, paper);
        box(16, 13, 32, 29, accent);
        line(const Offset(19, 38), const Offset(45, 38), cocoa, 2);
        drawFlower(const Offset(25, 25), 12, main);
      case DiaryStickerMotif.paperClip:
        line(const Offset(30, 57), const Offset(18, 21), accent, 4);
        canvas.drawArc(
          const Rect.fromLTWH(17, 8, 27, 42),
          -math.pi * 0.75,
          math.pi * 1.65,
          false,
          Paint()
            ..color = cocoa
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3,
        );
      case DiaryStickerMotif.postage:
        box(10, 11, 44, 42, paper);
        box(15, 16, 34, 32, main);
        drawFlower(const Offset(32, 31), 18, accent);
        for (var dot = 0; dot < 5; dot++) {
          oval(13 + dot * 9, 7, 3, 3, cocoa);
          oval(13 + dot * 9, 53, 3, 3, cocoa);
        }
      case DiaryStickerMotif.memoryBox:
        box(8, 31, 48, 24, main);
        box(5, 24, 54, 10, accent);
        box(17, 10, 15, 18, paper);
        box(35, 14, 14, 14, paper);
        line(const Offset(32, 35), const Offset(32, 53), terracotta, 3);
      case DiaryStickerMotif.photoCorners:
        box(11, 11, 42, 42, paper);
        for (final corner in [
          const Offset(14, 14),
          const Offset(48, 14),
          const Offset(14, 48),
          const Offset(48, 48),
        ]) {
          line(
            corner,
            Offset(corner.dx + (corner.dx < 32 ? 9 : -9), corner.dy),
            sage,
            3,
          );
          line(
            corner,
            Offset(corner.dx, corner.dy + (corner.dy < 32 ? 9 : -9)),
            sage,
            3,
          );
        }
        drawFlower(const Offset(32, 31), 17, accent);
      case DiaryStickerMotif.daisy:
        line(const Offset(32, 58), const Offset(32, 37), sage, 3);
        drawFlower(const Offset(32, 25), 25, paper);
        oval(26, 19, 12, 12, accent);
      case DiaryStickerMotif.wildflower:
        for (final stem in [18.0, 32.0, 46.0]) {
          line(
            Offset(stem, 57),
            Offset(stem + (stem - 32) * 0.22, 27),
            sage,
            2,
          );
          drawFlower(Offset(stem + (stem - 32) * 0.22, 23), 14, main);
        }
      case DiaryStickerMotif.coffee:
        box(11, 22, 34, 29, main);
        canvas.drawArc(
          const Rect.fromLTWH(39, 28, 18, 17),
          -math.pi / 2,
          math.pi,
          false,
          Paint()
            ..color = cocoa
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3,
        );
        line(const Offset(20, 15), const Offset(23, 8), cocoa, 2);
        line(const Offset(34, 15), const Offset(37, 8), cocoa, 2);
        oval(17, 18, 23, 6, accent);
      case DiaryStickerMotif.openBook:
        shape(
          Path()
            ..moveTo(7, 18)
            ..quadraticBezierTo(20, 12, 31, 20)
            ..lineTo(31, 54)
            ..quadraticBezierTo(19, 47, 7, 52)
            ..close(),
          paper,
        );
        shape(
          Path()
            ..moveTo(33, 20)
            ..quadraticBezierTo(44, 12, 57, 18)
            ..lineTo(57, 52)
            ..quadraticBezierTo(44, 47, 33, 54)
            ..close(),
          paper,
        );
        line(const Offset(17, 29), const Offset(27, 29), accent, 2);
        line(const Offset(39, 29), const Offset(49, 29), accent, 2);
      case DiaryStickerMotif.letter:
        box(9, 16, 46, 36, paper);
        line(const Offset(11, 20), const Offset(32, 39), main, 2);
        line(const Offset(53, 20), const Offset(32, 39), main, 2);
        line(const Offset(17, 46), const Offset(29, 46), accent, 2);
        line(const Offset(35, 46), const Offset(47, 46), accent, 2);
      case DiaryStickerMotif.seal:
        oval(10, 10, 44, 44, main);
        oval(17, 17, 30, 30, paper);
        oval(24, 24, 16, 16, accent);
        line(
          const Offset(32, 6),
          const Offset(32, 58),
          main.withValues(alpha: 0.7),
          1.5,
        );
        line(
          const Offset(6, 32),
          const Offset(58, 32),
          main.withValues(alpha: 0.7),
          1.5,
        );
      case DiaryStickerMotif.ribbon:
        shape(
          Path()
            ..moveTo(32, 28)
            ..quadraticBezierTo(3, 5, 7, 34)
            ..quadraticBezierTo(10, 52, 32, 34)
            ..quadraticBezierTo(54, 52, 57, 34)
            ..quadraticBezierTo(61, 5, 32, 28)
            ..close(),
          main,
        );
        box(27, 24, 10, 17, accent);
        line(const Offset(29, 41), const Offset(21, 57), accent, 4);
        line(const Offset(35, 41), const Offset(43, 57), accent, 4);
      case DiaryStickerMotif.ticket:
        box(7, 19, 50, 28, main);
        canvas.drawCircle(const Offset(7, 33), 5, Paint()..color = paper);
        canvas.drawCircle(const Offset(57, 33), 5, Paint()..color = paper);
        line(const Offset(21, 27), const Offset(43, 27), paper, 2);
        line(const Offset(21, 38), const Offset(37, 38), paper, 2);
      case DiaryStickerMotif.sun:
        for (var ray = 0; ray < 8; ray++) {
          final angle = ray * math.pi / 4;
          line(
            Offset(32 + math.cos(angle) * 18, 32 + math.sin(angle) * 18),
            Offset(32 + math.cos(angle) * 28, 32 + math.sin(angle) * 28),
            accent,
            3,
          );
        }
        oval(17, 17, 30, 30, main);
        oval(25, 26, 4, 4, cocoa);
        oval(36, 26, 4, 4, cocoa);
      case DiaryStickerMotif.sparkle:
        shape(star(32, 31, 25), accent);
        oval(13, 12, 6, 6, main);
        oval(48, 45, 5, 5, main);
    }
    oval(6, 9, 3, 3, accent.withValues(alpha: 0.72));
    oval(55, 53, 3, 3, main.withValues(alpha: 0.72));
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant DiaryStickerPainter oldDelegate) =>
      oldDelegate.design != design;
}
