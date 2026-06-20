part of '../../tabs/main_home_tab.dart';

class _ModernHomeBody extends StatefulWidget {
  final _MainHomeTabState state;
  final bool isSingle;
  final String houseName;
  final String smartGreeting;
  final String circleValue;
  final String circleTopLabel;
  final String circleBottomLabel;
  final String? startDate;
  final String nameU1;
  final String nameU2;
  final String avtUser1;
  final String avtUser2;
  final double circleSize;
  final bool homeShowHouseName;
  final String customBackgroundUrl;
  final bool showDayCounter;
  final bool showLoveTimeDetail;
  final String countdownStyleKey;
  final VoidCallback? onEditStartDate;
  final VoidCallback? onEditTopLabel;
  final VoidCallback? onEditBottomLabel;
  final VoidCallback? onOpenSettings;

  const _ModernHomeBody({
    required this.state,
    required this.isSingle,
    required this.houseName,
    required this.smartGreeting,
    required this.circleValue,
    required this.circleTopLabel,
    required this.circleBottomLabel,
    this.startDate,
    required this.nameU1,
    required this.nameU2,
    required this.avtUser1,
    required this.avtUser2,
    required this.circleSize,
    required this.homeShowHouseName,
    required this.customBackgroundUrl,
    required this.showDayCounter,
    required this.showLoveTimeDetail,
    required this.countdownStyleKey,
    this.onEditStartDate,
    this.onEditTopLabel,
    this.onEditBottomLabel,
    this.onOpenSettings,
  });

  @override
  State<_ModernHomeBody> createState() => _ModernHomeBodyState();
}

class _ModernHomeBodyState extends State<_ModernHomeBody> {
  late final ValueNotifier<bool> _isDraggingNotifier;

  @override
  void initState() {
    super.initState();
    _isDraggingNotifier = ValueNotifier<bool>(false);
  }

