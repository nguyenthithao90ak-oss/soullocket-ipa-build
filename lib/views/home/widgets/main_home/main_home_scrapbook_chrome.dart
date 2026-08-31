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
}

class _HomeScrapbookCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final Color accentColor;
  final Color? color;
  final double radius;
  final _HomeCardAdornment adornment;

  const _HomeScrapbookCard({
    required this.child,
    required this.accentColor,
    this.padding = const EdgeInsets.all(20),
    this.color,
    this.radius = 28,
    this.adornment = _HomeCardAdornment.none,
  });

  @override
  Widget build(BuildContext context) {
    final ui = UiPrefs.notifier.value;
    final surface = color ?? SLColors.paper;
    final effectiveSurface = ui.transparentMode
        ? surface.withValues(alpha: 0.82)
        : surface;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          left: 7,
          top: 9,
          right: -5,
          bottom: -6,
          child: Transform.rotate(
            angle: 0.008,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(radius),
              ),
            ),
          ),
        ),
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: effectiveSurface,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: SLColors.border, width: 1.15),
            boxShadow: SLShadow.paper,
          ),
          child: Stack(
            children: [
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: 5,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        accentColor.withValues(alpha: 0.92),
                        accentColor.withValues(alpha: 0.34),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 16,
                top: 13,
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
            child: IgnorePointer(
              child: _HomePhotoCorner(color: accentColor),
            ),
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
      ],
    );
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
            child: _HomeDoodleStamp(
              icon: Icons.auto_awesome_rounded,
              color: SLColors.warningGold,
            ),
          ),
        ),
        Positioned(
          right: 2,
          bottom: 28,
          child: Transform.rotate(
            angle: 0.13,
            child: _HomeDoodleStamp(
              icon: isSingle
                  ? Icons.self_improvement_rounded
                  : Icons.favorite_rounded,
              color: accent,
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
