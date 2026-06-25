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
            return ValueListenableBuilder<bool>(
              valueListenable: _isUserTabSwipingNotifier,
              builder: (context, isSwiping, _) {
                return ValueListenableBuilder<int>(
                  valueListenable: _backgroundTabIndexNotifier,
                  builder: (context, currentIndex, _) {
                    final effectProfile = _resolveHomeEffectProfile(
                      UiPrefs.notifier.value,
                      pauseAnimations: isSwiping,
                    );
                    final bottomInset = MediaQuery.of(context).padding.bottom;
                    return Padding(
                      padding: EdgeInsets.only(bottom: bottomInset > 0 ? bottomInset : 0),
                      child: AnimatedSize(
                        duration: effectProfile.performanceMode || isSwiping
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
                                isSwiping: isSwiping,
                              ),
                      ),
                    );
                  },
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
    required bool isSwiping,
  }) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final accent = _HomeScreenState._navItems[currentIndex].activeColor;
    final uiState = UiPrefs.notifier.value;
    final effectProfile = _resolveHomeEffectProfile(
      uiState,
      pauseAnimations: isSwiping,
    );
    final isPerformanceMode = effectProfile.performanceMode;
    final useBackdropBlur = effectProfile.premiumEffects && !isPerformanceMode && !isSwiping;

    final navSurface = Container(
      key: _firstGuideBottomNavKey,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.black.withValues(alpha: 0.60)
            : Colors.black.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(40),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.12)
              : Colors.black.withValues(alpha: 0.08),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: isDark ? 0.18 : 0.04,
            ),
            blurRadius: 8,
            offset: const Offset(0, 4),
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
        padding: EdgeInsets.fromLTRB(
            24, 0, 24, bottomInset > 0 ? 4 : 12),
        child: Stack(
          alignment: Alignment.topCenter,
          clipBehavior: Clip.none,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: RepaintBoundary(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(40),
                  child: !useBackdropBlur
                      ? navSurface
                      : FastBackdropFilter(
                          filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                          fallbackColor: Colors.transparent,
                          child: navSurface,
                        ),
                ),
              ),
            ),
            Positioned(
              top: 0,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _setNavCollapsed(true),
                  onLongPress: _hideBottomNavForSession,
                  borderRadius: SLRadius.pillAll,
                  child: Ink(
                    width: 28,
                    height: 10,
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.12)
                          : Colors.white,
                      borderRadius: SLRadius.pillAll,
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.1)
                            : accent.withValues(alpha: 0.20),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black
                              .withValues(alpha: isDark ? 0.2 : 0.06),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 10,
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.8)
                            : accent.withValues(alpha: 0.9),
                      ),
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
            const EdgeInsets.fromLTRB(12, 0, 12, 0),
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
                  color: Colors.transparent,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                  border: Border(
                    top: BorderSide(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.09)
                          : accent.withValues(alpha: 0.15),
                      width: 1.1,
                    ),
                  ),
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
        isPerformanceMode ? Duration.zero : const Duration(milliseconds: 200);
    final inactiveColor =
        isDark ? Colors.white.withValues(alpha: 0.5) : const Color(0xFF94A3B8);

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
          onTap: () {
            unawaited(HapticFeedback.lightImpact());
            _switchToTab(index);
          },
          borderRadius: BorderRadius.circular(24),
          child: AnimatedContainer(
            duration: animationDuration,
            curve: Curves.easeOutCubic,
            height: 46,
            padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                KeyedSubtree(
                  key: targetKey,
                  child: AnimatedScale(
                    duration: animationDuration,
                    curve: Curves.easeOutBack,
                    scale: isActive && !isPerformanceMode ? 1.1 : 1.0,
                    child: Icon(
                      _getIconForTab(index),
                      color: isActive ? item.activeColor : inactiveColor,
                      size: isActive ? 20 : 19,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  L10nService().translate(item.labelKey),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: SLTheme.quicksand(
                    fontSize: 8.5,
                    fontWeight: isActive ? FontWeight.w800 : FontWeight.w500,
                    color: isActive ? item.activeColor : inactiveColor,
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
