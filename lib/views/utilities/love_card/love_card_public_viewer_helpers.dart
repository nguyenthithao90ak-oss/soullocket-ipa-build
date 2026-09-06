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
  final String senderName;
  final VoidCallback onOpen;

  const _SealedLoveEnvelope({
    required this.palette,
    required this.senderName,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: context.tr('love_card_receiver_open_action'),
      child: GestureDetector(
        onTap: onOpen,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: AspectRatio(
            aspectRatio: 1.38,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: 8,
                  right: 8,
                  top: 34,
                  bottom: 6,
                  child: Container(
                    decoration: BoxDecoration(
                      color: palette.envelopeLight,
                      borderRadius: BorderRadius.circular(26),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.40),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.24),
                          blurRadius: 30,
                          offset: const Offset(0, 17),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: 29,
                  right: 29,
                  top: 10,
                  height: 190,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                    decoration: BoxDecoration(
                      color: palette.paper,
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.10),
                          blurRadius: 14,
                          offset: const Offset(0, 7),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _PostageStamp(palette: palette, compact: true),
                        const Spacer(),
                        Text(
                          context.tr('love_card_receiver_letter_title'),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: SLTheme.quicksand(
                            color: palette.ink,
                            fontSize: 15,
                            height: 1.25,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          senderName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.dancingScript(
                            color: palette.accent,
                            fontSize: 19,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: 8,
                  right: 8,
                  bottom: 6,
                  height: 150,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(26),
                    child: ColoredBox(
                      color: palette.envelope,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned(
                            left: -83,
                            top: 18,
                            child: Transform.rotate(
                              angle: 0.72,
                              child: Container(
                                width: 180,
                                height: 180,
                                color: Colors.white.withValues(alpha: 0.12),
                              ),
                            ),
                          ),
                          Positioned(
                            right: -83,
                            top: 18,
                            child: Transform.rotate(
                              angle: -0.72,
                              child: Container(
                                width: 180,
                                height: 180,
                                color: Colors.black.withValues(alpha: 0.05),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 86,
                  child: Center(
                    child: Transform.rotate(
                      angle: 0.785,
                      child: Container(
                        width: 190,
                        height: 190,
                        decoration: BoxDecoration(
                          color: palette.envelopeLight,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 12,
                              offset: const Offset(4, 5),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 66,
                  child: Center(
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: palette.accent,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.62),
                          width: 3,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: palette.accent.withValues(alpha: 0.40),
                            blurRadius: 18,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Icon(
                        palette.leadingIcon,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PostageStamp extends StatelessWidget {
  final _LoveCardViewerTheme palette;
  final bool compact;

  const _PostageStamp({required this.palette, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final size = compact ? 46.0 : 58.0;
    return Align(
      alignment: Alignment.topRight,
      child: Transform.rotate(
        angle: 0.08,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: palette.envelopeLight.withValues(alpha: 0.70),
            borderRadius: BorderRadius.circular(compact ? 12 : 15),
            border: Border.all(
              color: palette.accent.withValues(alpha: 0.42),
              width: 1.5,
            ),
          ),
          child: Icon(
            palette.stampIcon,
            color: palette.accent,
            size: compact ? 22 : 27,
          ),
        ),
      ),
    );
  }
}

class _LetterBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool onPaper;

  const _LetterBadge({
    required this.icon,
    required this.label,
    required this.color,
    this.onPaper = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: onPaper
            ? color.withValues(alpha: 0.10)
            : Colors.white.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: onPaper
              ? color.withValues(alpha: 0.18)
              : Colors.white.withValues(alpha: 0.14),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: onPaper ? color : Colors.white, size: 15),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: SLTheme.quicksand(
                color: onPaper ? color : Colors.white,
                fontSize: 10.5,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LetterDivider extends StatelessWidget {
  final _LoveCardViewerTheme palette;

  const _LetterDivider({required this.palette});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 1,
            color: palette.accent.withValues(alpha: 0.16),
          ),
        ),
        const SizedBox(width: 10),
        Icon(palette.trailingIcon, color: palette.accent, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            height: 1,
            color: palette.accent.withValues(alpha: 0.16),
          ),
        ),
      ],
    );
  }
}

class _ViewerCircleButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _ViewerCircleButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: Ink(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.11),
              border: Border.all(color: Colors.white.withValues(alpha: 0.13)),
            ),
            child: Icon(icon, color: Colors.white, size: 19),
          ),
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
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 17, color: foreground),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: SLTheme.quicksand(
                    color: foreground,
                    fontSize: 12,
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
  return DateFormat(
    'HH:mm - dd/MM/yyyy',
  ).format(DateTime.fromMillisecondsSinceEpoch(timestampMs));
}
