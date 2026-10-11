part of '../love_card_public_viewer_screen.dart';

class _LoveCardViewerTheme {
  final String badge;
  final String headline;
  final String headerTitle;
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

  Color get accentInk => Color.lerp(accent, ink, 0.5)!;

  Color get mutedInk => Color.lerp(muted, ink, 0.2)!;

  List<Color> backgroundFor(bool isDark) => isDark
      ? background
      : [
          Color.lerp(paper, envelopeLight, 0.24)!,
          Color.lerp(paper, const Color(0xFFF2ECE3), 0.5)!,
        ];

  Color foregroundFor(bool isDark) => isDark ? const Color(0xFFFFF8F1) : ink;

  Color mutedFor(bool isDark) => isDark ? const Color(0xFFCBBFC7) : mutedInk;

  factory _LoveCardViewerTheme.of(String rawKey) {
    final key = rawKey.trim().toLowerCase();
    switch (key) {
      case 'birthday':
        return _LoveCardViewerTheme(
          badge: L10nService().translate('util_sinhnht_71c600'),
          headline: L10nService().translate('util_rcrvvuiti_6474ca'),
          headerTitle: L10nService().translate(
            'love_card_receiver_birthday_header',
          ),
          signatureFallback: L10nService().translate('util_chcmngsinh_1db118'),
          effectLabel: L10nService().translate('util_phogiybngn_b5a4e9'),
          background: const [Color(0xFF50302F), Color(0xFF201C2E)],
          accent: const Color(0xFFFF8B5E),
          envelope: const Color(0xFFFFB47E),
          envelopeLight: const Color(0xFFFFE09F),
          paper: const Color(0xFFFFFBF1),
          ink: const Color(0xFF382B35),
          muted: const Color(0xFF7B6E74),
          leadingIcon: Icons.cake_rounded,
          trailingIcon: Icons.celebration_rounded,
          stampIcon: Icons.local_activity_rounded,
        );
      case 'anniversary':
        return _LoveCardViewerTheme(
          badge: L10nService().translate('util_knim_4f6aeb'),
          headline: L10nService().translate('util_trangtrngv_a5c5a8'),
          headerTitle: L10nService().translate(
            'love_card_receiver_anniversary_header',
          ),
          signatureFallback: L10nService().translate('util_mtngyngnhc_02e59f'),
          effectLabel: L10nService().translate('util_hoquangkc_1a4d18'),
          background: const [Color(0xFF2D3F72), Color(0xFF171C3B)],
          accent: const Color(0xFF6478E8),
          envelope: const Color(0xFF8298F2),
          envelopeLight: const Color(0xFFBFD3FF),
          paper: const Color(0xFFF9FAFF),
          ink: const Color(0xFF29304B),
          muted: const Color(0xFF707791),
          leadingIcon: Icons.diamond_rounded,
          trailingIcon: Icons.workspace_premium_rounded,
          stampIcon: Icons.auto_awesome_rounded,
        );
      case 'miss':
        return _LoveCardViewerTheme(
          badge: L10nService().translate('util_nhnhau_5dc5c1'),
          headline: L10nService().translate('util_nhnhngvsul_592c70'),
          headerTitle: L10nService().translate(
            'love_card_receiver_miss_header',
          ),
          signatureFallback: L10nService().translate('util_nhbnnhiulm_fcda3f'),
          effectLabel: L10nService().translate('util_msaodum_19d800'),
          background: const [Color(0xFF413766), Color(0xFF1D1A34)],
          accent: const Color(0xFF8972D8),
          envelope: const Color(0xFFA995E4),
          envelopeLight: const Color(0xFFD5C7FA),
          paper: const Color(0xFFFCF9FF),
          ink: const Color(0xFF352E4D),
          muted: const Color(0xFF786F8A),
          leadingIcon: Icons.nights_stay_rounded,
          trailingIcon: Icons.star_rounded,
          stampIcon: Icons.bedtime_rounded,
        );
      case 'encouragement':
        return _LoveCardViewerTheme(
          badge: L10nService().translate('love_card_theme_encouragement_chip'),
          headline: L10nService().translate(
            'love_card_theme_encouragement_title',
          ),
          headerTitle: L10nService().translate(
            'love_card_receiver_encouragement_header',
          ),
          signatureFallback: L10nService().translate(
            'love_card_theme_encouragement_signature',
          ),
          effectLabel: L10nService().translate(
            'love_card_theme_encouragement_effect',
          ),
          background: const [Color(0xFF573829), Color(0xFF242126)],
          accent: const Color(0xFFF57C45),
          envelope: const Color(0xFFFFA65F),
          envelopeLight: const Color(0xFFFFD36C),
          paper: const Color(0xFFFFFBF0),
          ink: const Color(0xFF3B302D),
          muted: const Color(0xFF7D706A),
          leadingIcon: Icons.emoji_objects_rounded,
          trailingIcon: Icons.whatshot_rounded,
          stampIcon: Icons.bolt_rounded,
        );
      case 'gratitude':
        return _LoveCardViewerTheme(
          badge: L10nService().translate('love_card_theme_gratitude_chip'),
          headline: L10nService().translate('love_card_theme_gratitude_title'),
          headerTitle: L10nService().translate(
            'love_card_receiver_gratitude_header',
          ),
          signatureFallback: L10nService().translate(
            'love_card_theme_gratitude_signature',
          ),
          effectLabel: L10nService().translate(
            'love_card_theme_gratitude_effect',
          ),
          background: const [Color(0xFF214D52), Color(0xFF142A35)],
          accent: const Color(0xFF269B96),
          envelope: const Color(0xFF56BDB3),
          envelopeLight: const Color(0xFF9BE1D2),
          paper: const Color(0xFFF6FCF9),
          ink: const Color(0xFF243E3F),
          muted: const Color(0xFF687D7C),
          leadingIcon: Icons.volunteer_activism_rounded,
          trailingIcon: Icons.favorite_rounded,
          stampIcon: Icons.water_drop_rounded,
        );
      case 'adventure':
        return _LoveCardViewerTheme(
          badge: L10nService().translate('love_card_theme_adventure_chip'),
          headline: L10nService().translate('love_card_theme_adventure_title'),
          headerTitle: L10nService().translate(
            'love_card_receiver_adventure_header',
          ),
          signatureFallback: L10nService().translate(
            'love_card_theme_adventure_signature',
          ),
          effectLabel: L10nService().translate(
            'love_card_theme_adventure_effect',
          ),
          background: const [Color(0xFF214836), Color(0xFF172C27)],
          accent: const Color(0xFF2C8C68),
          envelope: const Color(0xFF65AD7B),
          envelopeLight: const Color(0xFFAED5B8),
          paper: const Color(0xFFF8FCF4),
          ink: const Color(0xFF293B31),
          muted: const Color(0xFF6B7C70),
          leadingIcon: Icons.explore_rounded,
          trailingIcon: Icons.flight_rounded,
          stampIcon: Icons.landscape_rounded,
        );
      case 'serenity':
        return _LoveCardViewerTheme(
          badge: L10nService().translate('love_card_theme_serenity_chip'),
          headline: L10nService().translate('love_card_theme_serenity_title'),
          headerTitle: L10nService().translate(
            'love_card_receiver_serenity_header',
          ),
          signatureFallback: L10nService().translate(
            'love_card_theme_serenity_signature',
          ),
          effectLabel: L10nService().translate(
            'love_card_theme_serenity_effect',
          ),
          background: const [Color(0xFF3E385A), Color(0xFF242137)],
          accent: const Color(0xFF7769BC),
          envelope: const Color(0xFF998CD1),
          envelopeLight: const Color(0xFFD5C9EE),
          paper: const Color(0xFFFBFAFD),
          ink: const Color(0xFF373246),
          muted: const Color(0xFF787285),
          leadingIcon: Icons.self_improvement_rounded,
          trailingIcon: Icons.nights_stay_rounded,
          stampIcon: Icons.spa_rounded,
        );
      default:
        return _LoveCardViewerTheme(
          badge: L10nService().translate('util_tnhyu_2814db'),
          headline: L10nService().translate('util_dudngvmp_f089f1'),
          headerTitle: L10nService().translate('utility_title_love_card'),
          signatureFallback: L10nService().translate('util_tngilunnhb_c60ef5'),
          effectLabel: L10nService().translate('util_tritimlpln_02cb79'),
          background: const [Color(0xFF5A3447), Color(0xFF251D32)],
          accent: const Color(0xFFE75B80),
          envelope: const Color(0xFFF47A99),
          envelopeLight: const Color(0xFFFFB8C9),
          paper: const Color(0xFFFFFAF6),
          ink: const Color(0xFF3D2E38),
          muted: const Color(0xFF806F79),
          leadingIcon: Icons.favorite_rounded,
          trailingIcon: Icons.auto_awesome_rounded,
          stampIcon: Icons.favorite_rounded,
        );
    }
  }
}

