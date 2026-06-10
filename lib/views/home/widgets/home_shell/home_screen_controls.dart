part of '../../home_screen.dart';

extension _HomeScreenShellControls on _HomeScreenState {
  Widget _buildMusicButton() {
    return ValueListenableBuilder<bool>(
      valueListenable: MusicService().isVisibleNotifier,
      builder: (context, isVisible, child) {
        if (!isVisible) return const SizedBox.shrink();

        return Positioned(
          bottom: 120,
          right: 20,
          child: ValueListenableBuilder<bool>(
            valueListenable: MusicService().isPlayingNotifier,
            builder: (context, isPlaying, child) {
              final shouldPulse = isPlaying && _musicController.isAnimating;
              return GestureDetector(
                onTap: MusicService().toggle,
                child: shouldPulse
                    ? AnimatedBuilder(
                        animation: _musicController,
                        builder: (context, child) {
                          return _buildMusicButtonVisual(
                            isPlaying: isPlaying,
                            animationValue: _musicController.value,
                          );
                        },
                      )
                    : _buildMusicButtonVisual(isPlaying: isPlaying),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildMusicButtonVisual({
    required bool isPlaying,
    double animationValue = 0,
  }) {
    final scale = isPlaying ? 1.0 + (animationValue * 0.05) : 1.0;
    return Transform.scale(
      scale: scale,
      child: Container(
        width: 58,
        height: 58,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [SLTheme.primary, SLTheme.accentPurple],
          ),
          boxShadow: [
            BoxShadow(
              color: SLTheme.primary.withValues(alpha: isPlaying ? 0.4 : 0.2),
              blurRadius: isPlaying ? 15 : 10,
              spreadRadius: isPlaying ? (animationValue * 3) : 0,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (isPlaying)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (index) {
                  final baseHeights = [10.0, 18.0, 14.0, 22.0];
                  final animatedHeight = baseHeights[index] +
                      ((index.isEven ? 1 : -1) * animationValue * 8);
                  return Container(
                    width: 3,
                    height: animatedHeight,
                    margin: const EdgeInsets.symmetric(horizontal: 1.5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.45),
                      borderRadius: SLRadius.smAll,
                    ),
                  );
                }),
              ),
            Icon(
              isPlaying ? Icons.music_note : Icons.music_off,
              color: Colors.white,
              size: 24,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNav({required bool isDark}) {
    return ValueListenableBuilder<bool>(
      valueListenable: _navCollapsedNotifier,
      builder: (context, navCollapsed, _) {
        return ValueListenableBuilder<bool>(
          valueListenable: UiPrefs.captureModeNotifier,
          builder: (context, captureMode, _) {
            if (_navHiddenUntilRestart ||
                _hideNavForDiarySelection ||
                captureMode) {
              return const SizedBox.shrink();
            }
            return ValueListenableBuilder<int>(
              valueListenable: _backgroundTabIndexNotifier,
              builder: (context, currentIndex, _) {
                final effectProfile = _resolveHomeEffectProfile(
                  UiPrefs.notifier.value,
                  pauseAnimations: _isUserTabSwiping,
                );
                return AnimatedSize(
                  duration: effectProfile.performanceMode
                      ? Duration.zero
                      : const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.bottomCenter,
                  child: navCollapsed
                      ? _buildCollapsedNavHandle(
                          isDark: isDark,
                          currentIndex: currentIndex,
                        )
                      : _buildExpandedBottomNav(
                          isDark: isDark,
                          currentIndex: currentIndex,
                        ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildExpandedBottomNav({
    required bool isDark,
    required int currentIndex,
  }) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final accent = _HomeScreenState._navItems[currentIndex].activeColor;
    final uiState = UiPrefs.notifier.value;
    final effectProfile = _resolveHomeEffectProfile(
      uiState,
      pauseAnimations: _isUserTabSwiping,
    );
    final isPerformanceMode = effectProfile.performanceMode;
    final useBackdropBlur = effectProfile.premiumEffects &&
        MediaQuery.of(context).size.shortestSide >= 600;
    final navSurface = Container(
      key: _firstGuideBottomNavKey,
      padding: EdgeInsets.fromLTRB(6, 8, 6, bottomInset > 0 ? bottomInset : 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [
                  const Color(0xFF151A25).withValues(
                    alpha: isPerformanceMode ? 0.98 : 0.95,
                  ),
                  const Color(0xFF20293A).withValues(
                    alpha: isPerformanceMode ? 0.96 : 0.92,
                  ),
                  const Color(0xFF141A24).withValues(
                    alpha: isPerformanceMode ? 0.98 : 0.95,
                  ),
                ]
              : [
                  const Color(0xFFFFF8FB).withValues(
                    alpha: isPerformanceMode ? 0.995 : 0.98,
                  ),
                  const Color(0xFFFFEEF5).withValues(
                    alpha: isPerformanceMode ? 0.992 : 0.97,
                  ),
                  const Color(0xFFF8F2FF).withValues(
                    alpha: isPerformanceMode ? 0.988 : 0.95,
                  ),
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
        border: Border(
          top: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.white.withValues(alpha: 0.96),
            width: 1.15,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: isDark
                  ? (isPerformanceMode ? 0.20 : 0.34)
                  : (isPerformanceMode ? 0.06 : 0.12),
            ),
            blurRadius: isPerformanceMode ? 12 : 24,
            offset: Offset(0, isPerformanceMode ? -4 : -8),
          ),
          if (!isDark && !isPerformanceMode)
            BoxShadow(
              color: const Color(0xFFFF89AF).withValues(alpha: 0.11),
              blurRadius: 24,
              offset: const Offset(0, -4),
            ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          for (var i = 0; i < _HomeScreenState._navItems.length; i++) ...[
            Expanded(
              child: _buildNavItem(
                i,
                isDark,
                currentIndex: currentIndex,
                isPerformanceMode: isPerformanceMode,
              ),
            ),
          ],
        ],
      ),
    );

    return GestureDetector(
      onVerticalDragEnd: (details) {
        if (details.primaryVelocity != null && details.primaryVelocity! > 0) {
          _setNavCollapsed(true);
        }
      },
      child: Padding(
        key: const ValueKey('expanded-nav'),
        padding: EdgeInsets.zero,
        child: Stack(
          alignment: Alignment.topCenter,
          clipBehavior: Clip.none,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: RepaintBoundary(
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(30),
                    topRight: Radius.circular(30),
                  ),
                  child: !useBackdropBlur
                      ? navSurface
                      : FastBackdropFilter(
                          filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                          fallbackColor: Colors.transparent,
                          child: navSurface,
                        ),
                ),
              ),
            ),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _setNavCollapsed(true),
                onLongPress: _hideBottomNavForSession,
                borderRadius: SLRadius.pillAll,
                child: Ink(
                  width: 32,
                  height: 14,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isDark
                          ? [
                              Colors.white.withValues(alpha: 0.10),
                              Colors.white.withValues(alpha: 0.05),
                            ]
                          : [
                              Colors.white.withValues(alpha: 0.98),
                              Color.lerp(accent, Colors.white, 0.84) ??
                                  Colors.white.withValues(alpha: 0.98),
                            ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    borderRadius: SLRadius.pillAll,
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : accent.withValues(alpha: 0.20),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black
                            .withValues(alpha: isDark ? 0.18 : 0.08),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 14,
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.84)
                          : accent.withValues(alpha: 0.88),
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

  Widget _buildCollapsedNavHandle({
    required bool isDark,
    required int currentIndex,
  }) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final accent = _HomeScreenState._navItems[currentIndex].activeColor;
    return GestureDetector(
      onVerticalDragEnd: (details) {
        if (details.primaryVelocity != null && details.primaryVelocity! < 0) {
          _setNavCollapsed(false);
        }
      },
      child: Padding(
        key: const ValueKey('collapsed-nav'),
        padding:
            EdgeInsets.fromLTRB(12, 0, 12, bottomInset > 0 ? bottomInset : 0),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _setNavCollapsed(false),
              onLongPress: _hideBottomNavForSession,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
              child: Ink(
                width: 44,
                height: 14,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [
                            const Color(0xFF1A2231).withValues(alpha: 0.94),
                            const Color(0xFF253047).withValues(alpha: 0.92),
                          ]
                        : [
                            Colors.white.withValues(alpha: 0.97),
                            Color.lerp(accent, Colors.white, 0.90) ??
                                Colors.white,
                          ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                  border: Border(
                    top: BorderSide(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.09)
                          : accent.withValues(alpha: 0.18),
                      width: 1.1,
                    ),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color:
                          Colors.black.withValues(alpha: isDark ? 0.24 : 0.10),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Center(
                  child: SizedBox(
                    width: 14,
                    height: 10,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Positioned(
                          top: -5,
                          child: Icon(
                            Icons.keyboard_arrow_up_rounded,
                            size: 14,
                            color: isDark ? Colors.white : accent,
                          ),
                        ),
                        Positioned(
                          bottom: -5,
                          child: Icon(
                            Icons.keyboard_arrow_up_rounded,
                            size: 14,
                            color: isDark ? Colors.white : accent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
    int index,
    bool isDark, {
    required int currentIndex,
    required bool isPerformanceMode,
  }) {
    final item = _HomeScreenState._navItems[index];
    final isActive = currentIndex == index;
    final animationDuration =
        isPerformanceMode ? Duration.zero : const Duration(milliseconds: 180);
    final inactiveColor = isDark
        ? Color.lerp(item.activeColor, Colors.white, 0.30) ?? item.activeColor
        : Color.lerp(item.activeColor, const Color(0xFF64748B), 0.22) ??
            item.activeColor;

    GlobalKey? targetKey;
    if ((!_HomeScreenState._communityTabEnabled && index == 1) ||
        (_HomeScreenState._communityTabEnabled && index == 2)) {
      targetKey = _firstGuideDiaryTabKey;
    } else if ((!_HomeScreenState._communityTabEnabled && index == 2) ||
        (_HomeScreenState._communityTabEnabled && index == 3)) {
      targetKey = _firstGuideUtilitiesTabKey;
    } else if ((!_HomeScreenState._communityTabEnabled && index == 4) ||
        (_HomeScreenState._communityTabEnabled && index == 5)) {
      targetKey = _firstGuideUpdateTabKey;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 1.0),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _switchToTab(index),
          borderRadius: SLRadius.lgAll,
          child: AnimatedContainer(
            duration: animationDuration,
            curve: Curves.easeOutCubic,
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 1, vertical: 6),
            decoration: BoxDecoration(
              color: isActive
                  ? item.activeColor.withValues(alpha: isDark ? 0.12 : 0.08)
                  : Colors.transparent,
              borderRadius: SLRadius.lgAll,
            ),
            child: Center(
              child: KeyedSubtree(
                key: targetKey,
                child: AnimatedScale(
                  duration: animationDuration,
                  curve: Curves.easeOutCubic,
                  scale: isActive && !isPerformanceMode ? 1.12 : 1,
                  child: Transform.translate(
                    offset: Offset(0, isActive ? -0.2 : 0),
                    child: Icon(
                      _getIconForTab(index),
                      color: isActive ? item.activeColor : inactiveColor,
                      size: isActive ? 24 : 21,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
