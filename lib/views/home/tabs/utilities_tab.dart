import 'widgets/utilities_tab_body.dart';
// ignore_for_file: unused_element, unused_field, unused_local_variable, dead_code, deprecated_member_use, use_super_parameters, prefer_const_constructors, use_build_context_synchronously, duplicate_ignore, avoid_web_libraries_in_flutter, avoid_unnecessary_containers
import 'dart:async';
import 'package:flutter/foundation.dart'
    show kDebugMode, kIsWeb, listEquals, TargetPlatform, defaultTargetPlatform;

import 'package:flutter/material.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../../../utils/sl_notice.dart';
import '../../../models/house_settings.dart';
import '../../../utils/services/admob_service.dart';
import '../../../utils/services/house_service.dart';
import '../../../utils/services/military_lock_service.dart';
import '../../../utils/services/utility_service.dart';
import '../../../utils/services/offline_cache_service.dart';
import '../../../core/sl_theme.dart';
import '../../utilities/bucket_list_screen.dart';
import '../../utilities/shared_notes_screen.dart';
import '../../utilities/finance_screen.dart';
import '../../utilities/friendly_chat_screen.dart';
import '../../utilities/wishlist_screen.dart';
import '../../utilities/habit_screen.dart';
import '../../utilities/voice_screen.dart';
import '../../utilities/calendar_screen.dart';
import '../../utilities/capsule_screen.dart';
import '../../utilities/cinema_screen.dart';
import '../../../features/wheel/wheel_screen.dart';
import '../../utilities/secret_vault_screen.dart';
import '../../utilities/gift_maker_screen.dart';
import '../../utilities/giftcode_screen.dart';
import '../../utilities/history_screen.dart';
import '../../utilities/drawing_studio_screen.dart';
import '../../utilities/diary_export_screen.dart';
import '../../utilities/reward_store_screen.dart';
import '../../../features/tarot/tarot_screen.dart';
import '../../utilities/collage_maker_screen.dart';
import '../../utilities/age_zodiac_screen.dart';
import '../../utilities/love_card_screen.dart';
import '../../utilities/calculator_screen.dart';
import '../../utilities/creative_diary_screen.dart';
import '../../utilities/sticker_library_screen.dart';
import '../../utilities/utility_sticker_icon.dart';

// import '../../utils/sl_notice.dart';

// ─── Web-parity: Map ID -> Icon & Colors ───

class UtilitiesTab extends StatefulWidget {
  const UtilitiesTab({super.key});

  @override
  State<UtilitiesTab> createState() => _UtilitiesTabState();
}

