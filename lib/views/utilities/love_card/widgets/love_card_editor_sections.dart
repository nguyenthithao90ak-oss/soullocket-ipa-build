part of '../../love_card_screen.dart';

class _LoveCardCreateView extends StatelessWidget {
  final _LoveCardScreenState state;

  const _LoveCardCreateView({
    required this.state,
  });

  @override
  Widget build(BuildContext context) {
    final theme = state._themeOf(state._selectedTheme);
    final colors = state._themeColors(theme.key);

    return LayoutBuilder(
      builder: (context, constraints) {
        final desktopInset = constraints.maxWidth >= 1120 ? 42.0 : 0.0;
        final compactWidth = constraints.maxWidth < 380;
        final bottomInset = MediaQuery.of(context).padding.bottom;

        return Stack(
          children: [
            ListView(
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              padding: EdgeInsets.fromLTRB(
                desktopInset,
                4,
                desktopInset,
                bottomInset + (compactWidth ? 128 : 136),
              ),
              children: [
                _LoveCardCreateHero(theme: theme),
                const SizedBox(height: 14),
                Padding(
                  padding:
                      EdgeInsets.symmetric(horizontal: compactWidth ? 16 : 20),
                  child: Text(
                    context.tr('util_chnphongcc_682dea'),
                    style: SLTheme.quicksand(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                _LoveCardThemePicker(state: state),
                const SizedBox(height: 18),
                Padding(
                  padding:
                      EdgeInsets.symmetric(horizontal: compactWidth ? 16 : 20),
                  child: Text(
                    'Xem trước thiệp',
                    style: SLTheme.quicksand(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding:
                      EdgeInsets.symmetric(horizontal: compactWidth ? 16 : 20),
                  child: _LoveCardPreviewPanel(
                    state: state,
                    theme: theme,
                    colors: colors,
                    fullBleed: false,
                  ),
                ),
                const SizedBox(height: 18),
                Padding(
                  padding:
                      EdgeInsets.symmetric(horizontal: compactWidth ? 16 : 20),
                  child: _LoveCardComposerPanel(
                    state: state,
                    theme: theme,
                    colors: colors,
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding:
                      EdgeInsets.symmetric(horizontal: compactWidth ? 16 : 20),
                  child: Text(
                    context.tr('util_saukhigiap_ef330c'),
                    textAlign: TextAlign.center,
                    style: SLTheme.quicksand(
                      color: Colors.white.withValues(alpha: 0.68),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            Positioned(
              left: desktopInset,
              right: desktopInset,
              bottom: 0,
              child: _LoveCardCreateStickyFooter(
                state: state,
                theme: theme,
                colors: colors,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _LoveCardCreateStickyFooter extends StatelessWidget {
  final _LoveCardScreenState state;
  final _LoveThemeData theme;
  final List<Color> colors;

  const _LoveCardCreateStickyFooter({
    required this.state,
    required this.theme,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0x00FFFFFF),
            colors.last.withValues(alpha: 0.82),
            Color.lerp(colors.last, colors.first, 0.18)!.withValues(alpha: 0.98),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Container(
        padding: EdgeInsets.fromLTRB(16, 14, 16, bottomInset + 10),
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
          ),
        ),
        child: _LoveCardSendAction(
          state: state,
          theme: theme,
          colors: colors,
        ),
      ),
    );
  }
}

class _LoveCardCreateHero extends StatelessWidget {
  final _LoveThemeData theme;

  const _LoveCardCreateHero({
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.send_and_archive_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Gửi thiệp yêu thương trực tiếp',
                  style: SLTheme.quicksand(
                    color: Colors.white,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Tạo liên kết riêng để chia sẻ nhanh cho người ấy xem trực tiếp.',
                  style: SLTheme.quicksand(
                    color: Colors.white.withValues(alpha: 0.72),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LoveCardThemePicker extends StatelessWidget {
  final _LoveCardScreenState state;

  const _LoveCardThemePicker({
    required this.state,
  });

  @override
  Widget build(BuildContext context) {
    final viewportWidth = MediaQuery.of(context).size.width;
    final cardWidth = max(168.0, min(190.0, ((viewportWidth - 60) / 2)));

    return SizedBox(
      height: 146,
      child: ListView.separated(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        itemCount: state._themes.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final entry = state._themes.entries.elementAt(index);
          final data = entry.value;
          final isSelected = state._selectedTheme == entry.key;
          final themeColors = state._themeColors(data.key);

          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => state._selectTheme(entry.key),
              borderRadius: BorderRadius.circular(28),
              child: Ink(
                width: cardWidth,
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      themeColors.first.withValues(alpha: isSelected ? 0.92 : 0.58),
                      themeColors.last.withValues(alpha: isSelected ? 0.88 : 0.46),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: isSelected
                        ? Colors.white.withValues(alpha: 0.56)
                        : Colors.white.withValues(alpha: 0.18),
                    width: isSelected ? 1.4 : 1,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: themeColors.first.withValues(alpha: 0.35),
                            blurRadius: 18,
                            spreadRadius: 1,
                            offset: const Offset(0, 8),
                          ),
                        ]
                      : null,
                ),
                child: Stack(
                  children: [
                    Positioned(
                      right: -6,
                      bottom: -10,
                      child: Icon(
                        data.accentIcon,
                        size: 44,
                        color: Colors.white.withValues(
                          alpha: isSelected ? 0.18 : 0.12,
                        ),
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            _LoveCardGlassIcon(icon: data.icon, size: 34),
                            const Spacer(),
                            if (isSelected)
                              const Icon(
                                Icons.check_circle_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                          ],
                        ),
                        const Spacer(),
                        Text(
                          data.chip,
                          style: SLTheme.quicksand(
                            color: Colors.white,
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          data.effectLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: SLTheme.quicksand(
                            color: Colors.white.withValues(alpha: 0.90),
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          data.subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: SLTheme.quicksand(
                            color: Colors.white.withValues(alpha: 0.78),
                            fontSize: 11,
                            height: 1.35,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _LoveCardPreviewPanel extends StatelessWidget {
  final _LoveCardScreenState state;
  final _LoveThemeData theme;
  final List<Color> colors;
  final bool fullBleed;

  const _LoveCardPreviewPanel({
    required this.state,
    required this.theme,
    required this.colors,
    this.fullBleed = false,
  });

  @override
  Widget build(BuildContext context) {
    final viewportWidth = MediaQuery.of(context).size.width;
    final panelHeight = min(max(viewportWidth * 0.92, 340.0), 450.0);
    const surfacePadding = EdgeInsets.all(20);
    const outerRadius = 28.0;

    return AnimatedBuilder(
      animation: state._flipAnim,
      builder: (context, child) {
        final angle = state._flipAnim.value * (pi * 0.9);

        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001)
            ..rotateY(angle),
          child: Container(
            width: double.infinity,
            height: panelHeight,
            padding: surfacePadding,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: colors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                stops: const [0.08, 0.92],
              ),
              borderRadius: BorderRadius.circular(outerRadius),
              border: Border.all(
                color: Colors.white,
                width: 2.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: colors.first.withValues(alpha: 0.15),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: IgnorePointer(
                    child: _LoveCardPreviewThemeDecor(
                      theme: theme,
                      colors: colors,
                    ),
                  ),
                ),
                Positioned(
                  top: 18,
                  left: 24,
                  right: 24,
                  child: IgnorePointer(
                    child: Container(
                      height: 1.2,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withValues(alpha: 0),
                            Colors.white.withValues(alpha: 0.55),
                            Colors.white.withValues(alpha: 0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: -12,
                  right: -8,
                  child: Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.13),
                    ),
                  ),
                ),
                Positioned(
                  bottom: -24,
                  left: -24,
                  child: Container(
                    width: 132,
                    height: 132,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.18),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(theme.icon, color: Colors.white, size: 15),
                              const SizedBox(width: 6),
                              Text(
                                theme.chip,
                                style: SLTheme.quicksand(
                                  color: Colors.white,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        Icon(
                          theme.accentIcon,
                          color: Colors.white.withValues(alpha: 0.74),
                          size: 20,
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    if (state._selectedImageBytes != null) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: AspectRatio(
                          aspectRatio: 16 / 9,
                          child: Image.memory(
                            state._selectedImageBytes!,
                            fit: BoxFit.cover,
                            filterQuality: FilterQuality.high,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
                    Text(
                      context.tr('util_xemtrcthip_44a482'),
                      style: SLTheme.quicksand(
                        color: Colors.white.withValues(alpha: 0.76),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    _LoveCardEffectPill(theme: theme),
                    const SizedBox(height: 8),
                    Expanded(
                      child: Text(
                        state._previewContent(),
                        style: GoogleFonts.parisienne(
                          color: Colors.white,
                          fontSize: fullBleed ? 30 : 28,
                          height: 1.38,
                          fontWeight: FontWeight.w700,
                          shadows: [
                            Shadow(
                              color: Colors.black.withValues(alpha: 0.18),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withValues(alpha: 0.16),
                            Colors.white.withValues(alpha: 0.08),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.18),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            alignment: Alignment.center,
                            child: Icon(
                              Icons.draw_rounded,
                              color: Colors.white.withValues(alpha: 0.86),
                              size: 16,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  state._resolveSenderName(),
                                  style: SLTheme.quicksand(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  state._resolveSignature(theme.key),
                                  style: SLTheme.quicksand(
                                    color: Colors.white.withValues(alpha: 0.74),
                                    fontSize: 12,
                                    height: 1.4,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
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
      },
    );
  }
}

class _LoveCardEffectPill extends StatelessWidget {
  final _LoveThemeData theme;

  const _LoveCardEffectPill({
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(theme.accentIcon, color: Colors.white, size: 14),
          const SizedBox(width: 5),
          Text(
            theme.effectLabel,
            overflow: TextOverflow.ellipsis,
            style: SLTheme.quicksand(
              color: Colors.white,
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _LoveCardPreviewThemeDecor extends StatelessWidget {
  final _LoveThemeData theme;
  final List<Color> colors;

  const _LoveCardPreviewThemeDecor({
    required this.theme,
    required this.colors,
  });

  Widget _buildAccent() {
    switch (theme.key) {
      case 'birthday':
        return Positioned(
          top: 64,
          right: 18,
          child: _LoveCardPreviewConfetti(
            baseColor: Colors.white.withValues(alpha: 0.80),
            accentColor: colors.first.withValues(alpha: 0.78),
          ),
        );
      case 'anniversary':
        return Positioned(
          top: 56,
          right: 16,
          child: _LoveCardPreviewHalo(
            size: 84,
            color: Colors.white.withValues(alpha: 0.24),
            accent: const Color(0xFFFFD98B).withValues(alpha: 0.70),
          ),
        );
      case 'miss':
        return Positioned(
          top: 54,
          right: 14,
          child: _LoveCardPreviewMoon(
            size: 70,
            color: Colors.white.withValues(alpha: 0.22),
            cutoutColor: colors.last.withValues(alpha: 0.94),
          ),
        );
      default:
        return Positioned(
          top: 58,
          right: 16,
          child: _LoveCardPreviewHeartCluster(
            color: Colors.white.withValues(alpha: 0.72),
            accent: colors.first.withValues(alpha: 0.82),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          bottom: 92,
          left: 20,
          child: _LoveCardPreviewRibbon(
            icon: theme.accentIcon,
            label: theme.effectLabel,
          ),
        ),
        _buildAccent(),
      ],
    );
  }
}

class _LoveCardPreviewRibbon extends StatelessWidget {
  final IconData icon;
  final String label;

  const _LoveCardPreviewRibbon({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white.withValues(alpha: 0.94), size: 14),
          const SizedBox(width: 7),
          Text(
            label,
            style: SLTheme.quicksand(
              color: Colors.white.withValues(alpha: 0.94),
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _LoveCardPreviewHeartCluster extends StatelessWidget {
  final Color color;
  final Color accent;

  const _LoveCardPreviewHeartCluster({
    required this.color,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 92,
      height: 74,
      child: Stack(
        children: [
          Positioned(
            right: 8,
            top: 10,
            child: Icon(Icons.favorite_rounded, color: accent, size: 28),
          ),
          Positioned(
            left: 8,
            bottom: 6,
            child: Icon(Icons.favorite_border_rounded, color: color, size: 22),
          ),
          Positioned(
            left: 30,
            top: 0,
            child: Icon(Icons.auto_awesome_rounded, color: color, size: 18),
          ),
          Positioned(
            right: 0,
            bottom: 14,
            child: Icon(Icons.auto_awesome_rounded, color: color, size: 16),
          ),
        ],
      ),
    );
  }
}

class _LoveCardPreviewConfetti extends StatelessWidget {
  final Color baseColor;
  final Color accentColor;

  const _LoveCardPreviewConfetti({
    required this.baseColor,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 90,
      height: 76,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 14,
            child: Transform.rotate(
              angle: 0.34,
              child: _LoveCardPreviewConfettiBar(
                width: 18,
                height: 5,
                color: baseColor,
              ),
            ),
          ),
          Positioned(
            left: 24,
            top: 0,
            child: Transform.rotate(
              angle: -0.34,
              child: _LoveCardPreviewConfettiBar(
                width: 12,
                height: 12,
                color: accentColor,
                isRound: true,
              ),
            ),
          ),
          Positioned(
            right: 16,
            top: 12,
            child: Transform.rotate(
              angle: 0.48,
              child: _LoveCardPreviewConfettiBar(
                width: 18,
                height: 5,
                color: accentColor,
              ),
            ),
          ),
          Positioned(
            right: 0,
            bottom: 10,
            child: Transform.rotate(
              angle: -0.54,
              child: _LoveCardPreviewConfettiBar(
                width: 10,
                height: 10,
                color: baseColor,
                isRound: true,
              ),
            ),
          ),
          Positioned(
            left: 32,
            bottom: 0,
            child: Transform.rotate(
              angle: 0.22,
              child: _LoveCardPreviewConfettiBar(
                width: 24,
                height: 6,
                color: baseColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoveCardPreviewConfettiBar extends StatelessWidget {
  final double width;
  final double height;
  final Color color;
  final bool isRound;

  const _LoveCardPreviewConfettiBar({
    required this.width,
    required this.height,
    required this.color,
    this.isRound = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(isRound ? width : 999),
      ),
    );
  }
}

class _LoveCardPreviewHalo extends StatelessWidget {
  final double size;
  final Color color;
  final Color accent;

  const _LoveCardPreviewHalo({
    required this.size,
    required this.color,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: color, width: 2),
            ),
          ),
          Container(
            width: size * 0.70,
            height: size * 0.70,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: accent, width: 1.5),
            ),
          ),
          Icon(Icons.auto_awesome_rounded, color: accent, size: size * 0.22),
        ],
      ),
    );
  }
}

class _LoveCardPreviewMoon extends StatelessWidget {
  final double size;
  final Color color;
  final Color cutoutColor;

  const _LoveCardPreviewMoon({
    required this.size,
    required this.color,
    required this.cutoutColor,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
            ),
          ),
          Positioned(
            right: size * 0.06,
            top: size * 0.08,
            child: Container(
              width: size * 0.72,
              height: size * 0.72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: cutoutColor,
              ),
            ),
          ),
          Positioned(
            left: 8,
            top: 8,
            child: Icon(
              Icons.star_rounded,
              size: size * 0.16,
              color: Colors.white.withValues(alpha: 0.44),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoveCardComposerPanel extends StatelessWidget {
  final _LoveCardScreenState state;
  final _LoveThemeData theme;
  final List<Color> colors;

  const _LoveCardComposerPanel({
    required this.state,
    required this.theme,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colors.first.withValues(alpha: 0.14),
            colors.last.withValues(alpha: 0.06),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.16),
        ),
        boxShadow: [
          BoxShadow(
            color: colors.first.withValues(alpha: 0.08),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Soạn thảo thiệp',
            style: SLTheme.quicksand(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            theme.subtitle,
            style: SLTheme.quicksand(
              color: Colors.white.withValues(alpha: 0.72),
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          _LoveCardMetaField(
            label: context.tr('util_tnhinth_6cccad'),
            hintText: state._defaultSenderName(),
            controller: state._senderNameCtrl,
            icon: Icons.favorite_border_rounded,
            onChanged: (_) => state._refreshUi(),
          ),
          const SizedBox(height: 10),
          _LoveCardMetaField(
            label: context.tr('util_dngkghich_b5c3f9'),
            hintText: state._defaultSignatureForTheme(theme.key),
            controller: state._signatureCtrl,
            icon: Icons.auto_awesome_rounded,
            minLines: 2,
            maxLines: 2,
            onChanged: (_) => state._refreshUi(),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.16),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.chat_bubble_outline_rounded,
                      color: Colors.white.withValues(alpha: 0.7),
                      size: 14,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        context.tr('util_vitnidungt_69403f'),
                        style: SLTheme.quicksand(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                TextField(
                  controller: state._contentCtrl,
                  maxLines: 4,
                  maxLength: 500,
                  cursorColor: Colors.white,
                  onChanged: (_) => state._refreshUi(),
                  style: SLTheme.quicksand(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    height: 1.45,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: context.tr('util_vitiubnmun_f241e9'),
                    hintStyle: SLTheme.quicksand(
                      color: Colors.white.withValues(alpha: 0.36),
                      fontWeight: FontWeight.w600,
                    ),
                    counterStyle: SLTheme.quicksand(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 6),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _LoveCardImageAttachmentPanel(
            state: state,
            theme: theme,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                Icons.lightbulb_rounded,
                color: Colors.amber.shade200,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  context.tr('util_monidungng_755e07'),
                  style: SLTheme.quicksand(
                    color: Colors.white.withValues(alpha: 0.72),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LoveCardMetaField extends StatelessWidget {
  final String label;
  final String hintText;
  final TextEditingController controller;
  final IconData icon;
  final ValueChanged<String> onChanged;
  final int minLines;
  final int maxLines;

  const _LoveCardMetaField({
    required this.label,
    required this.hintText,
    required this.controller,
    required this.icon,
    required this.onChanged,
    this.minLines = 1,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.16),
          width: 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white.withValues(alpha: 0.7), size: 14),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: SLTheme.quicksand(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          TextField(
            controller: controller,
            minLines: minLines,
            maxLines: maxLines,
            cursorColor: Colors.white,
            onChanged: onChanged,
            textAlignVertical: TextAlignVertical.center,
            style: SLTheme.quicksand(
              color: Colors.white,
              fontSize: 15,
              height: 1.35,
              fontWeight: FontWeight.w800,
            ),
            decoration: InputDecoration(
              isDense: true,
              hintText: hintText,
              hintStyle: SLTheme.quicksand(
                color: Colors.white.withValues(alpha: 0.36),
                fontWeight: FontWeight.w600,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 6),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoveCardImageAttachmentPanel extends StatelessWidget {
  final _LoveCardScreenState state;
  final _LoveThemeData theme;

  const _LoveCardImageAttachmentPanel({
    required this.state,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage = state._selectedImageBytes != null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: hasImage ? null : state._pickCardImage,
        borderRadius: BorderRadius.circular(26),
        child: Ink(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: hasImage
              ? Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: SizedBox(
                        width: 68,
                        height: 68,
                        child: Image.memory(
                          state._selectedImageBytes!,
                          fit: BoxFit.cover,
                          filterQuality: FilterQuality.high,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.tr('util_thipskmnhk_d2a84e'),
                            style: SLTheme.quicksand(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 13.5,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            context.tr('util_nginhnsthy_de894b'),
                            style: SLTheme.quicksand(
                              color: Colors.white.withValues(alpha: 0.70),
                              fontWeight: FontWeight.w600,
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: state._clearSelectedImage,
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                      ),
                    ),
                  ],
                )
              : Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.10),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        state._isPickingImage
                            ? Icons.hourglass_top_rounded
                            : Icons.add_photo_alternate_rounded,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            state._isPickingImage
                                ? context.tr('util_angchnnh_aa478d')
                                : context.tr('util_thmnhchoth_4d9184'),
                            style: SLTheme.quicksand(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 13.5,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Ảnh sẽ xuất hiện trong trang thiệp khi mở liên kết ${theme.chip.toLowerCase()}.',
                            style: SLTheme.quicksand(
                              color: Colors.white.withValues(alpha: 0.68),
                              fontWeight: FontWeight.w600,
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _LoveCardSendAction extends StatelessWidget {
  final _LoveCardScreenState state;
  final _LoveThemeData theme;
  final List<Color> colors;

  const _LoveCardSendAction({
    required this.state,
    required this.theme,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final enabled =
        state._contentCtrl.text.trim().isNotEmpty && !state._isSending;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 180),
      opacity: enabled ? 1 : 0.72,
      child: IgnorePointer(
        ignoring: !enabled,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFFFFF7FB),
                Colors.white.withValues(alpha: 0.92),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.65),
            ),
            boxShadow: [
              BoxShadow(
                color: colors.first.withValues(alpha: 0.22),
                blurRadius: 22,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: state._sendCard,
              borderRadius: BorderRadius.circular(28),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (state._isSending)
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Color(theme.colors.first),
                          ),
                        ),
                      )
                    else
                      Icon(
                        Icons.send_rounded,
                        color: Color(theme.colors.first),
                        size: 20,
                      ),
                    const SizedBox(width: 10),
                    Text(
                      state._isSending
                          ? context.tr('util_angtothip_573c10')
                          : context.tr('util_githipvtol_f437a3'),
                      style: SLTheme.quicksand(
                        color: Color(theme.colors.first),
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
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
