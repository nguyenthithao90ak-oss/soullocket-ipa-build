// ignore_for_file: unused_element, unused_field, unused_local_variable, unused_import, dead_code
part of '../../home_screen.dart';

extension _HomeScreenShellControls on _HomeScreenState {
  static final L10nService _l10nService = L10nService();

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
      child: ValueListenableBuilder<int>(
        valueListenable: _backgroundTabIndexNotifier,
        builder: (context, currentIndex, _) {
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
                      final effectProfile = _resolveHomeEffectProfile(
                        UiPrefs.notifier.value,
                        pauseAnimations: isSwiping,
                      );
                      final bottomInset = MediaQuery.paddingOf(context).bottom;
                      final extraBottomPadding = Platform.isIOS
                          ? (bottomInset > 0 ? bottomInset / 2.5 : 0.0)
                          : (bottomInset > 0 ? bottomInset : 0.0);
                      return AnimatedSize(
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
    final viewportWidth = MediaQuery.sizeOf(context).width;
    final horizontalInset = viewportWidth > 784
        ? (viewportWidth - 760) / 2
        : 12.0;
    final uiState = UiPrefs.notifier.value;
    final effectProfile = _resolveHomeEffectProfile(
      uiState,
      pauseAnimations: isSwiping,
    );
    final isPerformanceMode = effectProfile.performanceMode;
    const useBackdropBlur = false;

    final navSurface = Container(
      key: _firstGuideBottomNavKey,
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 9),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF2A2430).withValues(alpha: 0.96)
            : SLColors.paper.withValues(alpha: 0.97),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.12)
              : SLColors.border,
          width: 1.1,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.34)
                : SLColors.ink.withValues(alpha: 0.12),
            blurRadius: 24,
            spreadRadius: -8,
            offset: const Offset(0, 10),
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
          horizontalInset,
          0,
          horizontalInset,
          bottomInset > 0 ? bottomInset + 5 : 10,
        ),
        child: Stack(
          alignment: Alignment.topCenter,
          clipBehavior: Clip.none,
          children: [
            RepaintBoundary(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: !useBackdropBlur
                    ? navSurface
                    : FastBackdropFilter(
                        filter: ui.ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                        fallbackColor: isDark
                            ? const Color(0xFF1E1E28)
                            : Colors.white,
                        child: navSurface,
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
                    width: 60,
                    height: 20,
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: SLRadius.pillAll,
                    ),
                    child: Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.2)
                              : Colors.black.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
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
    final animationDuration = isPerformanceMode
        ? Duration.zero
        : const Duration(milliseconds: 200);
    final inactiveColor = isDark
        ? const Color(0x99FFFFFF)
        : SLColors.textTertiary;

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
            // Không khóa cứng chiều cao: metric của font có thể cao hơn 1px
            // trên Android/Web và làm RenderFlex báo tràn ở mép dưới.
            constraints: const BoxConstraints(minHeight: 52),
            padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
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
                  child: AnimatedContainer(
                    duration: animationDuration,
                    curve: Curves.easeOutBack,
                    width: isActive ? 34 : 30,
                    height: 28,
                    decoration: BoxDecoration(
                      color: isActive
                          ? item.activeColor.withValues(alpha: 0.13)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(11),
                      border: isActive
                          ? Border.all(
                              color: item.activeColor.withValues(alpha: 0.22),
                            )
                          : null,
                    ),
                    child: Icon(
                      _getIconForTab(index, isActive: isActive),
                      color: isActive ? item.activeColor : inactiveColor,
                      size: isActive ? 21 : 20,
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _l10nService.translate(item.labelKey),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: SLTheme.quicksand(
                    fontSize: 9.2,
                    fontWeight: isActive ? FontWeight.w900 : FontWeight.w700,
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
