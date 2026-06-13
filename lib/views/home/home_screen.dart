// ignore_for_file: unused_element, unused_field, unused_local_variable, dead_code, deprecated_member_use, use_super_parameters, prefer_const_constructors, use_build_context_synchronously, duplicate_ignore, avoid_web_libraries_in_flutter, avoid_unnecessary_containers
import 'dart:async';
import 'dart:ui' as ui;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter/material.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import '../../utils/services/offline_cache_service.dart';

import '../../core/sl_route.dart';
import '../../core/sl_theme.dart';
import '../../utils/services/auth_service.dart';
import '../../utils/services/device_manager_service.dart';
import '../../utils/services/friends_service.dart';
import '../../utils/services/house_service.dart';
import '../../utils/services/home_startup_media_cache.dart';
import '../../utils/services/house_settings_service.dart';
import '../../utils/services/music_service.dart';
import '../../utils/services/breakup_service.dart';
import '../../utils/services/military_lock_service.dart';
import '../../utils/services/notification_service.dart';
import '../../utils/services/role_utils.dart';
import '../../utils/services/schedule_notif_service.dart';
import '../../utils/services/webrtc_service.dart';
import '../../utils/services/widget_action_service.dart';
import '../../utils/services/update_checker_service.dart';
import '../../widgets/legacy_falling_effect.dart';
import '../../widgets/touch_effect_overlay.dart';
import '../notifications/notification_center_screen.dart';
import '../chat/chat_detail_screen.dart';
import '../relationship/couple_connect_screen.dart';
import '../relationship/video_call_screen.dart';
import '../utilities/calendar_screen.dart';
import 'love_insights_screen.dart';
import '../ui_prefs.dart';
import 'tabs/community_tab.dart';
import 'tabs/diary_tab.dart';
import 'tabs/game_tab.dart';
import 'tabs/main_home_tab.dart';
import 'tabs/settings_tab.dart' show SettingsTab;
import 'tabs/update_tab.dart';
import 'tabs/utilities_tab.dart';
import '../utilities/utility_sticker_icon.dart';
import '../../utils/services/widget_service.dart';
import '../../utils/sl_notice.dart';
import '../../utils/app_error_mapper.dart';
import '../../widgets/first_setup_spotlight_guide.dart';
import '../../core/fast_backdrop_filter.dart';

part 'widgets/home_shell/home_screen_sync_flows.dart';
part 'widgets/home_shell/home_screen_notice_flows.dart';
part 'widgets/home_shell/home_screen_background.dart';
part 'widgets/home_shell/home_screen_controls.dart';

class HomeScreen extends StatefulWidget {
  final int initialTab;

  const HomeScreen({super.key, this.initialTab = 0});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _NavItem {
  final String labelKey;
  final Color activeColor;

  const _NavItem({
    required this.labelKey,
    required this.activeColor,
  });
}

typedef _HomeTabBuilder = Widget Function(bool isActive);

class _TabActivationHost extends StatefulWidget {
  final int tabIndex;
  final ValueListenable<int> activeIndexListenable;
  final _HomeTabBuilder builder;

  const _TabActivationHost({
    required this.tabIndex,
    required this.activeIndexListenable,
    required this.builder,
  });

  @override
  State<_TabActivationHost> createState() => _TabActivationHostState();
}

class _TabActivationHostState extends State<_TabActivationHost> {
  late bool _isActive;
  Widget? _cachedChild;

  @override
  void initState() {
    super.initState();
    _isActive = widget.activeIndexListenable.value == widget.tabIndex;
    widget.activeIndexListenable.addListener(_onActiveIndexChanged);
    _cachedChild = widget.builder(_isActive);
  }

  @override
  void didUpdateWidget(covariant _TabActivationHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activeIndexListenable != widget.activeIndexListenable ||
        oldWidget.tabIndex != widget.tabIndex) {
      oldWidget.activeIndexListenable.removeListener(_onActiveIndexChanged);
      _isActive = widget.activeIndexListenable.value == widget.tabIndex;
      widget.activeIndexListenable.addListener(_onActiveIndexChanged);
    }
    // Update cache if the builder itself changes (e.g., from a hot reload or parent rebuild)
    if (oldWidget.builder != widget.builder) {
      _cachedChild = widget.builder(_isActive);
    }
  }

  @override
  void dispose() {
    widget.activeIndexListenable.removeListener(_onActiveIndexChanged);
    super.dispose();
  }

