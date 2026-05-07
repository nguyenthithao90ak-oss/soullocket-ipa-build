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
                    'Chọn phong cách thiệp',
                    style: SLTheme.quicksand(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                _LoveCardThemePicker(state: state),
                const SizedBox(height: 16),
                _LoveCardPreviewPanel(
                  state: state,
                  theme: theme,
                  colors: colors,
                  fullBleed: true,
                ),
                const SizedBox(height: 16),
                _LoveCardComposerPanel(
                  state: state,
                  theme: theme,
                ),
                const SizedBox(height: 10),
                Padding(
                  padding:
                      EdgeInsets.symmetric(horizontal: compactWidth ? 16 : 20),
                  child: Text(
                    'Sau khi gửi, app sẽ tự tạo link mới để bạn chia sẻ ngay.',
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
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0.18),
            Colors.white.withValues(alpha: 0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.16)),
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.16)),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            right: -14,
            top: -14,
            child: Icon(
              theme.accentIcon,
              size: 96,
              color: Colors.white.withValues(alpha: 0.08),
            ),
          ),
          Positioned(
            right: 4,
            bottom: -4,
            child: Icon(
              Icons.link_rounded,
              size: 82,
              color: Colors.white.withValues(alpha: 0.07),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const _LoveCardGlassIcon(
                    icon: Icons.auto_awesome_rounded,
                    size: 34,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Thiệp đẹp hơn, xem ngay bằng link',
                          style: SLTheme.quicksand(
                            color: Colors.white,
                            fontSize: 16.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          theme.title,
                          style: SLTheme.quicksand(
                            color: Colors.white.withValues(alpha: 0.72),
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Người nhận chỉ cần mở liên kết là thấy ngay thiệp của bạn, không cần vào lại màn hình này.',
                style: SLTheme.quicksand(
                  color: Colors.white.withValues(alpha: 0.82),
                  fontSize: 13,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              const Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _LoveCardHeroChip(
                    icon: Icons.link_rounded,
                    label: 'Tạo link riêng',
                  ),
                  _LoveCardHeroChip(
                    icon: Icons.visibility_rounded,
                    label: 'Mở là xem ngay',
                  ),
                  _LoveCardHeroChip(
                    icon: Icons.history_rounded,
                    label: 'Lưu lại lịch sử',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.13),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: const Icon(
                        Icons.ios_share_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Gửi xong app tự tạo link công khai và copy sẵn để bạn chia sẻ.',
                        style: SLTheme.quicksand(
                          color: Colors.white.withValues(alpha: 0.78),
                          fontSize: 12.5,
                          height: 1.35,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
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
              borderRadius: BorderRadius.circular(24),
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
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isSelected
                        ? Colors.white.withValues(alpha: 0.56)
                        : Colors.white.withValues(alpha: 0.18),
                    width: isSelected ? 1.4 : 1,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: themeColors.first.withValues(alpha: 0.28),
                            blurRadius: 22,
                            offset: const Offset(0, 14),
                          ),
                        ]
                      : null,
                ),
                child: Stack(
                  children: [
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
    final panelHeight =
        fullBleed ? min(max(viewportWidth * 0.94, 348.0), 480.0) : 300.0;
    final surfacePadding = fullBleed
        ? const EdgeInsets.fromLTRB(20, 24, 20, 22)
        : const EdgeInsets.all(24);
    final outerRadius = fullBleed ? 0.0 : 32.0;

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
                color: Colors.white.withValues(alpha: 0.30),
                width: 1.3,
              ),
              boxShadow: [
                BoxShadow(
                  color: colors.first.withValues(alpha: 0.26),
                  blurRadius: fullBleed ? 42 : 34,
                  offset: Offset(0, fullBleed ? 26 : 22),
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
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
                    Text(
                      'Xem trước thiệp',
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

  const _LoveCardComposerPanel({
    required this.state,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0.18),
            Colors.white.withValues(alpha: 0.09),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.16)),
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.16)),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Viết nội dung thiệp',
            style: SLTheme.quicksand(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            theme.subtitle,
            style: SLTheme.quicksand(
              color: Colors.white.withValues(alpha: 0.72),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          _LoveCardMetaField(
            label: 'Tên hiển thị',
            hintText: state._defaultSenderName(),
            controller: state._senderNameCtrl,
            icon: Icons.favorite_border_rounded,
            onChanged: (_) => state._refreshUi(),
          ),
          const SizedBox(height: 10),
          _LoveCardMetaField(
            label: 'Dòng ký / ghi chú',
            hintText: state._defaultSignatureForTheme(theme.key),
            controller: state._signatureCtrl,
            icon: Icons.auto_awesome_rounded,
            minLines: 2,
            maxLines: 2,
            onChanged: (_) => state._refreshUi(),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white.withValues(alpha: 0.96),
                  const Color(0xFFFFF7FB),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: const Color(0xFFFFB4C7).withValues(alpha: 0.75),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: TextField(
              controller: state._contentCtrl,
              maxLines: 5,
              maxLength: 500,
              cursorColor: const Color(0xFFD81B60),
              onChanged: (_) => state._refreshUi(),
              style: SLTheme.quicksand(
                color: const Color(0xFF243041),
                fontSize: 15.5,
                fontWeight: FontWeight.w700,
                height: 1.45,
              ),
              decoration: InputDecoration(
                hintText:
                    'Viết điều bạn muốn nói thật ngắn gọn nhưng đủ chạm...',
                hintStyle: SLTheme.quicksand(
                  color: const Color(0xFFB55A73),
                  fontWeight: FontWeight.w600,
                ),
                counterStyle: SLTheme.quicksand(
                  color: const Color(0xFFB55A73),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              ),
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
                  'Mẹo: nội dung ngắn, rõ và chân thành sẽ lên thiệp đẹp hơn.',
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
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0xFFFF8AA0).withValues(alpha: 0.32),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(icon, color: const Color(0xFFD94D73), size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontFamily: 'Quicksand',
                    color: Color(0xFF8D4563),
                    fontSize: 12,
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
            cursorColor: const Color(0xFFD81B60),
            onChanged: onChanged,
            textAlignVertical: TextAlignVertical.center,
            style: TextStyle(
              fontFamily: 'Quicksand',
              color: const Color(0xFF243041),
              fontSize: 15.5,
              height: 1.4,
              fontWeight: FontWeight.w800,
            ),
            decoration: InputDecoration(
              isDense: true,
              hintText: hintText,
              hintStyle: TextStyle(
                fontFamily: 'Quicksand',
                color: const Color(0xFFB55A73).withValues(alpha: 0.6),
                fontWeight: FontWeight.w600,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
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
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(22),
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
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Thiệp sẽ kèm ảnh khi mở link',
                            style: SLTheme.quicksand(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 13.5,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Người nhận sẽ thấy ảnh nằm trong thiệp công khai.',
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
                                ? 'Đang chọn ảnh...'
                                : 'Thêm ảnh cho thiệp',
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
            borderRadius: BorderRadius.circular(24),
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
              borderRadius: BorderRadius.circular(24),
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
                          ? 'Đang tạo thiệp...'
                          : 'Gửi thiệp và tạo link mới',
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