  @override
  void dispose() {
    _isDraggingNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final uiState = UiPrefs.notifier.value;
    final effectProfile = UiPrefs.resolveEffectProfile(
      state: uiState,
      isWeb: kIsWeb,
    );
    final showDecorGlow = !effectProfile.performanceMode;
    final screenWidth = MediaQuery.of(context).size.width;
    final horizontalPadding = SLResponsive.horizontalPaddingForWidth(
      screenWidth,
      compactPadding: 12,
      handsetPadding: 16,
      tabletPadding: 24,
    );
    final contentWidth = SLResponsive.maxContentWidthForWidth(
      screenWidth,
      handsetMax: 520,
      tabletMax: 620,
      desktopMax: 680,
    );

    return Stack(
      children: [
        Positioned.fill(
          child: RepaintBoundary(
            child: Stack(
              children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF2A1523).withValues(alpha: 0.18),
                          const Color(0xFF5B2544).withValues(alpha: 0.12),
                          const Color(0xFF120A11).withValues(alpha: 0.08),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ),
                Positioned.fill(child: SLTheme.meshPattern()),
                if (showDecorGlow) ...[
                  Positioned(
                    top: -88,
                    right: -72,
                    child: _HomeDecorGlow(
                      size: 210,
                      color: SLColors.primary.withValues(alpha: 0.20),
                    ),
                  ),
                  Positioned(
                    top: 250,
                    left: -96,
                    child: _HomeDecorGlow(
                      size: 230,
                      color: SLColors.secondary.withValues(alpha: 0.16),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            if (notification is ScrollStartNotification) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  widget.state._isScrollingNotifier.value = true;
                }
              });
            } else if (notification is ScrollEndNotification) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  widget.state._isScrollingNotifier.value = false;
                }
              });
            }
            return false;
          },
          child: ValueListenableBuilder<bool>(
            valueListenable: _isDraggingNotifier,
            builder: (context, isDragging, _) {
              return SingleChildScrollView(
                physics: isDragging
                    ? const NeverScrollableScrollPhysics()
                    : const BouncingScrollPhysics(),
                padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: contentWidth),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        SizedBox(height: MediaQuery.of(context).padding.top + 36),
                        RepaintBoundary(
                          child: widget.state.widget.isSwipingListenable == null
                              ? _MainHomeHeroCountdownSection(
                                  state: widget.state,
                                  isSingle: widget.isSingle,
                                  houseName: widget.houseName,
                                  smartGreeting: widget.smartGreeting,
                                  circleValue: widget.circleValue,
                                  circleTopLabel: widget.circleTopLabel,
                                  circleBottomLabel: widget.circleBottomLabel,
                                  startDate: widget.startDate,
                                  circleSize: widget.circleSize,
                                  homeShowHouseName: widget.homeShowHouseName,
                                  showDayCounter: widget.showDayCounter,
                                  showLoveTimeDetail: widget.showLoveTimeDetail,
                                  countdownStyleKey: widget.countdownStyleKey,
                                  enableMotion: effectProfile.animationEnabled &&
                                      !widget.state._deferHeavyHomeMotion,
                                  onEditStartDate: widget.onEditStartDate,
                                  onEditTopLabel: widget.onEditTopLabel,
                                  onEditBottomLabel: widget.onEditBottomLabel,
                                  firstGuideHeroKey: widget.state.widget.firstGuideHeroKey,
                                )
                              : ValueListenableBuilder<bool>(
                                  valueListenable: widget.state.widget.isSwipingListenable!,
                                  builder: (context, isSwiping, _) {
                                    return _MainHomeHeroCountdownSection(
                                      state: widget.state,
                                      isSingle: widget.isSingle,
                                      houseName: widget.houseName,
                                      smartGreeting: widget.smartGreeting,
                                      circleValue: widget.circleValue,
                                      circleTopLabel: widget.circleTopLabel,
                                      circleBottomLabel: widget.circleBottomLabel,
                                      startDate: widget.startDate,
                                      circleSize: widget.circleSize,
                                      homeShowHouseName: widget.homeShowHouseName,
                                      showDayCounter: widget.showDayCounter,
                                      showLoveTimeDetail: widget.showLoveTimeDetail,
                                      countdownStyleKey: widget.countdownStyleKey,
                                      enableMotion: effectProfile.animationEnabled &&
                                          !isSwiping &&
                                          !widget.state._deferHeavyHomeMotion,
                                      onEditStartDate: widget.onEditStartDate,
                                      onEditTopLabel: widget.onEditTopLabel,
                                      onEditBottomLabel: widget.onEditBottomLabel,
                                      firstGuideHeroKey: widget.state.widget.firstGuideHeroKey,
                                    );
                                  },
                                ),
                        ),
                        SLSpacing.h8,
                        RepaintBoundary(
                          child: widget.state._buildModernAvatarSection(
                            isSingle: widget.isSingle,
                            nameU1: widget.nameU1,
                            nameU2: widget.nameU2,
                            avtUser1: widget.avtUser1,
                            avtUser2: widget.avtUser2,
                          ),
                        ),
                        SLSpacing.h20,
                        _HomeBlockDragList(
                          uiState: uiState,
                          isSingle: widget.isSingle,
                          contentWidth: contentWidth,
                          effectProfile: effectProfile,
                          state: widget.state,
                          startDate: widget.startDate,
                          nameU1: widget.nameU1,
                          nameU2: widget.nameU2,
                          isDraggingNotifier: _isDraggingNotifier,
                        ),
                        RepaintBoundary(
                          child: widget.state._buildHomeToolSlotSection(),
                        ),
                        SLSpacing.gapH(148),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        _MainHomeHeroHeader(
          state: widget.state,
          isSingle: widget.isSingle,
          onOpenSettings: widget.onOpenSettings,
          firstGuideSettingsKey: widget.state.widget.firstGuideSettingsKey,
        ),
      ],
    );
  }
}

extension _MainHomeTabHeroSection on _MainHomeTabState {}

/// Widget xử lý kéo thả sắp xếp lại các block card trên màn hình chính.
/// Dùng LongPressDraggable + DragTarget. Freeze scroll của parent khi đang kéo
/// thông qua [scrollPhysicsNotifier] — notifier được cung cấp bởi _ModernHomeBody.
class _HomeBlockDragList extends StatefulWidget {
  final UiPrefsState uiState;
  final bool isSingle;
  final double contentWidth;
  final UiEffectProfile effectProfile;
  final _MainHomeTabState state;
  final String? startDate;
  final String nameU1;
  final String nameU2;
  /// Notifier cho phép widget này tắt scroll của SingleChildScrollView bên ngoài
  /// khi người dùng đang kéo card.
  final ValueNotifier<bool> isDraggingNotifier;

  const _HomeBlockDragList({
    required this.uiState,
    required this.isSingle,
    required this.contentWidth,
    required this.effectProfile,
    required this.state,
    required this.startDate,
    required this.nameU1,
    required this.nameU2,
    required this.isDraggingNotifier,
  });

  @override
  State<_HomeBlockDragList> createState() => _HomeBlockDragListState();
}

