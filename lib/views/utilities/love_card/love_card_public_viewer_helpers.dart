part of '../love_card_public_viewer_screen.dart';

class _LoveCardViewerTheme {
  final String badge;
  final String headline;
  final String headerTitle;
  final String openHint;
  final String tearHint;
  final String signatureFallback;
  final String effectLabel;
  final List<Color> background;
  final Color accent;
  final Color envelope;
  final Color envelopeLight;
  final Color paper;
  final Color ink;
  final Color muted;
  final IconData leadingIcon;
  final IconData trailingIcon;
  final IconData stampIcon;

  const _LoveCardViewerTheme({
    required this.badge,
    required this.headline,
    required this.headerTitle,
    required this.openHint,
    required this.tearHint,
    required this.signatureFallback,
    required this.effectLabel,
    required this.background,
    required this.accent,
    required this.envelope,
    required this.envelopeLight,
    required this.paper,
    required this.ink,
    required this.muted,
    required this.leadingIcon,
    required this.trailingIcon,
    required this.stampIcon,
  });

  static _LoveCardViewerTheme of(String key) {
    switch (key.trim().toLowerCase()) {
      case 'birthday':
        return _LoveCardViewerTheme(
          badge: L10nService().translate('util_sinhnht_71c600'),
          headline: L10nService().translate('util_lichccbung_0dbab0'),
          headerTitle: 'Birthday Card',
          openHint: L10nService().translate('util_chmmquchcm_63c8ab'),
          tearHint: L10nService().translate('util_koxdiquvxe_a06353'),
          signatureFallback: L10nService().translate('util_chcmngsinh_1db118'),
          effectLabel: L10nService().translate('util_phogiybngn_b5a4e9'),
          background: const [
            Color(0xFFFAD0C4),
            Color(0xFFFFD1FF),
            Color(0xFFFFF0F5)
          ],
          accent: const Color(0xFFFF7DB0),
          envelope: const Color(0xFFFFD8E5),
          envelopeLight: const Color(0xFFFFF2F6),
          paper: const Color(0xFFFFFCFE),
          ink: const Color(0xFF6B3A5A),
          muted: const Color(0xFF9E688A),
          leadingIcon: Icons.celebration_rounded,
          trailingIcon: Icons.cake_rounded,
          stampIcon: Icons.celebration_rounded,
        );
      case 'anniversary':
        return _LoveCardViewerTheme(
          badge: L10nService().translate('util_knim_4f6aeb'),
          headline: L10nService().translate('util_mtctmcpcmr_62adaa'),
          headerTitle: 'Anniversary Card',
          openHint: L10nService().translate('util_chmmthipkn_52c875'),
          tearHint: L10nService().translate('util_koxvlractm_cfd029'),
          signatureFallback: L10nService().translate('util_mtngyngnhc_02e59f'),
          effectLabel: L10nService().translate('util_hoquangkc_1a4d18'),
          background: const [
            Color(0xFFA1C4FD),
            Color(0xFFC2E9FB),
            Color(0xFFE6F3FF)
          ],
          accent: const Color(0xFF6A9DFE),
          envelope: const Color(0xFFCCE4FF),
          envelopeLight: const Color(0xFFEDF6FF),
          paper: const Color(0xFFFAFDFE),
          ink: const Color(0xFF284C7E),
          muted: const Color(0xFF5B7BA3),
          leadingIcon: Icons.workspace_premium_rounded,
          trailingIcon: Icons.diamond_rounded,
          stampIcon: Icons.workspace_premium_rounded,
        );
      case 'miss':
        return _LoveCardViewerTheme(
          badge: L10nService().translate('util_nhnhau_5dc5c1'),
          headline: L10nService().translate('util_linhthngxu_de9d2c'),
          headerTitle: 'Miss You Card',
          openHint: L10nService().translate('util_chmmlinhth_3f9037'),
          tearHint: L10nService().translate('util_koxdigiyvc_ae668f'),
          signatureFallback: L10nService().translate('util_nhbnnhiulm_fcda3f'),
          effectLabel: L10nService().translate('util_msaodum_19d800'),
          background: const [
            Color(0xFFBDB2FF),
            Color(0xFFFFC6FF),
            Color(0xFFFFF0FF)
          ],
          accent: const Color(0xFF8B5CF6),
          envelope: const Color(0xFFE8D8FF),
          envelopeLight: const Color(0xFFF7F3FF),
          paper: const Color(0xFFFDFCFF),
          ink: const Color(0xFF4C3E8A),
          muted: const Color(0xFF7E72B7),
          leadingIcon: Icons.nights_stay_rounded,
          trailingIcon: Icons.star_rounded,
          stampIcon: Icons.star_rounded,
        );
      default:
        return _LoveCardViewerTheme(
          badge: L10nService().translate('util_tnhyu_2814db'),
          headline: L10nService().translate('util_mtlthringc_c46917'),
          headerTitle: 'Love Card',
          openHint: L10nService().translate('util_chmmlthrin_c5daf2'),
          tearHint: L10nService().translate('util_koxdigiyvl_f36b97'),
          signatureFallback: L10nService().translate('util_tngilunnhb_c60ef5'),
          effectLabel: L10nService().translate('util_tritimlpln_02cb79'),
          background: const [
            Color(0xFFFF8A9A),
            Color(0xFFFFB7B2),
            Color(0xFFFFF1F2)
          ],
          accent: const Color(0xFFFF5E8B),
          envelope: const Color(0xFFFFD5DD),
          envelopeLight: const Color(0xFFFFF0F3),
          paper: const Color(0xFFFFFBFC),
          ink: const Color(0xFF7B3645),
          muted: const Color(0xFFAD6C7C),
          leadingIcon: Icons.auto_awesome_rounded,
          trailingIcon: Icons.favorite_rounded,
          stampIcon: Icons.favorite_rounded,
        );
    }
  }
}

