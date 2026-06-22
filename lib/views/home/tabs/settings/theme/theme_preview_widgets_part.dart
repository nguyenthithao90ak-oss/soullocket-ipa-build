part of '../../settings_tab.dart';
// ignore_for_file: unused_element

extension _SettingsTabThemePreviewWidgetsPart on _SettingsTabState {
  Widget _buildThemeHomeLikePreviewCard(
    String imageUrl, {
    required String themeKey,
    required String effectKey,
    required String graphicsKey,
  }) {
    final ui = UiPrefs.notifier.value;
    final resolvedThemeKey = _resolvePreviewThemeKey(themeKey);
    final isDark = _isPreviewDarkTheme(resolvedThemeKey);
    final resolvedEffectKey = _resolvePreviewEffectKey(effectKey, resolvedThemeKey);
    final accent = _previewThemeAccent(resolvedThemeKey);
    final gradient = _previewThemeGradient(resolvedThemeKey, isDark);

    return RepaintBoundary(
      child: Center(
        child: Container(
          width: 320,
          height: 480,
          margin: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.16),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
            border: Border.all(
              color: const Color(0xFFFFD6E4).withValues(alpha: 0.4),
              width: 2,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(26),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Background
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: gradient,
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
                if (imageUrl.isNotEmpty)
                  Positioned.fill(
                    child: Opacity(
                      opacity: ui.liteMode ? 0.12 : 0.28,
                      child: CachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => const SizedBox.shrink(),
                      ),
                    ),
                  ),
                // Effect layer
                if (resolvedEffectKey != 'off' && !ui.liteMode && graphicsKey != 'low')
                  Positioned.fill(
                    child: IgnorePointer(
                      child: _buildThemePreviewEffectLayer(
                        resolvedEffectKey,
                        accent,
                        isDark,
                      ),
                    ),
                  ),
                // Main Content inside phone mockup
                SafeArea(
                  minimum: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Icon(
                            Icons.cloud_queue_rounded,
                            size: 16,
                            color: isDark ? Colors.white70 : const Color(0xFF5F4C58),
                          ),
                          Text(
                            'SoulLocket',
                            style: _themeFontStyle(
                              _draftFontKey ?? ui.fontKey,
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: isDark ? Colors.white : const Color(0xFFD81B60),
                            ),
                          ),
                          Icon(
                            Icons.settings_rounded,
                            size: 16,
                            color: isDark ? Colors.white70 : const Color(0xFF5F4C58),
                          ),
                        ],
                      ),
                      const Spacer(flex: 2),
                      // Countdown Circle
                      _buildThemePreviewCountdownCircle(
                        size: _localCountdownSize != null 
                            ? (_localCountdownSize! * 0.36).clamp(90.0, 150.0)
                            : 110.0,
                        fontKey: _draftFontKey ?? ui.fontKey,
                        visual: _themePreviewCountdownVisual(_draftCountdownStyleKey ?? ui.countdownStyleKey),
                        topLabel: _themePreviewLabel(
                          ui.countdownTopLabel,
                          fallback: 'NGÀY BÊN NHAU',
                          uppercase: true,
                        ),
                        valueText: '240',
                        bottomLabel: _themePreviewLabel(
                          ui.countdownBottomLabel,
                          fallback: 'LOVE',
                          uppercase: true,
                        ),
                        styleKey: _draftCountdownStyleKey ?? ui.countdownStyleKey,
                        transparentMode: _draftTransparentMode ?? ui.transparentMode,
                      ),
                      const Spacer(flex: 2),
                      // Presence Card
                      _buildThemePreviewPresenceCard(
                        fontKey: _draftFontKey ?? ui.fontKey,
                        avatarFrameKey: _draftAvatarFrameKey ?? ui.avatarFrameKey,
                        homeToneKey: _draftHomeBlockToneKey ?? ui.homeBlockToneKey,
                        isDark: isDark,
                      ),
                      const Spacer(flex: 3),
                      // Bottom navigation dock preview
                      _buildThemePreviewDock(
                        fontKey: _draftFontKey ?? ui.fontKey,
                        accent: accent,
                        isDark: isDark,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }


  String _themePreviewLabel(
    String raw, {
    required String fallback,
    bool uppercase = false,
    int maxLength = 18,
  }) {
    var value = raw.trim();
    if (value.isEmpty) value = fallback;
    if (uppercase) value = value.toUpperCase();
    if (value.length > maxLength) {
      value = value.substring(0, maxLength);
    }
    return value;
  }

  int _themePreviewAgeDays(String dob) {
    final raw = dob.trim();
    if (raw.isEmpty) return 0;
    try {
      final birth = DateTime.parse(raw);
      final today = DateTime.now();
      final start = DateTime(birth.year, birth.month, birth.day);
      final current = DateTime(today.year, today.month, today.day);
      final diff = current.difference(start).inDays;
      return diff < 0 ? 0 : diff;
    } catch (_) {
      return 0;
    }
  }

  String _themePreviewMilestoneText({
    required int days,
    required bool isSingle,
  }) {
    if (isSingle) {
      return 'Nền và bố cục sẽ hiện đúng như ở trang chủ của bạn.';
    }
    if (days <= 0) {
      return 'Bắt đầu lưu ngày bên nhau ngay từ hôm nay.';
    }
    final nextMonth = (days ~/ 30) + 1;
    final nextMilestoneDays = nextMonth * 30;
    final daysLeft = nextMilestoneDays - days;
    if (daysLeft <= 0) {
      return 'Hôm nay là kỷ niệm tròn ${nextMonth - 1} tháng bên nhau.';
    }
    return 'Còn $daysLeft ngày nữa tới kỷ niệm tròn $nextMonth tháng bên nhau';
  }

  _ThemePreviewCountdownVisual _themePreviewCountdownVisual(String styleKey) {
    switch (styleKey) {
      case 'plain':
        return const _ThemePreviewCountdownVisual(
          outerDecoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            border: Border.fromBorderSide(
              BorderSide(color: Color(0xFFE9DDE6), width: 2.2),
            ),
            boxShadow: [
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 18,
                offset: Offset(0, 8),
              ),
            ],
          ),
          innerDecoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0xFFFBF8FA),
          ),
          numberGradient: [Color(0xFF252036), Color(0xFF51465F)],
          topLabelColor: Color(0xFF51465F),
          bottomLabelColor: Color(0xFF6E6475),
          labelShadows: [],
          numberShadows: [],
          backdropType: 'soft',
        );
      case 'glass':
        return _ThemePreviewCountdownVisual(
          outerDecoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [
                Colors.white.withValues(alpha: 0.92),
                const Color(0xFFE6F7FF).withValues(alpha: 0.64),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: Colors.white.withValues(alpha: 0.82), width: 3),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF8EC5FC).withValues(alpha: 0.34),
                blurRadius: 42,
                offset: const Offset(0, 18),
              ),
            ],
          ),
          innerDecoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.16),
            border:
                Border.all(color: Colors.white.withValues(alpha: 0.42), width: 1.2),
          ),
          numberGradient: const [Color(0xFF27B4FF), Color(0xFFD81B60)],
          topLabelColor: const Color(0xFF2378A8),
          bottomLabelColor: const Color(0xFF51606D),
          labelShadows: [
            Shadow(color: Colors.white.withValues(alpha: 0.85), blurRadius: 8),
          ],
          numberShadows: const [
            Shadow(
              color: Color(0x2E27B4FF),
              blurRadius: 16,
              offset: Offset(0, 6),
            ),
          ],
          backdropType: 'soft',
        );
      case 'glow':
      case 'rose_wave':
        return _ThemePreviewCountdownVisual(
          outerDecoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [Colors.white, Color(0xFFFFF2F8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: Colors.white.withValues(alpha: 0.82), width: 4),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF5E92).withValues(alpha: 0.34),
                blurRadius: 40,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          innerDecoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [
                const Color(0xFFFFC6DA).withValues(alpha: 0.34),
                Colors.white.withValues(alpha: 0.12),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          numberGradient: const [Color(0xFFFF2F7A), Color(0xFFB5179E)],
          topLabelColor: const Color(0xFFC2185B),
          bottomLabelColor: const Color(0xFF7A2C58),
          labelShadows: [
            Shadow(color: Colors.white.withValues(alpha: 0.82), blurRadius: 8),
          ],
          numberShadows: [
            Shadow(
              color: const Color(0xFFFF2F7A).withValues(alpha: 0.32),
              blurRadius: 20,
              offset: const Offset(0, 7),
            ),
          ],
          backdropType: 'glow',
        );
      case 'candy':
      case 'crystal':
        return _ThemePreviewCountdownVisual(
          outerDecoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [Color(0xFFFFE3F3), Color(0xFFE0F7FF), Color(0xFFFFF4C8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: Colors.white.withValues(alpha: 0.88), width: 4),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF77C8).withValues(alpha: 0.24),
                blurRadius: 36,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          innerDecoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.58), width: 1),
          ),
          numberGradient: const [Color(0xFFFF3D9A), Color(0xFF36C9FF)],
          topLabelColor: const Color(0xFFE6378D),
          bottomLabelColor: const Color(0xFF4C6178),
          labelShadows: [
            Shadow(color: Colors.white.withValues(alpha: 0.85), blurRadius: 8),
          ],
          numberShadows: [
            Shadow(
              color: const Color(0xFFFF3D9A).withValues(alpha: 0.24),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
          backdropType: 'soft',
        );
      case 'hyper':
        return _ThemePreviewCountdownVisual(
          outerDecoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const SweepGradient(
              colors: [
                Color(0xFFFF005D),
                Color(0xFFFFD600),
                Color(0xFF00F5FF),
                Color(0xFF7C4DFF),
                Color(0xFFFF00C8),
                Color(0xFFFF005D),
              ],
            ),
            border: Border.all(color: Colors.white.withValues(alpha: 0.88), width: 4),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF00A8).withValues(alpha: 0.42),
                blurRadius: 48,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          innerDecoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.black.withValues(alpha: 0.16),
            border:
                Border.all(color: Colors.white.withValues(alpha: 0.38), width: 1.4),
          ),
          numberGradient: const [
            Colors.white,
            Color(0xFFFFF176),
            Color(0xFF00F5FF)
          ],
          topLabelColor: Colors.white,
          bottomLabelColor: const Color(0xFFFFF59D),
          labelShadows: [
            Shadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 10),
          ],
          numberShadows: [
            Shadow(
              color: const Color(0xFFFF00A8).withValues(alpha: 0.55),
              blurRadius: 24,
              offset: const Offset(0, 7),
            ),
            Shadow(
              color: const Color(0xFF00F5FF).withValues(alpha: 0.42),
              blurRadius: 18,
            ),
          ],
          backdropType: 'cosmic',
        );
      case 'galaxy':
      case 'neon':
      case 'aurora':
      case 'fireworks':
      case 'lava':
        final isLava = styleKey == 'lava';
        final isAurora = styleKey == 'aurora';
        return _ThemePreviewCountdownVisual(
          outerDecoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: isLava
                  ? const [Color(0xFF1A0502), Color(0xFF4A1103)]
                  : isAurora
                      ? const [Color(0xFF001B2E), Color(0xFF021A10)]
                      : const [Color(0xFF120024), Color(0xFF05000F)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: Colors.white.withValues(alpha: 0.22), width: 3),
            boxShadow: [
              BoxShadow(
                color: (isLava
                        ? const Color(0xFFFF5A00)
                        : isAurora
                            ? const Color(0xFF00FFC8)
                            : const Color(0xFF8A2BFF))
                    .withValues(alpha: 0.42),
                blurRadius: 54,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          innerDecoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.black.withValues(alpha: 0.12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.18), width: 1),
          ),
          numberGradient: isLava
              ? const [Color(0xFFFFF176), Color(0xFFFF5A00), Color(0xFFFF1744)]
              : isAurora
                  ? const [
                      Color(0xFFE6FFF9),
                      Color(0xFF00FFC8),
                      Color(0xFF7C4DFF)
                    ]
                  : const [
                      Color(0xFFFFFFFF),
                      Color(0xFF00E5FF),
                      Color(0xFFFF4EBB)
                    ],
          topLabelColor: Colors.white,
          bottomLabelColor:
              isLava ? const Color(0xFFFFD180) : const Color(0xFFBDEBFF),
          labelShadows: [
            Shadow(color: Colors.black.withValues(alpha: 0.48), blurRadius: 10),
          ],
          numberShadows: [
            Shadow(
              color:
                  (isLava ? const Color(0xFFFF5A00) : const Color(0xFF00E5FF))
                      .withValues(alpha: 0.45),
              blurRadius: 22,
              offset: const Offset(0, 7),
            ),
          ],
          backdropType: 'cosmic',
        );
      default:
        return _ThemePreviewCountdownVisual(
          outerDecoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            border: Border.all(color: const Color(0xFFF2EAF0), width: 2.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          innerDecoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0xFFFBF7FA),
          ),
          numberGradient: const [Color(0xFFD81B60), Color(0xFF57D9E9)],
          topLabelColor: const Color(0xFFD9508A),
          bottomLabelColor: const Color(0xFF6B5B79),
          labelShadows: const [],
          numberShadows: const [
            Shadow(
              color: Color(0x22FF7AA8),
              blurRadius: 12,
              offset: Offset(0, 5),
            ),
          ],
          backdropType: 'soft',
        );
    }
  }

  Widget _buildThemePreviewCountdownCircle({
    required double size,
    required String fontKey,
    required _ThemePreviewCountdownVisual visual,
    required String topLabel,
    required String valueText,
    required String bottomLabel,
    required String styleKey,
    required bool transparentMode,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: visual.outerDecoration,
      child: Padding(
        padding: const EdgeInsets.all(7),
        child: Container(
          decoration: visual.innerDecoration,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                child: RepaintBoundary(
                  child: AnimatedWaveBackground(
                    styleKey: styleKey,
                    enableMotion: true,
                    transparentMode: transparentMode,
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: size * 0.12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        topLabel,
                        maxLines: 1,
                        style: _themeFontStyle(
                          fontKey,
                          fontSize: size * 0.085,
                          fontWeight: FontWeight.w900,
                          color: visual.topLabelColor,
                        ).copyWith(
                          letterSpacing: 1.0,
                          shadows: visual.labelShadows,
                        ),
                      ),
                    ),
                    SizedBox(height: size * 0.05),
                    ShaderMask(
                      shaderCallback: (bounds) => LinearGradient(
                        colors: visual.numberGradient,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ).createShader(bounds),
                      child: Text(
                        valueText,
                        style: _themeFontStyle(
                          fontKey,
                          fontSize: size * 0.34,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          height: 0.98,
                        ).copyWith(shadows: visual.numberShadows),
                      ),
                    ),
                    SizedBox(height: size * 0.03),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        bottomLabel,
                        maxLines: 1,
                        style: _themeFontStyle(
                          fontKey,
                          fontSize: size * 0.09,
                          fontWeight: FontWeight.w900,
                          color: visual.bottomLabelColor,
                        ).copyWith(
                          letterSpacing: 0.4,
                          shadows: visual.labelShadows,
                        ),
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

  Widget _buildThemePreviewCountdownBackdrop(
    String backdropType, {
    required double size,
  }) {
    if (backdropType == 'cosmic') {
      return Stack(
        children: [
          Positioned(
            left: size * 0.12,
            top: size * 0.20,
            child: Container(
              width: size * 0.38,
              height: size * 0.38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF8A2BFF).withValues(alpha: 0.75),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            right: size * 0.12,
            bottom: size * 0.18,
            child: Container(
              width: size * 0.34,
              height: size * 0.34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF00E5FF).withValues(alpha: 0.82),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          ...const [
            (0.18, 0.22, 3.0),
            (0.74, 0.28, 2.0),
            (0.28, 0.64, 2.5),
            (0.60, 0.72, 3.0),
            (0.48, 0.18, 2.2),
            (0.76, 0.58, 1.8),
          ].map(
            (item) => Positioned(
              left: size * item.$1,
              top: size * item.$2,
              child: Container(
                width: item.$3,
                height: item.$3,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.82),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        ],
      );
    }

    if (backdropType == 'glow') {
      return Stack(
        children: [
          Positioned(
            left: size * 0.18,
            top: size * 0.18,
            child: Container(
              width: size * 0.48,
              height: size * 0.48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFFFFA1C2).withValues(alpha: 0.42),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildThemePreviewPresenceCard({
    required String fontKey,
    required String avatarFrameKey,
    required String homeToneKey,
    required bool isDark,
  }) {
    final leftName = _nameU1.trim().isEmpty ? 'Bạn' : _nameU1.trim();
    final rightName = _nameU2.trim().isEmpty ? 'Người ấy' : _nameU2.trim();
    final status1 = _showStatus ? 'Off 26 phút trước' : '';
    final status2 = _showStatus ? 'Đang hoạt động' : '';
    final weather1 = _showWeather ? '☀ 27°C' : '';
    final weather2 = _showWeather ? '☀ 27°C' : '';

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 10),
      decoration: _previewHomeCardDecoration(homeToneKey, isDark).copyWith(
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _buildThemePreviewProfileColumn(
              name: leftName,
              avatarUrl: _avatarUrl1,
              avatarFrameKey: avatarFrameKey,
              ageBadge: _themePreviewAgeDays(_dobU1) > 0
                  ? '${_themePreviewAgeDays(_dobU1)}'
                  : '',
              status: status1,
              weather: weather1,
              fontKey: fontKey,
              isUser1: true,
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(top: 18, left: 6, right: 6),
            child: Text(
              '💖',
              style: TextStyle(fontSize: 24, height: 1),
            ),
          ),
          Expanded(
            child: _buildThemePreviewProfileColumn(
              name: _relationshipMode == 'single' ? 'Chờ kết nối' : rightName,
              avatarUrl: _relationshipMode == 'single' ? '' : _avatarUrl2,
              avatarFrameKey: avatarFrameKey,
              ageBadge: _relationshipMode == 'single'
                  ? ''
                  : (_themePreviewAgeDays(_dobU2) > 0
                      ? '${_themePreviewAgeDays(_dobU2)}'
                      : ''),
              status: _relationshipMode == 'single' ? '' : status2,
              weather: _relationshipMode == 'single' ? '' : weather2,
              fontKey: fontKey,
              isUser1: false,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThemePreviewProfileColumn({
    required String name,
    required String avatarUrl,
    required String avatarFrameKey,
    required String ageBadge,
    required String status,
    required String weather,
    required String fontKey,
    required bool isUser1,
  }) {
    const avatarSize = 44.0;
    final accent = isUser1 ? const Color(0xFF2563EB) : const Color(0xFFFF4D79);
    final avatarImage = _buildThemePreviewAvatarImage(
      avatarUrl,
      accent,
      name,
    );

    return Column(
      children: [
        SlAvatarFrame(
          frameKey: avatarFrameKey,
          size: avatarSize,
          accentColor: accent,
          isUser1: isUser1,
          child: avatarImage,
        ),
        if (ageBadge.isNotEmpty) ...[
          const SizedBox(height: 5),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isUser1
                    ? const [Color(0xFF60A5FA), Color(0xFF2563EB)]
                    : const [Color(0xFFFF8FB1), Color(0xFFFF4D79)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              ageBadge,
              style: _themeFontStyle(
                fontKey,
                fontSize: 7.4,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
          ),
        ],
        const SizedBox(height: 5),
        Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: _themeFontStyle(
            fontKey,
            fontSize: 9.2,
            fontWeight: FontWeight.w900,
            color: const Color(0xFF273244),
          ),
        ),
        if (status.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            status,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: _themeFontStyle(
              fontKey,
              fontSize: 6.9,
              fontWeight: FontWeight.w800,
              color: status.contains('Đang')
                  ? const Color(0xFF22C55E)
                  : const Color(0xFF94A3B8),
            ),
          ),
        ],
        if (weather.isNotEmpty) ...[
          const SizedBox(height: 5),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.78),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.white.withValues(alpha: 0.88)),
            ),
            child: Text(
              weather,
              style: _themeFontStyle(
                fontKey,
                fontSize: 6.8,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF5B6470),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildThemePreviewAvatarImage(
    String avatarUrl,
    Color accent,
    String name,
  ) {
    if (avatarUrl.trim().isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: avatarUrl.trim(),
        fit: BoxFit.cover,
        filterQuality: FilterQuality.medium,
        errorWidget: (_, __, ___) =>
            _buildThemePreviewAvatarFallback(accent, name),
      );
    }
    return _buildThemePreviewAvatarFallback(accent, name);
  }

  Widget _buildThemePreviewAvatarFallback(Color accent, String name) {
    final trimmed = name.trim();
    final letter = trimmed.isEmpty ? 'S' : trimmed[0];
    return Container(
      color: accent.withValues(alpha: 0.16),
      alignment: Alignment.center,
      child: Text(
        letter.toUpperCase(),
        style: SLTheme.quicksand(
          fontSize: 18,
          fontWeight: FontWeight.w900,
          color: accent,
        ),
      ),
    );
  }

  Widget _buildThemePreviewEffectLayer(
    String effectKey,
    Color accent,
    bool isDark,
  ) {
    final effectColor = isDark ? Colors.white : accent;
    final faintColor = effectColor.withValues(alpha: isDark ? 0.24 : 0.16);

    switch (effectKey) {
      case 'hearts':
        return const Stack(
          children: [
            Positioned(
              left: 22,
              top: 84,
              child: Text('💕', style: TextStyle(fontSize: 13, height: 1)),
            ),
            Positioned(
              right: 26,
              top: 118,
              child: Text('💖', style: TextStyle(fontSize: 12, height: 1)),
            ),
            Positioned(
              left: 34,
              bottom: 136,
              child: Text('💗', style: TextStyle(fontSize: 11, height: 1)),
            ),
          ],
        );
      case 'stars':
      case 'sparkles':
      default:
        return Stack(
          children: [
            Positioned(
              left: 24,
              top: 96,
              child:
                  Icon(Icons.auto_awesome_rounded, size: 9, color: faintColor),
            ),
            Positioned(
              right: 30,
              top: 142,
              child:
                  Icon(Icons.auto_awesome_rounded, size: 10, color: faintColor),
            ),
            Positioned(
              left: 40,
              bottom: 126,
              child: Icon(Icons.star_rounded, size: 8, color: faintColor),
            ),
            Positioned(
              right: 46,
              bottom: 154,
              child: Icon(Icons.star_rounded, size: 7, color: faintColor),
            ),
          ],
        );
    }
  }

  Widget _buildThemePreviewDock({
    required String fontKey,
    required Color accent,
    required bool isDark,
  }) {
    final items = <(IconData, String, Color, bool)>[
      (Icons.home_rounded, 'Home', accent, true),
      (Icons.public_rounded, 'Xã hội', const Color(0xFF38BDF8), false),
      (Icons.menu_book_rounded, 'Nhật ký', const Color(0xFF22C55E), false),
      (Icons.widgets_rounded, 'Tiện ích', const Color(0xFFA78BFA), false),
      (
        Icons.sports_esports_rounded,
        'Vui chơi',
        const Color(0xFFF59E0B),
        false
      ),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: isDark ? 0.80 : 0.88),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.88)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: items.map((item) {
          return Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: item.$4
                        ? item.$3.withValues(alpha: 0.16)
                        : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(item.$1, size: 12, color: item.$3),
                ),
                const SizedBox(height: 3),
                Text(
                  item.$2,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _themeFontStyle(
                    fontKey,
                    fontSize: 5.9,
                    fontWeight: FontWeight.w900,
                    color: item.$3,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  String _resolvePreviewThemeKey(String themeKey) {
    final key = themeKey.trim();
    if (key.isEmpty || key == UiPrefsState.defaults.themeKey) {
      return UiPrefsState.defaults.themeKey;
    }
    if (key == 'theme-vip-rotate') {
      const rotatingThemes = <String>[
        'theme-pink-glow',
        'theme-default',
        'theme-sunset',
        'theme-ocean',
        'theme-night',
      ];
      final slot = DateTime.now().millisecondsSinceEpoch ~/
          const Duration(seconds: 30).inMilliseconds;
      return rotatingThemes[slot % rotatingThemes.length];
    }
    if (key != 'theme-auto') {
      return key;
    }

    final now = DateTime.now();
    final isNight = now.hour >= 19 || now.hour < 6;
    if (isNight) return 'theme-night';

    switch (now.month) {
      case 12:
      case 1:
      case 2:
        return 'theme-pink-glow';
      case 6:
      case 7:
      case 8:
        return 'theme-ocean';
      case 9:
      case 10:
      case 11:
        return 'theme-sunset';
      default:
        return 'theme-default';
    }
  }

  String _resolvePreviewEffectKey(String effectKey, String resolvedThemeKey) {
    final raw = effectKey.trim();
    final key = raw.isEmpty ? 'auto' : raw;
    if (key != 'auto') return key;

    final now = DateTime.now();
    if (_isPreviewDarkTheme(resolvedThemeKey)) {
      return 'stars';
    }
    if (now.month == 12 || now.month == 1) {
      return 'snow';
    }
    if (now.month >= 9 && now.month <= 11) {
      return 'leaves';
    }

    switch (resolvedThemeKey) {
      case 'theme-ocean':
        return 'bubbles';
      case 'theme-sunset':
        return 'meteors';
      case 'theme-crazy-party':
        return 'hearts';
      default:
        return 'sparkles';
    }
  }

  bool _isPreviewDarkTheme(String themeKey) {
    return themeKey == 'theme-night' ||
        themeKey == 'theme-dark' ||
        themeKey == 'theme-true-black' ||
        themeKey == 'theme-mystic-dark';
  }

  List<Color> _previewThemeGradient(String themeKey, bool isDark) {
    switch (themeKey) {
      case 'theme-night':
        return const [
          Color(0xFF141E30),
          Color(0xFF243B55),
          Color(0xFF4A00E0),
          Color(0xFF8E2DE2),
        ];
      case 'theme-dark':
        return const [
          Color(0xFF0A0A0A),
          Color(0xFF1A1A1A),
          Color(0xFF2D2D2D),
          Color(0xFF1A1A1A),
        ];
      case 'theme-true-black':
        return const [
          Color(0xFF000000),
          Color(0xFF050505),
          Color(0xFF0A0A0A),
          Color(0xFF000000),
        ];
      case 'theme-mystic-dark':
        return const [
          Color(0xFF0F0C29),
          Color(0xFF302B63),
          Color(0xFF24243E),
          Color(0xFF0F0C29),
        ];
      case 'theme-ocean':
        return const [
          Color(0xFF4FACFE),
          Color(0xFF00F2FE),
          Color(0xFF43E97B),
          Color(0xFF38F9D7),
        ];
      case 'theme-sunset':
        return const [
          Color(0xFFFF0844),
          Color(0xFFFFB199),
          Color(0xFFFA709A),
          Color(0xFFFEE140),
        ];
      case 'theme-crazy-party':
        return const [
          Color(0xFFFF2400),
          Color(0xFFE8B71D),
          Color(0xFF1DE840),
          Color(0xFF2B1DE8),
        ];
      case 'theme-pink-glow':
        return const [
          Color(0xFFFFE4E1),
          Color(0xFFFFC0CB),
          Color(0xFFFBC2EB),
          Color(0xFFFF9A9E),
        ];
      default:
        return isDark
            ? const [
                Color(0xFF1A1430),
                Color(0xFF241C3E),
                Color(0xFF302552),
              ]
            : const [
                Color(0xFFFFF3F8),
                Color(0xFFFEE8F0),
                Color(0xFFEFDFFF),
              ];
    }
  }

  Color _previewThemeAccent(String themeKey) {
    switch (themeKey) {
      case 'theme-night':
        return const Color(0xFF8E9BFF);
      case 'theme-dark':
      case 'theme-true-black':
        return const Color(0xFFB39DDB);
      case 'theme-mystic-dark':
        return const Color(0xFF9C6BFF);
      case 'theme-ocean':
        return const Color(0xFF00B8D4);
      case 'theme-sunset':
        return const Color(0xFFFF6B6B);
      case 'theme-crazy-party':
        return const Color(0xFFFF4D8D);
      case 'theme-pink-glow':
        return const Color(0xFFFF5E92);
      default:
        return const Color(0xFFD81B60);
    }
  }
}
