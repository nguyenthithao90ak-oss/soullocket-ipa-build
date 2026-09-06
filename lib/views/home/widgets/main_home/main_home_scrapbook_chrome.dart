part of '../../tabs/main_home_tab.dart';

/// Lớp trang trí nền dành riêng cho Home. Painter chỉ phủ các nét giấy và
/// đường chỉ mờ nên vẫn giữ nguyên hình nền/chủ đề người dùng đã chọn.
class _HomeScrapbookBackdrop extends StatelessWidget {
  final bool hasCustomBackground;

  const _HomeScrapbookBackdrop({required this.hasCustomBackground});

  @override
  Widget build(BuildContext context) {
    final ui = UiPrefs.notifier.value;
    final themeKey = ui.themeKey.trim();
    final isAutomaticNight =
        themeKey == 'theme-auto' &&
        (DateTime.now().hour >= 19 || DateTime.now().hour < 6);
    final isDark =
        Theme.of(context).brightness == Brightness.dark ||
        themeKey == 'theme-night' ||
        themeKey == 'theme-dark' ||
        themeKey == 'theme-mystic-dark' ||
        isAutomaticNight;
    final preserveShellBackground =
        hasCustomBackground || ui.transparentMode || isDark;

    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _HomeScrapbookBackdropPainter(
            hasCustomBackground: preserveShellBackground,
            isDark: isDark,
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _HomeScrapbookBackdropPainter extends CustomPainter {
  final bool hasCustomBackground;
  final bool isDark;

  const _HomeScrapbookBackdropPainter({
    required this.hasCustomBackground,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rect = Offset.zero & size;

    if (!hasCustomBackground) {
      final hour = DateTime.now().hour;
      final List<Color> daytimePaper = hour < 6
          ? const [Color(0xFFF3ECFF), Color(0xFFFFF2F7), Color(0xFFF8EEE3)]
          : hour < 11
          ? const [Color(0xFFFFF8E8), Color(0xFFFFEEF3), Color(0xFFFFEAD8)]
          : hour < 15
          ? const [Color(0xFFFFF4DF), Color(0xFFFFF0EA), Color(0xFFFFE7EF)]
          : hour < 19
          ? const [Color(0xFFFFEAF0), Color(0xFFF7EDFF), Color(0xFFFFF1E6)]
          : const [Color(0xFFF0E9FF), Color(0xFFFFEAF3), Color(0xFFF8EEE3)];
      canvas.drawRect(
        rect,
        Paint()
          ..shader = LinearGradient(
            colors: isDark
                ? <Color>[
                    const Color(0xFF241C2B).withValues(alpha: 0.52),
                    const Color(0xFF302235).withValues(alpha: 0.28),
                    Colors.transparent,
                  ]
                : <Color>[
                    daytimePaper[0].withValues(alpha: 0.72),
                    daytimePaper[1].withValues(alpha: 0.50),
                    daytimePaper[2].withValues(alpha: 0.30),
                  ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ).createShader(rect),
      );
    }

    final lineColor = (isDark ? Colors.white : const Color(0xFF8F6F78))
        .withValues(alpha: hasCustomBackground ? 0.045 : 0.075);
    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 0.85;
    for (double y = 118; y < size.height; y += 42) {
      canvas.drawLine(
        Offset(18, y),
        Offset(size.width - 18, y + ((y ~/ 42).isEven ? 0.7 : -0.5)),
        linePaint,
      );
    }

    final threadPaint = Paint()
      ..color = SLColors.thread.withValues(
        alpha: hasCustomBackground ? 0.08 : 0.14,
      )
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.45
      ..strokeCap = StrokeCap.round;
    final thread = Path()
      ..moveTo(-18, size.height * 0.18)
      ..cubicTo(
        size.width * 0.26,
        size.height * 0.12,
        size.width * 0.08,
        size.height * 0.34,
        size.width * 0.36,
        size.height * 0.38,
      )
      ..cubicTo(
        size.width * 0.68,
        size.height * 0.43,
        size.width * 0.72,
        size.height * 0.64,
        size.width + 24,
        size.height * 0.59,
      );
    canvas.drawPath(thread, threadPaint);

    final dotPaint = Paint()
      ..color = SLColors.secondary.withValues(
        alpha: hasCustomBackground ? 0.08 : 0.14,
      );
    for (var index = 0; index < 18; index++) {
      final x = 22.0 + ((index * 71) % max(44, size.width.toInt() - 28));
      final y = 78.0 + ((index * 137) % max(80, size.height.toInt() - 92));
      canvas.drawCircle(Offset(x, y), index.isEven ? 1.8 : 1.1, dotPaint);
    }

    _drawHeart(
      canvas,
      Offset(size.width - 42, 132),
      13,
      SLColors.thread.withValues(alpha: hasCustomBackground ? 0.08 : 0.15),
    );
    _drawHeart(
      canvas,
      Offset(34, size.height * 0.72),
      9,
      SLColors.secondary.withValues(alpha: hasCustomBackground ? 0.07 : 0.13),
    );
  }

  void _drawHeart(Canvas canvas, Offset center, double size, Color color) {
    final path = Path()
      ..moveTo(center.dx, center.dy + size * 0.55)
      ..cubicTo(
        center.dx - size * 1.05,
        center.dy - size * 0.10,
        center.dx - size * 0.55,
        center.dy - size * 0.90,
        center.dx,
        center.dy - size * 0.34,
      )
      ..cubicTo(
        center.dx + size * 0.55,
        center.dy - size * 0.90,
        center.dx + size * 1.05,
        center.dy - size * 0.10,
        center.dx,
        center.dy + size * 0.55,
      );
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _HomeScrapbookBackdropPainter oldDelegate) {
    return oldDelegate.hasCustomBackground != hasCustomBackground ||
        oldDelegate.isDark != isDark;
  }
}

/// Thẻ nhiều lớp mô phỏng một mẩu giấy được dán vào sổ kỷ niệm.
enum _HomeCardAdornment {
  none,
  washiTape,
  paperClip,
  heartPin,
  postageStamp,
  photoCorners,
  threadKnot,
  waxSeal,
}

/// Mỗi nhóm nội dung trên Home có một chất liệu riêng để các khối không bị
/// lặp lại cùng một kiểu "tờ giấy có dải màu".
enum _HomeCardVisualStyle { paper, couple, milestone, map, insight }

class _HomeCardVisualSpec {
  final List<Color> surfaceColors;
  final Color borderColor;
  final Color shadowColor;
  final Color frameColor;
  final Color accentColor;
  final double frameAngle;
  final double frameLeft;
  final double frameTop;
  final double frameRight;
  final double frameBottom;

  const _HomeCardVisualSpec({
    required this.surfaceColors,
    required this.borderColor,
    required this.shadowColor,
    required this.frameColor,
    required this.accentColor,
    required this.frameAngle,
    required this.frameLeft,
    required this.frameTop,
    required this.frameRight,
    required this.frameBottom,
  });

  static _HomeCardVisualSpec resolve({
    required _HomeCardVisualStyle style,
    required Color surface,
    required Color accent,
  }) {
    Color tint(Color color, double opacity) {
      // Chỉ pha màu, không làm mất độ trong suốt mà người dùng đã chọn.
      return Color.alphaBlend(
        color.withValues(alpha: opacity),
        surface.withValues(alpha: 1),
      ).withValues(alpha: surface.a);
    }

    switch (style) {
      case _HomeCardVisualStyle.couple:
        return _HomeCardVisualSpec(
          surfaceColors: [
            tint(const Color(0xFFFFE9F0), 0.40),
            tint(const Color(0xFFFFFBF4), 0.62),
            tint(const Color(0xFFF8EFFA), 0.34),
          ],
          borderColor: const Color(0xFFE889A5).withValues(alpha: 0.48),
          shadowColor: const Color(0xFFE95B87).withValues(alpha: 0.16),
          frameColor: const Color(0xFFFF91AC).withValues(alpha: 0.20),
          accentColor: const Color(0xFFE95B87),
          frameAngle: -0.008,
          frameLeft: 4,
          frameTop: 7,
          frameRight: -4,
          frameBottom: -5,
        );
      case _HomeCardVisualStyle.milestone:
        return _HomeCardVisualSpec(
          surfaceColors: [
            tint(const Color(0xFFFFF0EF), 0.46),
            tint(const Color(0xFFFFFCF6), 0.78),
            tint(const Color(0xFFFFF2F7), 0.42),
          ],
          borderColor: const Color(0xFFF1A2B1).withValues(alpha: 0.52),
          shadowColor: const Color(0xFFFF7A96).withValues(alpha: 0.15),
          frameColor: const Color(0xFFFFB1C3).withValues(alpha: 0.22),
          accentColor: const Color(0xFFFF6D8E),
          frameAngle: 0.010,
          frameLeft: 8,
          frameTop: 9,
          frameRight: -6,
          frameBottom: -6,
        );
      case _HomeCardVisualStyle.map:
        return _HomeCardVisualSpec(
          surfaceColors: [
            tint(const Color(0xFFE5F7FF), 0.50),
            tint(const Color(0xFFF9FDFF), 0.84),
            tint(const Color(0xFFF1EEFF), 0.38),
          ],
          borderColor: const Color(0xFF72C9ED).withValues(alpha: 0.54),
          shadowColor: const Color(0xFF4DBBEA).withValues(alpha: 0.16),
          frameColor: const Color(0xFF9EDCFF).withValues(alpha: 0.28),
          accentColor: const Color(0xFF3399D4),
          frameAngle: -0.012,
          frameLeft: 4,
          frameTop: 10,
          frameRight: -5,
          frameBottom: -6,
        );
      case _HomeCardVisualStyle.insight:
        return _HomeCardVisualSpec(
          surfaceColors: [
            tint(const Color(0xFFF1E9FF), 0.52),
            tint(const Color(0xFFFFFBFF), 0.88),
            tint(const Color(0xFFFFEEF8), 0.46),
          ],
          borderColor: const Color(0xFFB9A5EF).withValues(alpha: 0.54),
          shadowColor: const Color(0xFF9A7BE5).withValues(alpha: 0.16),
          frameColor: const Color(0xFFCDBCF8).withValues(alpha: 0.26),
          accentColor: const Color(0xFF8D72D8),
          frameAngle: 0.006,
          frameLeft: 7,
          frameTop: 8,
          frameRight: -5,
          frameBottom: -7,
        );
      case _HomeCardVisualStyle.paper:
        return _HomeCardVisualSpec(
          surfaceColors: [surface, surface],
          borderColor: SLColors.border,
          shadowColor: accent.withValues(alpha: 0.12),
          frameColor: accent.withValues(alpha: 0.15),
          accentColor: accent,
          frameAngle: 0.008,
          frameLeft: 7,
          frameTop: 9,
          frameRight: -5,
          frameBottom: -6,
        );
    }
  }
}

class _HomeScrapbookCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final Color accentColor;
  final Color? color;
  final double radius;
  final _HomeCardAdornment adornment;
  final _HomeCardVisualStyle visualStyle;

  const _HomeScrapbookCard({
    required this.child,
    required this.accentColor,
    this.padding = const EdgeInsets.all(20),
    this.color,
    this.radius = 28,
    this.adornment = _HomeCardAdornment.none,
    this.visualStyle = _HomeCardVisualStyle.paper,
  });

  @override
  Widget build(BuildContext context) {
    final ui = UiPrefs.notifier.value;
    final surface = color ?? SLColors.paper;
    final effectiveSurface = ui.transparentMode
        ? surface.withValues(alpha: 0.82)
        : surface;
    final visual = _HomeCardVisualSpec.resolve(
      style: visualStyle,
      surface: effectiveSurface,
      accent: accentColor,
    );

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          left: visual.frameLeft,
          top: visual.frameTop,
          right: visual.frameRight,
          bottom: visual.frameBottom,
          child: Transform.rotate(
            angle: visual.frameAngle,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: visual.frameColor,
                borderRadius: BorderRadius.circular(radius),
              ),
            ),
          ),
        ),
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: visualStyle == _HomeCardVisualStyle.paper
                ? effectiveSurface
                : null,
            gradient: visualStyle == _HomeCardVisualStyle.paper
                ? null
                : LinearGradient(
                    colors: visual.surfaceColors,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: visual.borderColor, width: 1.15),
            boxShadow: [
              if (visualStyle != _HomeCardVisualStyle.paper)
                BoxShadow(
                  color: visual.shadowColor,
                  blurRadius: 21,
                  spreadRadius: -5,
                  offset: const Offset(0, 10),
                ),
              ...SLShadow.paper,
            ],
          ),
          child: Stack(
            children: [
              if (visualStyle != _HomeCardVisualStyle.paper)
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: _HomeCardMotifPainter(
                        style: visualStyle,
                        accent: visual.accentColor,
                      ),
                    ),
                  ),
                ),
              if (visualStyle == _HomeCardVisualStyle.paper ||
                  visualStyle == _HomeCardVisualStyle.map)
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: visualStyle == _HomeCardVisualStyle.map ? 4 : 5,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          visual.accentColor.withValues(alpha: 0.92),
                          visual.accentColor.withValues(
                            alpha: visualStyle == _HomeCardVisualStyle.paper
                                ? 0.34
                                : 0.28,
                          ),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ),
              if (visualStyle == _HomeCardVisualStyle.paper)
                Positioned(
                  right: 16,
                  top: 13,
                  child: IgnorePointer(
                    child: Row(
                      children: List.generate(
                        3,
                        (index) => Container(
                          width: 4,
                          height: 4,
                          margin: const EdgeInsets.only(left: 5),
                          decoration: BoxDecoration(
                            color: accentColor.withValues(alpha: 0.20),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              if (visualStyle == _HomeCardVisualStyle.couple)
                Positioned.fill(
                  child: IgnorePointer(
                    child: Padding(
                      padding: const EdgeInsets.all(7),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(radius - 7),
                          border: Border.all(
                            color: visual.accentColor.withValues(alpha: 0.16),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              if (visualStyle == _HomeCardVisualStyle.milestone)
                Positioned(
                  left: 26,
                  right: 26,
                  top: 0,
                  height: 4,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,
                            visual.accentColor.withValues(alpha: 0.72),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              if (visualStyle == _HomeCardVisualStyle.insight)
                Positioned(
                  right: 19,
                  top: 17,
                  child: IgnorePointer(
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            Colors.white.withValues(alpha: 0.92),
                            visual.accentColor.withValues(alpha: 0.12),
                          ],
                        ),
                        border: Border.all(
                          color: visual.accentColor.withValues(alpha: 0.16),
                        ),
                      ),
                    ),
                  ),
                ),
              Padding(padding: padding, child: child),
            ],
          ),
        ),
        if (adornment == _HomeCardAdornment.washiTape)
          Positioned(
            left: 24,
            top: -8,
            child: IgnorePointer(
              child: Transform.rotate(
                angle: -0.06,
                child: Container(
                  width: 64,
                  height: 16,
                  decoration: BoxDecoration(
                    color: Color.alphaBlend(
                      accentColor.withValues(alpha: 0.14),
                      SLColors.washi.withValues(alpha: 0.90),
                    ),
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(
                      color: accentColor.withValues(alpha: 0.16),
                    ),
                  ),
                ),
              ),
            ),
          ),
        if (adornment == _HomeCardAdornment.paperClip)
          Positioned(
            right: 24,
            top: -13,
            child: IgnorePointer(
              child: Transform.rotate(
                angle: 0.18,
                child: Icon(
                  Icons.attach_file_rounded,
                  size: 34,
                  color: accentColor.withValues(alpha: 0.72),
                  shadows: [
                    Shadow(
                      color: SLColors.ink.withValues(alpha: 0.14),
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
              ),
            ),
          ),
        if (adornment == _HomeCardAdornment.heartPin)
          Positioned(
            left: 26,
            top: -11,
            child: IgnorePointer(
              child: Container(
                width: 27,
                height: 27,
                decoration: BoxDecoration(
                  color: SLColors.paper,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: accentColor.withValues(alpha: 0.36),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: SLColors.ink.withValues(alpha: 0.12),
                      blurRadius: 9,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.favorite_rounded,
                  size: 13,
                  color: accentColor,
                ),
              ),
            ),
          ),
        if (adornment == _HomeCardAdornment.postageStamp)
          Positioned(
            left: 22,
            top: -13,
            child: IgnorePointer(
              child: Transform.rotate(
                angle: -0.08,
                child: Container(
                  width: 42,
                  height: 35,
                  decoration: BoxDecoration(
                    color: SLColors.paperBlush,
                    borderRadius: BorderRadius.circular(7),
                    border: Border.all(
                      color: accentColor.withValues(alpha: 0.42),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: SLColors.ink.withValues(alpha: 0.10),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.mark_email_read_rounded,
                    size: 18,
                    color: accentColor,
                  ),
                ),
              ),
            ),
          ),
        if (adornment == _HomeCardAdornment.photoCorners) ...[
          Positioned(
            left: 10,
            top: 10,
            child: IgnorePointer(child: _HomePhotoCorner(color: accentColor)),
          ),
          Positioned(
            right: 10,
            bottom: 10,
            child: IgnorePointer(
              child: Transform.rotate(
                angle: pi,
                child: _HomePhotoCorner(color: accentColor),
              ),
            ),
          ),
        ],
        if (adornment == _HomeCardAdornment.threadKnot)
          Positioned(
            right: 22,
            top: -10,
            child: IgnorePointer(
              child: CustomPaint(
                size: const Size(48, 29),
                painter: _HomeThreadKnotPainter(accentColor),
              ),
            ),
          ),
        if (adornment == _HomeCardAdornment.waxSeal)
          Positioned(
            right: 22,
            top: -13,
            child: IgnorePointer(
              child: Transform.rotate(
                angle: 0.08,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        accentColor,
                        Color.lerp(accentColor, SLColors.thread, 0.52)!,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(
                      color: SLColors.paper.withValues(alpha: 0.72),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: SLColors.ink.withValues(alpha: 0.18),
                        blurRadius: 9,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Container(
                    margin: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.48),
                      ),
                    ),
                    child: const Icon(
                      Icons.favorite_rounded,
                      size: 12,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Họa tiết rất nhẹ phía sau nội dung. Không dùng animation liên tục để Home
/// vẫn mượt trên máy cấu hình yếu; hiệu ứng đến từ chiều sâu, nét vẽ và màu.
class _HomeCardMotifPainter extends CustomPainter {
  final _HomeCardVisualStyle style;
  final Color accent;

  const _HomeCardMotifPainter({required this.style, required this.accent});

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width < 64 || size.height < 42) return;

    switch (style) {
      case _HomeCardVisualStyle.couple:
        _paintCoupleFrame(canvas, size);
        break;
      case _HomeCardVisualStyle.milestone:
        _paintPostcardEdge(canvas, size);
        break;
      case _HomeCardVisualStyle.map:
        _paintMapRoute(canvas, size);
        break;
      case _HomeCardVisualStyle.insight:
        _paintInsightConstellation(canvas, size);
        break;
      case _HomeCardVisualStyle.paper:
        break;
    }
  }

  void _paintCoupleFrame(Canvas canvas, Size size) {
    final frameRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(11, 11, size.width - 22, size.height - 22),
      const Radius.circular(22),
    );
    canvas.drawRRect(
      frameRect,
      Paint()
        ..color = accent.withValues(alpha: 0.10)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );

    final thread = Path()
      ..moveTo(size.width * 0.12, size.height * 0.78)
      ..cubicTo(
        size.width * 0.30,
        size.height * 0.62,
        size.width * 0.40,
        size.height * 0.94,
        size.width * 0.50,
        size.height * 0.79,
      )
      ..cubicTo(
        size.width * 0.61,
        size.height * 0.62,
        size.width * 0.74,
        size.height * 0.93,
        size.width * 0.88,
        size.height * 0.73,
      );
    canvas.drawPath(
      thread,
      Paint()
        ..color = accent.withValues(alpha: 0.11)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3
        ..strokeCap = StrokeCap.round,
    );
    _drawHeart(
      canvas,
      Offset(size.width * 0.50, size.height * 0.79),
      5.2,
      accent.withValues(alpha: 0.15),
    );
  }

  void _paintPostcardEdge(Canvas canvas, Size size) {
    final perforation = Paint()..color = accent.withValues(alpha: 0.18);
    for (double x = 22; x < size.width - 20; x += 12) {
      canvas.drawCircle(Offset(x, 13), 1.15, perforation);
      canvas.drawCircle(Offset(x, size.height - 13), 1.15, perforation);
    }

    final seal = Offset(size.width - 37, size.height - 33);
    canvas.drawCircle(
      seal,
      17,
      Paint()
        ..color = accent.withValues(alpha: 0.055)
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      seal,
      12,
      Paint()
        ..color = accent.withValues(alpha: 0.15)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1,
    );
    _drawHeart(canvas, seal, 5.0, accent.withValues(alpha: 0.20));
  }

  void _paintMapRoute(Canvas canvas, Size size) {
    final points = [
      Offset(size.width * 0.12, size.height * 0.76),
      Offset(size.width * 0.31, size.height * 0.56),
      Offset(size.width * 0.53, size.height * 0.70),
      Offset(size.width * 0.73, size.height * 0.36),
      Offset(size.width * 0.88, size.height * 0.46),
    ];
    final route = Path()..moveTo(points.first.dx, points.first.dy);
    for (var index = 1; index < points.length; index++) {
      final previous = points[index - 1];
      final current = points[index];
      route.quadraticBezierTo(
        (previous.dx + current.dx) / 2,
        index.isEven ? size.height * 0.84 : size.height * 0.29,
        current.dx,
        current.dy,
      );
    }
    canvas.drawPath(
      route,
      Paint()
        ..color = accent.withValues(alpha: 0.14)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.45
        ..strokeCap = StrokeCap.round,
    );
    for (var index = 0; index < points.length; index++) {
      final point = points[index];
      canvas.drawCircle(
        point,
        index == 0 || index == points.length - 1 ? 4.4 : 2.8,
        Paint()..color = Colors.white.withValues(alpha: 0.82),
      );
      canvas.drawCircle(
        point,
        index == 0 || index == points.length - 1 ? 3.3 : 1.9,
        Paint()..color = accent.withValues(alpha: 0.28),
      );
    }
  }

  void _paintInsightConstellation(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.76, size.height * 0.30);
    final orbitPaint = Paint()
      ..color = accent.withValues(alpha: 0.10)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawArc(
      Rect.fromCenter(center: center, width: 82, height: 30),
      -0.35,
      pi * 1.40,
      false,
      orbitPaint,
    );
    canvas.drawArc(
      Rect.fromCenter(center: center, width: 34, height: 76),
      1.25,
      pi * 1.32,
      false,
      orbitPaint,
    );

    final stars = [
      Offset(size.width * 0.16, size.height * 0.23),
      Offset(size.width * 0.85, size.height * 0.20),
      Offset(size.width * 0.68, size.height * 0.78),
      Offset(size.width * 0.28, size.height * 0.73),
    ];
    for (var index = 0; index < stars.length; index++) {
      _drawSparkle(
        canvas,
        stars[index],
        index.isEven ? 4.8 : 3.6,
        accent.withValues(alpha: index.isEven ? 0.20 : 0.14),
      );
    }
  }

  void _drawHeart(Canvas canvas, Offset center, double size, Color color) {
    final heart = Path()
      ..moveTo(center.dx, center.dy + size * 0.60)
      ..cubicTo(
        center.dx - size,
        center.dy,
        center.dx - size * 0.54,
        center.dy - size * 0.82,
        center.dx,
        center.dy - size * 0.28,
      )
      ..cubicTo(
        center.dx + size * 0.54,
        center.dy - size * 0.82,
        center.dx + size,
        center.dy,
        center.dx,
        center.dy + size * 0.60,
      );
    canvas.drawPath(
      heart,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.15
        ..strokeCap = StrokeCap.round,
    );
  }

  void _drawSparkle(Canvas canvas, Offset center, double size, Color color) {
    final sparkle = Path()
      ..moveTo(center.dx, center.dy - size)
      ..lineTo(center.dx + size * 0.34, center.dy - size * 0.34)
      ..lineTo(center.dx + size, center.dy)
      ..lineTo(center.dx + size * 0.34, center.dy + size * 0.34)
      ..lineTo(center.dx, center.dy + size)
      ..lineTo(center.dx - size * 0.34, center.dy + size * 0.34)
      ..lineTo(center.dx - size, center.dy)
      ..lineTo(center.dx - size * 0.34, center.dy - size * 0.34)
      ..close();
    canvas.drawPath(sparkle, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _HomeCardMotifPainter oldDelegate) {
    return oldDelegate.style != style || oldDelegate.accent != accent;
  }
}

class _HomePhotoCorner extends StatelessWidget {
  final Color color;

  const _HomePhotoCorner({required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 26,
      height: 26,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(color: color.withValues(alpha: 0.46), width: 2.2),
            top: BorderSide(color: color.withValues(alpha: 0.46), width: 2.2),
          ),
        ),
      ),
    );
  }
}

class _HomeThreadKnotPainter extends CustomPainter {
  final Color color;

  const _HomeThreadKnotPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.74)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.7
      ..strokeCap = StrokeCap.round;
    final path = Path()
      ..moveTo(1, size.height * 0.50)
      ..cubicTo(
        size.width * 0.20,
        -2,
        size.width * 0.38,
        size.height + 2,
        size.width * 0.52,
        size.height * 0.48,
      )
      ..cubicTo(
        size.width * 0.66,
        -1,
        size.width * 0.78,
        size.height + 1,
        size.width - 1,
        size.height * 0.24,
      );
    canvas.drawPath(path, paint);
    canvas.drawCircle(
      Offset(size.width * 0.52, size.height * 0.48),
      3.2,
      Paint()..color = color.withValues(alpha: 0.88),
    );
  }

  @override
  bool shouldRepaint(covariant _HomeThreadKnotPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _HomeStoryLetterhead extends StatelessWidget {
  final String smartGreeting;
  final String houseName;
  final bool showHouseName;
  final bool isSingle;

  const _HomeStoryLetterhead({
    required this.smartGreeting,
    required this.houseName,
    required this.showHouseName,
    required this.isSingle,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final dateLabel = MaterialLocalizations.of(context).formatMediumDate(now);
    final hour = now.hour;

    late final String timeLabel;
    late final String timeMood;
    late final IconData timeIcon;
    late final Color timeAccent;
    late final Color timeSurface;

    if (hour < 6) {
      timeLabel = context.tr('Khuya rồi');
      timeMood = context.tr('Nhẹ nhàng bên nhau một chút nhé');
      timeIcon = Icons.bedtime_rounded;
      timeAccent = const Color(0xFF8B72C8);
      timeSurface = const Color(0xFFF2EDFF);
    } else if (hour < 11) {
      timeLabel = context.tr('Chào buổi sáng');
      timeMood = context.tr('Một ngày mới của hai mình');
      timeIcon = Icons.wb_sunny_rounded;
      timeAccent = const Color(0xFFF3A64A);
      timeSurface = const Color(0xFFFFF5DD);
    } else if (hour < 14) {
      timeLabel = context.tr('Buổi trưa dịu dàng');
      timeMood = context.tr('Nhớ nghỉ một chút và thương nhau');
      timeIcon = Icons.light_mode_rounded;
      timeAccent = const Color(0xFFEA8B65);
      timeSurface = const Color(0xFFFFEEE5);
    } else if (hour < 19) {
      timeLabel = context.tr('Chiều của chúng mình');
      timeMood = context.tr('Lưu thêm một điều đáng nhớ hôm nay');
      timeIcon = Icons.auto_awesome_rounded;
      timeAccent = const Color(0xFFE46F91);
      timeSurface = const Color(0xFFFFEAF0);
    } else {
      timeLabel = context.tr('Tối bình yên');
      timeMood = context.tr('Khép ngày bằng một lời yêu thương');
      timeIcon = Icons.nightlight_round;
      timeAccent = const Color(0xFF8F72D8);
      timeSurface = const Color(0xFFF2ECFF);
    }

    final accent = isSingle ? SLColors.secondary : SLColors.thread;

    return Semantics(
      header: true,
      child: _HomeScrapbookCard(
        accentColor: accent,
        adornment: _HomeCardAdornment.washiTape,
        radius: 30,
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 17),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            const Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(painter: _HomeLetterheadThreadPainter()),
              ),
            ),
            Positioned(
              right: -2,
              bottom: -3,
              child: IgnorePointer(
                child: Icon(
                  Icons.favorite_rounded,
                  size: 42,
                  color: accent.withValues(alpha: 0.055),
                ),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            accent.withValues(alpha: 0.95),
                            SLColors.primary.withValues(alpha: 0.78),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(13),
                        boxShadow: [
                          BoxShadow(
                            color: accent.withValues(alpha: 0.18),
                            blurRadius: 12,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.favorite_rounded,
                        size: 17,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'SOULLOCKET',
                          style: SLTheme.quicksand(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.7,
                            color: SLColors.thread,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          context.tr('Góc nhỏ của hai mình'),
                          style: SLTheme.quicksand(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            color: SLColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: timeSurface,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: timeAccent.withValues(alpha: 0.18),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(timeIcon, size: 13, color: timeAccent),
                          const SizedBox(width: 5),
                          Text(
                            dateLabel,
                            style: SLTheme.quicksand(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              color: SLColors.textSecond,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 13),
                if (showHouseName) ...[
                  Text(
                    houseName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.dancingScript(
                      fontSize: 30,
                      height: 1.02,
                      fontWeight: FontWeight.w700,
                      color: SLColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 5),
                ],
                Text(
                  smartGreeting,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: showHouseName
                      ? SLTheme.quicksand(
                          fontSize: 12.5,
                          height: 1.35,
                          fontWeight: FontWeight.w700,
                          color: SLColors.textSecond,
                        )
                      : GoogleFonts.dancingScript(
                          fontSize: 26,
                          height: 1.10,
                          fontWeight: FontWeight.w700,
                          color: SLColors.textPrimary,
                        ),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: timeSurface.withValues(alpha: 0.82),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: timeAccent.withValues(alpha: 0.14),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 27,
                        height: 27,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.88),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(timeIcon, size: 14, color: timeAccent),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              timeLabel,
                              style: SLTheme.quicksand(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                color: timeAccent,
                              ),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              timeMood,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: SLTheme.quicksand(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: SLColors.textSecond,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.favorite_border_rounded,
                        size: 17,
                        color: accent.withValues(alpha: 0.75),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeLetterheadThreadPainter extends CustomPainter {
  const _HomeLetterheadThreadPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width * 0.62, size.height * 0.76)
      ..cubicTo(
        size.width * 0.72,
        size.height * 0.58,
        size.width * 0.82,
        size.height * 0.98,
        size.width + 8,
        size.height * 0.73,
      );
    canvas.drawPath(
      path,
      Paint()
        ..color = SLColors.thread.withValues(alpha: 0.12)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _HomeLetterheadThreadPainter oldDelegate) {
    return false;
  }
}

class _HomeHeroStage extends StatelessWidget {
  final Widget child;
  final bool isSingle;

  const _HomeHeroStage({required this.child, required this.isSingle});

  @override
  Widget build(BuildContext context) {
    final accent = isSingle ? SLColors.secondary : SLColors.primary;
    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: 2,
          top: 24,
          child: Transform.rotate(
            angle: -0.16,
            child: const HomeStickerMotion(
              motion: SoulLocketStickerMotion.sway,
              motionSeed: 'hero-sparkle',
              child: _HomeDoodleStamp(
                icon: Icons.auto_awesome_rounded,
                color: SLColors.warningGold,
              ),
            ),
          ),
        ),
        Positioned(
          right: 2,
          bottom: 28,
          child: Transform.rotate(
            angle: 0.13,
            child: HomeStickerMotion(
              motion: SoulLocketStickerMotion.heartbeat,
              motionSeed: 'hero-heart',
              child: _HomeDoodleStamp(
                icon: isSingle
                    ? Icons.self_improvement_rounded
                    : Icons.favorite_rounded,
                color: accent,
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class _HomeDoodleStamp extends StatelessWidget {
  final IconData icon;
  final Color color;

  const _HomeDoodleStamp({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: SLColors.paper.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.32)),
        boxShadow: [
          BoxShadow(
            color: SLColors.ink.withValues(alpha: 0.08),
            blurRadius: 12,
            spreadRadius: -5,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Icon(icon, color: color, size: 19),
    );
  }
}

class _HomeScrapbookDivider extends StatelessWidget {
  final Color color;

  const _HomeScrapbookDivider({this.color = SLColors.thread});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 30,
      child: CustomPaint(
        painter: _HomeScrapbookDividerPainter(color),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _HomeScrapbookDividerPainter extends CustomPainter {
  final Color color;

  const _HomeScrapbookDividerPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.25
      ..strokeCap = StrokeCap.round;
    final path = Path()
      ..moveTo(size.width * 0.08, size.height * 0.55)
      ..cubicTo(
        size.width * 0.32,
        size.height * 0.18,
        size.width * 0.42,
        size.height * 0.90,
        size.width * 0.50,
        size.height * 0.52,
      )
      ..cubicTo(
        size.width * 0.60,
        size.height * 0.10,
        size.width * 0.72,
        size.height * 0.86,
        size.width * 0.92,
        size.height * 0.45,
      );
    canvas.drawPath(path, paint);
    canvas.drawCircle(
      Offset(size.width * 0.50, size.height * 0.52),
      3,
      Paint()..color = color.withValues(alpha: 0.30),
    );
  }

  @override
  bool shouldRepaint(covariant _HomeScrapbookDividerPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
