// ignore_for_file: unused_element, unused_field, unused_local_variable, unused_import, dead_code
import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;
import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter/material.dart';
import '../utilities/update_dialog_helper.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import '../../utils/services/offline_cache_service.dart';

import '../../core/sl_route.dart';
import '../../core/sl_theme.dart';
import '../../utils/services/auth_service.dart';
import 'package:flutter_animate/flutter_animate.dart';
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
import '../../utils/services/local_action_throttle_service.dart';
import '../../widgets/legacy_falling_effect.dart';
import '../../widgets/touch_effect_overlay.dart';
import 'widgets/doodle_background.dart';
import '../notifications/notification_center_screen.dart';
import '../chat/chat_detail_screen.dart';
import '../relationship/couple_connect_screen.dart';
import 'package:soullocket_app/views/utilities/health_screen.dart';
import '../relationship/video_call_screen.dart';
import '../utilities/calendar_screen.dart';
import '../utilities/soul_events/soul_events_screen.dart';
import 'love_insights_screen.dart';
import '../ui_prefs.dart';
import 'package:soullocket_app/views/home/tabs/settings/settings_links_manager_screen.dart';
import 'package:soullocket_app/utils/services/memory_share_service.dart';
import 'tabs/diary_tab.dart';
import 'tabs/game_tab.dart';
import 'tabs/main_home_tab.dart';
import 'tabs/settings_tab.dart' show SettingsTab;
import 'tabs/update_tab.dart';
import 'tabs/utilities_tab.dart';
import '../utilities/utility_sticker_icon.dart';
import '../../utils/services/widget_service.dart';
import '../../utils/sl_notice.dart';
import '../../utils/services/pairing_service.dart';
import '../../views/home/tabs/settings/pairing/pairing_dashboard_screen.dart';
import '../../utils/app_error_mapper.dart';
import '../../widgets/first_setup_spotlight_guide.dart';
import '../../core/fast_backdrop_filter.dart';
import '../../core/sl_page_physics.dart';
import '../../utils/app_cache_manager.dart';

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

typedef _HomeTabBuilder = Widget Function(ValueNotifier<bool> isActiveNotifier);

class _TabActivationHost extends StatefulWidget {
  final int tabIndex;
  final ValueListenable<int> activeIndexListenable;
  final ValueListenable<int> backgroundIndexListenable;
  final ValueListenable<bool> isSwipingListenable;
  final ValueListenable<({int source, int target})?> jumpListenable;
  final _HomeTabBuilder builder;

  const _TabActivationHost({
    required this.tabIndex,
    required this.activeIndexListenable,
    required this.backgroundIndexListenable,
    required this.isSwipingListenable,
    required this.jumpListenable,
    required this.builder,
  });

  @override
  State<_TabActivationHost> createState() => _TabActivationHostState();
}

class _TabActivationHostState extends State<_TabActivationHost> {
  late final ValueNotifier<bool> _isActiveNotifier;
  late bool _isVisible;
  Widget? _cachedChild;


  @override
  void initState() {
    super.initState();
    final isActive = widget.activeIndexListenable.value == widget.tabIndex;
    _isActiveNotifier = ValueNotifier<bool>(isActive);
    _isVisible = _calculateVisibility();
    widget.activeIndexListenable.addListener(_onStateChanged);
    widget.backgroundIndexListenable.addListener(_onStateChanged);
    widget.isSwipingListenable.addListener(_onStateChanged);
    widget.jumpListenable.addListener(_onStateChanged);
    _cachedChild = widget.builder(_isActiveNotifier);
  }

  bool _calculateVisibility() {
    final activeIndex = widget.activeIndexListenable.value;
    final isSwiping = widget.isSwipingListenable.value;
    if (isSwiping) {
      // Chỉ hiển thị tab hiện tại và 2 tab kề bên để tránh giật lag do render toàn bộ 5 tab
      return (widget.tabIndex - activeIndex).abs() <= 1;
    }

    final jump = widget.jumpListenable.value;
    if (jump != null) {
      return widget.tabIndex == jump.source || widget.tabIndex == jump.target;
    }
    if (activeIndex == widget.tabIndex) {
      return true;
    }
    return false;
  }