  void _onActiveIndexChanged() {
    final nextActive = widget.activeIndexListenable.value == widget.tabIndex;
    if (_isActive != nextActive) {
      setState(() {
        _isActive = nextActive;
        _cachedChild = widget.builder(_isActive);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return TickerMode(
      enabled: _isActive,
      child: _cachedChild ?? widget.builder(_isActive),
    );
  }
}

class _KeepAliveTabPage extends StatefulWidget {
  final Widget child;

  const _KeepAliveTabPage({
    super.key,
    required this.child,
  });

  @override
  State<_KeepAliveTabPage> createState() => _KeepAliveTabPageState();
}

class _KeepAliveTabPageState extends State<_KeepAliveTabPage>
    with AutomaticKeepAliveClientMixin<_KeepAliveTabPage> {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

class _HomeTabPagePhysics extends PageScrollPhysics {
  static const double _pageSwitchThreshold = 0.46;
  static const double _dragThreshold = 3.0;
  static const double _minFlingDistanceMultiplier = 0.82;
  static const double _minFlingVelocityMultiplier = 0.88;

  const _HomeTabPagePhysics({super.parent});

  @override
  _HomeTabPagePhysics applyTo(ScrollPhysics? ancestor) {
    return _HomeTabPagePhysics(parent: buildParent(ancestor));
  }

  double _getPage(ScrollMetrics position) {
    if (position is PageMetrics) {
      return position.page ?? 0.0;
    }
    final safeViewport =
        position.viewportDimension == 0 ? 1.0 : position.viewportDimension;
    return position.pixels / safeViewport;
  }

  double _getPixels(ScrollMetrics position, double page) {
    final viewportFraction =
        position is PageMetrics ? position.viewportFraction : 1.0;
    final safeViewport = (position.viewportDimension * viewportFraction) == 0
        ? 1.0
        : (position.viewportDimension * viewportFraction);
    return page * safeViewport;
  }

  double _getTargetPixels(ScrollMetrics position, double velocity) {
    final page = _getPage(position);
    final basePage = page.floorToDouble();

    double targetPage;
    if (velocity >= minFlingVelocity) {
      targetPage = basePage + 1.0;
    } else if (velocity <= -minFlingVelocity) {
      targetPage = page.ceilToDouble() - 1.0;
    } else {
      final pageFraction = page - basePage;
      targetPage =
          pageFraction >= _pageSwitchThreshold ? basePage + 1.0 : basePage;
    }

    final targetPixels = _getPixels(position, targetPage);
    if (targetPixels < position.minScrollExtent) {
      return position.minScrollExtent;
    }
    if (targetPixels > position.maxScrollExtent) {
      return position.maxScrollExtent;
    }
    return targetPixels;
  }

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    if ((velocity <= 0.0 && position.pixels <= position.minScrollExtent) ||
        (velocity >= 0.0 && position.pixels >= position.maxScrollExtent)) {
      return super.createBallisticSimulation(position, velocity);
    }

    final tolerance = toleranceFor(position);
    final target = _getTargetPixels(position, velocity);
    if ((target - position.pixels).abs() <= tolerance.distance) {
      return null;
    }

    return ScrollSpringSimulation(
      spring,
      position.pixels,
      target,
      velocity,
      tolerance: tolerance,
    );
  }

  @override
  double get minFlingDistance =>
      super.minFlingDistance * _minFlingDistanceMultiplier;

  @override
  double get minFlingVelocity =>
      super.minFlingVelocity * _minFlingVelocityMultiplier;

  @override
  double? get dragStartDistanceMotionThreshold => _dragThreshold;
}

class _HomePreloadPageView extends StatefulWidget {
  final PageController controller;
  final List<Widget> children;
  final ValueChanged<int>? onPageChanged;
  final ScrollPhysics? physics;
  final DragStartBehavior dragStartBehavior;

  const _HomePreloadPageView({
    required this.controller,
    required this.children,
    this.onPageChanged,
    this.physics,
    this.dragStartBehavior = DragStartBehavior.start,
  });

  @override
  State<_HomePreloadPageView> createState() => _HomePreloadPageViewState();
}

class _HomePreloadPageViewState extends State<_HomePreloadPageView> {
  late int _lastReportedPage;

  @override
  void initState() {
    super.initState();
    _lastReportedPage = _clampPage(widget.controller.initialPage);
  }

  @override
  void didUpdateWidget(covariant _HomePreloadPageView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _lastReportedPage = _clampPage(_lastReportedPage);
  }

  int _clampPage(int page) {
    if (widget.children.isEmpty) {
      return 0;
    }
    return page.clamp(0, widget.children.length - 1);
  }

  AxisDirection _axisDirectionFor(BuildContext context) {
    return textDirectionToAxisDirection(Directionality.of(context));
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    if (notification.depth != 0 || widget.onPageChanged == null) {
      return false;
    }

    final metrics = notification.metrics;
    if (metrics is! PageMetrics) {
      return false;
    }

    if (notification is ScrollEndNotification) {
      final currentPage =
          metrics.page ?? widget.controller.initialPage.toDouble();
      final closestPage = _clampPage(currentPage.round());
      if (closestPage != _lastReportedPage) {
        if (mounted) {
          setState(() {
            _lastReportedPage = closestPage;
          });
        }
        widget.onPageChanged?.call(closestPage);
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final axisDirection = _axisDirectionFor(context);
    // Render all tabs upfront so they are warmed in layout, preventing any build overhead during swipe transitions.
    final cacheExtent = widget.children.length.toDouble();

    return NotificationListener<ScrollNotification>(
      onNotification: _handleScrollNotification,
      child: Scrollable(
        axisDirection: axisDirection,
        controller: widget.controller,
        physics: widget.physics,
        dragStartBehavior: widget.dragStartBehavior,
        viewportBuilder: (context, position) {
          return Viewport(
            axisDirection: axisDirection,
            offset: position,
            cacheExtent: cacheExtent,
            cacheExtentStyle: CacheExtentStyle.viewport,
            clipBehavior: Clip.hardEdge,
            slivers: [
              SliverFillViewport(
                viewportFraction: widget.controller.viewportFraction,
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    return RepaintBoundary(
                      child: widget.children[index],
                    );
                  },
                  childCount: widget.children.length,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  int _currentIndex = 0;
  bool _navCollapsed =
      OfflineCacheService.getPrefsSync()?.getBool(_navCollapsedPrefsKey) ??
          false;
  bool _navHiddenUntilRestart = false;
  bool _hideNavForDiarySelection = false;
  late final ValueNotifier<bool> _navCollapsedNotifier;
  late final ValueNotifier<bool> _isUserTabSwipingNotifier;
  bool _didCheckCoupleOnboarding = false;
  bool _didCheckNewUserWelcomeNotice = false;
  bool _didCheckFirstSetupGuide = false;
  bool _didCheckPendingDeviceNotice = false;
  bool _isShowingBreakupEntryNotice = false;
  final _houseService = HouseService();
  final _houseSettingsService = HouseSettingsService();
  final _breakupService = BreakupService();
  late final List<_HomeTabBuilder> _tabBuilders;
  final Map<int, Widget> _tabPageCache = <int, Widget>{};
  int _homeReloadCounter = 0;
  late final ValueNotifier<int> _activeTabIndexNotifier;
  late final ValueNotifier<int>
      _backgroundTabIndexNotifier; // ⚡ Thêm để tránh rebuild toàn bộ
  late final ValueNotifier<int> _vipThemeRotationTickNotifier;
  late final PageController _pageController;
  DateTime? _lastExitAttemptAt;
  bool _isUserTabSwiping = false;
  final GlobalKey _firstGuideHomeHeroKey = GlobalKey();
  final GlobalKey _firstGuideSettingsKey = GlobalKey();
  final GlobalKey _firstGuideBottomNavKey = GlobalKey();
  final GlobalKey _firstGuideDiaryTabKey = GlobalKey();
  final GlobalKey _firstGuideUtilitiesTabKey = GlobalKey();
  final GlobalKey _firstGuideUpdateTabKey = GlobalKey();

  late AnimationController _musicController;

  StreamSubscription? _callSub;
  StreamSubscription? _settingsSub;
  StreamSubscription<WidgetLaunchAction>? _widgetActionSub;
  StreamSubscription<DatabaseEvent>? _notificationBadgeSub;
  Timer? _vipThemeRotateTimer;
  Timer? _startupTasksTimer;
  Timer? _startupAnimationTimer;
  String _prewarmedBackgroundUrl = '';
  bool _isPrewarmingShellMedia = false;
  bool _allowStartupAnimations = false;
  Map<String, dynamic>? _incomingCall;
  String? _notificationBadgeHouseId;

  static const String _navCollapsedPrefsKey = 'il_home_nav_collapsed_v2';
  static const String _lastTabPrefsKey = 'il_home_last_tab_v1';
  static const String _countdownPinnedLaunchPrefsKey =
      'il_countdown_mode_pinned_launch_v1';
  static const int _notificationBadgeLimit = 75;
  static const Duration _homeStartupTaskDelay = Duration(milliseconds: 700);
  static const Duration _homeStartupAnimationDelay =
      Duration(milliseconds: 900);
  static const MethodChannel _appControlChannel =
      MethodChannel('soul_locket/app_control');
  static const bool _communityTabEnabled = false;

  static const List<String> _vipRotatingThemes = <String>[
    'theme-pink-glow',
    'theme-default',
    'theme-sunset',
    'theme-ocean',
    'theme-night',
  ];

  static const _navItems = [
    _NavItem(labelKey: 'nav_home', activeColor: Color(0xFFFF4B91)),
    if (_communityTabEnabled)
      _NavItem(labelKey: 'nav_feed', activeColor: Color(0xFF4FC3F7)),
    _NavItem(labelKey: 'nav_diary', activeColor: Color(0xFF00C853)),
    _NavItem(labelKey: 'nav_apps', activeColor: Color(0xFFB388FF)),
    _NavItem(labelKey: 'nav_fun', activeColor: Color(0xFFFFAB00)),
    _NavItem(labelKey: 'nav_update', activeColor: Color(0xFF2979FF)),
  ];

  @override
  void initState() {
    super.initState();
    RoleUtils.roleNotifier.addListener(_handleGlobalRoleChanged);
    _currentIndex = widget.initialTab.clamp(0, _navItems.length - 1);
    _activeTabIndexNotifier = ValueNotifier<int>(_currentIndex);
    _backgroundTabIndexNotifier =
        ValueNotifier<int>(_currentIndex); // ⚡ Init background notifier
    _vipThemeRotationTickNotifier = ValueNotifier<int>(0);
    _navCollapsedNotifier = ValueNotifier<bool>(_navCollapsed);
    _isUserTabSwipingNotifier = ValueNotifier<bool>(false);
    _pageController = PageController(initialPage: _currentIndex);
    _tabBuilders = [
      (isActive) => MainHomeTab(
            isActive: isActive,
            onOpenSettings: _openSettings,
            isSwipingListenable: _isUserTabSwipingNotifier,
          ),
      if (_communityTabEnabled) (isActive) => CommunityTab(isActive: isActive),
      (isActive) => DiaryTab(
            isActive: isActive,
            onSelectionOverlayChanged: _handleDiarySelectionOverlayChanged,
            isSwipingListenable: _isUserTabSwipingNotifier,
          ),
      (_) => const UtilitiesTab(),
      (_) => const GameTab(),
      (_) => const UpdateTab(),
    ];
    _tabPageCache[_currentIndex] = _buildTabPage(_currentIndex);
    _musicController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );
    final musicService = MusicService();
    musicService.isPlayingNotifier.addListener(_handleMusicPlaybackChanged);
    musicService.isVisibleNotifier.addListener(_handleMusicVisibilityChanged);
    _syncMusicAnimationState();

    UiPrefs.ensureLoaded().then((_) {
      if (!mounted) return;
      UiPrefs.notifier.addListener(_handleUiPrefsChanged);
      _handleUiPrefsChanged();
      _listenForSettings();
    });
    unawaited(_openPinnedCountdownModeIfNeeded());
    _hydrateNavCollapsed();
    _hydrateLastTab();
    WidgetsBinding.instance.addObserver(this);
    _startupAnimationTimer = Timer(_homeStartupAnimationDelay, () {
      if (!mounted || _allowStartupAnimations) return;
      setState(() => _allowStartupAnimations = true);
      _syncMusicAnimationState();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      unawaited(_consumePendingWidgetAction());
      unawaited(WidgetService.checkAndProcessPendingWidgetActions());
      unawaited(_prewarmShellMedia());
      _startupTasksTimer = Timer(_homeStartupTaskDelay, () {
        if (!mounted) return;
        unawaited(_runDeferredStartupTasks());
      });
      unawaited(UpdateCheckerService.checkUpdate(context));
    });
    _widgetActionSub = WidgetActionService().actions.listen((action) {
      unawaited(_handleWidgetLaunchAction(action));
    });
  }

  Future<void> _prewarmShellMedia() async {
    if (!mounted || _isPrewarmingShellMedia) return;
    final backgroundUrl = UiPrefs.notifier.value.customBackgroundUrl.trim();
    if (backgroundUrl.isEmpty || backgroundUrl == _prewarmedBackgroundUrl) {
      return;
    }
    if (HomeStartupMediaCache.getFile(backgroundUrl) != null) {
      _prewarmedBackgroundUrl = backgroundUrl;
      return;
    }

    _isPrewarmingShellMedia = true;
    try {
      final view = WidgetsBinding.instance.platformDispatcher.views.isNotEmpty
          ? WidgetsBinding.instance.platformDispatcher.views.first
          : null;
      final devicePixelRatio = view?.devicePixelRatio ?? 1.0;
      final logicalSize = view?.physicalSize != null
          ? Size(
              view!.physicalSize.width / devicePixelRatio,
              view.physicalSize.height / devicePixelRatio,
            )
          : const Size(430, 932);
      final cacheWidth =
          (logicalSize.width * devicePixelRatio).round().clamp(720, 1440);
      final cacheHeight =
          (logicalSize.height * devicePixelRatio).round().clamp(1280, 2560);

      final provider = CachedNetworkImageProvider(
        backgroundUrl,
        maxWidth: cacheWidth,
        maxHeight: cacheHeight,
      );
      await precacheImage(provider, context);
      _prewarmedBackgroundUrl = backgroundUrl;
    } catch (_) {
    } finally {
      _isPrewarmingShellMedia = false;
    }
  }

  Future<void> _runDeferredStartupTasks() async {
    if (!mounted) return;
    unawaited(_syncNotificationBadgeListener(forceRestart: true));
    await _maybeShowNewUserWelcomeNotice();
    await _maybeShowBreakupEntryNotice();
    await _maybeShowFirstSetupGuide();
    await _maybeShowPendingDeviceNotice();
    unawaited(_checkScheduleNotifs());
    precacheUtilityStickerList(context);

    final houseId = await HouseService().getCurrentHouseId();
    if (!mounted || houseId == null) return;
    unawaited(_syncIncomingCallListener(houseId));
    final houseData =
        await FirebaseDatabase.instance.ref('houses/$houseId').get();
    if (!mounted || !houseData.exists || houseData.value is! Map) return;
    final data = Map<String, dynamic>.from(
      Map<dynamic, dynamic>.from(houseData.value as Map),
    );
    if (data['startDate'] != null) {
      final startDate = DateTime.tryParse(data['startDate'].toString());
      if (startDate != null) {
        NotificationService().checkAnniversaryReminder(houseId, startDate);
      }
    }
  }

  Widget _buildTabPage(int index) {
    return _KeepAliveTabPage(
      key: PageStorageKey<String>('home-tab-$index-$_homeReloadCounter'),
      child: _TabActivationHost(
        tabIndex: index,
        activeIndexListenable: _activeTabIndexNotifier,
        builder: _tabBuilders[index],
      ),
    );
  }

  Widget _tabPageForIndex(int index) {
    return _tabPageCache.putIfAbsent(index, () => _buildTabPage(index));
  }

  void _handleGlobalRoleChanged() {
    if (!mounted) return;
    setState(() {
      _homeReloadCounter++;
      _tabPageCache.clear();
    });
  }

  void _handleMusicPlaybackChanged() {
    _syncMusicAnimationState();
  }

  void _handleMusicVisibilityChanged() {
    _syncMusicAnimationState();
  }

  void _handleUiPrefsChanged() {
    _syncVipThemeRotateTimer();
    unawaited(_prewarmShellMedia());
  }

  UiEffectProfile _resolveHomeEffectProfile(
    UiPrefsState uiState, {
    bool pauseAnimations = false,
  }) {
    return UiPrefs.resolveEffectProfile(
      state: uiState,
      isWeb: kIsWeb,
      pauseAnimations: pauseAnimations,
    );
  }

  bool _hasSwipeReactiveUi() {
    final uiState = UiPrefs.notifier.value;
    final resolvedThemeKey = _resolveThemeKey(uiState.themeKey);
    final effectProfile = _resolveHomeEffectProfile(uiState);
    final resolvedEffectKey = uiState.liteMode
        ? 'off'
        : _resolveEffectKey(uiState.fallingEffectKey, resolvedThemeKey);
    final musicService = MusicService();

    final hasAnimatedMusicButton = !kIsWeb &&
        musicService.isVisibleNotifier.value &&
        musicService.isPlayingNotifier.value;
    final hasFallingEffect = resolvedEffectKey != 'off';
    final hasTouchEffects =
        effectProfile.premiumEffects && resolvedEffectKey == 'off';

    return hasAnimatedMusicButton || hasFallingEffect || hasTouchEffects;
  }

  void _syncMusicAnimationState() {
    final musicService = MusicService();
    final shouldAnimate = mounted &&
        _allowStartupAnimations &&
        !kIsWeb &&
        !_isUserTabSwiping &&
        musicService.isVisibleNotifier.value &&
        musicService.isPlayingNotifier.value;
    if (shouldAnimate) {
      if (!_musicController.isAnimating) {
        _musicController.repeat(reverse: true);
      }
      return;
    }
    if (_musicController.isAnimating) {
      _musicController.stop();
    }
    if (_musicController.value != 0) {
      _musicController.value = 0;
    }
  }

  void _syncVipThemeRotateTimer() {
    final shouldRotate =
        UiPrefs.notifier.value.themeKey.trim() == 'theme-vip-rotate';
    if (!shouldRotate) {
      _vipThemeRotateTimer?.cancel();
      _vipThemeRotateTimer = null;
      return;
    }
    if (_vipThemeRotateTimer != null) {
      return;
    }
    _vipThemeRotateTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted) return;
      _vipThemeRotationTickNotifier.value++;
    });
  }

  Future<void> _syncNotificationBadgeListener({
    bool forceRestart = false,
  }) async {
    final houseId = await _houseService.getCurrentHouseId();
    final normalizedHouseId = houseId?.trim() ?? '';
    if (normalizedHouseId.isEmpty) {
      _detachNotificationBadgeListener(resetCounter: true);
      return;
    }
    if (!mounted) {
      return;
    }
    if (!forceRestart &&
        _notificationBadgeSub != null &&
        _notificationBadgeHouseId == normalizedHouseId) {
      return;
    }

    _detachNotificationBadgeListener(resetCounter: false);
    _notificationBadgeHouseId = normalizedHouseId;
    _notificationBadgeSub = FirebaseDatabase.instance
        .ref('notifications/$normalizedHouseId')
        .limitToLast(_notificationBadgeLimit)
        .onValue
        .listen((event) {
      NotificationBadgeCounter.instance.update(
        _countUnreadNotifications(event.snapshot.value),
      );
    }, onError: (_) {
      NotificationBadgeCounter.instance.update(0);
    });
  }

  void _detachNotificationBadgeListener({required bool resetCounter}) {
    _notificationBadgeSub?.cancel();
    _notificationBadgeSub = null;
    _notificationBadgeHouseId = null;
    if (resetCounter) {
      NotificationBadgeCounter.instance.update(0);
    }
  }

  Future<void> _syncIncomingCallListener(String houseId) async {
    final normalizedHouseId = houseId.trim();
    if (normalizedHouseId.isEmpty || _callSub != null) {
      return;
    }
    _callSub = WebRTCService().listenForIncomingCalls(
      normalizedHouseId,
      (roomId, callerId, data) {
        if (!mounted || _incomingCall != null) {
          return;
        }
        _incomingCall = <String, dynamic>{
          ...Map<String, dynamic>.from(data),
          'roomId': roomId,
          'callerId': callerId,
        };
        unawaited(_showIncomingCallDialog());
      },
    );
  }

  Future<void> _showIncomingCallDialog() async {
    final incoming = _incomingCall;
    if (!mounted || incoming == null) {
      return;
    }
    final callerName = (incoming['callerName'] ??
            incoming['callerId'] ??
            context.tr('home_ngigi_f1117f'))
        .toString()
        .trim();
    final accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(context.tr('home_cucgin_eff0b9')),
        content: Text(
          L10nService().format('home_incoming_call_from', {
            'name': callerName.isEmpty
                ? context.tr('home_ngigi_f1117f')
                : callerName
          }),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.tr('home_tchi_2119d8')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.tr('home_nghemy_e08606')),
          ),
        ],
      ),
    );
    if (!mounted) {
      return;
    }
    if (accepted == true) {
      await _acceptIncomingCall(incoming);
    } else {
      await _declineIncomingCall(incoming);
    }
    _incomingCall = null;
  }

  Future<void> _acceptIncomingCall(Map<String, dynamic> incoming) async {
    final roomId = (incoming['roomId'] ?? '').toString().trim();
    final callerHouseId =
        (incoming['houseId'] ?? incoming['callerId'] ?? '').toString().trim();
    final callerName =
        (incoming['callerName'] ?? context.tr('home_ngigi_f1117f'))
            .toString()
            .trim();
    if (roomId.isEmpty || callerHouseId.isEmpty) {
      return;
    }
    final myHouseId = (await _houseService.getCurrentHouseId() ?? '').trim();
    if (!mounted || myHouseId.isEmpty) {
      return;
    }
    await Navigator.of(context).push(
      SLRoute(
        builder: (_) => VideoCallScreen(
          houseId: myHouseId,
          targetHouseId: callerHouseId,
          targetName:
              callerName.isEmpty ? context.tr('home_ngigi_f1117f') : callerName,
          targetAvatarUrl: incoming['callerAvatar']?.toString(),
          isVideo: incoming['isVideo'] == true,
          roomId: roomId,
        ),
      ),
    );
  }

  Future<void> _declineIncomingCall(Map<String, dynamic> incoming) async {
    final roomId = (incoming['roomId'] ?? '').toString().trim();
    if (roomId.isEmpty) {
      return;
    }
    await FirebaseDatabase.instance.ref('calls/$roomId').update({
      'status': 'declined',
      'endedAt': ServerValue.timestamp,
    });
  }

  int _countUnreadNotifications(Object? rawValue) {
    if (rawValue is! Map) {
      return 0;
    }
    var unread = 0;
    for (final entry in rawValue.entries) {
      final value = entry.value;
      if (value is! Map) {
        continue;
      }
      final readAt = value['readAt'];
      if (readAt == null) {
        unread++;
        continue;
      }
      if (readAt is num && readAt <= 0) {
        unread++;
        continue;
      }
      final readAtText = readAt.toString().trim();
      if (readAtText.isEmpty || readAtText == '0') {
        unread++;
      }
    }
    return unread;
  }

  void _setActiveTabIndex(int index) {
    if (_activeTabIndexNotifier.value == index) return;
    _activeTabIndexNotifier.value = index;
  }

  @override
  void dispose() {
    RoleUtils.roleNotifier.removeListener(_handleGlobalRoleChanged);
    _callSub?.cancel();
    _settingsSub?.cancel();
    _widgetActionSub?.cancel();
    _detachNotificationBadgeListener(resetCounter: true);
    _startupTasksTimer?.cancel();
    _startupAnimationTimer?.cancel();
    final musicService = MusicService();
    musicService.isPlayingNotifier.removeListener(_handleMusicPlaybackChanged);
    musicService.isVisibleNotifier
        .removeListener(_handleMusicVisibilityChanged);
    UiPrefs.notifier.removeListener(_handleUiPrefsChanged);
    _vipThemeRotateTimer?.cancel();
    _pageController.dispose();
    _activeTabIndexNotifier.dispose();
    _backgroundTabIndexNotifier.dispose(); // ⚡ Dispose background notifier
    _vipThemeRotationTickNotifier.dispose();
    _musicController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _consumePendingWidgetAction() async {
    final action = WidgetActionService().consumePendingAction();
    if (action == null) return;
    await _handleWidgetLaunchAction(action);
  }

  Future<void> _handleWidgetLaunchAction(WidgetLaunchAction action) async {
    if (!mounted) return;

    switch (action) {
      case WidgetLaunchAction.diary:
        await _switchToTab(_communityTabEnabled ? 2 : 1);
        return;
      case WidgetLaunchAction.love:
        await _openLoveScreenFromWidget();
        return;
      case WidgetLaunchAction.calendar:
        await _openCalendarFromWidget();
        return;
    }
  }

  Future<void> _openLoveScreenFromWidget() async {
    final houseId = await _houseService.getCurrentHouseId();
    if (houseId == null || houseId.trim().isEmpty) {
      await _switchToTab(0);
      return;
    }

    final settings = await _houseSettingsService.fetchSettings(houseId);
    if (settings == null) {
      await _switchToTab(0);
      return;
    }
    if (!mounted) return;

    await _switchToTab(0);
    if (!mounted) return;

    await Navigator.of(context).push(
      SLRoute(
        builder: (_) => LoveInsightsScreen(
          houseId: houseId,
          nameU1: settings.nameU1,
          nameU2: settings.nameU2,
          loveDays: _calculateWidgetLoveDays(settings.startDate),
          relationshipMode: settings.relationshipMode,
        ),
      ),
    );
  }

  Future<void> _openCalendarFromWidget() async {
    final houseId = await _houseService.getCurrentHouseId();
    if (houseId == null || houseId.trim().isEmpty) {
      await _switchToTab(_communityTabEnabled ? 3 : 2);
      return;
    }

    final settings = await _houseSettingsService.fetchSettings(houseId);
    final prefs = await OfflineCacheService.getPrefs();
    final role = RoleUtils.normalize(prefs.getString('il_role'));
    final myName = role == 'user2'
        ? (settings?.nameU2.trim().isNotEmpty == true
            ? settings!.nameU2.trim()
            : context.tr('home_ngiy_5bab37'))
        : (settings?.nameU1.trim().isNotEmpty == true
            ? settings!.nameU1.trim()
            : context.tr('home_bn_1fd75b'));

    final resolvedMyName = myName
        .replaceAll(
            context.tr('home_ngiy_5bab37'), context.tr('home_ngiy_5bab37'))
        .replaceAll(context.tr('home_bn_1fd75b'), context.tr('home_bn_1fd75b'));

    if (!mounted) return;
    await Navigator.of(context).push(
      SLRoute(
        builder: (_) =>
            CalendarScreen(houseId: houseId, myName: resolvedMyName),
      ),
    );
  }

  int _calculateWidgetLoveDays(String rawDate) {
    final normalized = rawDate.trim();
    if (normalized.isEmpty) return 0;

    final parsed = DateTime.tryParse(normalized);
    if (parsed == null) return 0;

    final today = DateTime.now();
    final normalizedToday = DateTime(today.year, today.month, today.day);
    final normalizedStart = DateTime(parsed.year, parsed.month, parsed.day);
    final diff = normalizedToday.difference(normalizedStart).inDays;
    return diff < 0 ? 0 : diff;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.inactive) {
      _detachNotificationBadgeListener(resetCounter: false);
      _musicController.stop();
      if (_musicController.value != 0) {
        _musicController.value = 0;
      }
    } else if (state == AppLifecycleState.resumed) {
      unawaited(_syncNotificationBadgeListener(forceRestart: true));
      unawaited(WidgetService.checkAndProcessPendingWidgetActions());
      _syncMusicAnimationState();
      _checkScheduleNotifs();
      unawaited(_maybeShowBreakupEntryNotice());
    }
  }

  Future<void> _switchToTab(int index) async {
    final nextIndex = index.clamp(0, _navItems.length - 1);
    if (!mounted) return;
    if (_currentIndex != nextIndex) {
      HapticFeedback.selectionClick();
      _currentIndex = nextIndex;
      _isUserTabSwiping = false;
      _isUserTabSwipingNotifier.value = false;
      _setActiveTabIndex(nextIndex);
    }
    unawaited(_persistCurrentTab(nextIndex));
    if (_pageController.hasClients) {
      final currentPage = _pageController.page ?? _currentIndex.toDouble();
      if ((currentPage - nextIndex).abs() < 0.001) return;
      final pageDistance = (currentPage - nextIndex).abs();
      final duration = Duration(
        milliseconds: pageDistance > 1.0 ? 280 : 210,
      );
      await _pageController.animateToPage(
        nextIndex,
        duration: duration,
        curve: Curves.easeOutQuart,
      );
      return;
    }
    _backgroundTabIndexNotifier.value = nextIndex;
  }

  Future<void> _openPinnedCountdownModeIfNeeded() async {
    final prefs = await OfflineCacheService.getPrefs();
    if (prefs.getBool(_countdownPinnedLaunchPrefsKey) != true) return;
    if (!mounted) return;
    await Navigator.push(
      context,
      SLRoute(
        builder: (_) => const SettingsTab(autoOpenCountdownMode: true),
      ),
    );
  }

  void _handlePageChanged(int index) {
    if (!mounted) return;
    if (_currentIndex != index) {
      HapticFeedback.selectionClick();
      // ⚡ Không dùng setState - cập nhật ValueNotifier trực tiếp để tránh rebuild toàn bộ
      _currentIndex = index;
      _setActiveTabIndex(index);
      _backgroundTabIndexNotifier.value =
          index; // ⚡ Cập nhật background riêng biệt
    }
    unawaited(_persistCurrentTab(index));
  }

  bool _handlePageScrollNotification(ScrollNotification notification) {
    final metrics = notification.metrics;
    if (metrics is PageMetrics) {
      final previewIndex = (metrics.page ?? _currentIndex.toDouble())
          .round()
          .clamp(0, _navItems.length - 1);
      if (_backgroundTabIndexNotifier.value != previewIndex) {
        _backgroundTabIndexNotifier.value = previewIndex;
      }
    }

    final shouldStartTracking = notification is ScrollStartNotification &&
        notification.dragDetails != null;
    final shouldStopTracking = notification is ScrollEndNotification ||
        (notification is UserScrollNotification &&
            notification.direction == ScrollDirection.idle);

    if (shouldStartTracking && !_isUserTabSwiping && mounted) {
      _isUserTabSwiping = true;
      _isUserTabSwipingNotifier.value = true;
      _syncMusicAnimationState();
    } else if (shouldStopTracking && _isUserTabSwiping && mounted) {
      _isUserTabSwiping = false;
      _isUserTabSwipingNotifier.value = false;
      _syncMusicAnimationState();
    }
    return false;
  }

  Future<void> _hydrateNavCollapsed() async {
    final prefs = await OfflineCacheService.getPrefs();
    final collapsed = prefs.getBool(_navCollapsedPrefsKey) ?? false;
    if (!mounted) return;
    _navCollapsed = collapsed;
    _navCollapsedNotifier.value = collapsed;
  }

  Future<void> _setNavCollapsed(bool value) async {
    if (_navCollapsed == value) return;
    if (mounted) {
      _navCollapsed = value;
      _navCollapsedNotifier.value = value;
    }
    final prefs = await OfflineCacheService.getPrefs();
    await prefs.setBool(_navCollapsedPrefsKey, value);
  }

  void _handleDiarySelectionOverlayChanged(bool visible) {
    if (_hideNavForDiarySelection == visible || !mounted) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _hideNavForDiarySelection == visible) {
        return;
      }
      setState(() => _hideNavForDiarySelection = visible);
    });
  }