class _EnvelopeStage extends StatelessWidget {
  final _LoveCardViewerTheme palette;
  final double openValue;
  final VoidCallback onOpen;
  final String hintText;

  const _EnvelopeStage({
    required this.palette,
    required this.openValue,
    required this.onOpen,
    required this.hintText,
  });

  @override
  Widget build(BuildContext context) {
    final flapAngle = -pi * 0.94 * openValue;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 760),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 336,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.bottomCenter,
              children: [
                Positioned(
                  top: 20,
                  child: _GlowOrb(
                    size: 180,
                    color: Colors.white.withValues(alpha: 0.20),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: _EnvelopePocket(
                    color: palette.envelope,
                    shadow: palette.accent.withValues(alpha: 0.24),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 150,
                  child: Transform(
                    alignment: Alignment.topCenter,
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, 0.001)
                      ..rotateX(flapAngle),
                    child: _EnvelopeFlap(color: palette.envelopeLight),
                  ),
                ),
                Positioned(
                  left: 26,
                  top: 32,
                  child: Icon(
                    palette.leadingIcon,
                    color: Colors.white.withValues(alpha: 0.86),
                    size: 26,
                  ),
                ),
                Positioned(
                  right: 28,
                  top: 34,
                  child: Icon(
                    palette.trailingIcon,
                    color: Colors.white.withValues(alpha: 0.86),
                    size: 24,
                  ),
                ),
                Positioned(
                  bottom: 78,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: onOpen,
                      borderRadius: BorderRadius.circular(999),
                      child: Ink(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 22,
                          vertical: 18,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.22),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.12),
                              blurRadius: 24,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.unfold_more_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              L10nService().translate('util_mthip_c0ffaf'),
                              style: SLTheme.quicksand(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          AnimatedOpacity(
            opacity: openValue > 0.18 ? 0.54 : 1,
            duration: const Duration(milliseconds: 180),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
              ),
              child: Text(
                hintText,
                textAlign: TextAlign.center,
                style: SLTheme.quicksand(
                  color: Colors.white.withValues(alpha: 0.94),
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PaperBadge extends StatelessWidget {
  final String label;
  final Color background;
  final Color foreground;

  const _PaperBadge({
    required this.label,
    required this.background,
    required this.foreground,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: SLTheme.quicksand(
          color: foreground,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _PaperTearStrip extends StatelessWidget {
  final Color accent;
  final String label;

  const _PaperTearStrip({
    required this.accent,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _TearStripPainter(
        accent: accent,
        paper: const Color(0xFFFFFCFE),
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.center,
              child: Icon(
                Icons.swipe_rounded,
                color: accent,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: SLTheme.quicksand(
                  color: const Color(0xFF6C465A),
                  fontSize: 13,
                  height: 1.35,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EnvelopePocket extends StatelessWidget {
  final Color color;
  final Color shadow;

  const _EnvelopePocket({
    required this.color,
    required this.shadow,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 260,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(36),
        boxShadow: [
          BoxShadow(
            color: shadow,
            blurRadius: 28,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: CustomPaint(
        painter: _EnvelopePocketPainter(color: color.withValues(alpha: 0.94)),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _EnvelopeFlap extends StatelessWidget {
  final Color color;

  const _EnvelopeFlap({required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 176,
      child: CustomPaint(
        painter: _EnvelopeFlapPainter(color: color),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _EnvelopePocketPainter extends CustomPainter {
  final Color color;

  const _EnvelopePocketPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final basePaint = Paint()..color = color;
    final shinePaint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.white.withValues(alpha: 0.28),
          Colors.transparent,
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Offset.zero & size);

    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height * 0.58)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(path, basePaint);
    canvas.drawPath(path, shinePaint);
  }

  @override
  bool shouldRepaint(covariant _EnvelopePocketPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _EnvelopeFlapPainter extends CustomPainter {
  final Color color;

  const _EnvelopeFlapPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.white.withValues(alpha: 0.38),
          color,
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Offset.zero & size);

    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _EnvelopeFlapPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _TearStripPainter extends CustomPainter {
  final Color accent;
  final Color paper;

  const _TearStripPainter({
    required this.accent,
    required this.paper,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()..moveTo(18, 0);
    path.lineTo(size.width - 18, 0);
    path.quadraticBezierTo(size.width, 0, size.width, 18);
    path.lineTo(size.width, size.height - 18);

    const segments = 12;
    final segmentWidth = size.width / segments;
    for (var i = segments; i >= 0; i--) {
      final x = i * segmentWidth;
      final y = size.height - (i.isEven ? 6.0 : 16.0);
      path.lineTo(x, y);
    }

    path.lineTo(0, 18);
    path.quadraticBezierTo(0, 0, 18, 0);
    path.close();

    final fill = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.white,
          paper,
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Offset.zero & size);
    final border = Paint()
      ..color = accent.withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    canvas.drawShadow(path, Colors.black.withValues(alpha: 0.10), 10, false);
    canvas.drawPath(path, fill);
    canvas.drawPath(path, border);
  }

  @override
  bool shouldRepaint(covariant _TearStripPainter oldDelegate) {
    return oldDelegate.accent != accent || oldDelegate.paper != paper;
  }
}

enum _ViewerThemeEffectKind {
  love,
  birthday,
  anniversary,
  miss,
}

_ViewerThemeEffectKind _viewerThemeEffectOf(String key) {
  switch (key.trim().toLowerCase()) {
    case 'birthday':
      return _ViewerThemeEffectKind.birthday;
    case 'anniversary':
      return _ViewerThemeEffectKind.anniversary;
    case 'miss':
      return _ViewerThemeEffectKind.miss;
    default:
      return _ViewerThemeEffectKind.love;
  }
}

class _ThemeAmbientPainter extends CustomPainter {
  final String themeKey;
  final double openProgress;
  final double tearProgress;
  final Color accent;
  final Color softAccent;
  final Color backdrop;

  const _ThemeAmbientPainter({
    required this.themeKey,
    required this.openProgress,
    required this.tearProgress,
    required this.accent,
    required this.softAccent,
    required this.backdrop,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final reveal =
        max(openProgress, tearProgress * 0.9).clamp(0.0, 1.0).toDouble();
    if (reveal <= 0) {
      return;
    }

    switch (_viewerThemeEffectOf(themeKey)) {
      case _ViewerThemeEffectKind.love:
        _drawHeart(
          canvas,
          Offset(size.width * 0.14, size.height * 0.16),
          16,
          accent.withValues(alpha: 0.16 * reveal),
        );
        _drawHeart(
          canvas,
          Offset(size.width * 0.84, size.height * 0.28),
          22,
          softAccent.withValues(alpha: 0.18 * reveal),
        );
        _drawSparkle(
          canvas,
          Offset(size.width * 0.78, size.height * 0.12),
          12,
          Colors.white.withValues(alpha: 0.34 * reveal),
        );
        _drawSparkle(
          canvas,
          Offset(size.width * 0.24, size.height * 0.26),
          10,
          Colors.white.withValues(alpha: 0.26 * reveal),
        );
        break;
      case _ViewerThemeEffectKind.birthday:
        _drawBalloon(
          canvas,
          Offset(size.width * 0.18, size.height * 0.18),
          22,
          softAccent.withValues(alpha: 0.22 * reveal),
        );
        _drawBalloon(
          canvas,
          Offset(size.width * 0.84, size.height * 0.16),
          26,
          Colors.white.withValues(alpha: 0.18 * reveal),
        );
        for (var i = 0; i < 9; i++) {
          final x = size.width * (0.12 + i * 0.085);
          final y = size.height * (0.11 + (i.isEven ? 0.00 : 0.03));
          _drawConfettiPiece(
            canvas,
            Offset(x, y),
            Size(i.isEven ? 12 : 8, i.isEven ? 4 : 8),
            (i.isEven ? 0.42 : -0.52) + (i * 0.03),
            Color.lerp(accent, softAccent, i / 8)!
                .withValues(alpha: 0.28 * reveal),
          );
        }
        break;
      case _ViewerThemeEffectKind.anniversary:
        _drawRing(
          canvas,
          Offset(size.width * 0.84, size.height * 0.18),
          32,
          Colors.white.withValues(alpha: 0.22 * reveal),
          2,
        );
        _drawRing(
          canvas,
          Offset(size.width * 0.84, size.height * 0.18),
          20,
          const Color(0xFFFFD98B).withValues(alpha: 0.38 * reveal),
          1.5,
        );
        _drawSparkle(
          canvas,
          Offset(size.width * 0.16, size.height * 0.18),
          12,
          const Color(0xFFFFE3A2).withValues(alpha: 0.34 * reveal),
        );
        _drawSparkle(
          canvas,
          Offset(size.width * 0.26, size.height * 0.12),
          9,
          Colors.white.withValues(alpha: 0.24 * reveal),
        );
        break;
      case _ViewerThemeEffectKind.miss:
        _drawMoon(
          canvas,
          Offset(size.width * 0.84, size.height * 0.17),
          28,
          Colors.white.withValues(alpha: 0.20 * reveal),
          backdrop,
        );
        _drawSparkle(
          canvas,
          Offset(size.width * 0.18, size.height * 0.14),
          9,
          Colors.white.withValues(alpha: 0.26 * reveal),
        );
        _drawSparkle(
          canvas,
          Offset(size.width * 0.26, size.height * 0.22),
          7,
          softAccent.withValues(alpha: 0.22 * reveal),
        );
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _ThemeAmbientPainter oldDelegate) {
    return oldDelegate.themeKey != themeKey ||
        oldDelegate.openProgress != openProgress ||
        oldDelegate.tearProgress != tearProgress ||
        oldDelegate.accent != accent ||
        oldDelegate.softAccent != softAccent ||
        oldDelegate.backdrop != backdrop;
  }
}

class _BurstParticlesPainter extends CustomPainter {
  final String themeKey;
  final double progress;
  final double openProgress;
  final Color accent;
  final Color softAccent;

  const _BurstParticlesPainter({
    required this.themeKey,
    required this.progress,
    required this.openProgress,
    required this.accent,
    required this.softAccent,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 1) {
      return;
    }

    final effect = _viewerThemeEffectOf(themeKey);
    final eased = Curves.easeOut.transform(progress);
    final fade = (1 - Curves.easeIn.transform(progress)) *
        (0.84 + (openProgress * 0.16));
    final origin = Offset(size.width / 2, size.height * 0.72);

    switch (effect) {
      case _ViewerThemeEffectKind.love:
        for (var i = 0; i < 14; i++) {
          final angle = (-pi / 1.25) + (pi * 1.5) * (i / 13);
          final distance = lerpDouble(16, 210 + (i % 3) * 18, eased) ?? 0;
          final center = origin.translate(
            cos(angle) * distance,
            sin(angle) * distance,
          );
          final sizeFactor = lerpDouble(8, 18 - (i % 4), fade) ?? 10;
          final color = Color.lerp(
            accent.withValues(alpha: 0.90 * fade),
            softAccent.withValues(alpha: 0.78 * fade),
            i.isEven ? 0.24 : 0.68,
          )!;
          if (i % 3 == 0) {
            _drawSparkle(canvas, center, max(sizeFactor * 0.68, 5), color);
          } else {
            _drawHeart(canvas, center, max(sizeFactor, 6), color);
          }
        }
        break;
      case _ViewerThemeEffectKind.birthday:
        for (var i = 0; i < 18; i++) {
          final angle = (-pi / 1.2) + (pi * 1.45) * (i / 17);
          final distance = lerpDouble(18, 240 + (i % 4) * 10, eased) ?? 0;
          final center = origin.translate(
            cos(angle) * distance,
            sin(angle) * distance,
          );
          final color = Color.lerp(
            accent.withValues(alpha: 0.92 * fade),
            softAccent.withValues(alpha: 0.70 * fade),
            (i % 5) / 4,
          )!;
          if (i.isEven) {
            _drawConfettiPiece(
              canvas,
              center,
              Size(16 - (i % 3).toDouble(), 5 + (i % 2).toDouble()),
              angle + (i * 0.1),
              color,
            );
          } else {
            canvas.drawCircle(
              center,
              lerpDouble(3, 7, fade) ?? 4,
              Paint()..color = color,
            );
          }
        }
        break;
      case _ViewerThemeEffectKind.anniversary:
        for (var i = 0; i < 3; i++) {
          _drawRing(
            canvas,
            origin,
            lerpDouble(24 + (i * 8), 90 + (i * 28), eased) ?? 36,
            Color.lerp(
              accent.withValues(alpha: 0.20 * fade),
              const Color(0xFFFFD98B).withValues(alpha: 0.28 * fade),
              i / 2,
            )!,
            1.4 + (2 - i) * 0.4,
          );
        }
        for (var i = 0; i < 12; i++) {
          final angle = (-pi / 1.1) + (pi * 1.35) * (i / 11);
          final distance = lerpDouble(12, 170 + (i % 3) * 14, eased) ?? 0;
          final center = origin.translate(
            cos(angle) * distance,
            sin(angle) * distance,
          );
          final color = i.isEven
              ? const Color(0xFFFFE3A2).withValues(alpha: 0.54 * fade)
              : softAccent.withValues(alpha: 0.46 * fade);
          if (i % 3 == 0) {
            _drawSparkle(canvas, center, 10, color);
          } else {
            _drawDiamond(canvas, center, 8, color);
          }
        }
        break;
      case _ViewerThemeEffectKind.miss:
        for (var i = 0; i < 14; i++) {
          final angle = (-pi / 1.35) + (pi * 1.1) * (i / 13);
          final distance = lerpDouble(10, 160 + (i % 4) * 12, eased) ?? 0;
          final driftY = lerpDouble(0, -36, eased) ?? 0;
          final center = origin.translate(
            cos(angle) * distance,
            (sin(angle) * distance) + driftY,
          );
          final color = Color.lerp(
            softAccent.withValues(alpha: 0.62 * fade),
            Colors.white.withValues(alpha: 0.52 * fade),
            i / 13,
          )!;
          if (i.isEven) {
            _drawSparkle(canvas, center, 8, color);
          } else {
            canvas.drawCircle(
              center,
              lerpDouble(2, 5, fade) ?? 3,
              Paint()..color = color,
            );
          }
        }
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _BurstParticlesPainter oldDelegate) {
    return oldDelegate.themeKey != themeKey ||
        oldDelegate.progress != progress ||
        oldDelegate.openProgress != openProgress ||
        oldDelegate.accent != accent ||
        oldDelegate.softAccent != softAccent;
  }
}

void _drawHeart(Canvas canvas, Offset center, double size, Color color) {
  final width = size;
  final height = size * 0.92;
  final path = Path()
    ..moveTo(center.dx, center.dy + height * 0.35)
    ..cubicTo(
      center.dx - width * 0.60,
      center.dy - height * 0.10,
      center.dx - width * 0.56,
      center.dy - height * 0.58,
      center.dx,
      center.dy - height * 0.24,
    )
    ..cubicTo(
      center.dx + width * 0.56,
      center.dy - height * 0.58,
      center.dx + width * 0.60,
      center.dy - height * 0.10,
      center.dx,
      center.dy + height * 0.35,
    )
    ..close();

  canvas.drawPath(path, Paint()..color = color);
}

void _drawSparkle(Canvas canvas, Offset center, double size, Color color) {
  final paint = Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeWidth = max(size * 0.12, 1.2);

  canvas.drawLine(
    center.translate(0, -size),
    center.translate(0, size),
    paint,
  );
  canvas.drawLine(
    center.translate(-size, 0),
    center.translate(size, 0),
    paint,
  );
  canvas.drawLine(
    center.translate(-size * 0.62, -size * 0.62),
    center.translate(size * 0.62, size * 0.62),
    paint,
  );
  canvas.drawLine(
    center.translate(size * 0.62, -size * 0.62),
    center.translate(-size * 0.62, size * 0.62),
    paint,
  );
}

void _drawDiamond(Canvas canvas, Offset center, double size, Color color) {
  final path = Path()
    ..moveTo(center.dx, center.dy - size)
    ..lineTo(center.dx + size * 0.78, center.dy)
    ..lineTo(center.dx, center.dy + size)
    ..lineTo(center.dx - size * 0.78, center.dy)
    ..close();
  canvas.drawPath(path, Paint()..color = color);
}

void _drawConfettiPiece(
  Canvas canvas,
  Offset center,
  Size pieceSize,
  double rotation,
  Color color,
) {
  canvas.save();
  canvas.translate(center.dx, center.dy);
  canvas.rotate(rotation);
  final rect = RRect.fromRectAndRadius(
    Rect.fromCenter(
      center: Offset.zero,
      width: pieceSize.width,
      height: pieceSize.height,
    ),
    Radius.circular(pieceSize.height),
  );
  canvas.drawRRect(rect, Paint()..color = color);
  canvas.restore();
}

void _drawRing(
  Canvas canvas,
  Offset center,
  double radius,
  Color color,
  double strokeWidth,
) {
  canvas.drawCircle(
    center,
    radius,
    Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth,
  );
}

void _drawBalloon(Canvas canvas, Offset center, double size, Color color) {
  final paint = Paint()..color = color;
  canvas.drawOval(
    Rect.fromCenter(
      center: center,
      width: size * 0.92,
      height: size * 1.14,
    ),
    paint,
  );
  canvas.drawLine(
    center.translate(0, size * 0.56),
    center.translate(size * 0.18, size * 1.42),
    Paint()
      ..color = color.withValues(alpha: 0.82)
      ..strokeWidth = 1.4,
  );
}

void _drawMoon(
  Canvas canvas,
  Offset center,
  double size,
  Color color,
  Color cutout,
) {
  canvas.drawCircle(center, size, Paint()..color = color);
  canvas.drawCircle(
    center.translate(size * 0.34, -size * 0.12),
    size * 0.82,
    Paint()..color = cutout,
  );
}

class _GlowOrb extends StatelessWidget {
  final double size;
  final Color color;

  const _GlowOrb({
    required this.size,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          boxShadow: [
            BoxShadow(
              color: color,
              blurRadius: size * 0.36,
              spreadRadius: size * 0.02,
            ),
          ],
        ),
      ),
    );
  }
}

class _PaperGlow extends StatelessWidget {
  final double size;
  final Color color;

  const _PaperGlow({
    required this.size,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color,
              color.withValues(alpha: 0),
            ],
          ),
        ),
      ),
    );
  }
}

class _ViewerCircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _ViewerCircleButton({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
          ),
          child: Icon(icon, color: Colors.white, size: 19),
        ),
      ),
    );
  }
}

class _ActionPillButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final Color background;
  final Color foreground;

  const _ActionPillButton({
    required this.label,
    required this.icon,
    required this.onTap,
    required this.background,
    required this.foreground,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: foreground),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: SLTheme.quicksand(
                    color: foreground,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _formatTime(int timestampMs) {
  return DateFormat('HH:mm - dd/MM/yyyy').format(
    DateTime.fromMillisecondsSinceEpoch(timestampMs),
  );
}
