part of '../../drawing_studio_screen.dart';

abstract final class _StudioStyle {
  static const atlasAsset =
      'assets/runtime_lossless/drawing_studio_atlas_v1.png';
  static const cream = Color(0xFFFFF7EE);
  static const coral = Color(0xFFFF526C);
  static const ink = Color(0xFF754442);
  static const muted = Color(0xFF916D64);

  static TextStyle text(double size, {Color color = ink}) =>
      GoogleFonts.patrickHand(fontSize: size, color: color, height: 1.16);

  static Duration motion(BuildContext context) =>
      MediaQuery.disableAnimationsOf(context)
      ? Duration.zero
      : const Duration(milliseconds: 160);
}

class _StudioCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const _StudioCard({
    required this.child,
    this.padding = const EdgeInsets.all(14),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFFDFC), Color(0xFFFFFAF1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22C79562),
            blurRadius: 14,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: child,
    );
  }
}

void _drawStudioSprite(Canvas canvas, ui.Image atlas, int index, Rect target) {
  // Atlas có khoảng thở riêng cho từng hình; cắt theo hình để không lộ ô cạnh.
  const regions = <Rect>[
    Rect.fromLTWH(12, 67, 395, 337),
    Rect.fromLTWH(414, 67, 348, 363),
    Rect.fromLTWH(775, 88, 308, 299),
    Rect.fromLTWH(1145, 89, 258, 255),
    Rect.fromLTWH(63, 450, 278, 290),
    Rect.fromLTWH(425, 450, 286, 285),
    Rect.fromLTWH(748, 443, 320, 307),
    Rect.fromLTWH(1126, 452, 283, 288),
    Rect.fromLTWH(32, 785, 313, 270),
    Rect.fromLTWH(392, 762, 343, 305),
    Rect.fromLTWH(732, 808, 362, 256),
    Rect.fromLTWH(1102, 750, 338, 317),
  ];
  if (index < 0 || index >= regions.length) return;
  final region = regions[index];
  final source = Rect.fromLTWH(
    region.left / 1448 * atlas.width,
    region.top / 1086 * atlas.height,
    region.width / 1448 * atlas.width,
    region.height / 1086 * atlas.height,
  );
  final fitted = applyBoxFit(BoxFit.contain, source.size, target.size);
  canvas.drawImageRect(
    atlas,
    source,
    Alignment.center.inscribe(fitted.destination, target),
    Paint()..filterQuality = FilterQuality.medium,
  );
}

class _StudioSprite extends StatelessWidget {
  final ui.Image? atlas;
  final int index;
  final double size;
  final IconData fallback;

  const _StudioSprite({
    required this.atlas,
    required this.index,
    this.size = 48,
    this.fallback = Icons.auto_awesome_rounded,
  });

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: atlas == null
            ? Icon(fallback, color: _StudioStyle.coral, size: size * 0.6)
            : CustomPaint(painter: _StudioSpritePainter(atlas!, index)),
      ),
    );
  }
}

class _StudioSpritePainter extends CustomPainter {
  final ui.Image atlas;
  final int index;

  const _StudioSpritePainter(this.atlas, this.index);

  @override
  void paint(Canvas canvas, Size size) {
    _drawStudioSprite(canvas, atlas, index, Offset.zero & size);
  }

  @override
  bool shouldRepaint(covariant _StudioSpritePainter oldDelegate) =>
      atlas != oldDelegate.atlas || index != oldDelegate.index;
}

class _StudioTool extends StatelessWidget {
  final String id;
  final String label;
  final ui.Image? atlas;
  final int sprite;
  final IconData fallback;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool selected;
  final bool busy;