  @override
  void didUpdateWidget(covariant _TabActivationHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    bool needsRebuild = false;
    if (oldWidget.activeIndexListenable != widget.activeIndexListenable ||
        oldWidget.backgroundIndexListenable !=
            widget.backgroundIndexListenable ||
        oldWidget.isSwipingListenable != widget.isSwipingListenable ||
        oldWidget.jumpListenable != widget.jumpListenable ||
        oldWidget.tabIndex != widget.tabIndex) {
      oldWidget.activeIndexListenable.removeListener(_onStateChanged);
      oldWidget.backgroundIndexListenable.removeListener(_onStateChanged);
      oldWidget.isSwipingListenable.removeListener(_onStateChanged);
      oldWidget.jumpListenable.removeListener(_onStateChanged);

      widget.activeIndexListenable.addListener(_onStateChanged);
      widget.backgroundIndexListenable.addListener(_onStateChanged);
      widget.isSwipingListenable.addListener(_onStateChanged);
      widget.jumpListenable.addListener(_onStateChanged);

      final nextActive = widget.activeIndexListenable.value == widget.tabIndex;
      _isActiveNotifier.value = nextActive;
      _isVisible = _calculateVisibility();
      needsRebuild = true;
    }
    // Update cache if the builder itself changes (e.g., from a hot reload or parent rebuild)
    if (oldWidget.builder != widget.builder) {
      needsRebuild = true;
    }
    if (needsRebuild) {
      _cachedChild = widget.builder(_isActiveNotifier);
    }
  }

  @override
  void dispose() {
    widget.activeIndexListenable.removeListener(_onStateChanged);
    widget.backgroundIndexListenable.removeListener(_onStateChanged);
    widget.isSwipingListenable.removeListener(_onStateChanged);
    widget.jumpListenable.removeListener(_onStateChanged);
    _isActiveNotifier.dispose();
    super.dispose();
  }

  void _onStateChanged() {
    if (!mounted) return;
    final nextActive = widget.activeIndexListenable.value == widget.tabIndex;
    final nextVisible = _calculateVisibility();
    if (_isActiveNotifier.value != nextActive || _isVisible != nextVisible) {
      // Cập nhật ngay lập tức không delay microtask - tránh 1 frame blank
      // khi jumpToPage đã render tab mới nhưng visibility vẫn chưa được update
      _isActiveNotifier.value = nextActive;
      _isVisible = nextVisible;
      if (mounted) setState(() {});
    }
  }



