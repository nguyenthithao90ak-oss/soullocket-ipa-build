// ignore_for_file: invalid_use_of_protected_member

part of '../../soul_rhythm_game.dart';

extension _SoulRhythmMenuScreen on _SoulRhythmGameState {
  Widget _buildMenuScreen() {
    final width = MediaQuery.of(context).size.width;
    final compact = width < 390;
    final laneCount = width < 430 ? '3' : '4';
    final menuGlowScale =
        _isHighGraphics ? 1.0 : (_isLowGraphics ? 0.55 : 0.78);
    return Container(
      color: const Color(0xE605050F),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Center(
              child: SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight,
                    maxWidth: 432,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              _buildHudChip(
                                'BEST SCORE',
                                _highScore.toString(),
                                const Color(0xFFFFEB3B),
                              ),
                              _buildHudChip(
                                'GRAPHICS',
                                _graphicsChipValue,
                                _graphicsChipColor,
                              ),
                            ],
                          ),
                          _buildMiniBtn(
                            icon: Icons.exit_to_app_rounded,
                            onTap: () => Navigator.of(context).pop(),
                          ),
                        ],
                      ),
                      SizedBox(height: compact ? 10 : 14),
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.symmetric(
                          horizontal: compact ? 14 : 18,
                          vertical: compact ? 14 : 16,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(26),
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFF161024).withValues(alpha: 0.96),
                              const Color(0xFF0F1830).withValues(alpha: 0.94),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.1),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF00E5FF)
                                  .withValues(alpha: 0.10 * menuGlowScale),
                              blurRadius: 18 + (10 * menuGlowScale),
                            ),
                            BoxShadow(
                              color: const Color(0xFFFF0055)
                                  .withValues(alpha: 0.14 * menuGlowScale),
                              blurRadius: 16 + (8 * menuGlowScale),
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            _buildTrackPreviewPanel(compact),
                            const SizedBox(height: 10),
                            ShaderMask(
                              shaderCallback: (bounds) => const LinearGradient(
                                colors: [
                                  Color(0xFFFF00CC),
                                  Color(0xFFFF0055),
                                  Color(0xFFFF9900),
                                  Color(0xFFFFEB3B),
                                ],
                              ).createShader(bounds),
                              child: Text(
                                'SOUL RHYTHM',
                                textAlign: TextAlign.center,
                                style: SLTheme.quicksand(
                                  fontSize: compact ? 24 : 30,
                                  height: 1,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  letterSpacing: 1.4,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _customTrackBytes != null
                                  ? context.tr('util_officialtr_2dbfca')
                                  : 'Fixed Unity chart · melody locked',
                              textAlign: TextAlign.center,
                              style: SLTheme.quicksand(
                                fontSize: compact ? 12.5 : 13.5,
                                fontWeight: FontWeight.w900,
                                color: Colors.white70,
                                letterSpacing: 1.0,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildMetaChip(
                                    icon: Icons.view_week_rounded,
                                    label: 'LANES',
                                    value: laneCount,
                                    color: const Color(0xFFFF4081),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _buildMetaChip(
                                    icon: Icons.album_rounded,
                                    label: 'TRACK',
                                    value: _displayTrackLabel,
                                    color: const Color(0xFFFF6EC7),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              alignment: WrapAlignment.center,
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _buildToggleChip(
                                  icon: _musicAutoplayEnabled
                                      ? Icons.music_note_rounded
                                      : Icons.music_off_rounded,
                                  label: 'MUSIC',
                                  value: _musicAutoplayEnabled ? 'ON' : 'OFF',
                                  color: const Color(0xFF00E5FF),
                                  active: _musicAutoplayEnabled,
                                  onTap: () =>
                                      unawaited(_toggleMusicAutoplay()),
                                ),
                                _buildToggleChip(
                                  icon: _touchSoundEnabled
                                      ? Icons.touch_app_rounded
                                      : Icons.pan_tool_alt_rounded,
                                  label: 'TAP FX',
                                  value: _touchSoundEnabled ? 'ON' : 'OFF',
                                  color: const Color(0xFFFFEB3B),
                                  active: _touchSoundEnabled,
                                  onTap: () => unawaited(_toggleTouchSound()),
                                ),
                                _buildToggleChip(
                                  icon: _isLowGraphics
                                      ? Icons.speed_rounded
                                      : Icons.auto_awesome_rounded,
                                  label: 'LOW FX',
                                  value: _isLowGraphics ? 'ON' : 'OFF',
                                  color: const Color(0xFFFFA726),
                                  active: _isLowGraphics,
                                  onTap: () => unawaited(_toggleLowGraphics()),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            _buildPrimaryPlayButton(compact),
                          ],
                        ),
                      ),
                      SizedBox(height: compact ? 10 : 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.055),
                          borderRadius: BorderRadius.circular(22),
                          border:
                              Border.all(color: Colors.white.withValues(alpha: 0.09)),
                        ),
                        child: Column(
                          children: [
                            Text(
                              context.tr('util_chnch_52d13c'),
                              style: SLTheme.quicksand(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                color: Colors.white54,
                                letterSpacing: 1.8,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              alignment: WrapAlignment.center,
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _buildDiffBtn(
                                    'easy', Icons.eco_rounded, 'Easy'),
                                _buildDiffBtn(
                                  'normal',
                                  Icons.flash_on_rounded,
                                  'Normal',
                                ),
                                _buildDiffBtn(
                                  'hard',
                                  Icons.whatshot_rounded,
                                  'Hard',
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: SLRadius.lgAll,
                        ),
                        child: Text(
                          _displayMixTitle,
                          style: SLTheme.quicksand(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: Colors.white54,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildTrackPreviewPanel(bool compact) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 12 : 14,
        vertical: compact ? 10 : 12,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Hero(
            tag: 'soul-rhythm-cover',
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image(
                image: _gameIconProvider(
                  devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
                ),
                width: compact ? 48 : 54,
                height: compact ? 48 : 54,
                fit: BoxFit.cover,
                filterQuality: FilterQuality.high,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _displayMixTitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: SLTheme.quicksand(
                fontSize: compact ? 11.5 : 12.5,
                fontWeight: FontWeight.w800,
                color: Colors.white70,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrimaryPlayButton(bool compact) {
    final glowStrength = _isHighGraphics ? 1.0 : (_isLowGraphics ? 0.55 : 0.78);
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _startGame,
            borderRadius: BorderRadius.circular(24),
            splashColor: Colors.white.withValues(alpha: 0.16),
            highlightColor: Colors.transparent,
            child: Ink(
              width: double.infinity,
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 16 : 18,
                vertical: compact ? 11 : 12,
              ),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFFFF3D81),
                    Color(0xFFFF7DBE),
                    Color(0xFF6FE8FF),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0x99FF0055),
                    blurRadius:
                        (14 + (_pulseController.value * 8)) * glowStrength,
                    spreadRadius: (_pulseController.value * 1.6) * glowStrength,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 0,
                    child: Container(
                      height: 18,
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(24),
                        ),
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withValues(alpha: 0.22),
                            Colors.transparent,
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.16),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'ENTER STAGE',
                              style: SLTheme.quicksand(
                                fontSize: compact ? 17 : 19,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                            SLSpacing.gapH(1),
                            Text(
                              'Launch $_displayTrackLabel anthem mix',
                              style: SLTheme.quicksand(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: Colors.white70,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_rounded,
                        color: Colors.white.withValues(alpha: 0.92),
                        size: 20,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildToggleChip({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required bool active,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        splashColor: color.withValues(alpha: 0.18),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: active
                ? color.withValues(alpha: 0.16)
                : Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: active ? color.withValues(alpha: 0.75) : Colors.white24,
            ),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.22),
                      blurRadius: 12,
                      offset: const Offset(0, 5),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                transitionBuilder: (child, animation) => ScaleTransition(
                  scale: animation,
                  child: FadeTransition(opacity: animation, child: child),
                ),
                child: Icon(
                  icon,
                  key: ValueKey(icon),
                  size: 16,
                  color: active ? color : Colors.white60,
                ),
              ),
              const SizedBox(width: 6),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: SLTheme.quicksand(
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      color: Colors.white54,
                      letterSpacing: 1.0,
                    ),
                  ),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    transitionBuilder: (child, animation) => SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.2),
                        end: Offset.zero,
                      ).animate(animation),
                      child: FadeTransition(opacity: animation, child: child),
                    ),
                    child: Text(
                      value,
                      key: ValueKey('$label-$value'),
                      style: SLTheme.quicksand(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: active ? color : Colors.white70,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetaChip({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: SLTheme.quicksand(
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  color: Colors.white54,
                  letterSpacing: 1.0,
                ),
              ),
              Text(
                value,
                style: SLTheme.quicksand(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDiffBtn(String id, IconData icon, String label) {
    final isSelected = _difficulty == id;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: SLRadius.xlAll,
        onTap: () {
          unawaited(_playSfx(_selectBytes, volume: 0.74));
          if (!_touchSoundEnabled) {
            SystemSound.play(SystemSoundType.click);
          }
          HapticFeedback.lightImpact();
          setState(() {
            _difficulty = id;
            _rebuildGameChartForDifficulty();
          });
        },
        splashColor: const Color(0xFF00E5FF).withValues(alpha: 0.18),
        child: AnimatedScale(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          scale: isSelected ? 1.02 : 1,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            width: 96,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFF00E5FF).withValues(alpha: 0.18)
                  : Colors.white.withValues(alpha: 0.05),
              borderRadius: SLRadius.xlAll,
              border: Border.all(
                color: isSelected
                    ? const Color(0xFF00E5FF)
                    : Colors.white.withValues(alpha: 0.1),
                width: isSelected ? 2 : 1,
              ),
              boxShadow: isSelected
                  ? [
                      const BoxShadow(
                        color: Color(0x6600E5FF),
                        blurRadius: 12,
                        offset: Offset(0, 5),
                      ),
                    ]
                  : null,
            ),
            child: Column(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.white.withValues(alpha: 0.12)
                        : Colors.white.withValues(alpha: 0.04),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    color:
                        isSelected ? const Color(0xFF00E5FF) : Colors.white70,
                    size: 19,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  label.toUpperCase(),
                  style: SLTheme.quicksand(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: isSelected ? Colors.white : Colors.white54,
                    letterSpacing: 0.9,
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
