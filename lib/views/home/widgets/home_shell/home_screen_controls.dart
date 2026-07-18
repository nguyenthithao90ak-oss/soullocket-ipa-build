// ignore_for_file: unused_element, unused_field, unused_local_variable, unused_import, dead_code
part of '../../home_screen.dart';

extension _HomeScreenShellControls on _HomeScreenState {
  Widget _buildBottomNav({required bool isDark}) {
    return ValueListenableBuilder<bool>(
      valueListenable: _isBottomNavVisibleNotifier,
      builder: (context, isVisible, child) {
        return AnimatedSlide(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
          offset: isVisible ? Offset.zero : const Offset(0, 1.2),
          child: child,
        );
      },
      child: ValueListenableBuilder<bool>(
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
                    final bottomInset = MediaQuery.paddingOf(context).bottom;
                    final extraBottomPadding = Platform.isIOS 
                        ? (bottomInset > 0 ? bottomInset / 2.5 : 0.0) // Hạ thấp trên iOS cho gọn
                        : (bottomInset > 0 ? bottomInset : 0.0);
                    return Padding(
                      padding: EdgeInsets.only(bottom: extraBottomPadding),
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
    ),
  );
}

  Widget _buildExpandedBottomNav({
    required bool isDark,
    required int currentIndex,
    required bool isSwiping,
  }) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final accent = _HomeScreenState._navItems[currentIndex].activeColor;
    final uiState = UiPrefs.notifier.value;
    final effectProfile = _resolveHomeEffectProfile(
      uiState,
      pauseAnimations: isSwiping,
    );
    final isPerformanceMode = effectProfile.performanceMode;
    const useBackdropBlur = true;

    final navSurface = Container(
      key: _firstGuideBottomNavKey,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF2D2D3A).withValues(alpha: 0.65)
            : const Color(0xFFF3EEEA).withValues(alpha: 0.65),
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
              alpha: isDark ? 0.25 : 0.06,
            ),
            blurRadius: 10,
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
        padding: EdgeInsets.fromLTRB(24, 0, 24, bottomInset > 0 ? 4 : 12),
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
              top: 0, // Move up slightly so it doesn't overlap the icon
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _setNavCollapsed(true),
                  onLongPress: _hideBottomNavForSession,
                  borderRadius: SLRadius.pillAll,
                  child: Ink(
                    width: 40,
                    height: 20, // Slightly larger hit area
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: SLRadius.pillAll,
                    ),
                    child: Center(
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 16, // Slightly larger to be visible without background
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
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
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
                  child: Icon(
                    Icons.keyboard_arrow_up_rounded,
                    size: 16,
                    color: isDark ? Colors.white : accent,
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
    if (index == 1) {
      targetKey = _firstGuideDiaryTabKey;
    } else if (index == 2) {
      targetKey = _firstGuideUtilitiesTabKey;
    } else if (index == 3) {
      targetKey = _firstGuideEntertainmentTabKey;
    } else if (index == 4) {
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
            ).animate(target: isActive ? 1 : 0).shimmer(duration: 400.ms).scaleXY(begin: 0.95, end: 1.0, duration: 200.ms, curve: Curves.easeOutBack),
          ),
        ),
      ),
    );
  }
}
