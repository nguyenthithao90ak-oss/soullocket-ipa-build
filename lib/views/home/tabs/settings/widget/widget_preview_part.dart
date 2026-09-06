part of '../../settings_tab.dart';

extension _SettingsTabWidgetPreviewPart on _SettingsTabState {
  ({List<Color> colors, Color textColor, Color borderColor, bool premium})
  _widgetPreviewThemeSpec(String themeKey) {
    switch (themeKey) {
      case 'dark':
        return (
          colors: const [
            Color(0xFF0F172A),
            Color(0xFF1E1E38),
            Color(0xFF0F172A),
          ],
          textColor: Colors.white,
          borderColor: const Color(0xFF475569),
          premium: false,
        );
      case 'white':
        return (
          colors: const [
            Color(0xFFFFFFFF),
            Color(0xFFF8FAFC),
            Color(0xFFF1F5F9),
          ],
          textColor: const Color(0xFF1F2937),
          borderColor: const Color(0xFFE2E8F0),
          premium: false,
        );
      case 'blue':
        return (
          colors: const [
            Color(0xFFE0F2FE),
            Color(0xFFBAE6FD),
            Color(0xFF7DD3FC),
          ],
          textColor: const Color(0xFF0F3D7A),
          borderColor: const Color(0xFF93C5FD),
          premium: false,
        );
      case 'orange':
        return (
          colors: const [
            Color(0xFFFEF3C7),
            Color(0xFFFDBA74),
            Color(0xFFF97316),
          ],
          textColor: const Color(0xFF7C2D12),
          borderColor: const Color(0xFFFDBA74),
          premium: false,
        );
      case 'purple':
        return (
          colors: const [Color(0xFFCE93D8), Color(0xFF6A1B9A)],
          textColor: Colors.white,
          borderColor: const Color(0xFFCE93D8),
          premium: false,
        );
      case 'green':
        return (
          colors: const [
            Color(0xFFECFDF5),
            Color(0xFFA7F3D0),
            Color(0xFF6EE7B7),
          ],
          textColor: const Color(0xFF065F46),
          borderColor: const Color(0xFF86EFAC),
          premium: false,
        );
      case 'red':
        return (
          colors: const [
            Color(0xFFFFF5F5),
            Color(0xFFFED7D7),
            Color(0xFFFB7185),
          ],
          textColor: const Color(0xFF9F1239),
          borderColor: const Color(0xFFFCA5A5),
          premium: false,
        );
      case 'premium':
        return (
          colors: const [
            Color(0xFFFF5FA2),
            Color(0xFFFFB86B),
            Color(0xFF67E8F9),
            Color(0xFF7C3AED),
          ],
          textColor: Colors.white,
          borderColor: const Color(0xFFFFD166),
          premium: true,
        );
      case 'cosmic':
        return (
          colors: const [
            Color(0xFF0F0C20),
            Color(0xFF15102A),
            Color(0xFF1F1A3A),
          ],
          textColor: const Color(0xFFFFD700),
          borderColor: const Color(0xFFFFD700),
          premium: true,
        );
      case 'pink':
      default:
        return (
          colors: const [Color(0xFFFFB6CA), Color(0xFFFF7098)],
          textColor: Colors.white,
          borderColor: const Color(0xFFFFB6CA),
          premium: false,
        );
    }
  }

  List<Color> _widgetHeartPalette(String colorKey) {
    switch (colorKey) {
      case 'ruby':
        return const [Color(0xFFFF5E7E), Color(0xFFFF85A1), Color(0xFFFFE3EA)];
      case 'violet':
        return const [Color(0xFF8B5CF6), Color(0xFFC084FC), Color(0xFFF3E8FF)];
      case 'ocean':
        return const [Color(0xFF0EA5E9), Color(0xFF67E8F9), Color(0xFFE0F2FE)];
      case 'sunset':
        return const [Color(0xFFF97316), Color(0xFFFBBF24), Color(0xFFFFEDD5)];
      case 'gold':
        return const [Color(0xFFEAB308), Color(0xFFFDE68A), Color(0xFFFFFBEB)];
      case 'rose':
      default:
        return const [Color(0xFFFF4D73), Color(0xFFFF8FB1), Color(0xFFFFE4EC)];
    }
  }

