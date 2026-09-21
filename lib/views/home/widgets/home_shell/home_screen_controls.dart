// ignore_for_file: unused_element, unused_field, unused_local_variable, unused_import, dead_code
part of '../../home_screen.dart';

extension _HomeScreenShellControls on _HomeScreenState {
  static final L10nService _l10nService = L10nService();

  Widget _buildBottomNav() {
    // Thanh điều hướng luôn trắng kem, độc lập với theme/ảnh nền Home.
    const isDark = false;
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
                      final isIos =
                          !kIsWeb &&
                          defaultTargetPlatform == TargetPlatform.iOS;
                      final extraBottomPadding = isIos
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
    final navSurface = SoulNavigationSurface(
      key: _firstGuideBottomNavKey,
      isDark: isDark,
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
            RepaintBoundary(child: navSurface),
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
    return NavigationRestoreHandle(
      key: const ValueKey('collapsed-nav'),
      accent: _HomeScreenState._navItems[currentIndex].activeColor,
      onRestore: () => _setNavCollapsed(false),
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

    return SoulNavigationTile(
      label: _l10nService.translate(item.labelKey),
      icon: _getIconForTab(index, isActive: isActive),
      accent: item.activeColor,
      selected: isActive,
      isDark: isDark,
      iconKey: targetKey,
      reduceMotion: isPerformanceMode,
      onTap: () {
        unawaited(HapticFeedback.lightImpact());
        _switchToTab(index);
      },
    );
  }
}