  @override
  Widget build(BuildContext context) {
    return Visibility(
      visible: _isVisible,
      maintainState: true,
      child: TickerMode(
        enabled: _isActiveNotifier.value,
        child: _cachedChild ?? widget.builder(_isActiveNotifier),
      ),
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
        _lastReportedPage = closestPage;
        widget.onPageChanged?.call(closestPage);
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final axisDirection = _axisDirectionFor(context);
    // Tắt hoàn toàn cacheExtent (0.0) vì giờ đã dùng jumpToPage thay vì animateToPage.
    // Việc này giúp tiết kiệm lượng lớn RAM và loại bỏ hoàn toàn giật lag do render ngầm.
    const cacheExtent = 0.0;

    return NotificationListener<ScrollNotification>(
      onNotification: _handleScrollNotification,
      child: Scrollable(
        axisDirection: axisDirection,
        controller: widget.controller,
        physics: widget.physics,
        dragStartBehavior: widget.dragStartBehavior,
        viewportBuilder: (context, position) {
          return Viewport(
            scrollCacheExtent: const ScrollCacheExtent.viewport(cacheExtent),
            axisDirection: axisDirection,
            offset: position,
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
  late final ValueNotifier<bool> _isBottomNavVisibleNotifier;
  late final ValueNotifier<bool> _isUserTabSwipingNotifier;
  bool _didCheckCoupleOnboarding = false;
  bool _didCheckNewUserWelcomeNotice = false;
  bool _didCheckFirstSetupGuide = false;
  bool _didCheckPendingDeviceNotice = false;
  bool _isShowingBreakupEntryNotice = false;
  bool _isHouseUnpairedCache = false;
  bool _didShowFirstTabSwitchPairingPrompt = false;
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
  late final ValueNotifier<({int source, int target})?> _jumpNotifier;
  late final PageController _pageController;
  DateTime? _lastExitAttemptAt;
  bool _isUserTabSwiping = false;
  final GlobalKey _firstGuideHomeHeroKey = GlobalKey();
  final GlobalKey _firstGuideSettingsKey = GlobalKey();
  final GlobalKey _firstGuideBottomNavKey = GlobalKey();
  final GlobalKey _firstGuideDiaryTabKey = GlobalKey();
  final GlobalKey _firstGuideUtilitiesTabKey = GlobalKey();
  final GlobalKey _firstGuideEntertainmentTabKey = GlobalKey();
  final GlobalKey _firstGuideUpdateTabKey = GlobalKey();


  StreamSubscription? _callSub;
  StreamSubscription? _pairingSub;
  StreamSubscription? _settingsSub;
  StreamSubscription<WidgetLaunchAction>? _widgetActionSub;
  StreamSubscription<DatabaseEvent>? _notificationBadgeSub;
  Timer? _vipThemeRotateTimer;
  Timer? _startupTasksTimer;
  Timer? _startupAnimationTimer;
  Timer? _prewarmMediaTimer;
  Timer? _appUpdateTimer;
  Timer? _inactivityTimer;
  bool _isShowingInactivityDialog = false;
  static const Duration _inactivityTimeout = Duration(minutes: 45);
  static const int _inactivityCountdownSeconds = 5;
  String _prewarmedBackgroundUrl = '';
  bool _isPrewarmingShellMedia = false;
  bool _allowStartupAnimations = false;
  Map<String, dynamic>? _incomingCall;
  String? _notificationBadgeHouseId;

  static const String _navCollapsedPrefsKey = 'il_home_nav_collapsed_v2';
  static const String _lastTabPrefsKey = 'il_home_last_tab_v1';
  static const String _countdownPinnedLaunchPrefsKey =
      'il_countdown_mode_pinned_launch_v1';
  static const int _notificationBadgeLimit = 30;
  static const Duration _homeStartupTaskDelay = Duration(milliseconds: 700);
  static const Duration _homeStartupAnimationDelay =
      Duration(milliseconds: 900);
  static const MethodChannel _appControlChannel =
      MethodChannel('soul_locket/app_control');
  static const List<String> _vipRotatingThemes = <String>[
    'theme-pink-glow',
    'theme-default',
    'theme-sunset',
    'theme-ocean',
    'theme-night',
  ];

  static const _navItems = [
    _NavItem(labelKey: 'nav_home', activeColor: Color(0xFFFF4B91)),
    _NavItem(labelKey: 'nav_diary', activeColor: Color(0xFF00C853)),
    _NavItem(labelKey: 'nav_apps', activeColor: Color(0xFFB388FF)),
    _NavItem(labelKey: 'nav_fun', activeColor: Color(0xFFFFAB00)),
    _NavItem(labelKey: 'nav_update', activeColor: Color(0xFF2979FF)),
  ];

  @override
  void initState() {
    super.initState();
    _autoSyncOverlayData();
    RoleUtils.roleNotifier.addListener(_handleGlobalRoleChanged);
    RoleUtils.duplicateRoleNotifier.addListener(_handleDuplicateRoleWarning);
    _currentIndex = widget.initialTab.clamp(0, _navItems.length - 1);

    _activeTabIndexNotifier = ValueNotifier<int>(_currentIndex);
    _backgroundTabIndexNotifier =
        ValueNotifier<int>(_currentIndex); // ⚡ Init background notifier
    _vipThemeRotationTickNotifier = ValueNotifier<int>(0);
    _navCollapsedNotifier = ValueNotifier<bool>(_navCollapsed);
    _isBottomNavVisibleNotifier = ValueNotifier<bool>(true);
    _isUserTabSwipingNotifier = ValueNotifier<bool>(false);
    _jumpNotifier = ValueNotifier<({int source, int target})?>(null);
    _pageController = PageController(initialPage: _currentIndex);
    _tabBuilders = [
      (isActiveNotifier) => MainHomeTab(
            isActiveListenable: isActiveNotifier,
            onOpenSettings: _openSettings,
            isSwipingListenable: _isUserTabSwipingNotifier,
          ),
      (isActiveNotifier) => DiaryTab(
            isActiveListenable: isActiveNotifier,
            onSelectionOverlayChanged: _handleDiarySelectionOverlayChanged,
            isSwipingListenable: _isUserTabSwipingNotifier,
          ),
      (_) => const UtilitiesTab(),
      (_) => const GameTab(),
      (_) => const UpdateTab(),
    ];
    // Pre-init tất cả các tab để chuyển đổi mượt ngay từ lần đầu
    _tabPageCache[_currentIndex] = _buildTabPage(_currentIndex);


    UiPrefs.ensureLoaded().then((_) {
      if (!mounted) return;
      UiPrefs.notifier.addListener(_handleUiPrefsChanged);
      SLTheme.globalTabRequest.addListener(_handleGlobalTabRequest);

      if (widget.initialTab != 0) {
        _listenForSettings();
      }
    });
    unawaited(_openPinnedCountdownModeIfNeeded());
    _hydrateNavCollapsed();
    _hydrateLastTab();
    WidgetsBinding.instance.addObserver(this);
    _startupAnimationTimer = Timer(_homeStartupAnimationDelay, () {
      if (!mounted || _allowStartupAnimations) return;
      setState(() => _allowStartupAnimations = true);

    });
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      unawaited(_consumePendingWidgetAction());
      unawaited(WidgetService.checkAndProcessPendingWidgetActions());
      _prewarmMediaTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) {
          unawaited(_prewarmShellMedia());
        }
      });
      _startupTasksTimer = Timer(_homeStartupTaskDelay, () {
        if (!mounted) return;
        unawaited(_runDeferredStartupTasks());
      });
      _appUpdateTimer = Timer(const Duration(seconds: 5), () {
        if (mounted) {
          unawaited(_checkAndUpdateApp());
        }
      });
    });
    _widgetActionSub = WidgetActionService().actions.listen((action) {
      unawaited(_handleWidgetLaunchAction(action));
    });
    _resetInactivityTimer();
  }

  void _autoSyncOverlayData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final houseId = prefs.getString('il_house_id');
      final role = prefs.getString('il_role') ?? 'user1';
      final partnerName = prefs.getString('overlay_partner_name') ?? 'Người ấy';

      if (houseId != null && houseId.isNotEmpty) {
        final payloadText = jsonEncode({
          'houseId': houseId,
          'role': role,
          'partnerName': partnerName,
        });
        final dir = await getApplicationDocumentsDirectory();
        final file = File('${dir.path}/overlay_sync.json');
        await file.writeAsString(payloadText);
      }
    } catch (e) {
      debugPrint('[HomeScreen] auto sync overlay error: $e');
    }
  }

  Future<void> _checkAndUpdateApp() async {
    final updateInfo = await UpdateCheckerService.checkUpdate();
    if (updateInfo != null && updateInfo.needsUpdate && mounted) {
      UpdateDialogHelper.show(
        context,
        updateInfo.storeUrl,
        updateInfo.latestVersion,
        updateInfo.forceUpdate,
      );
    }
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
          (logicalSize.width * devicePixelRatio).round().clamp(480, 1080);
      final cacheHeight =
          (logicalSize.height * devicePixelRatio).round().clamp(853, 1920);

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
    final isUnpaired = await HouseService().isHouseUnpaired(houseId);
    if (mounted) {
      setState(() {
        _isHouseUnpairedCache = isUnpaired;
      });
    }
    unawaited(_syncIncomingCallListener(houseId));
    unawaited(_checkExpiredProGracePeriod(houseId));
    final startDateSnap = await FirebaseDatabase.instance
        .ref('houses/$houseId/settings/startDate')
        .get();
    if (!mounted || !startDateSnap.exists || startDateSnap.value == null) {
      return;
    }
    final startDate = DateTime.tryParse(startDateSnap.value.toString());
    if (startDate != null) {
      NotificationService().checkAnniversaryReminder(houseId, startDate);
    }
  }

  Widget _buildTabPage(int index) {
    Widget child = _TabActivationHost(
      tabIndex: index,
      activeIndexListenable: _activeTabIndexNotifier,
      backgroundIndexListenable: _backgroundTabIndexNotifier,
      isSwipingListenable: _isUserTabSwipingNotifier,
      jumpListenable: _jumpNotifier,
      builder: _tabBuilders[index],
    );

    if (index != 0) {
      child = ValueListenableBuilder<UiPrefsState>(
        valueListenable: UiPrefs.notifier,
        builder: (context, uiState, childWidget) {
          final themeKey = _resolveThemeKey(uiState.themeKey);
          final isDark = _usesDarkShell(index, _isDarkTheme(themeKey), usesCustomBackground: false);
          final gradient = _resolveTabShellGradient(
            tabIndex: index,
            themeKey: themeKey,
            isDark: isDark,
            usesCustomBackground: false,
          );
          
          Widget content = childWidget!;
          if (index == 1) {
            content = DoodleBackground(
              isDark: isDark,
              opacity: 0.08,
              child: content,
            );
          }
          
          return DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: gradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: content,
          );
        },
        child: child,
      );
    }

    return _KeepAliveTabPage(
      key: PageStorageKey<String>('home-tab-$index-$_homeReloadCounter'),
      child: child,
    );
  }

  Widget _tabPageForIndex(int index) {
    return _tabPageCache.putIfAbsent(index, () => _buildTabPage(index));
  }

  void _handleGlobalTabRequest() {
    final target = SLTheme.globalTabRequest.value;
    if (target != null && mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
      if (target == -1) {
        _openSettings();
      } else if (target != _currentIndex) {
        _pageController.animateToPage(
          target,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic,
        );
      }
      SLTheme.globalTabRequest.value = null;
    }
  }

  void _handleGlobalRoleChanged() {
    if (!mounted) return;
    setState(() {
      _homeReloadCounter++;
      _tabPageCache.clear();
    });
  }

  void _handleDuplicateRoleWarning() {
    if (!mounted || !RoleUtils.duplicateRoleNotifier.value) return;
    // Reset ngay để chỉ hiện 1 lần, throttle 24h được xử lý trong PresenceService.
    RoleUtils.duplicateRoleNotifier.value = false;
    final role = RoleUtils.roleNotifier.value ?? RoleUtils.currentRoleSync();
    final roleLabel = role == 'user2'
        ? L10nService().translate('Nữ')
        : L10nService().translate('Nam');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '⚠️ ${L10nService().translate('auth_err_role_conflict_1')} $roleLabel — ${L10nService().translate('auth_err_role_conflict_2')}',
        ),
        duration: const Duration(seconds: 5),
        behavior: SnackBarBehavior.floating,
      ),
    );
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

    final hasFallingEffect = resolvedEffectKey != 'off';
    final hasTouchEffects =
        effectProfile.premiumEffects && resolvedEffectKey == 'off';

    return hasFallingEffect || hasTouchEffects;
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
    RoleUtils.duplicateRoleNotifier.removeListener(_handleDuplicateRoleWarning);
    _callSub?.cancel();
    _pairingSub?.cancel();
    _settingsSub?.cancel();
    _widgetActionSub?.cancel();
    _detachNotificationBadgeListener(resetCounter: true);
    _startupTasksTimer?.cancel();
    _startupAnimationTimer?.cancel();
    _prewarmMediaTimer?.cancel();
    _appUpdateTimer?.cancel();
    _inactivityTimer?.cancel();
    UiPrefs.notifier.removeListener(_handleUiPrefsChanged);
    SLTheme.globalTabRequest.removeListener(_handleGlobalTabRequest);
    _vipThemeRotateTimer?.cancel();
    _pageController.dispose();
    _activeTabIndexNotifier.dispose();
    _backgroundTabIndexNotifier.dispose();
    _vipThemeRotationTickNotifier.dispose();
    _navCollapsedNotifier.dispose();
    _isBottomNavVisibleNotifier.dispose();
    _isUserTabSwipingNotifier.dispose();
    _jumpNotifier.dispose();

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
        await _switchToTab(1);
        return;
      case WidgetLaunchAction.love:
        await _openLoveScreenFromWidget();
        return;
      case WidgetLaunchAction.calendar:
        await _openCalendarFromWidget();
        return;
      case WidgetLaunchAction.cycle:
        await _openHealthScreenFromWidget();
        return;
      case WidgetLaunchAction.soul_events:
        await _openSoulEventsFromWidget();
        return;
    }
  }

  Future<void> _openSoulEventsFromWidget() async {
    final houseId = await _houseService.getCurrentHouseId();
    if (houseId == null || houseId.trim().isEmpty) {
      await _switchToTab(0);
      return;
    }
    if (!mounted) return;

    await _switchToTab(0);
    if (!mounted) return;

    await Navigator.of(context).push(
      SLRoute(
        builder: (_) => const SoulEventsScreen(),
      ),
    );
  }

  Future<void> _openHealthScreenFromWidget() async {
    final houseId = await _houseService.getCurrentHouseId();
    if (houseId == null || houseId.trim().isEmpty) {
      await _switchToTab(0);
      return;
    }
    if (!mounted) return;

    await _switchToTab(0);
    if (!mounted) return;

    await Navigator.of(context).push(
      SLRoute(
        builder: (_) => HealthScreen(
          houseId: houseId,
        ),
      ),
    );
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
      await _switchToTab(2);
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
      // Tạm dừng inactivity timer khi app vào background
      _inactivityTimer?.cancel();
    } else if (state == AppLifecycleState.resumed) {
      unawaited(_syncNotificationBadgeListener(forceRestart: true));
      unawaited(WidgetService.checkAndProcessPendingWidgetActions());
      _checkScheduleNotifs();
      unawaited(_maybeShowBreakupEntryNotice());
      // Khởi động lại inactivity timer khi app resume
      _resetInactivityTimer();
    }
  }

  Future<void> _switchToTab(int index) async {
    // Throttle: chống spam chuyển tab nhanh (tối đa 1 lần/200ms)
    final throttle = LocalActionThrottleService.instance.registerAttempt(
      'home_switch_tab',
      minInterval: const Duration(milliseconds: 200),
      maxAttempts: 8,
      burstWindow: const Duration(seconds: 3),
    );
    if (!throttle.isAllowed && throttle.isSuspiciousBurst) return;
    final nextIndex = index.clamp(0, _navItems.length - 1);
    if (!mounted) return;
    
    if (_isHouseUnpairedCache && _currentIndex != nextIndex) {
      unawaited(_checkAndShowPairingNotice());
    }

    final oldIndex = _currentIndex;
    if (_currentIndex != nextIndex) {
      _currentIndex = nextIndex;
      _isUserTabSwiping = false;
      _isUserTabSwipingNotifier.value = false;
      SLTheme.isTabSwiping.value = false;
      _backgroundTabIndexNotifier.value = nextIndex;
    }
    unawaited(_persistCurrentTab(nextIndex));
    if (_pageController.hasClients) {
      final currentPage = _pageController.page ?? oldIndex.toDouble();
      if ((currentPage - nextIndex).abs() < 0.001) {
        _setActiveTabIndex(nextIndex);
        return;
      }
      _isUserTabSwipingNotifier.value = true;
      SLTheme.isTabSwiping.value = true;
      
      _jumpNotifier.value = (source: oldIndex, target: nextIndex);

      await _pageController.animateToPage(
        nextIndex,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );

      _jumpNotifier.value = null;
      _isUserTabSwipingNotifier.value = false;
      SLTheme.isTabSwiping.value = false;
      _setActiveTabIndex(nextIndex);
      return;
    }
    _backgroundTabIndexNotifier.value = nextIndex;
    _setActiveTabIndex(nextIndex);
  }

  Future<void> _checkAndShowPairingNotice() async {
    if (!mounted) return;
    try {
      final prefs = await OfflineCacheService.getPrefs();
      final lastTimeMs = prefs.getInt('il_last_pairing_notice_time') ?? 0;
      final nowMs = DateTime.now().millisecondsSinceEpoch;

      // Giới hạn tần suất 15 phút 1 lần theo yêu cầu user
      if (nowMs - lastTimeMs < 15 * 60 * 1000) {
        return;
      }

      final dateKey = 'il_random_pairing_notice_date';
      final countKey = 'il_random_pairing_notice_count';

      final now = DateTime.now();
      final todayStr = '${now.year}-${now.month}-${now.day}';

      final lastDate = prefs.getString(dateKey);
      int count = prefs.getInt(countKey) ?? 0;

      if (lastDate != todayStr) {
        count = 0;
        await prefs.setString(dateKey, todayStr);
        await prefs.setInt(countKey, 0);
      }

      // Giới hạn 5 lần 1 ngày (tăng nhẹ so với 3 vì đã có 15p cooldown)
      if (count < 5) {
        // Random 30% chance or if it's the very first time today
        if (count == 0 || Random().nextInt(3) == 0) {
          await prefs.setInt('il_last_pairing_notice_time', nowMs);
          await prefs.setInt(countKey, count + 1);
          if (mounted) {
            _showPairingRequiredDialog();
          }
        }
      }
    } catch (_) {}
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
    if (notification.depth != 0) {
      return false;
    }
    final metrics = notification.metrics;
    if (metrics is PageMetrics) {
      final previewIndex = (metrics.page ?? _currentIndex.toDouble())
          .floor()
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
      SLTheme.isTabSwiping.value = true;

    } else if (shouldStopTracking && _isUserTabSwiping && mounted) {
      _isUserTabSwiping = false;
      _isUserTabSwipingNotifier.value = false;
      SLTheme.isTabSwiping.value = false;

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
    // Throttle: chống double-tap liên tục
    final throttle = LocalActionThrottleService.instance.registerAttempt(
      'home_messenger_open',
      minInterval: const Duration(milliseconds: 800),
      maxAttempts: 3,
      burstWindow: const Duration(seconds: 5),
    );
    if (!throttle.isAllowed) return;
    if (!mounted) return;
    final houseId = (await _houseService.getCurrentHouseId() ?? '').trim();
    if (houseId.isEmpty) return;

    final currentRole = await RoleUtils.currentRole();
    final targetRole = currentRole == 'user1' ? 'user2' : 'user1';
    var targetName = targetRole == 'user1'
        ? L10nService().translate('male_role_default')
        : L10nService().translate('female_role_default');
    var targetAvatar = '';

    try {
      final snap =
          await FirebaseDatabase.instance.ref('houses/$houseId/settings').get();
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


  Widget _buildShellBody({
    required Widget foregroundChild,
    required bool isDark,
    required String resolvedThemeKey,
    required String resolvedEffectKey,
    required String graphicsQualityKey,
    required bool shouldAnimateEffects,
    required bool shouldAnimateFallingEffect,
  }) {
    Widget bodyContent = Stack(
      children: [
        Positioned.fill(
          child: RepaintBoundary(
            child: _buildShellBackground(
              themeKey: resolvedThemeKey,
              tabIndex: 0,
              isDark: isDark,
              backgroundUrl: UiPrefs.notifier.value.customBackgroundUrl,
              graphicsQualityKey: graphicsQualityKey,
              animateAmbientEffects: shouldAnimateEffects,
            ),
          ),
        ),
        foregroundChild,
        if (resolvedEffectKey != 'off')
          ValueListenableBuilder<bool>(
            valueListenable: _isUserTabSwipingNotifier,
            builder: (context, isSwiping, _) {
              // ⚡ Dùng Visibility(maintainState: false) để dispose hẳn AnimationController khi swipe
              if (isSwiping) return const SizedBox.shrink();
              return Positioned.fill(
                child: RepaintBoundary(
                  child: IgnorePointer(
                    child: LegacyFallingEffect(
                      type: resolvedEffectKey,
                      isDark: isDark,
                      density: graphicsQualityKey,
                      opacity: isDark ? 0.96 : 0.88,
                      animate: shouldAnimateFallingEffect,
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );

    if (shouldAnimateEffects) {
      bodyContent = ValueListenableBuilder<bool>(
        valueListenable: _isUserTabSwipingNotifier,
        builder: (context, isSwiping, childUnderTouch) {
          return TouchEffectOverlay(
            isEnabled: !isSwiping,
            child: childUnderTouch ?? bodyContent,
          );
        },
        child: bodyContent,
      );
    }

    return bodyContent;
  }

  Widget _getOrBuildForegroundContent() {
    return Stack(
      children: [
        NotificationListener<ScrollNotification>(
          onNotification: _handlePageScrollNotification,
          child: _HomePreloadPageView(
            controller: _pageController,
            onPageChanged: _handlePageChanged,
            dragStartBehavior: DragStartBehavior.start,
            // 🛑 TẮT VƯỢT: NeverScrollableScrollPhysics để chỉ chuyển tab bằng nút bottom nav.
            // ✅ BẬT LẠI: đổi thành `const SLPagePhysics(parent: ClampingScrollPhysics())`
            physics: const NeverScrollableScrollPhysics(),
            children: List<Widget>.generate(
              _navItems.length,
              _tabPageForIndex,
              growable: false,
            ),
          ),
        ),

        ValueListenableBuilder<int>(
          valueListenable: _activeTabIndexNotifier,
          builder: (context, activeIndex, _) {
            return SoulMergeSticker(activeIndex: activeIndex);
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final foregroundContent = _getOrBuildForegroundContent();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _handleExitAttempt();
      },
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) => _resetInactivityTimer(),
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          child: Scaffold(
            extendBody: true,
            // ⚡ Dùng child param để foregroundContent không bị rebuild khi UiPrefs thay đổi
            body: NotificationListener<UserScrollNotification>(
              onNotification: (notification) {
                if (notification.direction == ScrollDirection.reverse) {
                  if (_isBottomNavVisibleNotifier.value) {
                    _isBottomNavVisibleNotifier.value = false;
                  }
                } else if (notification.direction == ScrollDirection.forward) {
                  if (!_isBottomNavVisibleNotifier.value) {
                    _isBottomNavVisibleNotifier.value = true;
                  }
                }
                return false;
              },
              child: ValueListenableBuilder<UiPrefsState>(
                valueListenable: UiPrefs.notifier,
              builder: (context, uiState, child) {
                final effectProfile = _resolveHomeEffectProfile(
                  uiState,
                  pauseAnimations: _isUserTabSwiping,
                );
                final graphicsQualityKey = effectProfile.graphicsQualityKey;
                final resolvedThemeKey = _resolveThemeKey(uiState.themeKey);
                final resolvedEffectKey = uiState.liteMode
                    ? 'off'
                    : _resolveEffectKey(
                        uiState.fallingEffectKey, resolvedThemeKey);
                final isDark = _isDarkTheme(resolvedThemeKey);
                final shouldAnimateEffects =
                    effectProfile.premiumEffects && resolvedEffectKey == 'off';
                final shouldAnimateFallingEffect =
                    !_isUserTabSwiping && resolvedEffectKey != 'off';

                final shellChild = child ?? const SizedBox.shrink();

                if (uiState.themeKey.trim() != 'theme-vip-rotate') {
                  return _buildShellBody(
                    foregroundChild: shellChild,
                    isDark: isDark,
                    resolvedThemeKey: resolvedThemeKey,
                    resolvedEffectKey: resolvedEffectKey,
                    graphicsQualityKey: graphicsQualityKey,
                    shouldAnimateEffects: shouldAnimateEffects,
                    shouldAnimateFallingEffect: shouldAnimateFallingEffect,
                  );
                }

                return ValueListenableBuilder<int>(
                  valueListenable: _vipThemeRotationTickNotifier,
                  builder: (context, _, __) {
                    final rotatedThemeKey = _resolveThemeKey(uiState.themeKey);
                    final rotatedEffectKey = uiState.liteMode
                        ? 'off'
                        : _resolveEffectKey(
                            uiState.fallingEffectKey, rotatedThemeKey);
                    final rotatedIsDark = _isDarkTheme(rotatedThemeKey);
                    final rotatedShouldAnimateEffects =
                        effectProfile.premiumEffects &&
                            rotatedEffectKey == 'off';
                    final rotatedShouldAnimateFallingEffect =
                        !_isUserTabSwiping && rotatedEffectKey != 'off';
                    return _buildShellBody(
                      foregroundChild: shellChild,
                      isDark: rotatedIsDark,
                      resolvedThemeKey: rotatedThemeKey,
                      resolvedEffectKey: rotatedEffectKey,
                      graphicsQualityKey: graphicsQualityKey,
                      shouldAnimateEffects: rotatedShouldAnimateEffects,
                      shouldAnimateFallingEffect:
                          rotatedShouldAnimateFallingEffect,
                    );
                  },
                );
              },
              child: foregroundContent,
            ),
            ),
            bottomNavigationBar: ValueListenableBuilder<UiPrefsState>(
              valueListenable: UiPrefs.notifier,
              builder: (context, uiState, _) {
                final resolvedThemeKey = _resolveThemeKey(uiState.themeKey);
                return _buildBottomNav(isDark: _isDarkTheme(resolvedThemeKey));
              },
            ),
          ),
        ),
      ),
    );
  }

  IconData _getIconForTab(int index) {
    switch (index) {
      case 0:
        return Icons.home_rounded;
      case 1:
        return Icons.menu_book_rounded;
      case 2:
        return Icons.widgets_rounded;
      case 3:
        return Icons.sports_esports_rounded;
      case 4:
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

    if (resolvedThemeKey == 'off') {
      return 'off';
    }

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