  Widget _buildWidgetDiaryPreview(
    Color textColor, {
    double width = 56,
    double height = 84,
  }) {
    if (!_showDiaryOnWidget) {
      return const SizedBox.shrink();
    }

    const outerRadius = 18.0;
    final houseId = _houseId?.trim();

    if (houseId == null || houseId.isEmpty) {
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: textColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(outerRadius),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.62),
            width: 0.95,
          ),
        ),
        child: Center(
          child: Icon(
            Icons.photo_library_rounded,
            size: width * 0.4,
            color: textColor.withValues(alpha: 0.45),
          ),
        ),
      );
    }

    return _WidgetDiaryPreviewStream(
      state: this,
      houseId: houseId,
      layoutKey: _widgetDiaryLayoutKey,
      textColor: textColor,
      width: width,
      height: height,
    );
  }

  Widget _buildWidgetHeartStylePicker() {
    final selectedKey = _normalizeWidgetHeartStyleKey(_widgetHeartStyleKey);
    final visibleHeartStyles = _widgetHeartStyleKeys
        .take(12)
        .toList(growable: false);
    final hiddenCount =
        _widgetHeartStyleKeys.length - visibleHeartStyles.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final crossAxisCount = constraints.maxWidth >= 560
                ? 8
                : constraints.maxWidth >= 400
                ? 6
                : 4;

            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: visibleHeartStyles.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1,
              ),
              itemBuilder: (context, index) {
                final heart = visibleHeartStyles[index];
                final isSelected = selectedKey == heart;
                final optionLabel = context
                    .tr('p7_heart_style_option')
                    .replaceAll('{index}', '${index + 1}');

                void selectHeart() {
                  unawaited(_handleWidgetHeartStyleChanged(heart));
                }

                return Semantics(
                  button: true,
                  selected: isSelected,
                  label: optionLabel,
                  onTap: selectHeart,
                  excludeSemantics: true,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: selectHeart,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOut,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFFFFEEF5)
                              : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFFFF6B97)
                                : const Color(0xFFE4EAF3),
                            width: isSelected ? 1.6 : 1.1,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: const Color(
                                      0xFFFF6B97,
                                    ).withValues(alpha: 0.16),
                                    blurRadius: 12,
                                    offset: const Offset(0, 5),
                                  ),
                                ]
                              : const [],
                        ),
                        child: Center(
                          child: AnimatedScale(
                            duration: const Duration(milliseconds: 220),
                            scale: isSelected ? 1.08 : 1,
                            child: ShaderMask(
                              shaderCallback: (bounds) => const LinearGradient(
                                colors: [
                                  Color(0xFFFF4D8D),
                                  Color(0xFFFFB86B),
                                  Color(0xFF8B5CF6),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ).createShader(bounds),
                              child: Text(
                                heart,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 23,
                                  height: 1,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
        if (hiddenCount > 0) ...[
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () {
                showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (sheetContext) {
                    return SafeArea(
                      child: Container(
                        margin: const EdgeInsets.all(12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.12),
                              blurRadius: 22,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    L10nService().translate(
                                      'home_tat_ca_kieu_trai_tim',
                                    ),
                                    style: SLTheme.quicksand(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900,
                                      color: const Color(0xFF4A3640),
                                    ),
                                  ),
                                ),
                                IconButton(
                                  onPressed: () => Navigator.pop(sheetContext),
                                  tooltip: context.tr('p7_close'),
                                  icon: const Icon(Icons.close_rounded),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Flexible(
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  final crossAxisCount =
                                      constraints.maxWidth >= 640
                                      ? 8
                                      : constraints.maxWidth >= 440
                                      ? 6
                                      : 4;

                                  return GridView.builder(
                                    shrinkWrap: true,
                                    physics: const ClampingScrollPhysics(),
                                    itemCount: _widgetHeartStyleKeys.length,
                                    gridDelegate:
                                        SliverGridDelegateWithFixedCrossAxisCount(
                                          crossAxisCount: crossAxisCount,
                                          crossAxisSpacing: 10,
                                          mainAxisSpacing: 10,
                                          childAspectRatio: 1,
                                        ),
                                    itemBuilder: (context, index) {
                                      final heart =
                                          _widgetHeartStyleKeys[index];
                                      final isSelected = selectedKey == heart;
                                      final optionLabel = context
                                          .tr('p7_heart_style_option')
                                          .replaceAll(
                                            '{index}',
                                            '${index + 1}',
                                          );

                                      Future<void> selectHeart() async {
                                        await _handleWidgetHeartStyleChanged(
                                          heart,
                                        );
                                        if (sheetContext.mounted) {
                                          Navigator.pop(sheetContext);
                                        }
                                      }

                                      return Semantics(
                                        button: true,
                                        selected: isSelected,
                                        label: optionLabel,
                                        onTap: selectHeart,
                                        excludeSemantics: true,
                                        child: Material(
                                          color: Colors.transparent,
                                          child: InkWell(
                                            borderRadius: BorderRadius.circular(
                                              18,
                                            ),
                                            onTap: selectHeart,
                                            child: AnimatedContainer(
                                              duration: const Duration(
                                                milliseconds: 220,
                                              ),
                                              curve: Curves.easeOut,
                                              decoration: BoxDecoration(
                                                color: isSelected
                                                    ? const Color(0xFFFFEEF5)
                                                    : const Color(0xFFF8FAFC),
                                                borderRadius:
                                                    BorderRadius.circular(18),
                                                border: Border.all(
                                                  color: isSelected
                                                      ? const Color(0xFFFF6B97)
                                                      : const Color(0xFFE4EAF3),
                                                  width: isSelected ? 1.6 : 1.1,
                                                ),
                                              ),
                                              child: Center(
                                                child: ShaderMask(
                                                  shaderCallback: (bounds) =>
                                                      const LinearGradient(
                                                        colors: [
                                                          Color(0xFFFF4D8D),
                                                          Color(0xFFFFB86B),
                                                          Color(0xFF8B5CF6),
                                                        ],
                                                        begin:
                                                            Alignment.topLeft,
                                                        end: Alignment
                                                            .bottomRight,
                                                      ).createShader(bounds),
                                                  child: Text(
                                                    heart,
                                                    textAlign: TextAlign.center,
                                                    style: const TextStyle(
                                                      fontSize: 23,
                                                      height: 1,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
              icon: const Icon(Icons.more_horiz_rounded),
              label: Text(
                L10nService()
                    .translate('home_xem_them')
                    .replaceAll('{count}', hiddenCount.toString()),
                style: SLTheme.quicksand(
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFFD81B60),
                ),
              ),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFD81B60),
              ),
            ),
          ),
        ],
      ],
    );
  }

  String _resolvedWidgetSeasonKey() {
    return WidgetService.resolveSeasonEffect(
      seasonModeKey: _widgetSeasonModeKey,
      loveDate: _loveDate,
      birthday1: _dobU1,
      birthday2: _dobU2,
    );
  }

  List<Color> _widgetSeasonPalette(String seasonKey) {
    switch (seasonKey) {
      case 'valentine':
        return const [Color(0xFFFF5B8A), Color(0xFFFFC4D6)];
      case 'anniversary':
        return const [Color(0xFFFFB84D), Color(0xFFFFE5A8)];
      case 'birthday':
        return const [Color(0xFF5B8CFF), Color(0xFF8FE8FF)];
      case 'none':
      default:
        return const [Color(0xFFE2E8F0), Color(0xFFF8FAFC)];
    }
  }

  double _widgetPreviewCardWidth(double maxWidth) {
    if (maxWidth <= 0) {
      return 0;
    }
    return maxWidth > 360 ? maxWidth - 4 : maxWidth;
  }

  Widget _buildWidgetHeartPreview(Color textColor, {double size = 72}) {
    final tick = _widgetPreviewTickNotifier.value;
    final styleKey = _normalizeWidgetHeartStyleKey(_widgetHeartStyleKey);

    final styleSeed = styleKey.runes.fold<int>(0, (sum, rune) => sum + rune);
    final colorSeed = _widgetHeartColorKey.runes.fold<int>(
      0,
      (sum, rune) => sum + rune,
    );
    final animatedStyleIndex =
        (tick * 7 + styleSeed + colorSeed) % _widgetHeartStyleKeys.length;
    final activeStyleKey = _widgetHeartAnimated
        ? _widgetHeartStyleKeys[animatedStyleIndex]
        : styleKey;
    final phase = (tick + styleSeed) % 6;
    final pulse = _widgetHeartAnimated
        ? <double>[1.0, 1.08, 0.95, 1.06, 0.98, 1.03][phase]
        : 1.0;
    final floatY = _widgetHeartAnimated
        ? <double>[0.0, -2.4, 1.0, -1.6, 0.7, -1.0][phase]
        : 0.0;
    final swayX = _widgetHeartAnimated
        ? <double>[0.0, 2.2, -2.0, 1.2, -1.3, 0.8][phase]
        : 0.0;
    final emojiSize = size * 0.62;

    if (_widgetHeartColorKey == 'none') {
      return SizedBox(
        width: size,
        height: size,
        child: Center(
          child: Transform.translate(
            offset: Offset(swayX * 0.42, floatY),
            child: Transform.scale(
              scale: pulse,
              child: Text(
                activeStyleKey,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: emojiSize, height: 1),
              ),
            ),
          ),
        ),
      );
    }

    final palette = _widgetHeartPalette(_widgetHeartColorKey);
    final primary = palette[0];
    final secondary = palette[1];
    final glow = palette[2];

    return SizedBox(
      width: size,
      height: size,
      child: Center(
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Container(
              width: size * 0.9,
              height: size * 0.9,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    glow.withValues(alpha: 0.92),
                    primary.withValues(alpha: 0.20),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.54, 1.0],
                ),
              ),
            ),
            if (_widgetHeartAnimated)
              Positioned(
                top: size * 0.18 + (floatY * 0.35),
                right: size * 0.14 - (swayX * 0.45),
                child: Container(
                  width: size * 0.14,
                  height: size * 0.14,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: secondary.withValues(alpha: 0.34),
                  ),
                ),
              ),
            if (_widgetHeartAnimated)
              Positioned(
                left: size * 0.14 + (swayX * 0.24),
                bottom: size * 0.16,
                child: Container(
                  width: size * 0.1,
                  height: size * 0.1,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: glow.withValues(alpha: 0.86),
                  ),
                ),
              ),
            Transform.translate(
              offset: Offset(swayX * 0.42, floatY),
              child: Transform.scale(
                scale: pulse,
                child: ShaderMask(
                  shaderCallback: (bounds) => LinearGradient(
                    colors: [primary, secondary, glow],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ).createShader(bounds),
                  child: Text(
                    activeStyleKey,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: emojiSize,
                      height: 1,
                      color: Colors.white,
                      shadows: [
                        Shadow(
                          color: primary.withValues(
                            alpha: _widgetHeartAnimated ? 0.28 : 0.16,
                          ),
                          blurRadius: size * 0.18,
                          offset: const Offset(0, 3),
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
    );
  }

  LinearGradient _widgetPreviewCardGradient(
    String themeKey,
    List<Color> colors,
  ) {
    if (themeKey != 'premium') {
      return LinearGradient(
        colors: colors,
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    }

    const begins = <Alignment>[
      Alignment(-1.0, -1.0),
      Alignment(-0.4, -1.0),
      Alignment(-0.9, -0.2),
      Alignment(-0.3, -0.9),
    ];
    const ends = <Alignment>[
      Alignment(1.0, 1.0),
      Alignment(0.9, 1.0),
      Alignment(1.0, 0.5),
      Alignment(1.0, 1.0),
    ];
    const stopOffsets = <double>[0.0, 0.04, -0.03, 0.02];
    final phase = _widgetPreviewTickNotifier.value % 4;

    return LinearGradient(
      colors: [
        colors[0].withValues(alpha: 0.98),
        colors[1].withValues(alpha: 0.96),
        colors[2].withValues(alpha: 0.94),
        colors[3].withValues(alpha: 0.98),
      ],
      stops: [0.0, (0.34 + stopOffsets[phase]).clamp(0.18, 0.46), 0.72, 1.0],
      begin: begins[phase],
      end: ends[phase],
    );
  }

  Widget _buildPremiumWidgetPreviewAurora(double cardWidth, double cardHeight) {
    final phase = _widgetPreviewTickNotifier.value % 4;
    const firstAlignments = <Alignment>[
      Alignment(-0.9, -0.9),
      Alignment(-0.55, -0.8),
      Alignment(-0.75, -0.35),
      Alignment(-0.5, -0.85),
    ];
    const secondAlignments = <Alignment>[
      Alignment(0.95, -0.15),
      Alignment(0.7, -0.45),
      Alignment(0.95, -0.3),
      Alignment(0.7, -0.1),
    ];
    const thirdAlignments = <Alignment>[
      Alignment(0.15, 1.0),
      Alignment(-0.15, 0.9),
      Alignment(0.3, 0.75),
      Alignment(-0.05, 1.0),
    ];

    Widget blob({
      required Alignment alignment,
      required double size,
      required List<Color> colors,
      required double opacity,
    }) {
      return AnimatedAlign(
        duration: const Duration(milliseconds: 850),
        curve: Curves.easeInOut,
        alignment: alignment,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                colors.first.withValues(alpha: opacity),
                colors.last.withValues(alpha: opacity * 0.52),
                Colors.transparent,
              ],
              stops: const [0.0, 0.48, 1.0],
            ),
          ),
        ),
      );
    }

    final themeKey = _draftWidgetThemeKey ?? 'pink';
    final isCosmic = themeKey == 'cosmic';

    return IgnorePointer(
      child: Stack(
        children: <Widget>[
          blob(
            alignment: firstAlignments[phase],
            size: cardWidth * 0.72,
            colors: isCosmic
                ? const [Color(0xFFFFD700), Color(0xFFB59410)]
                : const [Color(0xFFFF8AB8), Color(0xFFFFB86B)],
            opacity: isCosmic ? 0.35 : 0.54,
          ),
          blob(
            alignment: secondAlignments[phase],
            size: cardWidth * 0.62,
            colors: isCosmic
                ? const [Color(0xFFFDE68A), Color(0xFFFFB86B)]
                : const [Color(0xFF8AE7FF), Color(0xFF6D7CFF)],
            opacity: isCosmic ? 0.28 : 0.48,
          ),
          blob(
            alignment: thirdAlignments[phase],
            size: cardHeight * 0.98,
            colors: isCosmic
                ? const [Color(0xFFFFFBEB), Color(0xFFEAB308)]
                : const [Color(0xFFFFD38A), Color(0xFFCE8BFF)],
            opacity: isCosmic ? 0.22 : 0.34,
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withValues(alpha: 0.12),
                    Colors.transparent,
                    Colors.white.withValues(alpha: 0.06),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
          ),
          if (isCosmic) ...[
            Positioned(
              top: cardHeight * 0.15,
              left: cardWidth * 0.2,
              child: Icon(
                Icons.star_rounded,
                size: 8,
                color: Colors.white.withValues(alpha: 0.6),
              ),
            ),
            Positioned(
              top: cardHeight * 0.3,
              right: cardWidth * 0.25,
              child: Icon(
                Icons.star_rounded,
                size: 6,
                color: Colors.white.withValues(alpha: 0.4),
              ),
            ),
            Positioned(
              bottom: cardHeight * 0.2,
              left: cardWidth * 0.3,
              child: Icon(
                Icons.star_rounded,
                size: 7,
                color: Colors.white.withValues(alpha: 0.5),
              ),
            ),
            Positioned(
              bottom: cardHeight * 0.15,
              right: cardWidth * 0.15,
              child: Icon(
                Icons.star_rounded,
                size: 5,
                color: Colors.white.withValues(alpha: 0.4),
              ),
            ),
          ],
          Positioned(
            top: cardHeight * 0.16,
            right: cardWidth * 0.16,
            child: Icon(
              Icons.auto_awesome_rounded,
              size: cardWidth * 0.06,
              color: isCosmic
                  ? const Color(0xFFFFD700).withValues(alpha: 0.85)
                  : Colors.white.withValues(alpha: 0.72),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWidgetPreviewDecorations(
    String themeKey,
    Color accentColor,
    double width,
    double height,
  ) {
    if (themeKey == 'premium') return const SizedBox.shrink();

    final isDark = themeKey == 'dark';

    return Positioned.fill(
      child: IgnorePointer(
        child: Stack(
          children: [
            // Top Right glow circle
            if (!isDark && themeKey != 'white')
              Positioned(
                top: -height * 0.2,
                right: -width * 0.1,
                child: Container(
                  width: width * 0.44,
                  height: width * 0.44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        accentColor.withValues(alpha: 0.15),
                        accentColor.withValues(alpha: 0.04),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            // Bottom Left glow circle
            if (!isDark && themeKey != 'white')
              Positioned(
                bottom: -height * 0.22,
                left: -width * 0.12,
                child: Container(
                  width: width * 0.36,
                  height: width * 0.36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        Colors.white.withValues(alpha: 0.4),
                        Colors.white.withValues(alpha: 0.1),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            // Dark theme stars
            if (isDark) ...[
              Positioned(
                top: height * 0.15,
                right: width * 0.15,
                child: Icon(
                  Icons.auto_awesome_rounded,
                  size: 10,
                  color: Colors.white.withValues(alpha: 0.2),
                ),
              ),
              Positioned(
                bottom: height * 0.2,
                left: width * 0.12,
                child: Icon(
                  Icons.star_rounded,
                  size: 8,
                  color: Colors.white.withValues(alpha: 0.15),
                ),
              ),
            ],
            // White theme soft blue blob
            if (themeKey == 'white')
              Positioned(
                top: -height * 0.15,
                right: -width * 0.05,
                child: Container(
                  width: width * 0.38,
                  height: width * 0.38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFFE0F2FE).withValues(alpha: 0.5),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ignore: unused_element
  Widget _buildWidgetDayLabel(
    Color textColor,
    int days, {
    required bool compact,
  }) {
    return Text(
      L10nService().format('home_days_count', {'days': days}),
      style: SLTheme.quicksand(
        color: textColor,
        fontWeight: FontWeight.w900,
        fontSize: compact ? 14.2 : 15.4,
        letterSpacing: -0.2,
        height: 1,
      ),
    );
  }

  Widget _buildWidgetDayStackedLabel(
    Color textColor,
    int days, {
    required bool compact,
  }) {
    final countSize = compact ? 18.2 : 19.2;
    final unitSize = compact ? 12.4 : 13.2;
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$days\n',
            style: SLTheme.quicksand(
              color: textColor,
              fontWeight: FontWeight.w900,
              fontSize: countSize,
              letterSpacing: -0.3,
              height: 0.96,
            ),
          ),
          TextSpan(
            text: context.tr('p7_day_lowercase'),
            style: SLTheme.quicksand(
              color: textColor,
              fontWeight: FontWeight.w800,
              fontSize: unitSize,
              letterSpacing: -0.1,
              height: 0.98,
            ),
          ),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildWidgetPreview() {
    return ValueListenableBuilder<int>(
      valueListenable: _widgetPreviewTickNotifier,
      builder: (context, _, _) {
        final themeKey = _draftWidgetThemeKey ?? 'pink';
        final theme = _widgetPreviewThemeSpec(themeKey);
        final textColor = theme.textColor;
        final heartPalette = _widgetHeartPalette(_widgetHeartColorKey);
        final seasonKey = _resolvedWidgetSeasonKey();
        final seasonPalette = _widgetSeasonPalette(seasonKey);
        final accentColor = seasonKey == 'none'
            ? heartPalette.first
            : seasonPalette.first;
        final daysColor = theme.premium || themeKey == 'dark'
            ? Colors.white
            : Color.alphaBlend(accentColor.withValues(alpha: 0.18), textColor);
        final days = _loveDayCounter();
        final label1 = _nameU1.trim().isEmpty
            ? context.tr('role_male')
            : _nameU1.trim();
        final label2 = _nameU2.trim().isEmpty
            ? context.tr('role_female')
            : _nameU2.trim();
        final showDiaryPreview = _showDiaryOnWidget;
        final isCountdownStyle = _widgetStyleKey == 'countdown';
        final loveDateLabel = _loveDate.trim().isEmpty
            ? context.tr('p7_love_date_starts_today')
            : context
                  .tr('p7_love_date_since')
                  .replaceAll(
                    '{date}',
                    DateInputUtils.normalizeForDisplay(_loveDate),
                  );

        return LayoutBuilder(
          builder: (context, constraints) {
            final maxWidth =
                constraints.maxWidth.isFinite && constraints.maxWidth > 0
                ? constraints.maxWidth
                : 340.0;
            final cardWidth = _widgetPreviewCardWidth(maxWidth);
            final isCompact = cardWidth < 320;
            final isLarge = cardWidth >= 370;
            final cardHeight = showDiaryPreview
                ? (cardWidth * (isCompact ? 0.68 : 0.60))
                      .clamp(196.0, 286.0)
                      .toDouble()
                : (cardWidth * (isCompact ? 0.54 : 0.50))
                      .clamp(168.0, 236.0)
                      .toDouble();
            final avatarRadius = isCompact ? 25.0 : (isLarge ? 31.0 : 28.0);
            final avatarWidth = isCompact ? 82.0 : (isLarge ? 112.0 : 96.0);
            final heartSize = showDiaryPreview
                ? (isCompact ? 58.0 : (isLarge ? 70.0 : 64.0))
                : (isCompact ? 66.0 : (isLarge ? 76.0 : 70.0));
            final diaryPreviewWidth = isCompact
                ? 58.0
                : (isLarge ? 74.0 : 66.0);
            final diaryPreviewHeight = isCompact
                ? 84.0
                : (isLarge ? 108.0 : 96.0);
            final diaryBlockOffsetY = showDiaryPreview
                ? (isCompact ? 4.0 : (isLarge ? 8.0 : 6.0))
                : 0.0;
            final diaryBlockGap = showDiaryPreview
                ? (isCompact ? 4.0 : 6.0)
                : 6.0;

            final isSoulEventStyle = _widgetPanelTabKey == 'soulevent';
            if (isSoulEventStyle) {
              final widgetHeight = (cardWidth * (isCompact ? 0.56 : 0.52))
                  .clamp(176.0, 228.0)
                  .toDouble();

              return FutureBuilder<Map<String, String>>(
                future: _loadSoulEventPreviewData(),
                builder: (context, snapshot) {
                  final data = snapshot.data ?? _emptySoulEventPreviewData();

                  final colorHex = data['color']!;
                  Color eventColor;
                  try {
                    final buffer = StringBuffer();
                    if (colorHex.length == 6 || colorHex.length == 7) {
                      buffer.write('ff');
                    }
                    buffer.write(colorHex.replaceFirst('#', ''));
                    eventColor = Color(int.parse(buffer.toString(), radix: 16));
                  } catch (_) {
                    eventColor = const Color(0xFFEC4899);
                  }

                  final eventTitle = data['title']!;
                  final eventDate = data['date']!;
                  final eventDays = data['days']!;
                  final eventLabel = data['label']!;

                  return Center(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 850),
                      curve: Curves.easeInOut,
                      width: cardWidth,
                      height: widgetHeight,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(26),
                        border: Border.all(
                          color: eventColor.withValues(alpha: 0.35),
                          width: 1.8,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: eventColor.withValues(alpha: 0.08),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Stack(
                        children: [
                          Positioned(
                            bottom: -30,
                            right: -30,
                            child: Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: eventColor.withValues(alpha: 0.05),
                              ),
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.fromLTRB(
                              isCompact ? 16 : 20,
                              16,
                              isCompact ? 16 : 20,
                              16,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFFF0F5),
                                        borderRadius: BorderRadius.circular(12),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(
                                              alpha: 0.03,
                                            ),
                                            blurRadius: 4,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: const Text(
                                        '🎁',
                                        style: TextStyle(fontSize: 20),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            eventTitle,
                                            style: SLTheme.quicksand(
                                              color: const Color(0xFF2C1B22),
                                              fontSize: isCompact ? 16 : 18,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            eventDate,
                                            style: SLTheme.quicksand(
                                              color: const Color(0xFF8C7381),
                                              fontSize: isCompact ? 11 : 12,
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
                                  eventDays,
                                  style: SLTheme.quicksand(
                                    color: eventColor,
                                    fontSize: isCompact ? 38 : 44,
                                    fontWeight: FontWeight.w900,
                                    height: 1,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  eventLabel,
                                  style: SLTheme.quicksand(
                                    color: eventColor.withValues(alpha: 0.8),
                                    fontSize: isCompact ? 12 : 13,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            }

            if (isCountdownStyle) {
              final countdownHeight = (cardWidth * (isCompact ? 0.56 : 0.52))
                  .clamp(176.0, 228.0)
                  .toDouble();
              final topAvatarRadius = isCompact ? 20.0 : 24.0;

              return Center(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 850),
                  curve: Curves.easeInOut,
                  width: cardWidth,
                  height: countdownHeight,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    gradient: _widgetPreviewCardGradient(
                      themeKey,
                      theme.colors,
                    ),
                    borderRadius: BorderRadius.circular(26),
                    border: Border.all(
                      color: themeKey == 'white'
                          ? const Color(0xFFE2E8F0)
                          : theme.borderColor.withValues(alpha: 0.35),
                      width: 1.8,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: theme.colors.first.withValues(alpha: 0.22),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      if (theme.premium)
                        Positioned.fill(
                          child: _buildPremiumWidgetPreviewAurora(
                            cardWidth,
                            countdownHeight,
                          ),
                        )
                      else
                        _buildWidgetPreviewDecorations(
                          themeKey,
                          accentColor,
                          cardWidth,
                          countdownHeight,
                        ),
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          isCompact ? 16 : 20,
                          16,
                          isCompact ? 16 : 20,
                          16,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _buildWidgetPreviewPerson(
                                  avatarUrl: _avatarUrl1,
                                  label: label1,
                                  textColor: textColor,
                                  radius: topAvatarRadius,
                                  width: isCompact ? 70 : 78,
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                  ),
                                  child: Icon(
                                    Icons.favorite_rounded,
                                    color: accentColor,
                                    size: isCompact ? 18 : 20,
                                  ),
                                ),
                                _buildWidgetPreviewPerson(
                                  avatarUrl: _avatarUrl2,
                                  label: label2,
                                  textColor: textColor,
                                  radius: topAvatarRadius,
                                  width: isCompact ? 70 : 78,
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '$days',
                              style: SLTheme.quicksand(
                                color: daysColor,
                                fontSize: isCompact ? 34 : 40,
                                fontWeight: FontWeight.w900,
                                height: 1,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              L10nService().translate('home_days_label'),
                              style: SLTheme.quicksand(
                                color: daysColor.withValues(alpha: 0.78),
                                fontSize: isCompact ? 13 : 14,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              loveDateLabel,
                              textAlign: TextAlign.center,
                              style: SLTheme.quicksand(
                                color: textColor.withValues(alpha: 0.82),
                                fontSize: isCompact ? 11.8 : 12.6,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            return Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 850),
                curve: Curves.easeInOut,
                width: cardWidth,
                height: cardHeight,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  gradient: _widgetPreviewCardGradient(themeKey, theme.colors),
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(
                    color: themeKey == 'white'
                        ? const Color(0xFFE2E8F0)
                        : theme.borderColor.withValues(alpha: 0.35),
                    width: 1.8,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: theme.colors.first.withValues(alpha: 0.22),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    if (theme.premium)
                      Positioned.fill(
                        child: _buildPremiumWidgetPreviewAurora(
                          cardWidth,
                          cardHeight,
                        ),
                      )
                    else
                      _buildWidgetPreviewDecorations(
                        themeKey,
                        accentColor,
                        cardWidth,
                        cardHeight,
                      ),
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        isCompact ? 16 : 20,
                        16,
                        isCompact ? 16 : 20,
                        16,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: _buildWidgetPreviewPerson(
                                      avatarUrl: _avatarUrl1,
                                      label: label1,
                                      textColor: textColor,
                                      radius: avatarRadius,
                                      width: avatarWidth,
                                    ),
                                  ),
                                ),
                                SizedBox(width: isCompact ? 10 : 14),
                                SizedBox(
                                  width: isCompact ? 96 : (isLarge ? 118 : 106),
                                  child: Transform.translate(
                                    offset: Offset(0, diaryBlockOffsetY),
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        _buildWidgetDayStackedLabel(
                                          daysColor,
                                          days,
                                          compact: isCompact,
                                        ),
                                        SizedBox(height: diaryBlockGap),
                                        if (!showDiaryPreview)
                                          _buildWidgetHeartPreview(
                                            textColor,
                                            size: heartSize,
                                          ),
                                        if (showDiaryPreview) ...[
                                          SizedBox(height: diaryBlockGap),
                                          _buildWidgetDiaryPreview(
                                            textColor,
                                            width: diaryPreviewWidth,
                                            height: diaryPreviewHeight,
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                                SizedBox(width: isCompact ? 10 : 14),
                                Expanded(
                                  child: Align(
                                    alignment: Alignment.centerRight,
                                    child: _buildWidgetPreviewPerson(
                                      avatarUrl: _avatarUrl2,
                                      label: label2,
                                      textColor: textColor,
                                      radius: avatarRadius,
                                      width: avatarWidth,
                                    ),
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
              ),
            );
          },
        );
      },
    );
  }

  static Future<Map<String, String>>? _cachedSoulEventPreviewFuture;

  Future<Map<String, String>> _loadSoulEventPreviewData() async {
    if (_cachedSoulEventPreviewFuture != null) {
      return _cachedSoulEventPreviewFuture!;
    }

    _cachedSoulEventPreviewFuture = _loadSoulEventPreviewDataInternal();
    return _cachedSoulEventPreviewFuture!;
  }

  Future<Map<String, String>> _loadSoulEventPreviewDataInternal() async {
    final emptyData = _emptySoulEventPreviewData();
    final todayLabel = context.tr('p7_today_upper');
    final daysRemainingLabel = context.tr('p7_days_remaining');
    final houseId = _houseId ?? '';
    if (houseId.isEmpty) {
      return emptyData;
    }

    try {
      final events = await SoulEventService().getEvents(houseId);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      SoulEvent? topEvent;
      int minDays = 99999;

      for (final event in events) {
        if (!event.isPinned) continue;
        final nextDate = event.calculateNextOccurrence(today);
        if (nextDate != null) {
          final diff = nextDate.difference(today).inDays;
          if (diff >= 0 && diff < minDays) {
            minDays = diff;
            topEvent = event;
          }
        }
      }

      if (topEvent == null && events.isNotEmpty) {
        for (final event in events) {
          final nextDate = event.calculateNextOccurrence(today);
          if (nextDate != null) {
            final diff = nextDate.difference(today).inDays;
            if (diff >= 0 && diff < minDays) {
              minDays = diff;
              topEvent = event;
            }
          }
        }
      }

      if (topEvent != null) {
        final nextDate = topEvent.calculateNextOccurrence(today)!;
        final isToday = nextDate.isAtSameMomentAs(today);
        final dateStr =
            '${nextDate.day.toString().padLeft(2, '0')}/${nextDate.month.toString().padLeft(2, '0')}/${nextDate.year}';
        final colorHex = topEvent.colorHex.isNotEmpty
            ? topEvent.colorHex
            : '#EC4899';

        return {
          'title': topEvent.title,
          'date': dateStr,
          'days': isToday ? todayLabel : minDays.toString(),
          'label': isToday ? '🎉' : daysRemainingLabel,
          'color': colorHex,
        };
      }
    } catch (error) {
      debugPrint(
        '[SuppressedError] lib/views/home/tabs/settings/widget/widget_preview_part.dart: $error',
      );
    }

    return emptyData;
  }

  Map<String, String> _emptySoulEventPreviewData() {
    return {
      'title': context.tr('p7_no_upcoming_event'),
      'date': '--/--/----',
      'days': '0',
      'label': context.tr('p7_days_remaining'),
      'color': '#EC4899',
    };
  }

  Widget _buildWidgetPreviewPerson({
    required String avatarUrl,
    required String label,
    required Color textColor,
    double radius = 34,
    double width = 76,
  }) {
    final iconSize = radius * 0.78;
    final fontSize = radius >= 30 ? 12.5 : 11.4;

    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(3.5),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.20),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
          ),
          child: Container(
            padding: const EdgeInsets.all(1.5),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: CircleAvatar(
              radius: radius - 1.5,
              backgroundColor: Colors.white.withValues(alpha: 0.85),
              backgroundImage: avatarUrl.isNotEmpty
                  ? CachedNetworkImageProvider(avatarUrl)
                  : null,
              child: avatarUrl.isEmpty
                  ? Icon(
                      Icons.person,
                      color: textColor.withValues(alpha: 0.75),
                      size: iconSize * 0.9,
                    )
                  : null,
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: width,
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: SLTheme.quicksand(
              color: textColor,
              fontWeight: FontWeight.w900,
              fontSize: fontSize + 4.0,
              height: 1.15,
              letterSpacing: -0.1,
            ),
          ),
        ),
      ],
    );
  }
}

class _WidgetDiaryPreviewStream extends StatefulWidget {
  const _WidgetDiaryPreviewStream({
    required this.state,
    required this.houseId,
    required this.layoutKey,
    required this.textColor,
    required this.width,
    required this.height,
  });

  final _SettingsTabState state;
  final String houseId;
  final String layoutKey;
  final Color textColor;
  final double width;
  final double height;

  @override
  State<_WidgetDiaryPreviewStream> createState() =>
      _WidgetDiaryPreviewStreamState();
}

class _WidgetDiaryPreviewStreamState extends State<_WidgetDiaryPreviewStream> {
  static const double _outerRadius = 18;

  late Future<List<String>> _imageUrlsFuture;
  Timer? _rotationTimer;

  @override
  void initState() {
    super.initState();
    _updateStream();
    _rotationTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didUpdateWidget(covariant _WidgetDiaryPreviewStream oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.houseId != widget.houseId) {
      _updateStream();
    }
  }

  @override
  void dispose() {
    _rotationTimer?.cancel();
    super.dispose();
  }

  void _updateStream() {
    _imageUrlsFuture = widget.state._loadWidgetDiaryUrls(limit: 24);
  }

  Widget _buildEmptyPreview() {
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: widget.textColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(_outerRadius),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.62),
          width: 0.95,
        ),
      ),
      child: Center(
        child: Icon(
          Icons.photo_library_rounded,
          size: widget.width * 0.4,
          color: widget.textColor.withValues(alpha: 0.45),
        ),
      ),
    );
  }

  Widget _buildTile({
    String? imageUrl,
    required double tileWidth,
    required double tileHeight,
    required BorderRadius borderRadius,
  }) {
    final iconSize = (tileWidth < tileHeight ? tileWidth : tileHeight) * 0.34;
    return Container(
      width: tileWidth,
      height: tileHeight,
      decoration: BoxDecoration(
        color: widget.textColor.withValues(alpha: 0.07),
        borderRadius: borderRadius,
      ),
      child: imageUrl == null
          ? Icon(
              Icons.photo_library_rounded,
              size: iconSize,
              color: widget.textColor.withValues(alpha: 0.45),
            )
          : ClipRRect(
              borderRadius: borderRadius,
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                filterQuality: FilterQuality.medium,
                maxWidthDiskCache: tileWidth.ceil(),
                maxHeightDiskCache: tileHeight.ceil(),
                memCacheWidth: 400,
                errorWidget: (_, _, _) {
                  return Icon(
                    Icons.broken_image_rounded,
                    size: iconSize,
                    color: widget.textColor.withValues(alpha: 0.45),
                  );
                },
              ),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<String>>(
      future: _imageUrlsFuture,
      builder: (context, snapshot) {
        final imageUrls = snapshot.data ?? const <String>[];
        if (imageUrls.isEmpty) {
          return _buildEmptyPreview();
        }

        final timeOffset = (DateTime.now().millisecondsSinceEpoch ~/ 60000);
        final filledUrls = switch (widget.layoutKey) {
          'grid' => List<String?>.generate(
            4,
            (index) => imageUrls[(index + timeOffset) % imageUrls.length],
          ),
          'duo' => List<String?>.generate(
            2,
            (index) => imageUrls[(index + timeOffset) % imageUrls.length],
          ),
          _ => <String?>[imageUrls[timeOffset % imageUrls.length]],
        };
        final previewKey = '${widget.layoutKey}_${filledUrls.join('|')}';

        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 320),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          transitionBuilder: (child, animation) {
            return FadeTransition(opacity: animation, child: child);
          },
          child: Container(
            key: ValueKey(previewKey),
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(_outerRadius),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.68),
                width: 0.95,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(_outerRadius - 1),
              child: Padding(
                padding: const EdgeInsets.all(3),
                child: switch (widget.layoutKey) {
                  'grid' => Column(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Expanded(
                              child: _buildTile(
                                imageUrl: filledUrls[0],
                                tileWidth: widget.width / 2,
                                tileHeight: widget.height / 2,
                                borderRadius: BorderRadius.circular(11),
                              ),
                            ),
                            const SizedBox(width: 3),
                            Expanded(
                              child: _buildTile(
                                imageUrl: filledUrls[1],
                                tileWidth: widget.width / 2,
                                tileHeight: widget.height / 2,
                                borderRadius: BorderRadius.circular(11),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 3),
                      Expanded(
                        child: Row(
                          children: [
                            Expanded(
                              child: _buildTile(
                                imageUrl: filledUrls[2],
                                tileWidth: widget.width / 2,
                                tileHeight: widget.height / 2,
                                borderRadius: BorderRadius.circular(11),
                              ),
                            ),
                            const SizedBox(width: 3),
                            Expanded(
                              child: _buildTile(
                                imageUrl: filledUrls[3],
                                tileWidth: widget.width / 2,
                                tileHeight: widget.height / 2,
                                borderRadius: BorderRadius.circular(11),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  'duo' => Column(
                    children: [
                      Expanded(
                        child: _buildTile(
                          imageUrl: filledUrls[0],
                          tileWidth: widget.width,
                          tileHeight: widget.height / 2,
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Expanded(
                        child: _buildTile(
                          imageUrl: filledUrls[1],
                          tileWidth: widget.width,
                          tileHeight: widget.height / 2,
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ],
                  ),
                  _ => _buildTile(
                    imageUrl: filledUrls.first,
                    tileWidth: widget.width,
                    tileHeight: widget.height,
                    borderRadius: BorderRadius.circular(13),
                  ),
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