  const _StudioTool({
    required this.id,
    required this.label,
    required this.atlas,
    required this.sprite,
    required this.fallback,
    required this.onTap,
    this.onLongPress,
    this.selected = false,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: onTap != null,
      selected: selected,
      label: label,
      child: Tooltip(
        message: label,
        child: Material(
          color: selected ? const Color(0xFFFFEDF0) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            key: Key('drawing-tool-$id'),
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            onLongPress: onTap == null ? null : onLongPress,
            child: Opacity(
              opacity: onTap == null && !busy ? 0.38 : 1,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 6),
                child: Column(
                  children: [
                    if (busy)
                      const SizedBox.square(
                        dimension: 38,
                        child: Padding(
                          padding: EdgeInsets.all(8),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    else
                      _StudioSprite(
                        atlas: atlas,
                        index: sprite,
                        size: 38,
                        fallback: fallback,
                      ),
                    const SizedBox(height: 3),
                    Text(
                      label,
                      textAlign: TextAlign.center,
                      style: _StudioStyle.text(15),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StudioPaperClipper extends CustomClipper<Path> {
  const _StudioPaperClipper();

  @override
  Path getClip(Size size) {
    final path = Path()..moveTo(12, 3);
    for (double x = 12; x < size.width - 12; x += 9) {
      path.lineTo(x, 3 + math.sin(x * 0.7) * 1.5);
    }
    path.quadraticBezierTo(size.width - 3, 1, size.width - 3, 12);
    for (double y = 12; y < size.height - 12; y += 9) {
      path.lineTo(size.width - 3 + math.sin(y * 0.63) * 1.4, y);
    }
    path.quadraticBezierTo(
      size.width,
      size.height - 3,
      size.width - 12,
      size.height - 3,
    );
    for (double x = size.width - 12; x > 12; x -= 9) {
      path.lineTo(x, size.height - 3 + math.sin(x * 0.77) * 1.4);
    }
    path.quadraticBezierTo(3, size.height, 3, size.height - 12);
    for (double y = size.height - 12; y > 12; y -= 9) {
      path.lineTo(3 + math.sin(y * 0.68) * 1.4, y);
    }
    path.quadraticBezierTo(1, 3, 12, 3);
    return path..close();
  }

  @override
  bool shouldReclip(covariant _StudioPaperClipper oldClipper) => false;
}

class _StudioPaperShadow extends CustomPainter {
  const _StudioPaperShadow();

  @override
  void paint(Canvas canvas, Size size) {
    final path = const _StudioPaperClipper().getClip(size);
    canvas.drawShadow(path, const Color(0xFFB68F68), 5, true);
    canvas.drawPath(path, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _StudioPaperShadow oldDelegate) => false;
}

class _StudioGrainPainter extends CustomPainter {
  final bool paper;
  const _StudioGrainPainter({this.paper = false});

  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(29);
    final paint = Paint()
      ..color = const Color(0xFFB48D68).withValues(alpha: paper ? 0.06 : 0.07);
    for (var i = 0; i < 1000; i++) {
      final point = Offset(
        random.nextDouble() * size.width,
        random.nextDouble() * size.height,
      );
      canvas.drawCircle(point, random.nextDouble() * 0.55 + 0.15, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _StudioGrainPainter oldDelegate) =>
      paper != oldDelegate.paper;
}

class _StudioPaperTrim extends CustomPainter {
  const _StudioPaperTrim();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(
      13,
      13,
      math.max(0, size.width - 26),
      math.max(0, size.height - 26),
    );
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(13)));
    final paint = Paint()
      ..color = const Color(0xFFFFBCC8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round;
    for (final metric in path.computeMetrics()) {
      for (double start = 0; start < metric.length; start += 9) {
        canvas.drawPath(
          metric.extractPath(start, math.min(start + 4, metric.length)),
          paint,
        );
      }
    }
    final star = Path();
    const center = Offset(30, 40);
    for (var i = 0; i < 10; i++) {
      final angle = -math.pi / 2 + i * math.pi / 5;
      final radius = i.isEven ? 9.0 : 4.0;
      final p = center + Offset(math.cos(angle), math.sin(angle)) * radius;
      i == 0 ? star.moveTo(p.dx, p.dy) : star.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(star..close(), Paint()..color = const Color(0xFFFFCE66));
  }

  @override
  bool shouldRepaint(covariant _StudioPaperTrim oldDelegate) => false;
}

class _StudioWashiTape extends StatelessWidget {
  final bool blue;
  const _StudioWashiTape({this.blue = false});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Transform.rotate(
        angle: -0.57,
        child: CustomPaint(
          painter: _StudioWashiPainter(blue),
          size: const Size(62, 23),
        ),
      ),
    );
  }
}

class _StudioWashiPainter extends CustomPainter {
  final bool blue;
  const _StudioWashiPainter(this.blue);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = blue ? const Color(0xFF99D3F2) : const Color(0xFFFFE0E3),
    );
    if (blue) {
      for (double y = 4; y < size.height; y += 9) {
        for (double x = 4; x < size.width; x += 10) {
          canvas.drawCircle(
            Offset(x, y),
            1.7,
            Paint()..color = Colors.white.withValues(alpha: 0.85),
          );
        }
      }
    } else {
      for (double x = 0; x < size.width; x += 12) {
        canvas.drawRect(
          Rect.fromLTWH(x, 0, 6, size.height),
          Paint()..color = const Color(0xFFFBAEBB).withValues(alpha: 0.6),
        );
      }
      for (double y = 0; y < size.height; y += 10) {
        canvas.drawRect(
          Rect.fromLTWH(0, y, size.width, 5),
          Paint()..color = Colors.white.withValues(alpha: 0.5),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _StudioWashiPainter oldDelegate) =>
      blue != oldDelegate.blue;
}
