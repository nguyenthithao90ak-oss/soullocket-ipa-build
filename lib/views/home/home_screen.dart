import 'package:soullocket_app/utils/ui_copy.dart';
// ignore_for_file: unused_element, unused_field, unused_local_variable, unused_import, dead_code
import 'package:soullocket_app/utils/calendar/calendar_civil_date.dart';
import 'package:soullocket_app/widgets/sl_feedback.dart';
import 'package:soullocket_app/widgets/sl_dialog.dart';
import 'dart:async';
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
import '../utilities/sleep_tracker_screen.dart';
import '../utilities/update_dialog_helper.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';
import 'package:soullocket_app/models/account_deletion_status.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import '../../utils/services/offline_cache_service.dart';
import '../../utils/services/auth/auth_house_context_service.dart';

import '../../core/sl_route.dart';
import '../../core/routing/single_open_gate.dart';
import '../../core/sl_theme.dart';
import '../../core/app_appearance.dart';
import '../../widgets/sl_settings_kit.dart';
import '../../utils/services/auth_service.dart';
import '../../utils/services/device_manager_service.dart';
import '../../utils/services/friends_service.dart';
import '../../utils/services/house_service.dart';
import '../../utils/services/home_startup_media_cache.dart';
import '../../utils/services/wallpaper_luminance_service.dart';
import '../../utils/services/storage/storage_service.dart';
import '../../utils/services/infrastructure/cloudflare_r2_service.dart';
import '../../widgets/home_background_image.dart';
import '../../utils/home_image_policy.dart';
import '../../utils/services/house_settings_service.dart';
import '../../utils/services/music_service.dart';
import '../../utils/services/breakup_service.dart';
import '../../utils/services/military_lock_service.dart';
import '../../utils/services/location_service.dart';
import '../../utils/services/notification_service.dart';
import '../../utils/services/role_utils.dart';
import '../../utils/services/schedule_notif_service.dart';
import '../../utils/services/webrtc_service.dart';
import '../../utils/services/couple_call_signaling.dart';
import '../../utils/incoming_call_payload.dart';
import '../../utils/services/incoming_call_notifications.dart';
import '../../utils/services/incoming_call_suppression.dart';
import '../../utils/services/system_call_bridge.dart';
import '../relationship/incoming_call_screen.dart';
import '../../utils/services/widget_action_service.dart';
import '../../utils/services/update_checker_service.dart';
import '../../utils/services/local_action_throttle_service.dart';
import '../../widgets/legacy_falling_effect.dart';
import '../../widgets/touch_effect_overlay.dart';
import '../notifications/notification_center_screen.dart';
import '../relationship/couple_connect_screen.dart';
import 'package:soullocket_app/views/utilities/health_screen.dart';
import '../relationship/video_call_screen.dart';
import '../utilities/calendar_screen.dart';
import '../utilities/soul_events/soul_events_screen.dart';
import 'love_insights_screen.dart';
import '../ui_prefs.dart';
import 'package:soullocket_app/views/home/tabs/settings/settings_links_manager_screen.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:soullocket_app/utils/services/memory_share_service.dart';
import '../../utils/services/pro_feature_limits.dart';
// import 'tabs/community_tab.dart'; // DELETED_COMMUNITY_FEATURE 2026-06-28
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
import '../../utils/services/live_activity_service.dart';
import '../../views/home/tabs/settings/pairing/pairing_dashboard_screen.dart';
import '../../views/home/tabs/settings/pairing/pairing_quick_connect_sheet.dart';
import '../../views/home/tabs/settings/pairing/pairing_reminder_scheduler.dart';
import '../../utils/app_error_mapper.dart';
import '../../widgets/first_setup_spotlight_guide.dart';
import '../../core/fast_backdrop_filter.dart';
import '../../core/sl_page_physics.dart';
import '../../utils/app_cache_manager.dart';
import 'widgets/home_shell/soul_navigation_style.dart';
import 'widgets/home_shell/navigation_restore_handle.dart';
import 'widgets/home_shell/home_inactivity_reminder_dialog.dart';
import 'widgets/home_shell/home_breakup_notice.dart';
import '../../widgets/local_guide_companion.dart';

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

  const _NavItem({required this.labelKey, required this.activeColor});
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
  bool _pendingStateUpdate = false; // ⚡ batch multiple listener fires

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
    final jump = widget.jumpListenable.value;
    if (jump != null) {
      return widget.tabIndex == jump.source || widget.tabIndex == jump.target;
    }
    final activeIndex = widget.activeIndexListenable.value;
    if (activeIndex == widget.tabIndex) {
      return true;
    }
    final isSwiping = widget.isSwipingListenable.value;
    if (isSwiping) {
      final floorIndex = widget.backgroundIndexListenable.value;
      if (widget.tabIndex == floorIndex || widget.tabIndex == floorIndex + 1) {
        return true;
      }
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
    // ⚡ Multiple listenables may fire in the same microtask batch during a swipe.
    //   Coalesce them into a single setState via a deferred microtask.
    if (_pendingStateUpdate) return;
    _pendingStateUpdate = true;
    Future.microtask(() {
      if (!mounted) {
        _pendingStateUpdate = false;
        return;
      }
      _pendingStateUpdate = false;
      final nextActive = widget.activeIndexListenable.value == widget.tabIndex;
      final nextVisible = _calculateVisibility();
      if (_isActiveNotifier.value != nextActive || _isVisible != nextVisible) {
        setState(() {
          _isActiveNotifier.value = nextActive;
          _isVisible = nextVisible;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Visibility(
      visible: _isVisible,
      maintainState: true,
      maintainAnimation: false,
      maintainSize: false,
      maintainSemantics: false,
      child: TickerMode(
        enabled: _isActiveNotifier.value,
        child: _cachedChild ?? widget.builder(_isActiveNotifier),
      ),
    );
  }
}

class _KeepAliveTabPage extends StatefulWidget {
  final Widget child;

  const _KeepAliveTabPage({super.key, required this.child});

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
    // Render tab lân cận (cacheExtent = 1.0) để pre-render 1 tab kế tiếp,
    // giúp chuyển tab mượt nhưng không làm tràn RAM như khi để 2.0 (tải 5 tab cùng lúc).
    const cacheExtent = 0.5;

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
                delegate: SliverChildBuilderDelegate((context, index) {
                  return RepaintBoundary(child: widget.children[index]);
                }, childCount: widget.children.length),
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
  late final ValueNotifier<bool> _isBottomNavVisibleNotifier;
  bool _didCheckCoupleOnboarding = false;
  bool _didCheckNewUserWelcomeNotice = false;
  bool _didCheckFirstSetupGuide = false;
  bool _didCheckPendingDeviceNotice = false;
  final _breakupNoticeReady = ValueNotifier<bool>(false);
  late final Stream<User?> _breakupNoticeAuthChanges = FirebaseAuth.instance
      .authStateChanges();
  bool _isHouseUnpairedCache = false;
  final _houseService = HouseService();
  final _houseSettingsService = HouseSettingsService();
  final _breakupService = BreakupService();
  late final PairingReminderScheduler _pairingReminder =
      PairingReminderScheduler(
        canPresent: _canPresentPairingReminder,
        present: _presentPairingReminder,
      );
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
  final GlobalKey _firstGuideUpdateTabKey = GlobalKey();
  final GlobalKey _firstGuideEntertainmentTabKey = GlobalKey();

  late AnimationController _musicController;

  StreamSubscription? _callSub;
  StreamSubscription<Map<String, dynamic>>? _coupleCallSub;
  StreamSubscription? _pairingSub;
  StreamSubscription? _settingsSub;
  StreamSubscription<WidgetLaunchAction>? _widgetActionSub;
  final SingleOpenGate _widgetRouteGate = SingleOpenGate();
  StreamSubscription<DatabaseEvent>? _notificationBadgeSub;
  Timer? _vipThemeRotateTimer;
  Timer? _startupTasksTimer;
  Timer? _startupAnimationTimer;
  Timer? _prewarmMediaTimer;
  Timer? _appUpdateTimer;
  Timer? _inactivityTimer;
  Timer? _incomingCallAlertTimer;
  Route<bool>? _incomingCallDialogRoute;
  Future<void> Function(bool?)? _resolveIncomingCallRoute;
  bool _incomingCallRequestAttached = false;
  bool _openingIncomingCall = false;
  String? _checkingIncomingRoom;
  IncomingCallAction? _incomingActionDuringRead;
  String? _incomingOpeningRoom;
  String? _cancelIncomingOpen;
  int _incomingCallAlertSequence = 0;
  bool _isShowingInactivityDialog = false;
  bool _isCheckingScheduleNotifs = false;
  DateTime? _lastScheduleNotifsCheckAt;
  static const Duration _inactivityTimeout = Duration(minutes: 45);
  static const Duration _scheduleNotifsCooldown = Duration(seconds: 30);
  String _prewarmedBackgroundUrl = '';
  bool _isPrewarmingShellMedia = false;
  bool _allowStartupAnimations = false;
  Map<String, dynamic>? _incomingCall;
  final Map<String, int> _incomingCallSeenAt = <String, int>{};
  String? _incomingCallHouseId;
  String? _notificationBadgeHouseId;

  static const String _navCollapsedPrefsKey = 'il_home_nav_collapsed_v2';
  static const String _lastTabPrefsKey = 'il_home_last_tab_v1';
  static const String _countdownPinnedLaunchPrefsKey =
      'il_countdown_mode_pinned_launch_v1';
  static const int _notificationBadgeLimit = 30;
  static const Duration _homeStartupTaskDelay = Duration(milliseconds: 700);
  static const Duration _homeStartupAnimationDelay = Duration(
    milliseconds: 900,
  );
  static const MethodChannel _appControlChannel = MethodChannel(
    'soul_locket/app_control',
  );

  static const _navItems = [
    _NavItem(labelKey: 'nav_home', activeColor: Color(0xFFE75480)),
    _NavItem(labelKey: 'nav_diary', activeColor: Color(0xFFCF7993)),
    _NavItem(labelKey: 'nav_apps', activeColor: Color(0xFF9D7AE8)),
    _NavItem(labelKey: 'nav_fun', activeColor: Color(0xFFE4A44D)),
    _NavItem(labelKey: 'nav_update', activeColor: Color(0xFF5CADA5)),
  ];

  @override
  void initState() {
    super.initState();
    unawaited(LiveActivityService().init());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(NotificationService().handleSoulEventLaunch());
    });
    _autoSyncOverlayData();
    RoleUtils.roleNotifier.addListener(_handleGlobalRoleChanged);
    RoleUtils.duplicateRoleNotifier.addListener(_handleDuplicateRoleWarning);
    _currentIndex = widget.initialTab.clamp(0, _navItems.length - 1);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        LocalGuideContextNotifier.instance.setHomeTab(_currentIndex);
      }
    });
    _activeTabIndexNotifier = ValueNotifier<int>(_currentIndex);
    _backgroundTabIndexNotifier = ValueNotifier<int>(
      _currentIndex,
    ); // ⚡ Init background notifier
    _vipThemeRotationTickNotifier = ValueNotifier<int>(0);
    _navCollapsedNotifier = ValueNotifier<bool>(_navCollapsed);
    _isUserTabSwipingNotifier = ValueNotifier<bool>(false);
    _isBottomNavVisibleNotifier = ValueNotifier<bool>(true);
    _jumpNotifier = ValueNotifier<({int source, int target})?>(null);
    _pageController = PageController(initialPage: _currentIndex);
    _tabBuilders = [
      (isActiveNotifier) => MainHomeTab(
        firstGuideHeroKey: _firstGuideHomeHeroKey,
        firstGuideSettingsKey: _firstGuideSettingsKey,
        isActiveListenable: isActiveNotifier,
        onOpenSettings: _openSettings,
        onOpenDiary: () => _switchToTab(1),
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
      final partnerName =
          prefs.getString('overlay_partner_name') ??
          UiCopy.text('copy_145933221191');

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
    // Nền R2 dùng URL đọc có xác thực và cache theo UID/House ở lớp hiển thị.
    if (CloudflareR2Service.instance.isR2Url(backgroundUrl)) return;
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
      final cacheWidth = (logicalSize.width * devicePixelRatio).round().clamp(
        480,
        1080,
      );
      final cacheHeight = (logicalSize.height * devicePixelRatio).round().clamp(
        853,
        1920,
      );

      final provider = CachedNetworkImageProvider(
        backgroundUrl,
        maxWidth: cacheWidth,
        maxHeight: cacheHeight,
      );
      if (!mounted) return;
      await precacheImage(provider, context);
      _prewarmedBackgroundUrl = backgroundUrl;
    } catch (error) {
      debugPrint('[SuppressedError] lib/views/home/home_screen.dart: $error');
    } finally {
      _isPrewarmingShellMedia = false;
    }
  }

  Future<void> _runDeferredStartupTasks() async {
    if (!mounted) return;
    unawaited(_syncNotificationBadgeListener(forceRestart: true));
    await _maybeShowNewUserWelcomeNotice();
    await _maybeShowFirstSetupGuide();
    await _maybeShowPendingDeviceNotice();
    if (mounted) {
      _breakupNoticeReady.value = true;
      _pairingReminder.start();
    }
    unawaited(_checkScheduleNotifs());
    if (!mounted) return;
    precacheUtilityStickerList(context);

    final houseId = await HouseService().getCurrentHouseId();
    if (!mounted || houseId == null) return;
    final isUnpaired = await HouseService().isHouseUnpaired(houseId);
    if (mounted) {
      setState(() {
        _isHouseUnpairedCache = isUnpaired;
      });
      _didCheckNewUserWelcomeNotice = true;
      // _maybeShowDailyPairingNotice();
    }
    unawaited(_syncIncomingCallListener(houseId));
    unawaited(_checkExpiredProGracePeriod(houseId));
    // Nhắc kỷ niệm chỉ do _checkScheduleNotifs sở hữu và chống trùng ở server.
  }

  Widget _buildTabPage(int index) {
    return _KeepAliveTabPage(
      key: PageStorageKey<String>('home-tab-$index-$_homeReloadCounter'),
      child: _TabActivationHost(
        tabIndex: index,
        activeIndexListenable: _activeTabIndexNotifier,
        backgroundIndexListenable: _backgroundTabIndexNotifier,
        isSwipingListenable: _isUserTabSwipingNotifier,
        jumpListenable: _jumpNotifier,
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

  void _handleDuplicateRoleWarning() {
    if (!mounted || !RoleUtils.duplicateRoleNotifier.value) return;
    // Reset ngay để chỉ hiện 1 lần, throttle 24h được xử lý trong PresenceService.
    RoleUtils.duplicateRoleNotifier.value = false;
    unawaited(_showDuplicateRoleWarning());
  }

  /// Chỉ hiện khi một tài khoản KHÁC dùng nhầm vai của mình; nhãn Nam/Nữ theo
  /// cờ `genderSwapped` của nhà (đọc từ cache cài đặt Home nếu có).
  Future<void> _showDuplicateRoleWarning() async {
    final role = RoleUtils.roleNotifier.value ?? RoleUtils.currentRoleSync();
    final houseId = (await AuthHouseContextService.quickHouseId())?.trim();
    final cacheKey = 'home_settings_${houseId ?? ''}';
    final settings = houseId == null || houseId.isEmpty
        ? null
        : OfflineCacheService.getMemoryCache(cacheKey) ??
              OfflineCacheService.loadCacheSync(cacheKey);
    if (!mounted) return;
    final isFemale = RoleUtils.isFemaleRole(
      role,
      genderSwapped: RoleUtils.readGenderSwapped(settings),
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SLSnackBar(
        content: Text(
          L10nService().format('presence_duplicate_role_warning', {
            'gender': L10nService().translate(
              isFemale ? 'auth_gender_female' : 'auth_gender_male',
            ),
          }),
        ),
        duration: const Duration(seconds: 6),
        behavior: SnackBarBehavior.floating,
      ),
    );
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

    final hasAnimatedMusicButton =
        !kIsWeb &&
        musicService.isVisibleNotifier.value &&
        musicService.isPlayingNotifier.value;
    final hasFallingEffect = resolvedEffectKey != 'off';
    final hasTouchEffects =
        effectProfile.premiumEffects && resolvedEffectKey == 'off';

    return hasAnimatedMusicButton || hasFallingEffect || hasTouchEffects;
  }

  void _syncMusicAnimationState() {
    final musicService = MusicService();
    final shouldAnimate =
        mounted &&
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
    final lifecycleState = WidgetsBinding.instance.lifecycleState;
    final isAppResumed =
        lifecycleState == null || lifecycleState == AppLifecycleState.resumed;
    if (!shouldRotate || !isAppResumed) {
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
        .listen(
          (event) {
            NotificationBadgeCounter.instance.update(
              _countUnreadNotifications(event.snapshot.value),
            );
          },
          onError: (_) {
            NotificationBadgeCounter.instance.update(0);
          },
        );
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
    if (normalizedHouseId.isEmpty) {
      _detachIncomingCallListeners();
      return;
    }
    if (_callSub != null && _incomingCallHouseId == normalizedHouseId) {
      return;
    }
    _detachIncomingCallListeners();
    _incomingCallHouseId = normalizedHouseId;
    if (!_incomingCallRequestAttached) {
      NotificationService().incomingCallRequest.addListener(
        _consumeIncomingCallRequest,
      );
      _incomingCallRequestAttached = true;
    }
    _consumeIncomingCallRequest();
    final ownerUid = FirebaseAuth.instance.currentUser?.uid;
    void onIncoming(roomId, callerId, data) async {
      final normalizedRoomId = roomId.toString().trim();
      if (normalizedRoomId.isEmpty || data is! Map) return;
      final now = DateTime.now().millisecondsSinceEpoch;
      _incomingCallSeenAt.removeWhere(
        (_, seenAt) => now - seenAt > CoupleCallInvite.ringingSeconds * 1000,
      );
      // Paired inbox và query legacy có thể đưa cùng một room; chỉ mở một
      // dialog/notification cho room đó trong thời gian đổ chuông.
      if (_incomingCallSeenAt.containsKey(normalizedRoomId)) return;
      final payload = Map<String, dynamic>.from(data);
      final callerUid = payload['callerId']?.toString().trim() ?? '';
      final calleeHouseId = payload['calleeId']?.toString().trim() ?? '';
      final expiresAt = payload['localExpiresAt'];
      if (payload['status'] != 'ringing' ||
          calleeHouseId != normalizedHouseId ||
          callerUid.isEmpty ||
          callerUid == ownerUid ||
          expiresAt is! int ||
          expiresAt <= now) {
        _incomingCallSeenAt.remove(normalizedRoomId);
        return;
      }
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.reload();
        if (IncomingCallSuppression.isClosed(
          prefs,
          uid: ownerUid,
          roomId: normalizedRoomId,
        )) {
          return;
        }
      } catch (error) {
        debugPrint('Incoming call marker: ${error.runtimeType}');
      }
      if (!mounted ||
          _incomingCall != null ||
          _openingIncomingCall ||
          _incomingCallHouseId != normalizedHouseId ||
          WebRTCService().isBusy ||
          FirebaseAuth.instance.currentUser?.uid != ownerUid) {
        return;
      }
      _incomingCallSeenAt[normalizedRoomId] = now;
      _incomingCall = <String, dynamic>{
        ...payload,
        'roomId': normalizedRoomId,
        'callerHouseId': callerId,
      };
      _startIncomingCallAlert();
      unawaited(_showIncomingCallDialog());
    }

    // Gọi khác House dùng query `/calls` đã có index. Gọi trong cùng House
    // dùng thêm inbox riêng; cả hai đường được lọc và chống trùng bên trên.
    // Giữ query legacy để nhận được người gọi đang dùng app cũ.
    _callSub = WebRTCService().listenForIncomingCalls(
      normalizedHouseId,
      onIncoming,
    );
    if (!_isHouseUnpairedCache) {
      _coupleCallSub = WebRTCService()
          .watchIncomingCoupleCalls(normalizedHouseId)
          .listen(
            (data) => onIncoming(data['roomId'], data['houseId'], data),
            onError: (Object error) => debugPrint(
              'Couple call inbox: ${AppErrorMapper.resolve(error).message}',
            ),
          );
    }
  }

  void _detachIncomingCallListeners() {
    unawaited(_stopIncomingCallAlert());
    unawaited(SystemCallBridge.instance.setIncomingVisible(false));
    if (_incomingCallRequestAttached) {
      NotificationService().incomingCallRequest.removeListener(
        _consumeIncomingCallRequest,
      );
      _incomingCallRequestAttached = false;
    }
    _incomingCall = null;
    final dialog = _incomingCallDialogRoute;
    _incomingCallDialogRoute = null;
    _resolveIncomingCallRoute = null;
    if (dialog != null && dialog.isActive) {
      dialog.navigator?.removeRoute(dialog);
    }
    WebRTCService().stopIncomingCallListener();
    _callSub?.cancel();
    _callSub = null;
    _coupleCallSub?.cancel();
    _coupleCallSub = null;
    _incomingCallHouseId = null;
    _incomingCallSeenAt.clear();
    _checkingIncomingRoom = null;
    _incomingActionDuringRead = null;
  }

  void _consumeIncomingCallRequest() {
    final request = NotificationService().takeIncomingCallRequest();
    if (request == null) return;
    unawaited(_handleIncomingCallRequest(request));
  }

  Future<void> _handleIncomingCallRequest(IncomingCallRequest request) async {
    final ownerUid = FirebaseAuth.instance.currentUser?.uid;
    final houseId = _incomingCallHouseId;
    if (!mounted ||
        ownerUid == null ||
        houseId == null ||
        (request.data['accountUid'] != null &&
            request.data['accountUid'] != ownerUid) ||
        (request.data['houseId'] != null &&
            request.data['houseId'] != houseId)) {
      return;
    }
    if (_incomingOpeningRoom == request.roomId &&
        (request.action == IncomingCallAction.end ||
            request.action == IncomingCallAction.decline)) {
      _cancelIncomingOpen = request.roomId;
      return;
    }
    if (_incomingCall?['roomId'] == request.roomId) {
      final route = _incomingCallDialogRoute;
      if (route == null ||
          !route.isActive ||
          request.action == IncomingCallAction.open)
        return;
      if (request.action == IncomingCallAction.answer) {
        unawaited(_resolveIncomingCallRoute?.call(true));
      } else if (request.action == IncomingCallAction.decline ||
          request.action == IncomingCallAction.end) {
        unawaited(
          _resolveIncomingCallRoute?.call(
            request.action == IncomingCallAction.decline ? false : null,
          ),
        );
      }
      return;
    }
    if (_checkingIncomingRoom == request.roomId) {
      if (request.action != IncomingCallAction.open) {
        _incomingActionDuringRead = request.action;
      }
      return;
    }
    if (_incomingCall != null ||
        _openingIncomingCall ||
        WebRTCService().isBusy ||
        request.action == IncomingCallAction.end ||
        request.action == IncomingCallAction.mute) {
      return;
    }
    _openingIncomingCall = true;
    _checkingIncomingRoom = request.roomId;
    try {
      final incoming = await IncomingCallNotifications.readVerified(
        request.data,
      );
      final action = _incomingActionDuringRead ?? request.action;
      _checkingIncomingRoom = null;
      _incomingActionDuringRead = null;
      if (!mounted ||
          incoming == null ||
          FirebaseAuth.instance.currentUser?.uid != ownerUid ||
          _incomingCallHouseId != houseId) {
        await NotificationService().dismissIncomingCallNotification(
          request.roomId,
        );
        await SystemCallBridge.instance.end(request.roomId);
        return;
      }
      if (action == IncomingCallAction.open) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.reload();
        if (!mounted ||
            FirebaseAuth.instance.currentUser?.uid != ownerUid ||
            _incomingCallHouseId != houseId) {
          return;
        }
        if (IncomingCallSuppression.isClosed(
          prefs,
          uid: ownerUid,
          roomId: request.roomId,
        )) {
          await NotificationService().dismissIncomingCallNotification(
            request.roomId,
          );
          await SystemCallBridge.instance.end(request.roomId);
          return;
        }
      }
      _incomingCallSeenAt[request.roomId] =
          DateTime.now().millisecondsSinceEpoch;
      if (action == IncomingCallAction.end) {
        await NotificationService().dismissIncomingCallNotification(
          request.roomId,
        );
        await SystemCallBridge.instance.end(request.roomId);
      } else if (action == IncomingCallAction.answer) {
        await NotificationService().dismissIncomingCallNotification(
          request.roomId,
        );
        _incomingCall = incoming;
        unawaited(_showIncomingCallDialog(answerImmediately: true));
      } else if (action == IncomingCallAction.decline) {
        await NotificationService().dismissIncomingCallNotification(
          request.roomId,
        );
        await SystemCallBridge.instance.end(request.roomId);
        await _declineIncomingCall(incoming);
      } else {
        _incomingCall = incoming;
        _startIncomingCallAlert();
        unawaited(_showIncomingCallDialog());
      }
    } catch (error) {
      await SystemCallBridge.instance.end(request.roomId);
      debugPrint('Incoming notification action: ${error.runtimeType}');
    } finally {
      if (_checkingIncomingRoom == request.roomId) _checkingIncomingRoom = null;
      _openingIncomingCall = false;
    }
  }

  Future<void> _showIncomingCallDialog({bool answerImmediately = false}) async {
    final incoming = _incomingCall;
    if (!mounted || incoming == null) {
      return;
    }
    final callerName =
        (incoming['callerName'] ??
                incoming['callerId'] ??
                context.tr('home_ngigi_f1117f'))
            .toString()
            .trim();
    final navigator = Navigator.of(context, rootNavigator: true);
    late final MaterialPageRoute<bool> route;
    final decisionReady = Completer<bool?>();
    var resolving = false;
    Future<void> resolveIncoming(bool? decision) async {
      if (resolving || !route.isActive) return;
      resolving = true;
      unawaited(
        NotificationService().dismissIncomingCallNotification(
          incoming['roomId'].toString(),
        ),
      );
      if (decision == true) {
        unawaited(
          SystemCallBridge.instance.answer(incoming['roomId'].toString()),
        );
        decisionReady.complete(true);
        return; // Giữ màn nhận che Home trong lúc kiểm chứng và chuẩn bị media.
      }
      // Bỏ quyền hiện qua khóa trước khi route rời đi; Home không được lộ ra
      // trong thời gian kiểm tra mạng hoặc ghi thao tác từ chối.
      await SystemCallBridge.instance.setIncomingVisible(false);
      if (route.isActive) navigator.removeRoute(route, decision);
      if (!decisionReady.isCompleted) decisionReady.complete(decision);
    }

    route = MaterialPageRoute<bool>(
      fullscreenDialog: true,
      settings: const RouteSettings(name: 'soul_merge_incoming_call'),
      builder: (routeContext) => IncomingCallScreen(
        callerName: callerName.isEmpty
            ? routeContext.tr('home_ngigi_f1117f')
            : callerName,
        avatarUrl: incoming['callerAvatar']?.toString(),
        isVideo: incoming['isVideo'] == true,
        onAnswer: () => unawaited(resolveIncoming(true)),
        onDecline: () => unawaited(resolveIncoming(false)),
      ),
    );
    _incomingCallDialogRoute = route;
    _resolveIncomingCallRoute = resolveIncoming;
    final statusSub = FirebaseDatabase.instance
        .ref('calls/${incoming['roomId']}/status')
        .onValue
        .listen(
          (event) {
            final status = event.snapshot.value;
            if (status != 'ringing' && route.isActive) {
              unawaited(resolveIncoming(null));
            }
          },
          onError: (Object error) {
            if (route.isActive) unawaited(resolveIncoming(null));
          },
        );
    final remainingMs =
        (incoming['localExpiresAt'] as int? ?? 0) -
        DateTime.now().millisecondsSinceEpoch;
    // Caller bị kill/mất mạng có thể không ghi ended; không đổ chuông vô hạn.
    final expiry = Timer(
      Duration(milliseconds: remainingMs.clamp(0, 45000)),
      () {
        if (route.isActive) unawaited(resolveIncoming(null));
      },
    );
    bool? accepted;
    try {
      unawaited(
        navigator.push(route).then((result) {
          if (!decisionReady.isCompleted) decisionReady.complete(result);
        }),
      );
      unawaited(SystemCallBridge.instance.setIncomingVisible(true));
      if (answerImmediately) unawaited(resolveIncoming(true));
      accepted = await decisionReady.future;
      expiry.cancel();
      // Dừng chuông trước khi tải dữ liệu hoặc mở màn gọi. Navigator.push của
      // màn gọi chỉ hoàn tất khi cúp máy, không phải thời điểm đã bắt máy.
      if (identical(_incomingCall, incoming)) {
        await _stopIncomingCallAlert(answered: accepted == true);
        _incomingCall = null;
      }
      if (!mounted) return;
      if (accepted == true) {
        _openingIncomingCall = true;
        try {
          await _acceptIncomingCall(incoming, incomingRoute: route);
        } finally {
          _openingIncomingCall = false;
        }
      } else if (accepted == false) {
        await _declineIncomingCall(incoming);
      }
    } catch (error) {
      if (mounted) {
        SLNotice.showError(context, context.tr('p4_call_connection_failed'));
      }
      debugPrint('Incoming call: ${AppErrorMapper.resolve(error).message}');
    } finally {
      expiry.cancel();
      if (identical(_incomingCallDialogRoute, route)) {
        _incomingCallDialogRoute = null;
        _resolveIncomingCallRoute = null;
      }
      await statusSub.cancel();
      if (identical(_incomingCall, incoming)) {
        await _stopIncomingCallAlert();
        _incomingCall = null;
      }
      if (route.isActive) {
        await SystemCallBridge.instance.setIncomingVisible(false);
        if (route.isActive) route.navigator?.removeRoute(route);
      }
      if (_incomingCall == null && !_openingIncomingCall) {
        await SystemCallBridge.instance.setIncomingVisible(false);
      }
    }
  }

  void _startIncomingCallAlert() {
    _incomingCallAlertTimer?.cancel();
    final incoming = _incomingCall;
    if (incoming == null) return;
    _incomingCallAlertSequence = 0;
    unawaited(
      _showIncomingCallNotification(incoming, _incomingCallAlertSequence),
    );
    // Một notification lặp bằng hệ thống; không phát lại FSI mỗi ba giây.
  }

  Future<void> _showIncomingCallNotification(
    Map<String, dynamic> incoming,
    int sequence,
  ) async {
    if (!mounted || !identical(_incomingCall, incoming)) return;
    final callerName =
        (incoming['callerName'] ?? context.tr('home_ngigi_f1117f'))
            .toString()
            .trim();
    final isVideo =
        incoming['isVideo'] == true ||
        incoming['isVideo']?.toString().toLowerCase() == 'true';
    final roomId = (incoming['roomId'] ?? '').toString();
    final systemShown = await SystemCallBridge.instance.reportIncoming({
      'roomId': roomId,
      'callerName': callerName,
      'isVideo': isVideo,
      'accountUid': FirebaseAuth.instance.currentUser?.uid,
      'houseId': _incomingCallHouseId,
      'localExpiresAt': incoming['localExpiresAt'],
    });
    if (!systemShown && mounted && identical(_incomingCall, incoming)) {
      await NotificationService().showIncomingCallNotification(
        roomId: roomId,
        callerName: callerName,
        isVideo: isVideo,
        sequence: sequence,
        accountUid: FirebaseAuth.instance.currentUser?.uid,
        houseId: _incomingCallHouseId,
        callerAvatar: incoming['callerAvatar']?.toString(),
        localExpiresAt: incoming['localExpiresAt'] as int?,
      );
    }
    // Plugin có thể hoàn tất sau khi người dùng đã bắt máy/từ chối.
    if (!mounted || !identical(_incomingCall, incoming)) {
      await NotificationService().dismissIncomingCallNotification(roomId);
      if (!_openingIncomingCall) await SystemCallBridge.instance.end(roomId);
    }
  }

  Future<void> _stopIncomingCallAlert({bool answered = false}) async {
    final roomId = _incomingCall?['roomId']?.toString() ?? '';
    _incomingCallAlertTimer?.cancel();
    _incomingCallAlertTimer = null;
    if (roomId.trim().isNotEmpty) {
      await NotificationService().dismissIncomingCallNotification(roomId);
      if (!answered) await SystemCallBridge.instance.end(roomId);
    }
  }

  Future<void> _acceptIncomingCall(
    Map<String, dynamic> incoming, {
    Route<bool>? incomingRoute,
  }) async {
    final ownerUid = FirebaseAuth.instance.currentUser?.uid;
    final expectedHouseId = _incomingCallHouseId;
    if (ownerUid == null || expectedHouseId == null) return;
    final roomId = (incoming['roomId'] ?? '').toString().trim();
    _incomingOpeningRoom = roomId;
    _cancelIncomingOpen = null;
    try {
      final callerHouseId = (incoming['houseId'] ?? incoming['callerId'] ?? '')
          .toString()
          .trim();
      final callerName =
          (incoming['callerName'] ?? context.tr('home_ngigi_f1117f'))
              .toString()
              .trim();
      if (roomId.isEmpty || callerHouseId.isEmpty) {
        return;
      }
      final myHouseId =
          (await _houseService.getCurrentHouseId().timeout(
                    const Duration(seconds: 8),
                  ) ??
                  '')
              .trim();
      if (!mounted ||
          _cancelIncomingOpen == roomId ||
          myHouseId != expectedHouseId ||
          _incomingCallHouseId != expectedHouseId ||
          FirebaseAuth.instance.currentUser?.uid != ownerUid) {
        return;
      }
      final room = await FirebaseDatabase.instance
          .ref('calls/$roomId')
          .get()
          .timeout(const Duration(seconds: 8));
      if (!mounted ||
          _cancelIncomingOpen == roomId ||
          _incomingCallHouseId != expectedHouseId ||
          FirebaseAuth.instance.currentUser?.uid != ownerUid ||
          DateTime.now().millisecondsSinceEpoch >=
              (incoming['localExpiresAt'] as int? ?? 0) ||
          room.value is! Map ||
          (room.value as Map)['status'] != 'ringing' ||
          (room.value as Map)['calleeId'] != expectedHouseId ||
          (room.value as Map)['callerId'] != incoming['callerId'] ||
          (room.value as Map)['timestamp'] != incoming['timestamp']) {
        return;
      }
      if (WebRTCService().isBusy) return;
      await SystemCallBridge.instance.answer(roomId);
      if (!mounted ||
          FirebaseAuth.instance.currentUser?.uid != ownerUid ||
          _cancelIncomingOpen == roomId ||
          _incomingCallHouseId != expectedHouseId) {
        return;
      }
      final navigator = Navigator.of(context, rootNavigator: true);
      final completed = navigator.push(
        PageRouteBuilder<void>(
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
          pageBuilder: (_, _, _) => VideoCallScreen(
            houseId: myHouseId,
            targetHouseId: callerHouseId,
            targetName: callerName.isEmpty
                ? context.tr('home_ngigi_f1117f')
                : callerName,
            targetAvatarUrl: incoming['callerAvatar']?.toString(),
            isVideo: incoming['isVideo'] == true,
            roomId: roomId,
          ),
        ),
      );
      if (incomingRoute?.isActive == true)
        navigator.removeRoute(incomingRoute!);
      await completed;
    } finally {
      if (_cancelIncomingOpen == roomId) {
        try {
          await _declineIncomingCall(incoming);
        } catch (error) {
          debugPrint('Incoming call cancel: ${error.runtimeType}');
        }
      }
      if (_incomingOpeningRoom == roomId) _incomingOpeningRoom = null;
      await SystemCallBridge.instance.end(roomId);
      await SystemCallBridge.instance.setIncomingVisible(false);
    }
  }

  Future<void> _declineIncomingCall(Map<String, dynamic> incoming) async {
    final ownerUid = FirebaseAuth.instance.currentUser?.uid;
    final expectedHouseId = _incomingCallHouseId;
    final roomId = (incoming['roomId'] ?? '').toString().trim();
    if (roomId.isEmpty || ownerUid == null || expectedHouseId == null) {
      return;
    }
    await FirebaseDatabase.instance
        .ref('calls/$roomId')
        .runTransaction((current) {
          if (FirebaseAuth.instance.currentUser?.uid != ownerUid ||
              _incomingCallHouseId != expectedHouseId) {
            return Transaction.abort();
          }
          if (current == null) return Transaction.success(null);
          if (current is! Map ||
              current['status'] != 'ringing' ||
              current['calleeId'] != expectedHouseId ||
              current['callerId'] != incoming['callerId'] ||
              current['timestamp'] != incoming['timestamp']) {
            return Transaction.abort();
          }
          return Transaction.success({
            ...Map<String, dynamic>.from(current),
            'status': 'ended',
            'endReason': 'declined',
            'endedAt': ServerValue.timestamp,
          });
        }, applyLocally: false)
        .timeout(const Duration(seconds: 8));
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
    // Tab mới không kế thừa trạng thái ẩn do cuộn của tab trước.
    _isBottomNavVisibleNotifier.value = true;
    _activeTabIndexNotifier.value = index;
    LocalGuideContextNotifier.instance.setHomeTab(index);
  }

  @override
  void dispose() {
    RoleUtils.roleNotifier.removeListener(_handleGlobalRoleChanged);
    RoleUtils.duplicateRoleNotifier.removeListener(_handleDuplicateRoleWarning);
    _detachIncomingCallListeners();
    _stopIncomingCallAlert();
    _pairingSub?.cancel();
    _settingsSub?.cancel();
    _pairingReminder.dispose();
    _widgetActionSub?.cancel();
    _detachNotificationBadgeListener(resetCounter: true);
    _startupTasksTimer?.cancel();
    _startupAnimationTimer?.cancel();
    _prewarmMediaTimer?.cancel();
    _appUpdateTimer?.cancel();
    _inactivityTimer?.cancel();
    final musicService = MusicService();
    musicService.isPlayingNotifier.removeListener(_handleMusicPlaybackChanged);
    musicService.isVisibleNotifier.removeListener(
      _handleMusicVisibilityChanged,
    );
    UiPrefs.notifier.removeListener(_handleUiPrefsChanged);
    _vipThemeRotateTimer?.cancel();
    _pageController.dispose();
    _activeTabIndexNotifier.dispose();
    _breakupNoticeReady.dispose();
    _navCollapsedNotifier.dispose();
    _isBottomNavVisibleNotifier.dispose();
    _isUserTabSwipingNotifier.dispose();
    _backgroundTabIndexNotifier.dispose(); // ⚡ Dispose background notifier
    _vipThemeRotationTickNotifier.dispose();
    _jumpNotifier.dispose();
    _musicController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _consumePendingWidgetAction() async {
    final action = WidgetActionService().consumePendingAction();
    if (action == null) return;
    await _handleWidgetLaunchAction(action);
  }

  Future<void> _handleWidgetLaunchAction(WidgetLaunchAction action) {
    return _widgetRouteGate.run(
      () => _handleWidgetLaunchActionInternal(action),
    );
  }

  Future<void> _handleWidgetLaunchActionInternal(
    WidgetLaunchAction action,
  ) async {
    if (!mounted) return;

    switch (action) {
      case WidgetLaunchAction.widgetSettings:
        await slPush<void>(context, const SettingsTab(autoOpenWidget: true));
        return;
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
      case WidgetLaunchAction.sleep:
        final sleepHouse = await _houseService.getCurrentHouseId();
        if (!mounted || sleepHouse == null || sleepHouse.isEmpty) return;
        await slPush<void>(
          context,
          SleepTrackerScreen(houseId: sleepHouse, myName: ''),
        );
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

    await slPush<void>(context, const SoulEventsScreen());
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

    await slPush<void>(context, HealthScreen(houseId: houseId));
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

    await slPush<void>(
      context,
      LoveInsightsScreen(
        houseId: houseId,
        nameU1: settings.displayNameU1,
        nameU2: settings.displayNameU2,
        avatarU1: settings.avtUser1,
        avatarU2: settings.avtUser2,
        loveDays: _calculateWidgetLoveDays(settings.startDate),
        relationshipMode: settings.relationshipMode,
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
    if (!mounted) return;
    final myName = role == 'user2'
        ? (settings?.nameU2.trim().isNotEmpty == true
              ? settings!.nameU2.trim()
              : context.tr('home_ngiy_5bab37'))
        : (settings?.nameU1.trim().isNotEmpty == true
              ? settings!.nameU1.trim()
              : context.tr('home_bn_1fd75b'));

    final resolvedMyName = myName
        .replaceAll(
          context.tr('home_ngiy_5bab37'),
          context.tr('home_ngiy_5bab37'),
        )
        .replaceAll(context.tr('home_bn_1fd75b'), context.tr('home_bn_1fd75b'));

    if (!mounted) return;
    await slPush<void>(
      context,
      CalendarScreen(houseId: houseId, myName: resolvedMyName),
    );
  }

  int _calculateWidgetLoveDays(String rawDate) {
    final normalized = rawDate.trim();
    if (normalized.isEmpty) return 0;

    final parsed = DateTime.tryParse(normalized);
    if (parsed == null) return 0;

    final diff = CalendarCivilDate.daysBetween(parsed, DateTime.now());
    return diff < 0 ? 0 : diff;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.inactive) {
      unawaited(LocationService().onAppBackgrounded());
      _detachNotificationBadgeListener(resetCounter: false);
      _musicController.stop();
      if (_musicController.value != 0) {
        _musicController.value = 0;
      }
      // Tạm dừng inactivity timer khi app vào background
      _inactivityTimer?.cancel();
      _pairingReminder.setForeground(false);
      _syncVipThemeRotateTimer();
      unawaited(_syncLiveActivity());
    } else if (state == AppLifecycleState.resumed) {
      _pairingReminder.setForeground(true);
      unawaited(LocationService().onAppResumed());
      unawaited(_syncNotificationBadgeListener(forceRestart: true));
      unawaited(WidgetService.checkAndProcessPendingWidgetActions());
      _syncMusicAnimationState();
      _syncVipThemeRotateTimer();
      _checkScheduleNotifs();
      // Khởi động lại inactivity timer khi app resume
      _resetInactivityTimer();
    }
  }

  Future<void> _syncLiveActivity() async {
    try {
      final houseId = await _houseService.getCurrentHouseId();
      if (houseId == null || houseId.isEmpty) return;
      final settings = await _houseSettingsService.fetchSettings(houseId);
      if (settings == null) return;

      final days = _calculateWidgetLoveDays(settings.startDate);
      final title = '${settings.displayNameU1} 💖 ${settings.displayNameU2}';

      await LiveActivityService().startOrUpdateActivity(
        avatar1: settings.avtUser1,
        avatar2: settings.avtUser2,
        days: days,
        title: title,
      );
    } catch (e) {
      debugPrint('[HomeScreen] _syncLiveActivity error: $e');
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

    // if (_isHouseUnpairedCache && nextIndex != 0) {
    //   _showPairingRequiredDialog();
    //   return;
    // }

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
      _pageController.jumpToPage(nextIndex);
      _isUserTabSwipingNotifier.value = false;
      SLTheme.isTabSwiping.value = false;
      _setActiveTabIndex(nextIndex);
      return;
    }
    _backgroundTabIndexNotifier.value = nextIndex;
    _setActiveTabIndex(nextIndex);
  }

  Future<void> _openPinnedCountdownModeIfNeeded() async {
    final prefs = await OfflineCacheService.getPrefs();
    if (prefs.getBool(_countdownPinnedLaunchPrefsKey) != true) return;
    if (!mounted) return;
    await slPush<void>(context, const SettingsTab(autoOpenCountdownMode: true));
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
    if (notification is UserScrollNotification &&
        notification.metrics.axis == Axis.vertical) {
      if (notification.direction == ScrollDirection.reverse) {
        if (_isBottomNavVisibleNotifier.value) {
          _isBottomNavVisibleNotifier.value = false;
        }
      } else if (notification.direction == ScrollDirection.forward) {
        if (!_isBottomNavVisibleNotifier.value) {
          _isBottomNavVisibleNotifier.value = true;
        }
      }
    }

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

    final shouldStartTracking =
        notification is ScrollStartNotification &&
        notification.dragDetails != null;
    final shouldStopTracking =
        notification is ScrollEndNotification ||
        (notification is UserScrollNotification &&
            notification.direction == ScrollDirection.idle);

    if (shouldStartTracking && !_isUserTabSwiping && mounted) {
      _isUserTabSwiping = true;
      _isUserTabSwipingNotifier.value = true;
      SLTheme.isTabSwiping.value = true;
      _syncMusicAnimationState();
    } else if (shouldStopTracking && _isUserTabSwiping && mounted) {
      _isUserTabSwiping = false;
      _isUserTabSwipingNotifier.value = false;
      SLTheme.isTabSwiping.value = false;
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
    SLNotice.showInfo(context, context.tr('home_nthanhtabm_68ae53'));
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

  Widget _buildShellBody({
    required Widget foregroundChild,
    required bool isDark,
    required String resolvedThemeKey,
    required String resolvedEffectKey,
    required String graphicsQualityKey,
    required bool shouldAnimateEffects,
    required bool shouldAnimateFallingEffect,
  }) {
    final bodyContent = ValueListenableBuilder<int>(
      valueListenable: _activeTabIndexNotifier,
      builder: (context, activeIndex, _) {
        final isMainHomeTab = activeIndex == 0;
        return Stack(
          children: [
            Positioned.fill(
              child: RepaintBoundary(
                child: _buildShellBackground(
                  themeKey: resolvedThemeKey,
                  tabIndex: activeIndex,
                  isDark: isDark,
                  backgroundUrl: UiPrefs.notifier.value.customBackgroundUrl,
                  graphicsQualityKey: graphicsQualityKey,
                  animateAmbientEffects: shouldAnimateEffects,
                ),
              ),
            ),
            foregroundChild,
            if (isMainHomeTab && resolvedEffectKey != 'off')
              ValueListenableBuilder<bool>(
                valueListenable: _isUserTabSwipingNotifier,
                builder: (context, isSwiping, _) {
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
      },
    );

    return ValueListenableBuilder<int>(
      valueListenable: _activeTabIndexNotifier,
      builder: (context, activeIndex, child) {
        final resolvedChild = child ?? const SizedBox.shrink();
        final isMainHomeTab = activeIndex == 0;
        return ValueListenableBuilder<bool>(
          valueListenable: _isUserTabSwipingNotifier,
          builder: (context, isSwiping, childUnderTouch) {
            final targetChild = childUnderTouch ?? resolvedChild;
            // Giữ nguyên lớp cha cả khi cấu hình hiệu ứng đổi giữa lúc kéo.
            // Chỉ tắt hiệu ứng chạm, không dispose/dựng lại Home và bé thỏ.
            return TouchEffectOverlay(
              isEnabled: shouldAnimateEffects && isMainHomeTab && !isSwiping,
              child: targetChild,
            );
          },
          child: resolvedChild,
        );
      },
      child: bodyContent,
    );
  }

  Widget _getOrBuildForegroundContent() {
    return Stack(
      children: [
        NotificationListener<ScrollNotification>(
          onNotification: _handlePageScrollNotification,
          child: ValueListenableBuilder<bool>(
            valueListenable: SLTheme.isCountdownCustomizeOpen,
            builder: (context, isCustomizeSheetOpen, _) {
              return _HomePreloadPageView(
                controller: _pageController,
                onPageChanged: _handlePageChanged,
                dragStartBehavior: DragStartBehavior.start,
                physics: isCustomizeSheetOpen
                    ? const NeverScrollableScrollPhysics()
                    : const SLPagePhysics(parent: ClampingScrollPhysics()),
                children: List<Widget>.generate(
                  _navItems.length,
                  _tabPageForIndex,
                  growable: false,
                ),
              );
            },
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
          child: const SizedBox(),
        ),
        ValueListenableBuilder<int>(
          valueListenable: _activeTabIndexNotifier,
          builder: (context, activeIndex, _) {
            return SoulMergeSticker(activeIndex: activeIndex);
          },
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: ValueListenableBuilder<bool>(
            valueListenable: _breakupNoticeReady,
            builder: (context, ready, _) => StreamBuilder<User?>(
              stream: _breakupNoticeAuthChanges,
              initialData: FirebaseAuth.instance.currentUser,
              builder: (context, snapshot) => ValueListenableBuilder<int>(
                valueListenable: _activeTabIndexNotifier,
                builder: (context, index, _) {
                  final uid = snapshot.data?.uid;
                  return HomeBreakupNotice(
                    active: ready && index == 0,
                    scopeKey: uid == null ? '' : '$uid:$_homeReloadCounter',
                    loadRequest: _loadHomeBreakupNotice,
                    onManageRequest: (request) {
                      if (request.expireAt > 0) {
                        unawaited(
                          slPush<void>(context, const PairingDashboardScreen()),
                        );
                      } else {
                        unawaited(
                          slPush<void>(
                            context,
                            const SettingsTab(autoOpenRelationship: true),
                          ),
                        );
                      }
                    },
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    AppAppearanceScope.watch(context);
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
            body: ValueListenableBuilder<UiPrefsState>(
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
                        uiState.fallingEffectKey,
                        resolvedThemeKey,
                      );
                final isDark = _isDarkTheme(resolvedThemeKey);
                final shouldAnimateEffects =
                    effectProfile.premiumEffects && resolvedEffectKey == 'off';
                final shouldAnimateFallingEffect =
                    effectProfile.animationEnabled &&
                    resolvedEffectKey != 'off';

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
                  builder: (context, _, _) {
                    final rotatedThemeKey = _resolveThemeKey(uiState.themeKey);
                    final rotatedEffectKey = uiState.liteMode
                        ? 'off'
                        : _resolveEffectKey(
                            uiState.fallingEffectKey,
                            rotatedThemeKey,
                          );
                    final rotatedIsDark = _isDarkTheme(rotatedThemeKey);
                    final rotatedShouldAnimateEffects =
                        effectProfile.premiumEffects &&
                        rotatedEffectKey == 'off';
                    final rotatedShouldAnimateFallingEffect =
                        effectProfile.animationEnabled &&
                        rotatedEffectKey != 'off';
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
            bottomNavigationBar: ValueListenableBuilder<UiPrefsState>(
              valueListenable: UiPrefs.notifier,
              builder: (context, uiState, _) {
                return _buildBottomNav();
              },
            ),
          ),
        ),
      ),
    );
  }

  IconData _getIconForTab(int index, {bool isActive = true}) {
    switch (index) {
      case 0:
        return isActive
            ? Icons.favorite_rounded
            : Icons.favorite_outline_rounded;
      case 1:
        return isActive ? Icons.book_rounded : Icons.book_outlined;
      case 2:
        return isActive ? Icons.grid_view_rounded : Icons.grid_view_outlined;
      case 3:
        return isActive
            ? Icons.sports_esports_rounded
            : Icons.sports_esports_outlined;
      case 4:
        return isActive
            ? Icons.auto_awesome_rounded
            : Icons.auto_awesome_outlined;
      default:
        return Icons.circle;
    }
  }

  String _resolveThemeKey(String themeKey) =>
      AppThemeSelection.resolve(themeKey);

  String _resolveEffectKey(String effectKey, String resolvedThemeKey) {
    final raw = effectKey.trim();
    if (raw == 'off') return 'off';
    if (raw == 'auto' || raw.isEmpty) return 'off';
    return raw;
  }

  bool _isDarkTheme(String themeKey) => AppThemeSelection.isDark(themeKey);
}
