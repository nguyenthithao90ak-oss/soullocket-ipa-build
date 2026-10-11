import 'dart:math' as math;

import 'package:flutter/material.dart';

enum SoulNavigationGlyph { home, diary, apps, fun, update }

class SoulNavigationSurface extends StatelessWidget {
  const SoulNavigationSurface({
    super.key,
    required this.isDark,
    required this.child,
    this.activeIndex = 0,
  });

  final bool isDark;
  final Widget child;
  final int activeIndex;

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _SoulNavigationSurfacePainter(
      isDark: isDark,
      activeIndex: activeIndex,
      textDirection: Directionality.of(context),
    ),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(6, 19, 6, 7),
      child: child,
    ),
  );
}

class SoulNavigationTile extends StatelessWidget {
  const SoulNavigationTile({
    super.key,
    required this.label,
    required this.glyph,
    required this.accent,
    required this.selected,
    required this.isDark,
    required this.onTap,
    this.iconKey,
    this.reduceMotion = false,
  });

  final String label;
  final SoulNavigationGlyph glyph;
  final Color accent;
  final bool selected;
  final bool isDark;
  final VoidCallback onTap;
  final Key? iconKey;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    final duration = reduceMotion || MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 220);
    final ink = Color.lerp(accent, const Color(0xFF42273C), .48)!;
    final labelColor = isDark
        ? (selected ? Colors.white : const Color(0xFFD1C8DB))
        : (selected ? ink : const Color(0xFF716278));

    return Semantics(
      label: label,
      button: true,
      selected: selected,
      child: Tooltip(
        message: label,
        excludeFromSemantics: true,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(25),
            child: AnimatedContainer(
              duration: duration,
              curve: Curves.easeOutCubic,
              margin: const EdgeInsets.symmetric(horizontal: 1),
              padding: const EdgeInsets.fromLTRB(2, 4, 2, 3),
              child: ExcludeSemantics(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      key: iconKey,
                      width: 48,
                      height: 46,
                      child: CustomPaint(
                        painter: _SoulNavigationTilePainter(
                          accent: accent,
                          selected: selected,
                          isDark: isDark,
                        ),
                        child: Center(
                          child: SizedBox(
                            width: 28,
                            height: 28,
                            child: CustomPaint(
                              painter: _SoulNavigationGlyphPainter(
                                glyph: glyph,
                                accent: accent,
                                selected: selected,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    SizedBox(
                      height: MediaQuery.textScalerOf(context).scale(11) * 2.4,
                      child: Center(
                        child: Text(
                          label,
                          maxLines: 2,
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            height: 1.15,
                            fontWeight: selected
                                ? FontWeight.w800
                                : FontWeight.w600,
                            color: labelColor,
                            letterSpacing: -.15,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 3),
                    AnimatedContainer(
                      duration: duration,
                      width: selected ? 22 : 4,
                      height: 3,
                      decoration: BoxDecoration(
                        gradient: selected
                            ? LinearGradient(
                                colors: [
                                  accent.withValues(alpha: .35),
                                  accent,
                                  Color.lerp(accent, Colors.white, .35)!,
                                ],
                              )
                            : null,
                        color: selected ? null : Colors.transparent,
                        borderRadius: BorderRadius.circular(3),
                      ),
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

class _SoulNavigationSurfacePainter extends CustomPainter {
  const _SoulNavigationSurfacePainter({
    required this.isDark,
    required this.activeIndex,
    required this.textDirection,
  });

  final bool isDark;
  final int activeIndex;
  final TextDirection textDirection;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 16 || size.height <= 16) return;

    canvas.save();
    if (textDirection == TextDirection.rtl) {
      canvas.translate(size.width, 0);
      canvas.scale(-1, 1);
    }

    final paperRect = Rect.fromLTRB(1.5, 2, size.width - 1.5, size.height - 5);
    final cornerRadius = math.min(15.0, paperRect.shortestSide * .2);
    final foldSize = math.min(17.0, paperRect.shortestSide * .18);
    final paperPath = _paperOutline(paperRect, cornerRadius, foldSize);
    final backingSheet = RRect.fromRectAndRadius(
      Rect.fromLTRB(4, 7, size.width - 3, size.height - 1),
      Radius.circular(cornerRadius),
    );

    canvas.drawShadow(
      Path()..addRRect(backingSheet),
      const Color(0xFF765247).withValues(alpha: isDark ? .24 : .15),
      9,
      true,
    );
    canvas.drawRRect(
      backingSheet,
      Paint()
        ..color = isDark ? const Color(0xFF29232F) : const Color(0xFFF1E2D5),
    );
    canvas.drawRRect(
      backingSheet,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = .8
        ..color = isDark
            ? const Color(0xFF7E667A)
            : const Color(0xFFD6BCA8).withValues(alpha: .65),
    );
    canvas.drawPath(
      paperPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? const [Color(0xFF433746), Color(0xFF302836)]
              : const [Color(0xFFFFFCF4), Color(0xFFFFF4E7)],
        ).createShader(paperRect),
    );

    canvas.save();
    canvas.clipPath(paperPath);
    _paintPaperGrain(canvas, paperRect.deflate(6));

    final rulePaint = Paint()
      ..color = isDark
          ? const Color(0xFFE3D3DF).withValues(alpha: .065)
          : const Color(0xFFB9A5A3).withValues(alpha: .19)
      ..strokeWidth = .65;
    for (
      var ruleY = paperRect.top + 23;
      ruleY < paperRect.bottom - 5;
      ruleY += 19
    ) {
      canvas.drawLine(
        Offset(paperRect.left + 11, ruleY),
        Offset(paperRect.right - 11, ruleY),
        rulePaint,
      );
    }
    if (size.width >= 160) {
      canvas.drawLine(
        Offset(paperRect.left + 24, paperRect.top + 6),
        Offset(paperRect.left + 24, paperRect.bottom - 5),
        Paint()
          ..strokeWidth = .7
          ..color = const Color(
            0xFFCC8B8B,
          ).withValues(alpha: isDark ? .13 : .22),
      );
    }

    final safeIndex = activeIndex.clamp(0, 4);
    final slotWidth = (size.width - 12) / 5;
    final activeCenter = Offset(
      6 + slotWidth * (safeIndex + .5),
      size.height * .43,
    );
    final accent = _navigationAccent(safeIndex);
    final glowRadius = math.min(62.0, size.height * .55);
    canvas.drawCircle(
      activeCenter,
      glowRadius,
      Paint()
        ..shader =
            RadialGradient(
              colors: [
                accent.withValues(alpha: isDark ? .14 : .085),
                accent.withValues(alpha: 0),
              ],
            ).createShader(
              Rect.fromCircle(center: activeCenter, radius: glowRadius),
            ),
    );

    if (size.width >= 160) {
      _paintTape(canvas, Offset(paperRect.left + 47, paperRect.top + 6));
    }

    final foldPath = Path()
      ..moveTo(paperRect.right - foldSize, paperRect.top)
      ..lineTo(paperRect.right - foldSize, paperRect.top + foldSize - 2)
      ..quadraticBezierTo(
        paperRect.right - foldSize,
        paperRect.top + foldSize,
        paperRect.right - foldSize + 2,
        paperRect.top + foldSize,
      )
      ..lineTo(paperRect.right, paperRect.top + foldSize)
      ..close();
    canvas.drawPath(
      foldPath,
      Paint()
        ..shader =
            LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: isDark
                  ? const [Color(0xFF63505F), Color(0xFF473A47)]
                  : const [Color(0xFFF8E8D7), Color(0xFFE8CCB6)],
            ).createShader(
              Rect.fromLTWH(
                paperRect.right - foldSize,
                paperRect.top,
                foldSize,
                foldSize,
              ),
            ),
    );
    canvas.drawPath(
      foldPath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = .65
        ..color = isDark
            ? const Color(0xFFAE8C9F).withValues(alpha: .45)
            : const Color(0xFFC5A58D).withValues(alpha: .4),
    );
    canvas.restore();

    canvas.drawPath(
      paperPath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = .9
        ..color = isDark
            ? const Color(0xFF997A91).withValues(alpha: .7)
            : const Color(0xFFC8A98E).withValues(alpha: .65),
    );
    canvas.restore();
  }

  Path _paperOutline(Rect rect, double radius, double foldSize) => Path()
    ..moveTo(rect.left + radius, rect.top)
    ..lineTo(rect.right - foldSize, rect.top)
    ..lineTo(rect.right, rect.top + foldSize)
    ..lineTo(rect.right, rect.bottom - radius)
    ..quadraticBezierTo(
      rect.right,
      rect.bottom,
      rect.right - radius,
      rect.bottom,
    )
    ..lineTo(rect.left + radius, rect.bottom)
    ..quadraticBezierTo(rect.left, rect.bottom, rect.left, rect.bottom - radius)
    ..lineTo(rect.left, rect.top + radius)
    ..quadraticBezierTo(rect.left, rect.top, rect.left + radius, rect.top)
    ..close();

  void _paintPaperGrain(Canvas canvas, Rect rect) {
    final grainPaint = Paint()
      ..color = isDark
          ? Colors.white.withValues(alpha: .035)
          : const Color(0xFF99775D).withValues(alpha: .085)
      ..strokeWidth = .4
      ..strokeCap = StrokeCap.round;
    var rowIndex = 0;
    for (var grainY = rect.top; grainY < rect.bottom; grainY += 12) {
      var columnIndex = 0;
      for (var grainX = rect.left; grainX < rect.right; grainX += 14) {
        final offset = ((rowIndex * 7 + columnIndex * 11) % 9).toDouble();
        final grainStart = Offset(grainX + offset, grainY + offset * .35);
        canvas.drawLine(
          grainStart,
          grainStart + const Offset(1.2, .25),
          grainPaint,
        );
        columnIndex++;
      }
      rowIndex++;
    }
  }

  void _paintTape(Canvas canvas, Offset center) {
    const tapeRect = Rect.fromLTWH(-24, -5.5, 48, 11);
    final tapePath = Path()
      ..moveTo(tapeRect.left + 1, tapeRect.top)
      ..lineTo(tapeRect.right - 1, tapeRect.top)
      ..lineTo(tapeRect.right, tapeRect.top + 3)
      ..lineTo(tapeRect.right - 1.5, tapeRect.center.dy)
      ..lineTo(tapeRect.right, tapeRect.bottom - 2)
      ..lineTo(tapeRect.right - 1, tapeRect.bottom)
      ..lineTo(tapeRect.left, tapeRect.bottom)
      ..lineTo(tapeRect.left + 1.5, tapeRect.bottom - 3)
      ..lineTo(tapeRect.left, tapeRect.center.dy)
      ..lineTo(tapeRect.left + 1.5, tapeRect.top + 2)
      ..close();
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-.08);
    canvas.drawPath(
      tapePath,
      Paint()
        ..color = const Color(0xFFE6ADA3).withValues(alpha: isDark ? .27 : .48),
    );
    canvas.drawLine(
      const Offset(-20, -3),
      const Offset(20, -3),
      Paint()
        ..color = Colors.white.withValues(alpha: .32)
        ..strokeWidth = .65,
    );
    canvas.restore();
  }

  Color _navigationAccent(int index) {
    const accents = [
      Color(0xFFE75480),
      Color(0xFFCF7993),
      Color(0xFF9D7AE8),
      Color(0xFFE4A44D),
      Color(0xFF5CADA5),
    ];
    return accents[index.clamp(0, accents.length - 1)];
  }

  @override
  bool shouldRepaint(covariant _SoulNavigationSurfacePainter oldDelegate) =>
      oldDelegate.isDark != isDark ||
      oldDelegate.activeIndex != activeIndex ||
      oldDelegate.textDirection != textDirection;
}

class _SoulNavigationTilePainter extends CustomPainter {
  const _SoulNavigationTilePainter({
    required this.accent,
    required this.selected,
    required this.isDark,
  });

  final Color accent;
  final bool selected;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final orbSize = selected ? 45.0 : 42.0;
    final orbRect = Rect.fromCenter(
      center: Offset(center.dx, center.dy + (selected ? 0 : 1)),
      width: orbSize,
      height: orbSize,
    );
    final orb = RRect.fromRectAndRadius(
      orbRect,
      Radius.circular(selected ? 16 : 21),
    );
    final orbPath = Path()..addRRect(orb);

    if (selected) {
      canvas.drawShadow(orbPath, accent.withValues(alpha: .24), 7, true);
      canvas.drawRRect(
        orb,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color.lerp(accent, Colors.white, .42)!,
              accent,
              Color.lerp(accent, const Color(0xFF4A2448), .14)!,
            ],
          ).createShader(orbRect),
      );

      final sheenRect = Rect.fromLTWH(
        orbRect.left + 2,
        orbRect.top + 1,
        orbRect.width - 4,
        orbRect.height * .38,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(sheenRect, const Radius.circular(14)),
        Paint()
          ..shader = LinearGradient(
            colors: [
              Colors.white.withValues(alpha: .34),
              Colors.white.withValues(alpha: 0),
            ],
          ).createShader(sheenRect),
      );
      canvas.drawRRect(
        orb,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.05
          ..color = Colors.white.withValues(alpha: .52),
      );
    } else {
      canvas.drawCircle(
        Offset(center.dx, center.dy + 1),
        20.5,
        Paint()
          ..color = isDark
              ? Colors.white.withValues(alpha: .045)
              : accent.withValues(alpha: .045),
      );
      canvas.drawCircle(
        Offset(center.dx + 14, center.dy - 13),
        1.45,
        Paint()..color = accent.withValues(alpha: .55),
      );
      canvas.drawCircle(
        Offset(center.dx + 10.5, center.dy - 16),
        .7,
        Paint()..color = accent.withValues(alpha: .36),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SoulNavigationTilePainter oldDelegate) =>
      oldDelegate.accent != accent ||
      oldDelegate.selected != selected ||
      oldDelegate.isDark != isDark;
}

class _SoulNavigationGlyphPainter extends CustomPainter {
  const _SoulNavigationGlyphPainter({
    required this.glyph,
    required this.accent,
    required this.selected,
  });

  final SoulNavigationGlyph glyph;
  final Color accent;
  final bool selected;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final scale = math.min(size.width, size.height) / 28;
    canvas.save();
    canvas.translate(
      (size.width - 28 * scale) / 2,
      (size.height - 28 * scale) / 2,
    );
    canvas.scale(scale);

    final lineColor = selected
        ? Colors.white
        : Color.lerp(accent, const Color(0xFF42273C), .18)!;
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color.lerp(lineColor, Colors.white, selected ? .12 : .72)!,
          lineColor,
        ],
      ).createShader(const Rect.fromLTWH(2, 2, 24, 24));
    final strokePaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = selected ? 1.7 : 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    switch (glyph) {
      case SoulNavigationGlyph.home:
        _paintHeart(canvas, fillPaint, strokePaint);
      case SoulNavigationGlyph.diary:
        _paintDiary(canvas, fillPaint, strokePaint);
      case SoulNavigationGlyph.apps:
        _paintApps(canvas, fillPaint, strokePaint);
      case SoulNavigationGlyph.fun:
        _paintFun(canvas, fillPaint, strokePaint);
      case SoulNavigationGlyph.update:
        _paintUpdate(canvas, fillPaint, strokePaint);
    }
    canvas.restore();
  }

  void _paintHeart(Canvas canvas, Paint fillPaint, Paint strokePaint) {
    final heart = Path()
      ..moveTo(14, 24)
      ..cubicTo(12.4, 22.5, 4.1, 17.2, 4.1, 10.4)
      ..cubicTo(4.1, 6.2, 8.8, 4.2, 14, 9.1)
      ..cubicTo(19.2, 4.2, 23.9, 6.2, 23.9, 10.4)
      ..cubicTo(23.9, 17.2, 15.6, 22.5, 14, 24)
      ..close();
    if (selected) {
      canvas.drawPath(heart, fillPaint);
      canvas.drawPath(
        heart,
        Paint()
          ..color = Colors.white.withValues(alpha: .45)
          ..style = PaintingStyle.stroke
          ..strokeWidth = .7,
      );
    } else {
      canvas.drawPath(heart, strokePaint);
    }
    canvas.drawCircle(
      const Offset(20.7, 7.4),
      1.2,
      Paint()..color = selected ? Colors.white : accent.withValues(alpha: .6),
    );
  }

  void _paintDiary(Canvas canvas, Paint fillPaint, Paint strokePaint) {
    final cover = RRect.fromRectAndRadius(
      const Rect.fromLTWH(4, 4, 20, 20),
      const Radius.circular(3.6),
    );
    canvas.drawRRect(
      cover,
      selected
          ? (Paint()..color = Colors.white.withValues(alpha: .14))
          : (Paint()..color = accent.withValues(alpha: .08)),
    );
    canvas.drawRRect(cover, strokePaint);
    canvas.drawLine(const Offset(9, 5), const Offset(9, 23), strokePaint);
    for (final y in const [10.0, 13.4, 16.8]) {
      strokePaint.strokeWidth = 1.25;
      canvas.drawLine(Offset(12, y), Offset(20, y), strokePaint);
    }
    final bookmark = Path()
      ..moveTo(15, 4.8)
      ..lineTo(20, 4.8)
      ..lineTo(20, 11)
      ..lineTo(17.5, 9.4)
      ..lineTo(15, 11)
      ..close();
    canvas.drawPath(bookmark, fillPaint);
  }

  void _paintApps(Canvas canvas, Paint fillPaint, Paint strokePaint) {
    final positions = <Rect>[
      const Rect.fromLTWH(4.5, 4.5, 7, 7),
      const Rect.fromLTWH(16.5, 4.5, 7, 7),
      const Rect.fromLTWH(4.5, 16.5, 7, 7),
      const Rect.fromLTWH(16.5, 16.5, 7, 7),
    ];
    for (final position in positions) {
      final rounded = RRect.fromRectAndRadius(
        position,
        const Radius.circular(1.8),
      );
      canvas.drawRRect(
        rounded,
        selected
            ? (Paint()..color = Colors.white.withValues(alpha: .16))
            : (Paint()..color = accent.withValues(alpha: .08)),
      );
      canvas.drawRRect(rounded, strokePaint);
    }
    canvas.drawCircle(
      const Offset(14, 14),
      1.2,
      Paint()..color = selected ? Colors.white : accent,
    );
  }

  void _paintFun(Canvas canvas, Paint fillPaint, Paint strokePaint) {
    final controller = Path()
      ..moveTo(8, 9)
      ..cubicTo(6.2, 9, 5.3, 10.2, 4.8, 12.1)
      ..lineTo(3.8, 17.7)
      ..cubicTo(3.4, 20.1, 4.8, 22, 6.6, 22)
      ..cubicTo(8.4, 22, 9.3, 20, 10.2, 18.9)
      ..lineTo(17.8, 18.9)
      ..cubicTo(18.7, 20, 19.6, 22, 21.4, 22)
      ..cubicTo(23.2, 22, 24.6, 20.1, 24.2, 17.7)
      ..lineTo(23.2, 12.1)
      ..cubicTo(22.7, 10.2, 21.8, 9, 20, 9)
      ..close();
    canvas.drawPath(
      controller,
      selected
          ? (Paint()..color = Colors.white.withValues(alpha: .14))
          : (Paint()..color = accent.withValues(alpha: .08)),
    );
    canvas.drawPath(controller, strokePaint);
    canvas.drawLine(const Offset(8, 12.5), const Offset(8, 16), strokePaint);
    canvas.drawLine(
      const Offset(6.3, 14.25),
      const Offset(9.7, 14.25),
      strokePaint,
    );
    canvas.drawCircle(
      const Offset(19, 13),
      1.25,
      Paint()..color = selected ? Colors.white : accent,
    );
    canvas.drawCircle(
      const Offset(21.5, 15.5),
      1.25,
      Paint()..color = selected ? Colors.white : accent.withValues(alpha: .72),
    );
  }

  void _paintUpdate(Canvas canvas, Paint fillPaint, Paint strokePaint) {
    _drawSparkle(
      canvas,
      center: const Offset(9, 15),
      radius: 6.1,
      paint: fillPaint,
    );
    _drawSparkle(
      canvas,
      center: const Offset(18.8, 9),
      radius: 4.2,
      paint: selected ? strokePaint : fillPaint,
    );
    canvas.drawCircle(
      const Offset(22.5, 20.8),
      1.25,
      Paint()..color = selected ? Colors.white : accent,
    );
    canvas.drawCircle(
      const Offset(5.2, 6.1),
      .9,
      Paint()..color = selected ? Colors.white : accent.withValues(alpha: .7),
    );
  }

  void _drawSparkle(
    Canvas canvas, {
    required Offset center,
    required double radius,
    required Paint paint,
  }) {
    final path = Path()
      ..moveTo(center.dx, center.dy - radius)
      ..quadraticBezierTo(
        center.dx + radius * .28,
        center.dy - radius * .28,
        center.dx + radius,
        center.dy,
      )
      ..quadraticBezierTo(
        center.dx + radius * .28,
        center.dy + radius * .28,
        center.dx,
        center.dy + radius,
      )
      ..quadraticBezierTo(
        center.dx - radius * .28,
        center.dy + radius * .28,
        center.dx - radius,
        center.dy,
      )
      ..quadraticBezierTo(
        center.dx - radius * .28,
        center.dy - radius * .28,
        center.dx,
        center.dy - radius,
      )
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SoulNavigationGlyphPainter oldDelegate) =>
      oldDelegate.glyph != glyph ||
      oldDelegate.accent != accent ||
      oldDelegate.selected != selected;
}