class _HomeBlockDragListState extends State<_HomeBlockDragList> {
  List<String> get _visibleKeys {
    final orderedKeys = widget.uiState.homeBlockOrder.isEmpty
        ? const ['highlight', 'map', 'insight']
        : widget.uiState.homeBlockOrder;
    final activeKeys = widget.isSingle
        ? const ['map', 'insight']
        : const ['highlight', 'map', 'insight'];
    final result = orderedKeys.where((k) => activeKeys.contains(k)).toList();
    for (final key in activeKeys) {
      if (!result.contains(key)) result.add(key);
    }
    return result;
  }

  Widget _buildBlock(String key) {
    switch (key) {
      case 'highlight':
        if (widget.isSingle) return const SizedBox.shrink();
        return widget.state._buildModernHighlightCard(
          startDate: widget.startDate,
          isSingle: widget.isSingle,
          dragHandle: null,
        );
      case 'map':
        return widget.state._buildModernMapCard(
          nameU1: widget.nameU1,
          nameU2: widget.nameU2,
          dragHandle: null,
        );
      case 'insight':
        final enableMotion = widget.effectProfile.animationEnabled &&
            !widget.state._deferHeavyHomeMotion;
        if (widget.state.widget.isSwipingListenable == null) {
          return widget.state._buildModernInsightCard(
            isSingle: widget.isSingle,
            nameU1: widget.nameU1,
            nameU2: widget.nameU2,
            enableMotion: enableMotion,
            dragHandle: null,
          );
        }
        return ValueListenableBuilder<bool>(
          valueListenable: widget.state.widget.isSwipingListenable!,
          builder: (context, isSwiping, _) {
            return widget.state._buildModernInsightCard(
              isSingle: widget.isSingle,
              nameU1: widget.nameU1,
              nameU2: widget.nameU2,
              enableMotion: enableMotion && !isSwiping,
              dragHandle: null,
            );
          },
        );
      default:
        return const SizedBox.shrink();
    }
  }

  void _onReorder(String draggedKey, String targetKey) {
    final orderedKeys = widget.uiState.homeBlockOrder.isEmpty
        ? const ['highlight', 'map', 'insight']
        : widget.uiState.homeBlockOrder;
    final visibleKeys = _visibleKeys;
    final oldIndex = visibleKeys.indexOf(draggedKey);
    final newIndex = visibleKeys.indexOf(targetKey);
    if (oldIndex == -1 || newIndex == -1 || oldIndex == newIndex) return;
    final updatedKeys = List<String>.from(orderedKeys);
    updatedKeys.remove(draggedKey);
    final destIdx = updatedKeys.indexOf(targetKey);
    if (destIdx != -1) {
      updatedKeys.insert(
        oldIndex < newIndex ? destIdx + 1 : destIdx,
        draggedKey,
      );
    } else {
      updatedKeys.add(draggedKey);
    }
    unawaited(UiPrefs.saveState(
      widget.uiState.copyWith(homeBlockOrder: updatedKeys),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final visibleKeys = _visibleKeys;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: visibleKeys.map((key) {
        final childWidget = Container(
          margin: const EdgeInsets.only(bottom: 20),
          child: RepaintBoundary(child: _buildBlock(key)),
        );

        return DragTarget<String>(
          key: ValueKey('target_$key'),
          onWillAcceptWithDetails: (details) => details.data != key,
          onAcceptWithDetails: (details) => _onReorder(details.data, key),
          builder: (context, candidateData, rejectedData) {
            final isOver = candidateData.isNotEmpty;
            return LongPressDraggable<String>(
              data: key,
              hapticFeedbackOnStart: true,
              onDragStarted: () {
                widget.isDraggingNotifier.value = true;
              },
              onDragEnd: (_) {
                widget.isDraggingNotifier.value = false;
              },
              onDraggableCanceled: (_, __) {
                widget.isDraggingNotifier.value = false;
              },
              onDragCompleted: () {
                widget.isDraggingNotifier.value = false;
              },
              feedback: Material(
                color: Colors.transparent,
                child: SizedBox(
                  width: widget.contentWidth,
                  child: Transform.scale(
                    scale: 1.03,
                    child: Opacity(opacity: 0.88, child: childWidget),
                  ),
                ),
              ),
              childWhenDragging: Opacity(
                opacity: 0.25,
                child: childWidget,
              ),
              child: AnimatedScale(
                scale: isOver ? 0.97 : 1.0,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                child: childWidget,
              ),
            );
          },
        );
      }).toList(),
    );
  }
}

class _HomeDecorGlow extends StatelessWidget {
  final double size;
  final Color color;

  const _HomeDecorGlow({
    required this.size,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color,
              color.withValues(alpha: 0.0),
            ],
          ),
        ),
      ),
    );
  }
}