class _LoveCardBackdropMotif extends StatelessWidget {
  final _LoveCardViewerTheme palette;

  const _LoveCardBackdropMotif({required this.palette});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: [
            Positioned(
              top: -70,
              right: -55,
              child: _BackdropOrb(
                size: 210,
                color: palette.envelopeLight.withValues(alpha: 0.10),
              ),
            ),
            Positioned(
              left: -80,
              bottom: 30,
              child: _BackdropOrb(
                size: 240,
                color: palette.accent.withValues(alpha: 0.10),
              ),
            ),
            Positioned(
              top: constraints.maxHeight * 0.18,
              left: 24,
              child: Icon(
                palette.trailingIcon,
                size: 23,
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
            Positioned(
              top: constraints.maxHeight * 0.32,
              right: 28,
              child: Transform.rotate(
                angle: 0.22,
                child: Icon(
                  palette.stampIcon,
                  size: 31,
                  color: palette.envelopeLight.withValues(alpha: 0.11),
                ),
              ),
            ),
            Positioned(
              bottom: constraints.maxHeight * 0.15,
              left: constraints.maxWidth * 0.18,
              child: Icon(
                Icons.auto_awesome_rounded,
                size: 18,
                color: Colors.white.withValues(alpha: 0.09),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _BackdropOrb extends StatelessWidget {
  final double size;
  final Color color;

  const _BackdropOrb({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}

class _SealedLoveEnvelope extends StatelessWidget {
  final _LoveCardViewerTheme palette;
  final VoidCallback onOpen;

  const _SealedLoveEnvelope({required this.palette, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: context.tr('love_card_receiver_open_action'),
      onTap: onOpen,
      child: ExcludeSemantics(
        child: GestureDetector(
          key: const ValueKey('love-card-envelope'),
          behavior: HitTestBehavior.opaque,
          onTap: onOpen,
          child: RepaintBoundary(
            child: AspectRatio(
              aspectRatio: 1.6,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final sealSize = (constraints.maxWidth * 0.18).clamp(
                    52.0,
                    68.0,
                  );
                  return CustomPaint(
                    painter: _LoveEnvelopePainter(palette: palette),
                    child: Center(
                      child: Transform.translate(
                        offset: Offset(0, constraints.maxHeight * 0.1),
                        child: Container(
                          width: sealSize,
                          height: sealSize,
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: palette.accentInk,
                            border: Border.all(
                              color: palette.paper.withValues(alpha: 0.85),
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: palette.accentInk.withValues(alpha: 0.2),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: palette.paper.withValues(alpha: 0.4),
                              ),
                            ),
                            child: Icon(
                              palette.leadingIcon,
                              color: palette.paper,
                              size: sealSize * 0.4,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LoveEnvelopePainter extends CustomPainter {
  final _LoveCardViewerTheme palette;

  const _LoveEnvelopePainter({required this.palette});

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;
    final letter = RRect.fromRectAndRadius(
      Rect.fromLTWH(width * 0.1, height * 0.04, width * 0.8, height * 0.6),
      const Radius.circular(10),
    );
    canvas.drawRRect(letter, Paint()..color = palette.paper);
    final pen = Paint()
      ..color = palette.accentInk.withValues(alpha: 0.16)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(width * 0.2, height * 0.13),
      Offset(width * 0.55, height * 0.13),
      pen,
    );
    canvas.drawLine(
      Offset(width * 0.2, height * 0.18),
      Offset(width * 0.4, height * 0.18),
      pen,
    );
    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(width * 0.025, height * 0.23, width * 0.95, height * 0.7),
      const Radius.circular(14),
    );
    canvas.drawShadow(
      Path()..addRRect(body),
      palette.ink.withValues(alpha: 0.16),
      8,
      false,
    );
    canvas.drawRRect(body, Paint()..color = palette.envelope);
    canvas.save();
    canvas.clipRRect(body);
    final leftFold = Path()
      ..moveTo(width * 0.025, height * 0.23)
      ..lineTo(width * 0.56, height * 0.69)
      ..lineTo(width * 0.025, height * 0.93)
      ..close();
    canvas.drawPath(
      leftFold,
      Paint()..color = Color.lerp(palette.envelope, palette.paper, 0.2)!,
    );
    final rightFold = Path()
      ..moveTo(width * 0.975, height * 0.23)
      ..lineTo(width * 0.44, height * 0.69)
      ..lineTo(width * 0.975, height * 0.93)
      ..close();
    canvas.drawPath(
      rightFold,
      Paint()..color = Color.lerp(palette.envelope, palette.accentInk, 0.08)!,
    );
    final pocket = Path()
      ..moveTo(width * 0.025, height * 0.93)
      ..lineTo(width * 0.46, height * 0.59)
      ..quadraticBezierTo(
        width * 0.5,
        height * 0.56,
        width * 0.54,
        height * 0.59,
      )
      ..lineTo(width * 0.975, height * 0.93)
      ..close();
    canvas.drawPath(
      pocket,
      Paint()..color = Color.lerp(palette.envelope, palette.paper, 0.12)!,
    );
    final flap = Path()
      ..moveTo(width * 0.025, height * 0.23)
      ..lineTo(width * 0.46, height * 0.62)
      ..quadraticBezierTo(
        width * 0.5,
        height * 0.66,
        width * 0.54,
        height * 0.62,
      )
      ..lineTo(width * 0.975, height * 0.23)
      ..close();
    canvas.drawShadow(flap, palette.ink.withValues(alpha: 0.12), 3, false);
    canvas.drawPath(flap, Paint()..color = palette.envelopeLight);
    canvas.restore();
    canvas.drawRRect(
      body,
      Paint()
        ..color = palette.accentInk.withValues(alpha: 0.12)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(covariant _LoveEnvelopePainter oldDelegate) =>
      oldDelegate.palette.envelope != palette.envelope ||
      oldDelegate.palette.envelopeLight != palette.envelopeLight ||
      oldDelegate.palette.accentInk != palette.accentInk ||
      oldDelegate.palette.paper != palette.paper ||
      oldDelegate.palette.ink != palette.ink;
}

class _PostageStamp extends StatelessWidget {
  final _LoveCardViewerTheme palette;

  const _PostageStamp({required this.palette});

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Transform.rotate(
        angle: 0.06,
        child: CustomPaint(
          painter: _PostageStampPainter(palette: palette),
          child: SizedBox(
            width: 56,
            height: 66,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: palette.accentInk.withValues(alpha: 0.05),
                  border: Border.all(
                    color: palette.accentInk.withValues(alpha: 0.2),
                  ),
                ),
                child: Icon(
                  palette.stampIcon,
                  color: palette.accentInk,
                  size: 24,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PostageStampPainter extends CustomPainter {
  final _LoveCardViewerTheme palette;

  const _PostageStampPainter({required this.palette});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = Color.lerp(palette.paper, palette.envelopeLight, 0.35)!,
    );
    final cutout = Paint()..color = palette.paper;
    for (var edge = 4.0; edge < size.width; edge += 8) {
      canvas.drawCircle(Offset(edge, 0), 2.2, cutout);
      canvas.drawCircle(Offset(edge, size.height), 2.2, cutout);
    }
    for (var edge = 4.0; edge < size.height; edge += 8) {
      canvas.drawCircle(Offset(0, edge), 2.2, cutout);
      canvas.drawCircle(Offset(size.width, edge), 2.2, cutout);
    }
  }

  @override
  bool shouldRepaint(covariant _PostageStampPainter oldDelegate) =>
      oldDelegate.palette.paper != palette.paper ||
      oldDelegate.palette.envelopeLight != palette.envelopeLight;
}

class _LetterPhoto extends StatelessWidget {
  final _LoveCardViewerTheme palette;
  final String imageUrl;

  const _LetterPhoto({required this.palette, required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return RepaintBoundary(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final cacheWidth =
              (constraints.maxWidth * MediaQuery.devicePixelRatioOf(context))
                  .clamp(320.0, 1600.0)
                  .round();
          return Stack(
            clipBehavior: Clip.none,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Transform.rotate(
                  angle: -0.012,
                  child: Container(
                    key: const ValueKey('love-card-polaroid'),
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 22),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFEFA),
                      boxShadow: [
                        BoxShadow(
                          color: palette.ink.withValues(alpha: 0.08),
                          blurRadius: 12,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: AspectRatio(
                        aspectRatio: 16 / 10,
                        child: CachedNetworkImage(
                          imageUrl: imageUrl,
                          memCacheWidth: cacheWidth,
                          fit: BoxFit.cover,
                          fadeInDuration: reduceMotion
                              ? Duration.zero
                              : const Duration(milliseconds: 180),
                          placeholder: (context, url) => ColoredBox(
                            color: palette.envelopeLight.withValues(alpha: 0.3),
                            child: Center(
                              child: Semantics(
                                label: context.tr('loading'),
                                child: Icon(
                                  Icons.photo_outlined,
                                  color: palette.accentInk,
                                  size: 30,
                                ),
                              ),
                            ),
                          ),
                          errorWidget: (context, url, error) => ColoredBox(
                            color: palette.envelopeLight.withValues(alpha: 0.3),
                            child: Icon(
                              Icons.broken_image_outlined,
                              color: palette.mutedInk,
                              size: 30,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Center(
                  child: Transform.rotate(
                    angle: -0.04,
                    child: Container(
                      width: 68,
                      height: 18,
                      decoration: BoxDecoration(
                        color: palette.envelopeLight.withValues(alpha: 0.8),
                        border: Border.all(
                          color: palette.accentInk.withValues(alpha: 0.1),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _LetterBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _LetterBadge({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            style: SLTheme.quicksand(
              color: color,
              fontSize: 12,
              height: 1.4,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _LetterDivider extends StatelessWidget {
  final _LoveCardViewerTheme palette;

  const _LetterDivider({required this.palette});

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Row(
        children: [
          Expanded(
            child: Divider(
              height: 1,
              color: palette.accentInk.withValues(alpha: 0.12),
            ),
          ),
          const SizedBox(width: 12),
          Icon(palette.trailingIcon, color: palette.accentInk, size: 16),
          const SizedBox(width: 12),
          Expanded(
            child: Divider(
              height: 1,
              color: palette.accentInk.withValues(alpha: 0.12),
            ),
          ),
        ],
      ),
    );
  }
}

class _ViewerCircleButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color foreground;

  const _ViewerCircleButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    required this.foreground,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      tooltip: tooltip,
      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      style: IconButton.styleFrom(
        foregroundColor: foreground,
        backgroundColor: foreground.withValues(alpha: 0.04),
        side: BorderSide(color: foreground.withValues(alpha: 0.08)),
      ),
      icon: Icon(icon, size: 19),
    );
  }
}

class _ActionPillButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final Color background;
  final Color foreground;
  final bool outlined;

  const _ActionPillButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    required this.background,
    required this.foreground,
    this.outlined = false,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      onTap: onTap,
      child: ExcludeSemantics(
        child: Material(
          color: background,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
            side: outlined
                ? BorderSide(color: foreground.withValues(alpha: 0.12))
                : BorderSide.none,
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 50),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, size: 18, color: foreground),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        label,
                        textAlign: TextAlign.center,
                        style: SLTheme.quicksand(
                          color: foreground,
                          fontSize: 13,
                          height: 1.4,
                          fontWeight: FontWeight.w700,
                        ),
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

String _formatTime(int timestampMs) {
  return LocaleDateFormat.timeAndDate(
    DateTime.fromMillisecondsSinceEpoch(timestampMs),
    separator: ' - ',
  );
}
