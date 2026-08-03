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
        final bottomInset = MediaQuery.paddingOf(context).bottom;

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
                      fontWeight: FontWeight.w900,
                      shadows: [
                        Shadow(
                          color: theme.colors.last != 0
                              ? Color(theme.colors.last).withValues(alpha: 0.3)
                              : Colors.black.withValues(alpha: 0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                _LoveCardThemePicker(state: state),
                const SizedBox(height: 24),
                Padding(
                  padding:
                      EdgeInsets.symmetric(horizontal: compactWidth ? 16 : 20),
                  child: Text(
                    'Xem trước thiệp',
                    style: SLTheme.quicksand(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      shadows: [
                        Shadow(
                          color: theme.colors.last != 0
                              ? Color(theme.colors.last).withValues(alpha: 0.3)
                              : Colors.black.withValues(alpha: 0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding:
                      EdgeInsets.symmetric(horizontal: compactWidth ? 16 : 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(left: 4, bottom: 6),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '📸 Thiệp sẽ hiển thị như thế này. Nhấn để xem toàn màn hình.',
                          style: SLTheme.quicksand(
                            color: Colors.amber.shade200,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      RepaintBoundary(
                        child: GestureDetector(
                          onTap: () => state._showFullScreenPreview(
                              context, theme, colors),
                          child: _LoveCardPreviewPanel(
                            state: state,
                            theme: theme,
                            colors: colors,
                            fullBleed: false,
                          ),
                        ),
                      ),
                    ],
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
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0x00FFFFFF),
            colors.last.withValues(alpha: 0.82),
            Color.lerp(colors.last, colors.first, 0.18)!
                .withValues(alpha: 0.98),
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
        color: Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white),
        boxShadow: [
          BoxShadow(
            color: Color(theme.colors.last).withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Color(theme.colors.first).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.send_and_archive_rounded,
              color: Color(theme.colors.first),
              size: 22,
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
                    color: SLColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Tạo liên kết riêng để chia sẻ nhanh cho người ấy xem trực tiếp.',
                  style: SLTheme.quicksand(
                    color: SLColors.textSecondary,
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
    final viewportWidth = MediaQuery.sizeOf(context).width;
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
                  color: Colors.white.withValues(alpha: 0.98),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: isSelected ? themeColors.first : Colors.white,
                    width: isSelected ? 2.5 : 1.0,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: themeColors.first.withValues(alpha: 0.3),
                            blurRadius: 12,
                            spreadRadius: 1,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : [
                          BoxShadow(
                            color: themeColors.last.withValues(alpha: 0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                ),
                child: Stack(
                  children: [
                    Positioned(
                      right: -6,
                      bottom: -10,
                      child: Icon(
                        data.accentIcon,
                        size: 44,
                        color: isSelected
                            ? themeColors.first.withValues(alpha: 0.2)
                            : themeColors.first.withValues(alpha: 0.1),
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
                                shape: BoxShape.circle,
                                color:
                                    themeColors.first.withValues(alpha: 0.15),
                              ),
                              child: Icon(
                                data.icon,
                                color: themeColors.first,
                                size: 16,
                              ),
                            ),
                            const Spacer(),
                            if (isSelected)
                              Icon(
                                Icons.check_circle_rounded,
                                color: themeColors.first,
                                size: 20,
                              ),
                          ],
                        ),
                        const Spacer(),
                        Text(
                          data.chip,
                          style: SLTheme.quicksand(
                            color: isSelected
                                ? themeColors.first
                                : SLColors.textPrimary,
                            fontSize: 14.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          data.effectLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: SLTheme.quicksand(
                            color: isSelected
                                ? themeColors.first.withValues(alpha: 0.8)
                                : themeColors.first,
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
                            color: SLColors.textSecondary,
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
    final viewportWidth = MediaQuery.sizeOf(context).width;
    final panelHeight = min(max(viewportWidth * 0.92, 340.0), 450.0);
    const surfacePadding = EdgeInsets.all(20);
    const outerRadius = 28.0;

    return AnimatedBuilder(
      animation: state._flipAnim,
      child: Container(
        width: double.infinity,
        height: panelHeight,
        padding: surfacePadding,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.98),
          borderRadius: BorderRadius.circular(outerRadius),
          border: Border.all(
            color: Color(theme.colors.first).withValues(alpha: 0.6),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Color(theme.colors.last).withValues(alpha: 0.25),
              blurRadius: 16,
              spreadRadius: -2,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 6,
              offset: const Offset(0, 2),
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
                        Color(theme.colors.first).withValues(alpha: 0),
                        Color(theme.colors.first).withValues(alpha: 0.3),
                        Color(theme.colors.first).withValues(alpha: 0),
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
                  color: Color(theme.colors.first).withValues(alpha: 0.05),
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
                  color: Color(theme.colors.last).withValues(alpha: 0.05),
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
                        color: Color(theme.colors.first).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color:
                              Color(theme.colors.first).withValues(alpha: 0.15),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(theme.icon,
                              color: Color(theme.colors.first), size: 15),
                          const SizedBox(width: 6),
                          Text(
                            theme.chip,
                            style: SLTheme.quicksand(
                              color: Color(theme.colors.first),
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
                      color: Color(theme.colors.first).withValues(alpha: 0.5),
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
                        filterQuality: FilterQuality.medium,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
                Text(
                  context.tr('util_xemtrcthip_44a482'),
                  style: SLTheme.quicksand(
                    color: SLColors.textSecondary,
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
                      color: SLColors.textPrimary,
                      fontSize: fullBleed ? 30 : 28,
                      height: 1.38,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.black.withValues(alpha: 0.06),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.draw_rounded,
                          color: SLColors.textSecondary,
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
                                color: SLColors.textPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              state._resolveSignature(theme.key),
                              style: SLTheme.quicksand(
                                color: SLColors.textSecondary,
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
      builder: (context, child) {
        final angle = state._flipAnim.value * (pi * 0.9);

        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001)
            ..rotateY(angle),
          child: child,
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
        color: Color(theme.colors.first).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
            color: Color(theme.colors.first).withValues(alpha: 0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(theme.accentIcon, color: Color(theme.colors.first), size: 14),
          const SizedBox(width: 5),
          Text(
            theme.effectLabel,
            overflow: TextOverflow.ellipsis,
            style: SLTheme.quicksand(
              color: Color(theme.colors.first),
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
            baseColor: colors.last.withValues(alpha: 0.3),
            accentColor: colors.first.withValues(alpha: 0.6),
          ),
        );
      case 'anniversary':
        return Positioned(
          top: 56,
          right: 16,
          child: _LoveCardPreviewHalo(
            size: 84,
            color: colors.first.withValues(alpha: 0.1),
            accent: const Color(0xFFFFD98B).withValues(alpha: 0.70),
          ),
        );
      case 'miss':
        return Positioned(
          top: 54,
          right: 14,
          child: _LoveCardPreviewMoon(
            size: 70,
            color: colors.first.withValues(alpha: 0.15),
            cutoutColor: colors.last.withValues(alpha: 0.8),
          ),
        );
      default:
        return Positioned(
          top: 58,
          right: 16,
          child: _LoveCardPreviewHeartCluster(
            color: colors.first.withValues(alpha: 0.3),
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
        color: Colors.black.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              color: SLColors.textPrimary.withValues(alpha: 0.8), size: 14),
          const SizedBox(width: 7),
          Text(
            label,
            style: SLTheme.quicksand(
              color: SLColors.textPrimary.withValues(alpha: 0.8),
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
      clipBehavior: Clip.antiAlias,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.98),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: colors.first.withValues(alpha: 0.35),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: colors.last.withValues(alpha: 0.15),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      colors.first.withValues(alpha: 0.30),
                      colors.last.withValues(alpha: 0.15)
                    ],
                  ),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Soạn thảo thiệp',
                  style: SLTheme.quicksand(
                    color: colors.first,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            theme.subtitle,
            style: SLTheme.quicksand(
              color: SLColors.textSecondary,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          _LoveCardMetaField(
            label: context.tr('util_tnhinth_6cccad'),
            hintText: state._defaultSenderName(),
            controller: state._senderNameCtrl,
            icon: Icons.favorite_border_rounded,
            themeColors: colors,
            maxLength: 30,
            onChanged: (_) => state._refreshUi(),
          ),
          const SizedBox(height: 10),
          _LoveCardMetaField(
            label: context.tr('util_dngkghich_b5c3f9'),
            hintText: state._defaultSignatureForTheme(theme.key),
            controller: state._signatureCtrl,
            icon: Icons.auto_awesome_rounded,
            themeColors: colors,
            minLines: 2,
            maxLines: 2,
            maxLength: 100,
            onChanged: (_) => state._refreshUi(),
          ),
          RepaintBoundary(
            child: _LoveCardContentEditor(
              controller: state._contentCtrl,
              theme: theme,
              colors: colors,
              onChanged: () => state._refreshUi(),
              hintText: context.tr('util_vitiubnmun_f241e9'),
              suggestions: theme.suggestions,
              onSuggestionTap: (text) {
                state._contentCtrl.text = text;
                state._refreshUi();
              },
            ),
          ),
          const SizedBox(height: 12),
          _LoveCardImageAttachmentPanel(
            state: state,
            theme: theme,
          ),
        ],
      ),
    );
  }
}

class _LoveCardMetaField extends StatefulWidget {
  final String label;
  final String hintText;
  final TextEditingController controller;
  final IconData icon;
  final ValueChanged<String> onChanged;
  final int minLines;
  final int maxLines;
  final List<Color>? themeColors;
  final int? maxLength;

  const _LoveCardMetaField({
    required this.label,
    required this.hintText,
    required this.controller,
    required this.icon,
    required this.onChanged,
    this.minLines = 1,
    this.maxLines = 1,
    this.themeColors,
    this.maxLength,
  });

  @override
  State<_LoveCardMetaField> createState() => _LoveCardMetaFieldState();
}

class _LoveCardMetaFieldState extends State<_LoveCardMetaField> {
  final _focusNode = FocusNode();
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      setState(() => _isFocused = _focusNode.hasFocus);
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = widget.themeColors?.first ?? Colors.white;

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: FastBackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
          decoration: BoxDecoration(
            color: _isFocused
                ? Colors.white.withValues(alpha: 0.98)
                : Colors.white.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: _isFocused
                  ? primaryColor.withValues(alpha: 0.55)
                  : Colors.white,
              width: _isFocused ? 1.8 : 1.0,
            ),
            boxShadow: _isFocused
                ? [
                    BoxShadow(
                      color: primaryColor.withValues(alpha: 0.25),
                      blurRadius: 16,
                      spreadRadius: 2,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    )
                  ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      widget.icon,
                      color: _isFocused ? primaryColor : SLColors.textSecondary,
                      size: 14,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 200),
                      style: SLTheme.quicksand(
                        color: _isFocused
                            ? primaryColor.withValues(alpha: 0.95)
                            : SLColors.textSecondary,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                      ),
                      child: Text(widget.label),
                    ),
                  ),
                  if (_isFocused)
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: primaryColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 2),
              TextField(
                controller: widget.controller,
                focusNode: _focusNode,
                minLines: widget.minLines,
                maxLines: widget.maxLines,
                maxLength: widget.maxLength,
                cursorColor: primaryColor,
                onChanged: widget.onChanged,
                textAlignVertical: TextAlignVertical.center,
                style: SLTheme.quicksand(
                  color: SLColors.textPrimary,
                  fontSize: 15,
                  height: 1.35,
                  fontWeight: FontWeight.w800,
                ),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: widget.hintText,
                  hintStyle: SLTheme.quicksand(
                    color: SLColors.textSecondary.withValues(alpha: 0.5),
                    fontWeight: FontWeight.w600,
                  ),
                  border: InputBorder.none,
                  counterText: '',
                  contentPadding: const EdgeInsets.symmetric(vertical: 6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoveCardContentEditor extends StatefulWidget {
  final TextEditingController controller;
  final _LoveThemeData theme;
  final List<Color> colors;
  final VoidCallback onChanged;
  final String hintText;
  final List<String> suggestions;
  final ValueChanged<String> onSuggestionTap;

  const _LoveCardContentEditor({
    required this.controller,
    required this.theme,
    required this.colors,
    required this.onChanged,
    required this.hintText,
    required this.suggestions,
    required this.onSuggestionTap,
  });

  @override
  State<_LoveCardContentEditor> createState() => _LoveCardContentEditorState();
}

class _LoveCardContentEditorState extends State<_LoveCardContentEditor>
    with SingleTickerProviderStateMixin {
  final _focusNode = FocusNode();
  bool _isFocused = false;
  late AnimationController _glowCtrl;
  late Animation<double> _glowAnim;

  @override
  void initState() {
    super.initState();
    _focusNode
        .addListener(() => setState(() => _isFocused = _focusNode.hasFocus));
    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _glowAnim = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _glowCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primary = widget.colors.first;
    final accent = widget.colors.last;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: BoxDecoration(
        color: _isFocused
            ? Colors.white.withValues(alpha: 0.98)
            : Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: _isFocused ? primary.withValues(alpha: 0.50) : Colors.white,
          width: _isFocused ? 1.8 : 1.0,
        ),
        boxShadow: _isFocused
            ? [
                BoxShadow(
                  color: primary.withValues(alpha: 0.25),
                  blurRadius: 16,
                  spreadRadius: 2,
                  offset: const Offset(0, 4),
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  Icons.chat_bubble_outline_rounded,
                  color: _isFocused ? primary : SLColors.textSecondary,
                  size: 14,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 200),
                  style: SLTheme.quicksand(
                    color: _isFocused
                        ? primary.withValues(alpha: 0.95)
                        : SLColors.textSecondary,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                  ),
                  child: Text(context.tr('util_vitnidungt_69403f')),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          TextField(
            controller: widget.controller,
            focusNode: _focusNode,
            maxLines: 4,
            maxLength: 500,
            cursorColor: primary,
            onChanged: (_) => widget.onChanged(),
            style: SLTheme.quicksand(
              color: SLColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w700,
              height: 1.45,
            ),
            decoration: InputDecoration(
              isDense: true,
              hintText: widget.hintText,
              hintStyle: SLTheme.quicksand(
                color: SLColors.textSecondary.withValues(alpha: 0.5),
                fontWeight: FontWeight.w600,
              ),
              counterStyle: SLTheme.quicksand(
                color: SLColors.textSecondary.withValues(alpha: 0.5),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 6),
            ),
          ),
          if (_isFocused && widget.suggestions.isNotEmpty) ...[
            const SizedBox(height: 8),
            AnimatedBuilder(
              animation: _glowAnim,
              builder: (context, _) {
                return Container(
                  height: 1.5,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        primary.withValues(alpha: _glowAnim.value * 0.6),
                        accent.withValues(alpha: _glowAnim.value * 0.4),
                        primary.withValues(alpha: _glowAnim.value * 0.6),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: widget.suggestions.map((s) {
                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => widget.onSuggestionTap(s),
                    borderRadius: BorderRadius.circular(999),
                    child: Ink(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            primary.withValues(alpha: 0.20),
                            accent.withValues(alpha: 0.14),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: primary.withValues(alpha: 0.25),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        s,
                        style: SLTheme.quicksand(
                          color: primary,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
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
            color: Colors.white.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: Colors.white),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            ],
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
                          filterQuality: FilterQuality.medium,
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
                              color: SLColors.textPrimary,
                              fontWeight: FontWeight.w800,
                              fontSize: 13.5,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            context.tr('util_nginhnsthy_de894b'),
                            style: SLTheme.quicksand(
                              color: SLColors.textSecondary,
                              fontWeight: FontWeight.w600,
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: state._clearSelectedImage,
                      icon: Icon(
                        Icons.close_rounded,
                        color: Color(theme.colors.first),
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
                        color:
                            Color(theme.colors.first).withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        state._isPickingImage
                            ? Icons.hourglass_top_rounded
                            : Icons.add_photo_alternate_rounded,
                        color: Color(theme.colors.first),
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
                              color: SLColors.textPrimary,
                              fontWeight: FontWeight.w800,
                              fontSize: 13.5,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Ảnh sẽ xuất hiện trong trang thiệp khi mở liên kết ${theme.chip.toLowerCase()}.',
                            style: SLTheme.quicksand(
                              color: SLColors.textSecondary,
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
                        color: SLColors.textPrimary,
                        size: 20,
                      ),
                    const SizedBox(width: 10),
                    Text(
                      state._isSending
                          ? context.tr('util_angtothip_573c10')
                          : context.tr('util_githipvtol_f437a3'),
                      style: SLTheme.quicksand(
                        color: SLColors.textPrimary,
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