  void _hideBottomNavForSession() {
    if (_navHiddenUntilRestart || !mounted) return;
    setState(() => _navHiddenUntilRestart = true);
    SLNotice.showInfo(
      context,
      context.tr('home_nthanhtabm_68ae53'),
    );
  }

  Future<void> _hydrateLastTab() async {
    // Không phục hồi tab cũ nữa, luôn mở ở trang chủ (tab 0)
    // if (widget.initialTab != 0) return;
    // final prefs = await SharedPreferences.getInstance();
    // final savedIndex = prefs.getInt(_lastTabPrefsKey);
    // if (savedIndex == null) return;
    // final clampedIndex = savedIndex.clamp(0, _navItems.length - 1);
    // if (!mounted || clampedIndex == _currentIndex) return;
    // setState(() => _currentIndex = clampedIndex);
  }

  Future<void> _persistCurrentTab(int index) async {
    // Không lưu tab hiện tại vào cache nữa
    // final prefs = await SharedPreferences.getInstance();
    // await prefs.setInt(_lastTabPrefsKey, index);
  }

  Future<void> _openHomeMessenger() async {
    if (!mounted) return;
    final houseId = (await _houseService.getCurrentHouseId() ?? '').trim();
    if (houseId.isEmpty) return;

    final currentRole = await RoleUtils.currentRole();
    final targetRole = currentRole == 'user1' ? 'user2' : 'user1';
    var targetName = targetRole == 'user1' ? 'Bạn nam' : 'Bạn nữ';
    var targetAvatar = '';

    try {
      final snap = await FirebaseDatabase.instance.ref('houses/$houseId').get();
      final raw = snap.value;
      if (raw is Map) {
        final data = Map<dynamic, dynamic>.from(raw);
        final nameKey = targetRole == 'user1' ? 'nameU1' : 'nameU2';
        final avatarKey = targetRole == 'user1' ? 'avtUser1' : 'avtUser2';
        final name = data[nameKey]?.toString().trim() ?? '';
        final avatar = data[avatarKey]?.toString().trim() ?? '';
        if (name.isNotEmpty) targetName = name;
        if (avatar.isNotEmpty) targetAvatar = avatar;
      }
    } catch (_) {}

    if (!mounted) return;
    await slPush(
      context,
      ChatDetailScreen(
        myHouseId: houseId,
        targetHouseId: houseId,
        targetName: targetName,
        targetAvatar: targetAvatar,
        isInternal: true,
        currentRole: currentRole,
        targetRole: targetRole,
      ),
    );
  }

