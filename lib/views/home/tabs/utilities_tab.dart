// ignore_for_file: unused_element, unused_field, unused_local_variable, unused_import, dead_code
import 'widgets/utilities_daily_pick_card.dart';
import 'widgets/utilities_tab_body.dart';
import 'dart:async';
import 'dart:math';
import 'package:intl/intl.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../utils/sl_notice.dart';
import '../../../models/house_settings.dart';
import '../../../utils/services/admob_service.dart';
import '../../../utils/services/house_service.dart';
import '../../../utils/services/utility_service.dart';
import '../../../utils/services/offline_cache_service.dart';
import '../../../core/sl_theme.dart';
import 'package:soullocket_app/views/utilities/utility_launcher.dart';
// import '../../utils/sl_notice.dart';

// ─── Web-parity: Map ID -> Icon & Colors ───

class UtilitiesTab extends StatefulWidget {
  const UtilitiesTab({super.key});

  @override
  State<UtilitiesTab> createState() => _UtilitiesTabState();
}

class _UtilitiesTabState extends State<UtilitiesTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final HouseService _houseService = HouseService();
  final UtilityService _utilityService = UtilityService();
  final AdMobService _adMob = AdMobService();

  String? _houseId;
  String _myName = L10nService().translate('home_bn_1fd75b');
  String _relationshipMode = 'single';
  List<UtilityApp> _recentApps = const <UtilityApp>[];
  bool _layoutReady = false;

  @override
  void initState() {
    super.initState();
    final prefs = OfflineCacheService.getPrefsSync();
    if (prefs != null) _restoreLayout(prefs);
    unawaited(_init());
  }

  // Không khai báo lại dispose() ở dưới nữa

  Future<void> _init() async {
    try {
      final prefs =
          OfflineCacheService.getPrefsSync() ??
          await SharedPreferences.getInstance();
      if (!mounted) return;
      // Cache nóng đã được áp dụng trong initState, không dựng lại lưới lần nữa.
      if (!_layoutReady) setState(() => _restoreLayout(prefs));
      await _fetchUtilityStats();
    } catch (error) {
      debugPrint('[Utilities] Không đọc được bố cục: $error');
    } finally {
      if (mounted && !_layoutReady) {
        setState(() => _layoutReady = true);
      }
    }
  }

  void _restoreLayout(SharedPreferences prefs) {
    final snapshot = _utilityService.readLayout(prefs);
    _recentApps = snapshot.recentApps;
    final account = UtilityService.cachedAccount(prefs, _auth.currentUser?.uid);
    _houseId = account?.houseId;
    _myName = account?.name ?? _myName;
    final mode = account?.relationshipMode;
    if (mode != null) {
      _relationshipMode = mode;
      _layoutReady = true;
    }
  }

  Future<void> _fetchUtilityStats() async {
    final user = _auth.currentUser;
    if (user == null) return;
    try {
      _houseId = await _houseService.getCurrentHouseId();
      if (!mounted || _auth.currentUser?.uid != user.uid) return;
      if (_houseId != null) {
        // Tải từ cache trước
        final cachedData = OfflineCacheService.loadCacheSync(
          'utilities_settings_$_houseId',
        );
        if (!_layoutReady && cachedData is Map) {
          _applySettings(cachedData);
        }

        final settingsSnap = await _dbRef
            .child('houses/$_houseId/settings')
            .get()
            .timeout(const Duration(seconds: 3));
        if (settingsSnap.exists && settingsSnap.value is Map) {
          final map = Map<dynamic, dynamic>.from(settingsSnap.value as Map);
          if (!mounted || _auth.currentUser?.uid != user.uid) return;
          _applySettings(map);
          await OfflineCacheService.saveCache(
            'utilities_settings_$_houseId',
            map,
          );
        }
      }
    } catch (error) {
      debugPrint(
        '[SuppressedError] lib/views/home/tabs/utilities_tab.dart: $error',
      );
    }
  }

  void _applySettings(Map<dynamic, dynamic> map) {
    if (!mounted) return;
    final mode = HouseSettings.inferRelationshipModeFromSettingsMap(map);
    final name = map['nameU1']?.toString() ?? context.tr('home_bn_1fd75b');
    if (_layoutReady && mode == _relationshipMode && name == _myName) return;
    setState(() {
      _relationshipMode = mode;
      _myName = name;
      _layoutReady = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (!_layoutReady) {
      return const Center(child: CircularProgressIndicator());
    }
    final categories = UtilityService.appsByCategory(_relationshipMode);
    final appsById = <String, UtilityApp>{
      for (final apps in categories.values)
        for (final app in apps) app.id: app,
    };
    final dailyPick = UtilityDailyPick.forDay(
      DateTime.now(),
      appsById.containsKey,
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SLTheme.softCanvasBackdrop(
        baseColor: SLColors.paperCanvas,
        accentColor: SLColors.secondary,
        secondaryAccent: SLColors.thread,
        motif: SLCanvasBackdropMotif.sparkles,
        child: UtilitiesTabBody(
          categories: categories,
          recentApps: _recentApps
              .where((app) => appsById.containsKey(app.id))
              .toList(growable: false),
          // Đã gỡ "Ghim lên trang Nhà" (12/10/2026): Home không còn hàng ô ghim.
          pinnedIds: const <String>{},
          dailyPick: dailyPick,
          dailyPickApp: dailyPick == null ? null : appsById[dailyPick.appId],
          onAppTap: _navigateToApp,
          onAppLongPress: null,
        ),
      ),
    );
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

  Future<void> _checkAndShowAppReviewForUtility() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      int openCount = (prefs.getInt('app_review_utility_open_count') ?? 0) + 1;
      await prefs.setInt('app_review_utility_open_count', openCount);

      if (openCount == 6 ||
          openCount == 30 ||
          openCount == 90 ||
          openCount == 200) {
        final InAppReview inAppReview = InAppReview.instance;
        if (await inAppReview.isAvailable()) {
          Future.delayed(const Duration(seconds: 2), () async {
            try {
              await inAppReview.requestReview();
            } catch (error) {
              debugPrint(
                '[SuppressedError] lib/views/home/tabs/utilities_tab.dart: $error',
              );
            }
          });
        }
      }
    } catch (error) {
      debugPrint(
        '[SuppressedError] lib/views/home/tabs/utilities_tab.dart: $error',
      );
    }
  }

  static DateTime? _lastUtilityAdTime;

  Future<void> _navigateToApp(String id) async {
    await UtilityLauncher.open(
      context,
      id: id,
      houseId: _houseId,
      myName: _myName,
      relationshipMode: _relationshipMode,
      beforeOpen: () => _prepareUtilityOpen(id),
    );
  }

  Future<bool> _prepareUtilityOpen(String id) async {
    if (!mounted) return false;

    final houseId = _houseId?.trim();
    final uid = _auth.currentUser?.uid;
    if (houseId == null || houseId.isEmpty || uid == null) return false;
    bool isCurrentScope() =>
        mounted &&
        _auth.currentUser?.uid == uid &&
        _houseId?.trim() == houseId &&
        TickerMode.valuesOf(context).enabled &&
        (ModalRoute.of(context)?.isCurrent ?? true);

    // Quyền Pro là bước phụ của việc mở tiện ích. Nếu dịch vụ mua hàng chậm
    // hoặc lỗi mạng, bỏ qua quảng cáo thay vì giữ khóa điều hướng.
    var isPro = true;
    try {
      isPro = await _adMob.isProUser().timeout(const Duration(seconds: 2));
    } catch (error) {
      debugPrint(
        '[Utilities] Không đọc được quyền Pro, bỏ qua quảng cáo: $error',
      );
    }
    if (!isCurrentScope()) return false;
    if (!isPro && id != 'store') {
      try {
        final now = DateTime.now();
        final prefs =
            OfflineCacheService.getPrefsSync() ??
            await SharedPreferences.getInstance().timeout(
              const Duration(seconds: 2),
            );
        if (!isCurrentScope()) return false;

        // 1. Tăng bộ đếm click
        int tapCount = (prefs.getInt('utility_click_tap_count') ?? 0) + 1;
        await prefs
            .setInt('utility_click_tap_count', tapCount)
            .timeout(const Duration(seconds: 1));

        // 2. Lấy mục tiêu ngẫu nhiên (nếu chưa có thì sinh mới 7-12)
        int target = prefs.getInt('utility_click_tap_target') ?? 0;
        if (target < 7 || target > 12) {
          target = 7 + Random().nextInt(6); // 7 đến 12
          await prefs
              .setInt('utility_click_tap_target', target)
              .timeout(const Duration(seconds: 1));
        }

        debugPrint('UtilityClickAd: Tap count = $tapCount, Target = $target');

        // 3. Nếu đạt mục tiêu
        if (tapCount >= target) {
          // Reset bộ đếm và sinh mục tiêu mới
          final nextTarget = 7 + Random().nextInt(6);
          await prefs
              .setInt('utility_click_tap_count', 0)
              .timeout(const Duration(seconds: 1));
          await prefs
              .setInt('utility_click_tap_target', nextTarget)
              .timeout(const Duration(seconds: 1));

          // Kiểm tra giới hạn 2 tiếng
          final lastShownMs =
              prefs.getInt('utility_click_ad_last_shown_time') ?? 0;
          final timeDiff = now.millisecondsSinceEpoch - lastShownMs;
          final has2HourCooldownPassed =
              lastShownMs == 0 || timeDiff >= 2 * 60 * 60 * 1000;

          // Kiểm tra giới hạn tối đa 3 cái một ngày
          final todayStr = DateFormat('yyyy-MM-dd').format(now);
          final savedDate =
              prefs.getString('utility_click_ad_shown_date') ?? '';
          int shownToday =
              prefs.getInt('utility_click_ad_shown_today_count') ?? 0;

          if (savedDate != todayStr) {
            shownToday = 0;
            await prefs
                .setString('utility_click_ad_shown_date', todayStr)
                .timeout(const Duration(seconds: 1));
            await prefs
                .setInt('utility_click_ad_shown_today_count', 0)
                .timeout(const Duration(seconds: 1));
          }

          final isUnderDailyLimit = shownToday < 3;

          debugPrint(
            'UtilityClickAd: Cooldown passed = $has2HourCooldownPassed, Shown today = $shownToday, Under limit = $isUnderDailyLimit',
          );

          if (has2HourCooldownPassed && isUnderDailyLimit) {
            debugPrint(
              'UtilityClickAd: Target reached! Showing click-count ad.',
            );
            final shown = await _showInterstitialAdWithoutBlocking(
              isCurrentScope,
            );
            if (shown) {
              await prefs
                  .setInt(
                    'utility_click_ad_last_shown_time',
                    now.millisecondsSinceEpoch,
                  )
                  .timeout(const Duration(seconds: 1));
              await prefs
                  .setInt('utility_click_ad_shown_today_count', shownToday + 1)
                  .timeout(const Duration(seconds: 1));
              _lastUtilityAdTime = now;
            }
          }
        } else {
          // Nếu chưa đạt mục tiêu click ngẫu nhiên, vẫn kiểm tra hiển thị ad thường 5 phút như cũ
          if ((_lastUtilityAdTime == null ||
                  now.difference(_lastUtilityAdTime!) >
                      const Duration(minutes: 5)) &&
              !_adMob.hasRecentFullscreenAd()) {
            final shown = await _showInterstitialAdWithoutBlocking(
              isCurrentScope,
            );
            if (shown) {
              _lastUtilityAdTime = now;
            }
          }
        }
      } catch (error) {
        // Preferences/quảng cáo là tối ưu phụ; không chặn màn hình chính.
        debugPrint('[Utilities] Bỏ qua quảng cáo khi chuẩn bị lỗi: $error');
      }
    }

    if (!isCurrentScope()) return false;

    // Không giữ route lại vì hai lần ghi prefs/đọc danh sách gần đây. Các
    // thao tác này chỉ cập nhật hàng "Gần đây" sau khi màn hình đã mở.
    unawaited(_persistRecentUtility(id, uid, houseId));

    unawaited(_checkAndShowAppReviewForUtility());
    return isCurrentScope();
  }

  Future<bool> _showInterstitialAdWithoutBlocking(
    bool Function() isCurrentScope,
  ) async {
    // Startup tự chuẩn bị SDK ở nền; cú chạm không mở thêm form khởi tạo.
    if (!_adMob.canRequestAds || !isCurrentScope()) return false;
    try {
      return await _adMob.showInterstitialAd(
        isCurrent: isCurrentScope,
        preparationTimeout: const Duration(seconds: 3),
      );
    } catch (error) {
      debugPrint('[Utilities] Không hiển thị được quảng cáo: $error');
      return false;
    }
  }

  Future<void> _persistRecentUtility(
    String id,
    String expectedUid,
    String expectedHouseId,
  ) async {
    try {
      await _utilityService.markAppAsRecentlyUsed(id);
      final updatedRecentApps = await _utilityService.getRecentApps();
      if (!mounted ||
          _auth.currentUser?.uid != expectedUid ||
          _houseId?.trim() != expectedHouseId ||
          _sameAppIds(_recentApps, updatedRecentApps)) {
        return;
      }
      setState(() => _recentApps = updatedRecentApps);
    } catch (error) {
      debugPrint('[Utilities] Không lưu được tiện ích gần đây: $error');
    }
  }
}