class _UtilitiesTabState extends State<UtilitiesTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final HouseService _houseService = HouseService();
  final UtilityService _utilityService = UtilityService();
  final AdMobService _adMob = AdMobService();
  final MilitaryLockService _militaryLockService = MilitaryLockService();

  String? _houseId;
  String _myName = L10nService().translate('home_bn_1fd75b');
  List<String> _customOrder = [];
  String _relationshipMode = 'single';
  bool _isEditMode = false;
  int _currentSegment = 0;
  BannerAd? _bottomBannerAd;
  bool _isBottomBannerReady = false;
  List<UtilityApp> _pinnedApps = const <UtilityApp>[];
  List<UtilityApp> _recentApps = const <UtilityApp>[];

  @override
  void initState() {
    super.initState();
    unawaited(_init());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_fetchUtilityStats());
      precacheUtilityStickerList(context);
      Future<void>.delayed(const Duration(milliseconds: 420), () {
        if (!mounted) return;
        _loadBottomBanner();
      });
    });
  }

  // Không khai báo lại dispose() ở dưới nữa

  Future<void> _init() async {
    final nextOrder = await _utilityService.getCustomOrder();
    final pinnedApps = await _utilityService.getPinnedApps();
    final recentApps = await _utilityService.getRecentApps();
    if (!mounted) return;
    final shouldUpdateOrder = !listEquals(_customOrder, nextOrder);
    final shouldUpdatePinned = !_sameAppIds(_pinnedApps, pinnedApps);
    final shouldUpdateRecent = !_sameAppIds(_recentApps, recentApps);
    if (!shouldUpdateOrder && !shouldUpdatePinned && !shouldUpdateRecent) {
      return;
    }
    setState(() {
      if (shouldUpdateOrder) {
        _customOrder = List<String>.from(nextOrder);
      }
      if (shouldUpdatePinned) {
        _pinnedApps = pinnedApps;
      }
      if (shouldUpdateRecent) {
        _recentApps = recentApps;
      }
    });
  }

  Future<void> _saveOrder() async {
    await _utilityService.saveCustomOrder(_customOrder);
  }

  List<String> _orderedIdsForApps(List<UtilityApp> apps) {
    final visibleIds = apps.map((app) => app.id).toSet();
    final ordered = <String>[];
    for (final appId in _customOrder) {
      if (visibleIds.remove(appId)) {
        ordered.add(appId);
      }
    }
    for (final app in apps) {
      if (visibleIds.remove(app.id)) {
        ordered.add(app.id);
      }
    }
    return ordered;
  }

  List<UtilityApp> _sortAppsByCurrentOrder(List<UtilityApp> apps) {
    final appById = <String, UtilityApp>{for (final app in apps) app.id: app};
    final orderedIds = _orderedIdsForApps(apps);
    if (!listEquals(_customOrder, orderedIds)) {
      _customOrder = List<String>.from(orderedIds);
    }
    return orderedIds
        .map((id) => appById[id])
        .whereType<UtilityApp>()
        .toList(growable: false);
  }

  Future<void> _reloadCustomOrder() async {
    final nextOrder = await _utilityService.getCustomOrder();
    if (!mounted) return;
    setState(() {
      _customOrder = List<String>.from(nextOrder);
    });
  }

  Future<void> _reorderAppAsync(String draggedId, String targetId) async {
    if (draggedId == targetId) return;
    if (!_customOrder.contains(draggedId) || !_customOrder.contains(targetId)) {
      await _reloadCustomOrder();
      return;
    }

    final nextOrder = List<String>.from(_customOrder);
    final oldIndex = nextOrder.indexOf(draggedId);
    final newIndex = nextOrder.indexOf(targetId);
    if (oldIndex == -1 || newIndex == -1 || oldIndex == newIndex) {
      return;
    }

    nextOrder.removeAt(oldIndex);
    nextOrder.insert(newIndex, draggedId);

    if (!mounted) return;
    setState(() {
      _customOrder = nextOrder;
    });
    await _saveOrder();
  }

  List<UtilityApp> _appsForCurrentSegment() {
    final visibleAppsAll = UtilityService.appsForMode(_relationshipMode);
    final filtered = _currentSegment == 1
        ? visibleAppsAll.where((app) => app.isTool).toList(growable: false)
        : visibleAppsAll.where((app) => !app.isTool).toList(growable: false);
    return _sortAppsByCurrentOrder(filtered);
  }

  void _handleOrderDrop(String draggedId, String targetId) {
    unawaited(_reorderAppAsync(draggedId, targetId));
  }

  Future<void> _resetOrderToDefault() async {
    if (!mounted) return;
    setState(() {
      _customOrder.clear();
    });
    await _utilityService.clearCustomOrder();
    await _reloadCustomOrder();
  }

  Future<void> _confirmResetLayout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: SLRadius.xlAll,
          ),
          title: Text(
            'Đặt lại bố cục',
            style: SLTheme.quicksand(
              fontWeight: FontWeight.w900,
              color: const Color(0xFFD81B60),
            ),
          ),
          content: Text(
            context.tr('home_bncchcmuna_5043aa'),
            style: SLTheme.quicksand(
              fontWeight: FontWeight.w700,
              height: 1.5,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(
                context.tr('home_hy_1e4050'),
                style: SLTheme.quicksand(fontWeight: FontWeight.w800),
              ),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFD81B60),
                foregroundColor: Colors.white,
              ),
              child: Text(
                context.tr('home_tli_ffd7c4'),
                style: SLTheme.quicksand(fontWeight: FontWeight.w900),
              ),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;
    await _resetOrderToDefault();
  }

  void _reorderApp(String draggedId, String targetId) {
    _handleOrderDrop(draggedId, targetId);
  }

  Future<void> _fetchUtilityStats() async {
    final user = _auth.currentUser;
    if (user == null) return;
    try {
      _houseId = await _houseService.getCurrentHouseId();
      if (_houseId != null) {
        // Tải từ cache trước
        final cachedData =
            OfflineCacheService.loadCacheSync('utilities_settings_$_houseId');
        if (cachedData != null) {
          if (mounted) {
            setState(() {
              _myName = cachedData['nameU1'] ?? context.tr('home_bn_1fd75b');
              _relationshipMode =
                  HouseSettings.inferRelationshipModeFromSettingsMap(
                      Map<dynamic, dynamic>.from(cachedData));
            });
          }
        }

        final settingsSnap = await _dbRef
            .child('houses/$_houseId/settings')
            .get()
            .timeout(const Duration(seconds: 3));
        if (settingsSnap.exists && settingsSnap.value is Map) {
          final map = Map<dynamic, dynamic>.from(settingsSnap.value as Map);
          OfflineCacheService.saveCache('utilities_settings_$_houseId', map);
          if (mounted) {
            setState(() {
              _myName = map['nameU1'] ?? context.tr('home_bn_1fd75b');
              _relationshipMode =
                  HouseSettings.inferRelationshipModeFromSettingsMap(map);
            });
          }
        }
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _bottomBannerAd?.dispose();
    super.dispose();
  }

  void _loadBottomBanner() async {
    if (kIsWeb || ModalRoute.of(context)?.isCurrent != true) return;

    await _adMob.initialize();
    if (!mounted || ModalRoute.of(context)?.isCurrent != true) return;

    // Nếu là tk Pro thì không hiển thị banner
    if (await _adMob.isProUser()) {
      _bottomBannerAd?.dispose();
      _bottomBannerAd = null;
      if (!mounted) return;
      setState(() => _isBottomBannerReady = false);
      return;
    }

    _bottomBannerAd?.dispose();
    _bottomBannerAd = null;
    if (!mounted || ModalRoute.of(context)?.isCurrent != true) return;
    _bottomBannerAd = await _adMob.createBannerAd(
      onAdLoaded: (_) {
        if (!mounted || ModalRoute.of(context)?.isCurrent != true) return;
        setState(() => _isBottomBannerReady = true);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final visibleApps = _appsForCurrentSegment();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: UtilitiesTabBody(
        currentSegment: _currentSegment,
        onSegmentChanged: _handleSegmentChanged,
        onResetTap: _confirmResetLayout,
        apps: visibleApps,
        pinnedApps: _shortcutPinnedApps,
        recentApps: _shortcutRecentApps,
        onShortcutTap: _navigateToApp,
        showBottomBanner: _shouldShowBottomBanner,
        bottomBannerAd: _bottomBannerAd,
        isEditMode: _isEditMode,
        onAppTap: _navigateToApp,
        onReorder: _reorderApp,
        onEditModeChanged: _handleEditModeChanged,
      ),
    );
  }

  bool get _shouldShowBottomBanner =>
      _currentSegment == 0 &&
      _isBottomBannerReady &&
      ModalRoute.of(context)?.isCurrent == true;

  List<UtilityApp> get _shortcutPinnedApps {
    return _pinnedApps
        .where(
            (app) => UtilityService.isUtilityAllowed(app.id, _relationshipMode))
        .toList(growable: false);
  }

  List<UtilityApp> get _shortcutRecentApps {
    final pinnedIds = _shortcutPinnedApps.map((app) => app.id).toSet();
    return _recentApps
        .where(
            (app) => UtilityService.isUtilityAllowed(app.id, _relationshipMode))
        .where((app) => !pinnedIds.contains(app.id))
        .toList(growable: false);
  }

  bool _sameAppIds(List<UtilityApp> left, List<UtilityApp> right) {
    if (left.length != right.length) {
      return false;
    }
    for (var i = 0; i < left.length; i++) {
      if (left[i].id != right[i].id) {
        return false;
      }
    }
    return true;
  }

  void _handleSegmentChanged(int segment) {
    if (_currentSegment == segment) return;
    setState(() => _currentSegment = segment);
  }

  void _handleEditModeChanged(bool value) {
    if (_isEditMode == value) return;
    setState(() => _isEditMode = value);
  }

  static DateTime? _lastUtilityAdTime;

  Future<void> _navigateToApp(String id) async {
    if (!UtilityService.isUtilityAllowed(id, _relationshipMode)) {
      final blockedMessage =
          UtilityService.blockedMessageForMode(id, _relationshipMode);
      if (blockedMessage.isNotEmpty) {
        SLNotice.showInfo(context, blockedMessage);
        return;
      }
      SLNotice.showInfo(context, context.tr('home_tinchnychd_6061d1'));
      return;
    }
    final houseId = _houseId;
    if (houseId == null || houseId.isEmpty) {
      SLNotice.showInfo(context, context.tr('home_angtidliun_f42fcd'));
      return;
    }

    final isPro = await _adMob.isProUser();
    if (!isPro && id != 'store') {
      final now = DateTime.now();
      if ((_lastUtilityAdTime == null ||
              now.difference(_lastUtilityAdTime!) >
                  const Duration(minutes: 15)) &&
          !_adMob.hasRecentFullscreenAd()) {
        await _adMob.showInterstitialAd();
        _lastUtilityAdTime = DateTime.now();
      }
    }

    if (!mounted) {
      return;
    }

    await _utilityService.markAppAsRecentlyUsed(id);
    final updatedRecentApps = await _utilityService.getRecentApps();
    if (mounted && !_sameAppIds(_recentApps, updatedRecentApps)) {
      setState(() {
        _recentApps = updatedRecentApps;
      });
    }

    Widget? screen;
    switch (id) {
      case 'bucket':
        screen = BucketListScreen(houseId: houseId, myName: _myName);
        break;
      case 'note':
        screen = SharedNotesScreen(houseId: houseId, myName: _myName);
        break;
      case 'friendly_chat':
        screen = FriendlyChatScreen(houseId: houseId, myName: _myName);
        break;
      case 'finance':
        screen = FinanceScreen(houseId: houseId, myName: _myName);
        break;
      case 'wish':
        screen = WishlistScreen(houseId: houseId, myName: _myName);
        break;
      case 'habit':
        screen = HabitScreen(houseId: houseId, myName: _myName);
        break;
      case 'drawing':
        screen = DrawingStudioScreen(houseId: houseId, myName: _myName);
        break;
      case 'sticker_library':
        screen = const StickerLibraryScreen();
        break;
      case 'voice':
        screen = VoiceScreen(houseId: houseId, myName: _myName);
        break;
      case 'calendar':
        screen = CalendarScreen(houseId: houseId, myName: _myName);
        break;
      case 'calculator':
        screen = const CalculatorScreen();
        break;
      case 'capsule':
        screen = CapsuleScreen(houseId: houseId, myName: _myName);
        break;
      case 'cinema':
        screen = CinemaScreen(houseId: houseId, myName: _myName);
        break;
      case 'wheel':
        screen = WheelScreen(houseId: houseId);
        break;
      case 'vault':
        if (kIsWeb) {
          // Buộc khóa lại trước khi vào để yêu cầu mật khẩu mỗi lần F5 hoặc thoát
          _militaryLockService.lockScope(LockScope.privateArea);
        }
        final unlocked = await _militaryLockService.requestUnlock(
          context: context,
          scope: LockScope.privateArea,
          houseId: houseId,
          title: MilitaryLockService.getScopeTitle(LockScope.privateArea),
          reason: MilitaryLockService.scopeReason(LockScope.privateArea),
        );
        if (!unlocked || !mounted) {
          return;
        }
        screen = SecretVaultScreen(houseId: houseId);
        break;
      case 'gift':
        screen = GiftMakerScreen(houseId: houseId, myName: _myName);
        break;
      case 'giftcode':
        screen = houseId.isEmpty ||
                (!kDebugMode &&
                    !kIsWeb &&
                    defaultTargetPlatform == TargetPlatform.iOS)
            ? null
            : GiftcodeScreen(houseId: houseId, myName: _myName);
        break;
      case 'history':
        screen = HistoryScreen(houseId: houseId);
        break;
      case 'diary_export':
        screen = DiaryExportScreen(houseId: houseId);
        break;
      case 'tarot':
        screen = TarotScreen(
          houseId: houseId,
          relationshipMode: _relationshipMode,
          myName: _myName,
        );
        break;
      case 'collage':
        screen = CollageMakerScreen(houseId: houseId);
        break;
      case 'store':
        screen = !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS
            ? null
            : const RewardStoreScreen();
        break;
      case 'age_zodiac':
        screen = AgeZodiacScreen(houseId: houseId);
        break;
      case 'love_card':
        screen = LoveCardScreen(
          houseId: houseId,
          myUid: _auth.currentUser!.uid,
        );
        break;
      case 'creative_diary':
        screen = CreativeDiaryScreen(houseId: houseId);
        break;
    }
    if (screen != null) {
      if (!mounted) {
        return;
      }
      Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => screen!,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0.0, 0.05),
                  end: Offset.zero,
                ).animate(CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeOutCubic,
                )),
                child: child,
              ),
            );
          },
          transitionDuration: const Duration(milliseconds: 300),
        ),
      );
    } else {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('home_tinchnyang_612f3d'))));
    }
  }
}