  Widget _buildHomeMessengerBubble() {
    return Positioned(
      right: 16,
      bottom: 110 + MediaQuery.of(context).padding.bottom,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _openHomeMessenger,
          borderRadius: BorderRadius.circular(22),
          child: Ink(
            width: 64,
            height: 74,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFFFF6EAD),
                  Color(0xFFFF4D97),
                  Color(0xFFE23C83),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.26),
                width: 1.1,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFD81B60).withValues(alpha: 0.22),
                  blurRadius: 18,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.20),
                    ),
                  ),
                  child: const Icon(
                    Icons.forum_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Iu ơi',
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: SLTheme.quicksand(
                    color: Colors.white,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final foregroundContent = Stack(
      children: [
        NotificationListener<ScrollNotification>(
          onNotification: _handlePageScrollNotification,
          child: _HomePreloadPageView(
            controller: _pageController,
            onPageChanged: _handlePageChanged,
            dragStartBehavior: DragStartBehavior.start,
            physics:
                const _HomeTabPagePhysics(parent: ClampingScrollPhysics()),
            children: List<Widget>.generate(
              _navItems.length,
              _tabPageForIndex,
              growable: false,
            ),
          ),
        ),
        ValueListenableBuilder<bool>(
          valueListenable: _isUserTabSwipingNotifier,
          builder: (context, isSwiping, child) {
            return TickerMode(
              enabled: !isSwiping,
              child: child ?? const SizedBox.shrink(),
            );
          },
          child: _buildMusicButton(),
        ),
      ],
    );

    return ValueListenableBuilder<UiPrefsState>(
      valueListenable: UiPrefs.notifier,
      child: foregroundContent,
      builder: (context, uiState, cachedForegroundChild) {
        final effectProfile = _resolveHomeEffectProfile(
          uiState,
          pauseAnimations: _isUserTabSwiping,
        );
        final graphicsQualityKey = effectProfile.graphicsQualityKey;

        Widget buildShell({required Widget foregroundChild}) {
          final resolvedThemeKey = _resolveThemeKey(uiState.themeKey);
          final resolvedEffectKey = uiState.liteMode
              ? 'off'
              : _resolveEffectKey(uiState.fallingEffectKey, resolvedThemeKey);
          final isDark = _isDarkTheme(resolvedThemeKey);
          final shouldAnimateEffects =
              effectProfile.premiumEffects && resolvedEffectKey == 'off';
          final shouldAnimateFallingEffect =
              effectProfile.animationEnabled && resolvedEffectKey != 'off';

          Widget bodyContent = Stack(
            children: [
              Positioned.fill(
                child: RepaintBoundary(
                  child: _buildShellBackground(
                    themeKey: resolvedThemeKey,
                    tabIndex: 0,
                    isDark: isDark,
                    backgroundUrl: uiState.customBackgroundUrl,
                    graphicsQualityKey: graphicsQualityKey,
                    animateAmbientEffects: shouldAnimateEffects,
                  ),
                ),
              ),
              foregroundChild,
              ValueListenableBuilder<int>(
                valueListenable: _activeTabIndexNotifier,
                builder: (context, activeIndex, _) {
                  final isMainHomeTab = activeIndex == 0;
                  if (!isMainHomeTab || resolvedEffectKey == 'off') {
                    return const SizedBox.shrink();
                  }
                  return ValueListenableBuilder<bool>(
                    valueListenable: _isUserTabSwipingNotifier,
                    builder: (context, isSwiping, _) {
                      return Positioned.fill(
                        child: RepaintBoundary(
                          child: IgnorePointer(
                            child: Offstage(
                              offstage: isSwiping,
                              child: LegacyFallingEffect(
                                type: resolvedEffectKey,
                                isDark: isDark,
                                density: graphicsQualityKey,
                                opacity: isDark ? 0.96 : 0.88,
                                animate: shouldAnimateFallingEffect && !isSwiping,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          );

          if (shouldAnimateEffects) {
            bodyContent = ValueListenableBuilder<int>(
              valueListenable: _activeTabIndexNotifier,
              builder: (context, activeIndex, child) {
                final resolvedChild = child ?? bodyContent;
                final isMainHomeTab = activeIndex == 0;
                if (!isMainHomeTab) {
                  return resolvedChild;
                }
                return ValueListenableBuilder<bool>(
                  valueListenable: _isUserTabSwipingNotifier,
                  builder: (context, isSwiping, childUnderTouch) {
                    final targetChild = childUnderTouch ?? resolvedChild;
                    if (isSwiping) {
                      return targetChild;
                    }
                    return TouchEffectOverlay(child: targetChild);
                  },
                  child: resolvedChild,
                );
              },
              child: bodyContent,
            );
          }

          return PopScope(
            canPop: false,
            onPopInvokedWithResult: (didPop, _) async {
              if (didPop) return;
              await _handleExitAttempt();
            },
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              child: Scaffold(
                extendBody: true,
                body: bodyContent,
                bottomNavigationBar: _buildBottomNav(isDark: isDark),
              ),
            ),
          );
        }

        if (uiState.themeKey.trim() != 'theme-vip-rotate') {
          return buildShell(foregroundChild: cachedForegroundChild!);
        }

        return ValueListenableBuilder<int>(
          valueListenable: _vipThemeRotationTickNotifier,
          child: cachedForegroundChild,
          builder: (context, _, foregroundChild) {
            return buildShell(
              foregroundChild: foregroundChild ?? const SizedBox.shrink(),
            );
          },
        );
      },
    );
  }

  IconData _getIconForTab(int index) {
    switch (index) {
      case 0:
        return Icons.home_rounded;
      case 1:
        return _communityTabEnabled
            ? Icons.language_rounded
            : Icons.menu_book_rounded;
      case 2:
        return _communityTabEnabled
            ? Icons.menu_book_rounded
            : Icons.widgets_rounded;
      case 3:
        return _communityTabEnabled
            ? Icons.widgets_rounded
            : Icons.sports_esports_rounded;
      case 4:
        return _communityTabEnabled
            ? Icons.sports_esports_rounded
            : Icons.notifications_rounded;
      case 5:
        return Icons.notifications_rounded;
      default:
        return Icons.circle;
    }
  }

  String _resolveThemeKey(String themeKey) {
    final key = themeKey.trim();
    if (key == 'off') return 'off';
    if (key == 'theme-vip-rotate') {
      final slot = DateTime.now().millisecondsSinceEpoch ~/
          const Duration(seconds: 30).inMilliseconds;
      return _vipRotatingThemes[slot % _vipRotatingThemes.length];
    }
    if (key != 'theme-auto') {
      return key.isEmpty ? UiPrefsState.defaults.themeKey : key;
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

  String _resolveEffectKey(String effectKey, String resolvedThemeKey) {
    final raw = effectKey.trim();
    final key = raw.isEmpty ? 'auto' : raw;
    if (key != 'auto') return key;

    final now = DateTime.now();
    if (_isDarkTheme(resolvedThemeKey)) {
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

  bool _isDarkTheme(String themeKey) {
    return themeKey == 'theme-night' ||
        themeKey == 'theme-dark' ||
        themeKey == 'theme-mystic-dark';
  }
}
