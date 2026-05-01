// ignore_for_file: unused_element, unused_field, unused_local_variable, dead_code, deprecated_member_use, use_super_parameters, prefer_const_constructors, use_build_context_synchronously, duplicate_ignore, avoid_web_libraries_in_flutter, avoid_unnecessary_containers
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants/app_config.dart';
import 'app_check_http_headers.dart';
import 'app_lifecycle_presence_guard.dart';
import 'consent_service.dart';
import 'house_service.dart';
import 'purchase_service.dart';
import 'revenue_security_telemetry_service.dart';

/// ============================================================
///  AdMobService — GRA (Phase Production)
///  Quản lý toàn bộ quảng cáo Google AdMob
///
///  Đơn vị quảng cáo thật (ca-app-pub-6165771694697009):
///  - Rewarded chính (Xen_Ke_Thuong):   /3441513253
///  - Rewarded điểm danh (Diem_Danh):   /9710840883
///  - Banner chính (Banner_Chinh):       /5949757521
///  - Interstitial (trung_gian):         /6283299015
///  - App Open (mo_ung_dung):            /3305781889
/// ============================================================

class RewardClaimResult {
  const RewardClaimResult({
    required this.ok,
    this.error,
    this.statusCode,
    this.granted = 0,
    this.points = 0,
  });

  final bool ok;
  final String? error;
  final int? statusCode;
  final int granted;
  final int points;

  factory RewardClaimResult.fromResponse(Map<String, dynamic>? response) {
    if (response == null) {
      return const RewardClaimResult(
        ok: false,
        error: 'reward_server_unavailable',
      );
    }

    return RewardClaimResult(
      ok: response['ok'] == true,
      error: response['error']?.toString(),
      statusCode: (response['statusCode'] as num?)?.toInt(),
      granted: (response['granted'] as num?)?.toInt() ?? 0,
      points: (response['points'] as num?)?.toInt() ?? 0,
    );
  }

  bool get alreadyClaimed => error == 'already_claimed';

  bool get endpointMissing =>
      statusCode == 404 || error == 'endpoint_not_found';

  bool get unauthenticated => statusCode == 401 || error == 'unauthenticated';

  bool get rateLimited => statusCode == 429 || error == 'rate_limited';

  bool get appCheckIssue =>
      error == 'missing_app_check' || error == 'invalid_app_check';

  bool get networkIssue =>
      error == 'network_error' ||
      error == 'network_timeout' ||
      error == 'invalid_auth_header';
}

class AdMobService {
  static final AdMobService _instance = AdMobService._internal();
  factory AdMobService() => _instance;
  AdMobService._internal();
  static const int rewardedMainPoints = 50;
  static const int dailyRewardedAdLimit = 50; // Giới hạn 10 quảng cáo/ngày
  static const String _autoInterstitialNextAtPrefsKey =
      'il_auto_interstitial_next_at_ms_v1';
  static const String _appOpenLastShownDatePrefsKey =
      'il_app_open_last_shown_date_v1';
  static const String _appOpenShownCountPrefsKey = 'il_app_open_shown_count_v1';
  static const String _appOpenShownDatePrefsKey = 'il_app_open_shown_date_v1';
  static const String _dailyRewardedAdCountPrefsKey =
      'il_daily_rewarded_ad_count_v1'; // Theo dõi số lần xem ads hôm nay
  static const String _dailyRewardedAdDatePrefsKey =
      'il_daily_rewarded_ad_date_v1'; // Ngày hiện tại (yyyy-MM-dd)
  static const int _autoInterstitialMinMinutes = 45;
  static const int _autoInterstitialMaxMinutes = 90;
  static const int _autoInterstitialRetryMinutes = 15;
  static const int _autoMandatoryRewardedChancePercent = 40;
  static const int _appOpenMaxPerDay = 3;
  final HouseService _houseService = HouseService();
  final ConsentService _consentService = ConsentService();
  final Random _random = Random();

  // ─── AD UNIT IDs ─────────────────────────────────────────────
  // Debug mode  → Google Test IDs (không tốn tiền khi test)
  // Release mode → ID thật từ AdMob Console của bạn

  // Fallback IDs (có thể giữ lại các ID thật hiện tại như bản phụ phòng hờ)
  static String _rewardedMainId = 'ca-app-pub-6165771694697009/3441513253';
  static String _rewardedCheckinId = 'ca-app-pub-6165771694697009/9710840883';
  static String _rewardedSoulGameId = 'ca-app-pub-6165771694697009/5113438527';
  static String _bannerId = 'ca-app-pub-6165771694697009/5949757521';
  static String _interstitialId = 'ca-app-pub-6165771694697009/6283299015';
  static String _appOpenId = 'ca-app-pub-6165771694697009/3305781889';

  /// Rewarded chính — "Xem quảng cáo nhận điểm"
  static String get rewardedMainId =>
      kDebugMode ? 'ca-app-pub-3940256099942544/5224354917' : _rewardedMainId;

  /// Rewarded điểm danh 7 ngày
  static String get rewardedCheckinId => kDebugMode
      ? 'ca-app-pub-3940256099942544/5224354917'
      : _rewardedCheckinId;

  static String get rewardedSoulGameId => kDebugMode
      ? 'ca-app-pub-3940256099942544/5224354917'
      : _rewardedSoulGameId;

  /// Banner hiển thị thường trực
  static String get bannerId =>
      kDebugMode ? 'ca-app-pub-3940256099942544/6300978111' : _bannerId;

  /// Interstitial — quảng cáo toàn màn hình giữa chừng
  static String get interstitialId =>
      kDebugMode ? 'ca-app-pub-3940256099942544/1033173712' : _interstitialId;

  /// App Open — quảng cáo khi mở app
  static String get appOpenId =>
      kDebugMode ? 'ca-app-pub-3940256099942544/9257395921' : _appOpenId;

  // ─── REWARDED AD (CHÍNH) ─────────────────────────────────────
  RewardedAd? _rewardedAd;
  bool _isRewardedAdLoading = false;
  RewardedAd? _soulGameRewardedAd;
  bool _isSoulGameRewardedAdLoading = false;
  AppOpenAd? _appOpenAd;
  bool _isAppOpenLoading = false;
  bool _isShowingAppOpenAd = false;
  int _lastFullscreenAdShownMs = 0;
  static const int _fullscreenAdCooldownMs = 2 * 60 * 1000;
  Completer<void>? _initializeCompleter;
  Completer<bool>? _appOpenLoadCompleter;
  bool _sdkInitialized = false;

  DatabaseReference? get _currentUserRef {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    return FirebaseDatabase.instance.ref('users/${user.uid}');
  }

  bool hasRecentFullscreenAd({
    Duration cooldown = const Duration(milliseconds: _fullscreenAdCooldownMs),
  }) {
    final lastShownMs = _lastFullscreenAdShownMs;
    if (lastShownMs <= 0) return false;
    return DateTime.now().millisecondsSinceEpoch - lastShownMs <
        cooldown.inMilliseconds;
  }

  Future<void> initialize() async {
    if (_sdkInitialized) return;
    if (!await _consentService.hasValidConsent()) return;
    if (_initializeCompleter != null) {
      return _initializeCompleter!.future;
    }
    final completer = Completer<void>();
    _initializeCompleter = completer;
    if (kIsWeb) {
      completer.complete();
      return;
    }

    // Implement UMP Consent Flow
    final params = ConsentRequestParameters(
      consentDebugSettings: ConsentDebugSettings(
        debugGeography: DebugGeography.debugGeographyDisabled,
        // testIdentifiers: ['YOUR-DEVICE-ID'], // Uncomment and add your device ID for testing
      ),
    );

    try {
      final consentCompleter = Completer<void>();
      ConsentInformation.instance.requestConsentInfoUpdate(
        params,
        () async {
          if (await ConsentInformation.instance.isConsentFormAvailable()) {
            ConsentForm.loadAndShowConsentFormIfRequired(
              (loadAndShowError) {
                if (loadAndShowError != null) {
                  debugPrint('Consent Form Error: $loadAndShowError');
                }
                if (!consentCompleter.isCompleted) {
                  consentCompleter.complete();
                }
              },
            );
          } else {
            if (!consentCompleter.isCompleted) {
              consentCompleter.complete();
            }
          }
        },
        (FormError error) {
          debugPrint('Consent Info Update Error: $error');
          if (!consentCompleter.isCompleted) {
            consentCompleter.complete();
          }
        },
      );
      await consentCompleter.future;
    } catch (e) {
      debugPrint('Error handling UMP Consent: $e');
    }

    try {
      if (!await ConsentInformation.instance.canRequestAds()) {
        return;
      }

      // Đồng bộ ID Quảng cáo từ Firebase nhằm loại bỏ HardCode Source
      try {
        final snap = await FirebaseDatabase.instance
            .ref('app_config/admob_ids')
            .get()
            .timeout(const Duration(seconds: 4));
        if (snap.exists && snap.value is Map) {
          final map = Map<dynamic, dynamic>.from(snap.value as Map);
          if (map['rewardedMainId'] != null) {
            _rewardedMainId = map['rewardedMainId'].toString();
          }
          if (map['rewardedCheckinId'] != null) {
            _rewardedCheckinId = map['rewardedCheckinId'].toString();
          }
          if (map['rewardedSoulGameId'] != null) {
            _rewardedSoulGameId = map['rewardedSoulGameId'].toString();
          }
          if (map['bannerId'] != null) {
            _bannerId = map['bannerId'].toString();
          }
          if (map['interstitialId'] != null) {
            _interstitialId = map['interstitialId'].toString();
          }
          if (map['appOpenId'] != null) {
            _appOpenId = map['appOpenId'].toString();
          }
        }
      } catch (e) {
        debugPrint('Failed to sync AdMob IDs: $e');
      }

      await MobileAds.instance.initialize();
      _sdkInitialized = true;
      _loadRewardedAd();
      _loadSoulGameRewardedAd();
      unawaited(loadInterstitialAd());
    } finally {
      if (!completer.isCompleted) {
        completer.complete();
      }
      _initializeCompleter = null;
    }
  }

  void _loadRewardedAd() {
    if (kIsWeb) return;
    if (!_sdkInitialized) return;
    if (_isRewardedAdLoading) return;
    _isRewardedAdLoading = true;

    RewardedAd.load(
      adUnitId: rewardedMainId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _isRewardedAdLoading = false;
        },
        onAdFailedToLoad: (error) {
          _rewardedAd = null;
          _isRewardedAdLoading = false;
        },
      ),
    );
  }

  void _loadSoulGameRewardedAd() {
    if (kIsWeb) return;
    if (!_sdkInitialized) return;
    if (_isSoulGameRewardedAdLoading) return;
    _isSoulGameRewardedAdLoading = true;

    RewardedAd.load(
      adUnitId: rewardedSoulGameId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _soulGameRewardedAd = ad;
          _isSoulGameRewardedAdLoading = false;
        },
        onAdFailedToLoad: (error) {
          _soulGameRewardedAd = null;
          _isSoulGameRewardedAdLoading = false;
        },
      ),
    );
  }

  void preloadSoulGameRewardedAd() {
    _loadSoulGameRewardedAd();
  }

  Future<bool> loadAppOpenAd() async {
    if (kIsWeb) return false;
    if (!_sdkInitialized) return false;
    if (_appOpenAd != null) return true;
    if (_isAppOpenLoading) {
      return _appOpenLoadCompleter?.future ?? false;
    }

    _isAppOpenLoading = true;
    final completer = Completer<bool>();
    _appOpenLoadCompleter = completer;
    await AppOpenAd.load(
      adUnitId: appOpenId,
      request: const AdRequest(),
      adLoadCallback: AppOpenAdLoadCallback(
        onAdLoaded: (ad) {
          _appOpenAd = ad;
          _isAppOpenLoading = false;
          if (!completer.isCompleted) {
            completer.complete(true);
          }
        },
        onAdFailedToLoad: (error) {
          _appOpenAd = null;
          _isAppOpenLoading = false;
          if (!completer.isCompleted) {
            completer.complete(false);
          }
        },
      ),
    );
    final loaded = await completer.future;
    if (identical(_appOpenLoadCompleter, completer)) {
      _appOpenLoadCompleter = null;
    }
    return loaded;
  }

  Future<bool> showAppOpenAdIfEligible() async {
    if (kIsWeb) return false;
    if (hasRecentFullscreenAd(cooldown: const Duration(minutes: 3))) {
      return false;
    }
    await initialize();
    if (!_sdkInitialized) return false;
    if (_isShowingAppOpenAd) return false;
    if (FirebaseAuth.instance.currentUser == null) return false;
    if (await isProUser()) return false;
    if (!await _canShowAppOpenToday()) return false;

    if (_appOpenAd == null) {
      final loaded = await loadAppOpenAd();
      if (!loaded || _appOpenAd == null) {
        return false;
      }
    }

    final completer = Completer<bool>();
    _isShowingAppOpenAd = true;
    AppLifecyclePresenceGuard.arm();
    _appOpenAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) async {
        _lastFullscreenAdShownMs = DateTime.now().millisecondsSinceEpoch;
        await _incrementAppOpenShownCount();
        if (!completer.isCompleted) completer.complete(true);
      },
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _appOpenAd = null;
        _isShowingAppOpenAd = false;
        AppLifecyclePresenceGuard.settle();
        unawaited(loadAppOpenAd());
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _appOpenAd = null;
        _isShowingAppOpenAd = false;
        AppLifecyclePresenceGuard.settle();
        if (!completer.isCompleted) completer.complete(false);
        unawaited(loadAppOpenAd());
      },
    );

    try {
      await _appOpenAd!.show();
    } catch (e) {
      _appOpenAd?.dispose();
      _appOpenAd = null;
      _isShowingAppOpenAd = false;
      AppLifecyclePresenceGuard.settle();
      if (!completer.isCompleted) {
        completer.complete(false);
      }
      unawaited(loadAppOpenAd());
    }
    return completer.future;
  }

  Future<bool> _canShowAppOpenToday() async {
    final prefs = await SharedPreferences.getInstance();
    final todayDate = _getTodayDateKey();
    final storedDate = prefs.getString(_appOpenShownDatePrefsKey);
    if (storedDate != todayDate) {
      await prefs.setString(_appOpenShownDatePrefsKey, todayDate);
      await prefs.setInt(_appOpenShownCountPrefsKey, 0);
    }

    final shownCount = prefs.getInt(_appOpenShownCountPrefsKey) ?? 0;
    if (shownCount >= _appOpenMaxPerDay) {
      return false;
    }

    // Cách 5 tiếng mới được hiện App Open Ad 1 lần
    final lastShownMs = prefs.getInt(_appOpenLastShownDatePrefsKey) ?? 0;
    final nowMs = DateTime.now().millisecondsSinceEpoch;

    if (lastShownMs == 0) {
      return true; // Lần đầu tiên
    }

    // 5 tiếng = 5 * 60 * 60 * 1000 = 18000000 ms
    final hoursDiff = (nowMs - lastShownMs) / (1000 * 60 * 60);
    if (hoursDiff >= 5) {
      return true;
    }

    return false;
  }

  Future<void> _incrementAppOpenShownCount() async {
    final prefs = await SharedPreferences.getInstance();
    final todayDate = _getTodayDateKey();
    final storedDate = prefs.getString(_appOpenShownDatePrefsKey);
    final currentCount = storedDate == todayDate
        ? prefs.getInt(_appOpenShownCountPrefsKey) ?? 0
        : 0;
    await prefs.setString(_appOpenShownDatePrefsKey, todayDate);
    await prefs.setInt(_appOpenShownCountPrefsKey, currentCount + 1);
    await prefs.setInt(
        _appOpenLastShownDatePrefsKey, DateTime.now().millisecondsSinceEpoch);
  }

  // ─── DAILY REWARDED AD LIMIT ──────────────────────────────────
  String _getTodayDateKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  /// Lấy số lần xem quảng cáo rewarded hôm nay
  Future<int> getDailyRewardedAdCount() async {
    final prefs = await SharedPreferences.getInstance();
    final storedDate = prefs.getString(_dailyRewardedAdDatePrefsKey);
    final todayDate = _getTodayDateKey();

    // Nếu ngày khác, reset counter
    if (storedDate != todayDate) {
      await prefs.setInt(_dailyRewardedAdCountPrefsKey, 0);
      await prefs.setString(_dailyRewardedAdDatePrefsKey, todayDate);
      return 0;
    }

    return prefs.getInt(_dailyRewardedAdCountPrefsKey) ?? 0;
  }

  /// Kiểm tra xem hôm nay còn được xem quảng cáo không
  Future<bool> canWatchRewardedAdToday() async {
    final count = await getDailyRewardedAdCount();
    return count < dailyRewardedAdLimit;
  }

  /// Lấy số lần còn lại có thể xem hôm nay
  Future<int> getRemainingDailyRewardedAds() async {
    final count = await getDailyRewardedAdCount();
    return (dailyRewardedAdLimit - count).clamp(0, dailyRewardedAdLimit);
  }

  /// Tăng bộ đếm lên 1
  Future<void> _incrementDailyRewardedAdCount() async {
    final prefs = await SharedPreferences.getInstance();
    final storedDate = prefs.getString(_dailyRewardedAdDatePrefsKey);
    final todayDate = _getTodayDateKey();

    // Nếu ngày khác, reset counter rồi set thành 1
    if (storedDate != todayDate) {
      await prefs.setInt(_dailyRewardedAdCountPrefsKey, 1);
      await prefs.setString(_dailyRewardedAdDatePrefsKey, todayDate);
    } else {
      final currentCount = prefs.getInt(_dailyRewardedAdCountPrefsKey) ?? 0;
      await prefs.setInt(_dailyRewardedAdCountPrefsKey, currentCount + 1);
    }
  }

  // ─── REWARDED COOLDOWN ─────────────────────────────────────────
  int _lastRewardedShownMs = 0;
  static const int _rewardedCooldownMs = 45000; // 45 seconds

  /// Hiển thị quảng cáo rewarded. Trả về true nếu user xem đủ.
  Future<bool> showRewardedAd() async {
    if (kIsWeb) return false;
    if (await isProUser()) return false;

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    if (nowMs - _lastRewardedShownMs < _rewardedCooldownMs) {
      debugPrint('AdMobService: Xem quảng cáo quá nhanh, đang chờ cooldown.');
      return false; // Chưa qua cooldown
    }

    await initialize();
    if (!_sdkInitialized) return false;
    if (_rewardedAd == null) {
      _loadRewardedAd();
      return false;
    }

    final completer = Completer<bool>();
    AppLifecyclePresenceGuard.arm();
    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) {
        _lastRewardedShownMs = DateTime.now().millisecondsSinceEpoch;
        _lastFullscreenAdShownMs = _lastRewardedShownMs;
      },
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _rewardedAd = null;
        _loadRewardedAd();
        AppLifecyclePresenceGuard.settle();
        if (!completer.isCompleted) completer.complete(false);
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _rewardedAd = null;
        _loadRewardedAd();
        AppLifecyclePresenceGuard.settle();
        if (!completer.isCompleted) completer.complete(false);
      },
    );

    _rewardedAd!.setImmersiveMode(true);
    _rewardedAd!.show(
        onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
      if (!completer.isCompleted) completer.complete(true);
    });

    return completer.future;
  }

  Future<bool> showSoulGameRewardedAd() async {
    if (kIsWeb) return false;
    if (await isProUser()) return false;

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    if (nowMs - _lastRewardedShownMs < _rewardedCooldownMs) {
      debugPrint(
          'AdMobService: Xem quảng cáo quá nhanh (Soul Game), đang chờ cooldown.');
      return false; // Chưa qua cooldown
    }

    await initialize();
    if (!_sdkInitialized) return false;
    if (_soulGameRewardedAd == null) {
      _loadSoulGameRewardedAd();
      return false;
    }

    final completer = Completer<bool>();
    AppLifecyclePresenceGuard.arm();
    _soulGameRewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) {
        _lastRewardedShownMs = DateTime.now().millisecondsSinceEpoch;
        _lastFullscreenAdShownMs = _lastRewardedShownMs;
      },
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _soulGameRewardedAd = null;
        _loadSoulGameRewardedAd();
        AppLifecyclePresenceGuard.settle();
        if (!completer.isCompleted) completer.complete(false);
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _soulGameRewardedAd = null;
        _loadSoulGameRewardedAd();
        AppLifecyclePresenceGuard.settle();
        if (!completer.isCompleted) completer.complete(false);
      },
    );

    _soulGameRewardedAd!.setImmersiveMode(true);
    _soulGameRewardedAd!.show(
      onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
        if (!completer.isCompleted) completer.complete(true);
      },
    );

    return completer.future;
  }

  // ─── BANNER AD ───────────────────────────────────────────────
  Future<BannerAd?> createBannerAd({required Function(Ad) onAdLoaded}) async {
    if (kIsWeb) return null;
    await initialize();
    if (!_sdkInitialized) return null;
    if (await isProUser()) return null; // No banner for PRO users

    final banner = BannerAd(
      adUnitId: bannerId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: onAdLoaded,
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
        },
      ),
    );
    await banner.load();
    return banner;
  }

  // ─── INTERSTITIAL AD ─────────────────────────────────────────
  InterstitialAd? _interstitialAd;
  Timer? _autoInterstitialTimer;
  bool _autoInterstitialSchedulerEnabled = false;
  bool _isShowingAutoInterstitial = false;

  Future<void> loadInterstitialAd() async {
    if (kIsWeb) return;
    if (!_sdkInitialized) return;
    if (_interstitialAd != null) return;
    await InterstitialAd.load(
      adUnitId: interstitialId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) => _interstitialAd = ad,
        onAdFailedToLoad: (_) => _interstitialAd = null,
      ),
    );
  }

  Future<void> showInterstitialAd() async {
    if (kIsWeb) return;
    if (await isProUser()) return;
    await initialize();
    if (!_sdkInitialized) return;
    if (_interstitialAd == null) {
      await loadInterstitialAd();
    }

    // Nếu vẫn null (do tải lỗi), thì bỏ qua
    if (_interstitialAd == null) return;

    final completer = Completer<void>();
    AppLifecyclePresenceGuard.arm();
    _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) {
        _lastFullscreenAdShownMs = DateTime.now().millisecondsSinceEpoch;
      },
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _interstitialAd = null;
        loadInterstitialAd(); // Nạp sẵn cái tiếp theo
        AppLifecyclePresenceGuard.settle();
        if (!completer.isCompleted) completer.complete();
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        ad.dispose();
        _interstitialAd = null;
        AppLifecyclePresenceGuard.settle();
        if (!completer.isCompleted) completer.complete();
      },
    );
    await _interstitialAd!.show();
    return completer.future;
  }

  Future<void> startAutoInterstitialScheduler() async {
    if (kIsWeb) return;
    await initialize();
    if (!_sdkInitialized) return;
    if (FirebaseAuth.instance.currentUser == null) return;
    if (await isProUser()) {
      await pauseAutoInterstitialScheduler();
      return;
    }

    _autoInterstitialSchedulerEnabled = true;
    await _setNextAutoInterstitialAt(_generateNextAutoInterstitialAt());
    await _scheduleAutoInterstitialTimer();
  }

  Future<void> pauseAutoInterstitialScheduler() async {
    _autoInterstitialTimer?.cancel();
    _autoInterstitialTimer = null;
  }

  Future<void> resumeAutoInterstitialScheduler() async {
    if (kIsWeb || !_autoInterstitialSchedulerEnabled) return;
    await initialize();
    if (!_sdkInitialized) return;
    if (FirebaseAuth.instance.currentUser == null) return;
    if (await isProUser()) {
      await pauseAutoInterstitialScheduler();
      return;
    }
    await _ensureNextAutoInterstitialAt();
    await _scheduleAutoInterstitialTimer();
  }

  Future<void> stopAutoInterstitialScheduler(
      {bool clearPersisted = false}) async {
    _autoInterstitialSchedulerEnabled = false;
    _autoInterstitialTimer?.cancel();
    _autoInterstitialTimer = null;
    if (clearPersisted) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_autoInterstitialNextAtPrefsKey);
    }
  }

  Future<void> _scheduleAutoInterstitialTimer() async {
    _autoInterstitialTimer?.cancel();
    final nextAt = await _readNextAutoInterstitialAt();
    if (nextAt == null) {
      await _setNextAutoInterstitialAt(_generateNextAutoInterstitialAt());
      return _scheduleAutoInterstitialTimer();
    }

    final now = DateTime.now();
    if (!nextAt.isAfter(now)) {
      unawaited(_handleAutoInterstitialDue());
      return;
    }

    _autoInterstitialTimer = Timer(nextAt.difference(now), () {
      unawaited(_handleAutoInterstitialDue());
    });
  }

  Future<void> _handleAutoInterstitialDue() async {
    if (kIsWeb ||
        !_autoInterstitialSchedulerEnabled ||
        _isShowingAutoInterstitial ||
        FirebaseAuth.instance.currentUser == null) {
      return;
    }
    if (await isProUser()) {
      await pauseAutoInterstitialScheduler();
      return;
    }

    _isShowingAutoInterstitial = true;
    try {
      final randomValue = _random.nextInt(100);
      final isMandatory = randomValue < _autoMandatoryRewardedChancePercent;

      if (isMandatory) {
        if (_rewardedAd == null) {
          _loadRewardedAd();
        }

        if (_rewardedAd != null) {
          final earnedReward = await showRewardedAd();
          if (earnedReward) {
            // Xem hết quảng cáo bắt buộc -> Đặt lại thời gian bình thường (30-60p)
            await _setNextAutoInterstitialAt(_generateNextAutoInterstitialAt());
          } else {
            // Thoát ngang quảng cáo bắt buộc -> Đặt thời gian hiện lại là 10 phút
            await _setNextAutoInterstitialAt(
              DateTime.now().add(const Duration(minutes: 10)),
            );
          }
        } else {
          // Lỗi tải quảng cáo -> Thử lại sau 2 phút
          await _setNextAutoInterstitialAt(
            DateTime.now().add(
              const Duration(minutes: _autoInterstitialRetryMinutes),
            ),
          );
        }
      } else {
        await loadInterstitialAd();
        if (_interstitialAd == null) {
          await _setNextAutoInterstitialAt(
            DateTime.now().add(
              const Duration(minutes: _autoInterstitialRetryMinutes),
            ),
          );
          return;
        }

        await showInterstitialAd();
        await _setNextAutoInterstitialAt(_generateNextAutoInterstitialAt());
      }
    } finally {
      _isShowingAutoInterstitial = false;
      if (_autoInterstitialSchedulerEnabled) {
        await _scheduleAutoInterstitialTimer();
      }
    }
  }

  Future<void> _ensureNextAutoInterstitialAt() async {
    final current = await _readNextAutoInterstitialAt();
    if (current == null) {
      await _setNextAutoInterstitialAt(_generateNextAutoInterstitialAt());
    }
  }

  DateTime _generateNextAutoInterstitialAt() {
    final offsetMinutes = _autoInterstitialMinMinutes +
        _random.nextInt(
          (_autoInterstitialMaxMinutes - _autoInterstitialMinMinutes) + 1,
        );
    return DateTime.now().add(Duration(minutes: offsetMinutes));
  }

  Future<DateTime?> _readNextAutoInterstitialAt() async {
    final prefs = await SharedPreferences.getInstance();
    final nextAtMs = prefs.getInt(_autoInterstitialNextAtPrefsKey);
    if (nextAtMs == null || nextAtMs <= 0) return null;
    return DateTime.fromMillisecondsSinceEpoch(nextAtMs);
  }

  Future<void> _setNextAutoInterstitialAt(DateTime nextAt) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      _autoInterstitialNextAtPrefsKey,
      nextAt.millisecondsSinceEpoch,
    );
  }

  // ─── ĐIỂM THƯỞNG (FIREBASE) ──────────────────────────────────
  Future<int> getUserPoints() async {
    final userRef = _currentUserRef;
    if (userRef == null) return 0;
    final snap = await userRef.child('points').get();
    return (snap.value as num?)?.toInt() ?? 0;
  }

  Stream<int> streamUserPoints() {
    final userRef = _currentUserRef;
    if (userRef == null) return Stream.value(0);
    return userRef.child('points').onValue.map((e) {
      return (e.snapshot.value as num?)?.toInt() ?? 0;
    });
  }

  Future<int> getCurrentProUntil() async {
    final access = await PurchaseService().getVipAccessInfo();
    if (!access.isVip) {
      return 0;
    }
    return access.expiresAtMs ??
        DateTime.now().add(const Duration(days: 36500)).millisecondsSinceEpoch;
  }

  Stream<int> streamCurrentProUntil() async* {
    final houseId = await _houseService.getCurrentHouseId();
    if (houseId == null || houseId.isEmpty) {
      yield 0;
      return;
    }
    yield* FirebaseDatabase.instance
        .ref('houses/$houseId/proUntil')
        .onValue
        .map((event) => (event.snapshot.value as num?)?.toInt() ?? 0);
  }

  Future<bool> isProUser() async {
    final access = await PurchaseService().getVipAccessInfo();
    return access.isVip;
  }

  Future<Map<String, dynamic>?> _postAuthenticatedJson(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return {'ok': false, 'error': 'unauthenticated'};
    }
    if (endpoint.trim().isEmpty) {
      return {'ok': false, 'error': 'endpoint_not_configured'};
    }

    Future<String> readBearerToken({required bool forceRefresh}) async {
      final rawToken = await user.getIdToken(forceRefresh).timeout(
                const Duration(seconds: 10),
                onTimeout: () => null,
              ) ??
          '';
      return rawToken.replaceAll(RegExp(r'\s+'), '');
    }

    Future<http.Response> postWithToken(String idToken) {
      return AppCheckHttpHeaders.withRequiredToken(
        {
          'Content-Type': 'application/json; charset=utf-8',
          'Authorization': 'Bearer $idToken',
        },
        forceRefresh: true,
      ).then(
        (headers) => http
            .post(
              Uri.parse(endpoint.trim()),
              headers: headers,
              body: jsonEncode(body),
            )
            .timeout(const Duration(seconds: 20)),
      );
    }

    String idToken;
    try {
      idToken = await readBearerToken(forceRefresh: true);
    } catch (tokenError) {
      debugPrint('Failed to get Firebase ID token (checkin): $tokenError');
      return {'ok': false, 'error': 'network_error'};
    }
    if (idToken.isEmpty) {
      return {'ok': false, 'error': 'unauthenticated'};
    }

    late final http.Response response;
    try {
      response = await postWithToken(idToken);
    } on StateError catch (error) {
      debugPrint(
          'Reward server blocked due to missing App Check token: $error');
      await RevenueSecurityTelemetryService.instance.logEvent(
        type: 'reward_claim_blocked',
        reason: 'missing_app_check',
        severity: 'high',
      );
      return {'ok': false, 'error': 'missing_app_check'};
    } on http.ClientException catch (error) {
      final message = error.message.toLowerCase();
      if (message.contains('parse header value')) {
        debugPrint(
          'Reward server auth header parse failed, refreshing token and retrying once.',
        );
        try {
          idToken = await readBearerToken(forceRefresh: true);
        } catch (retryTokenError) {
          debugPrint(
              'Failed to refresh Firebase ID token on retry: $retryTokenError');
          return {'ok': false, 'error': 'network_error'};
        }
        if (idToken.isEmpty) {
          return {'ok': false, 'error': 'unauthenticated'};
        }
        try {
          response = await postWithToken(idToken);
        } on StateError catch (retryAppCheckError) {
          debugPrint(
            'Reward server retry blocked due to missing App Check token: $retryAppCheckError',
          );
          await RevenueSecurityTelemetryService.instance.logEvent(
            type: 'reward_claim_blocked',
            reason: 'missing_app_check_retry',
            severity: 'high',
          );
          return {'ok': false, 'error': 'missing_app_check'};
        } on http.ClientException catch (retryError) {
          final retryMessage = retryError.message.toLowerCase();
          if (retryMessage.contains('parse header value')) {
            debugPrint(
              'Reward server request still failed after token refresh: $retryError',
            );
            return {'ok': false, 'error': 'invalid_auth_header'};
          }
          debugPrint('Reward server request failed: $retryError');
          return {'ok': false, 'error': 'network_error'};
        }
      } else {
        debugPrint('Reward server request failed: $error');
        return {'ok': false, 'error': 'network_error'};
      }
    } on TimeoutException catch (error) {
      debugPrint('Reward server request timed out: $error');
      return {'ok': false, 'error': 'network_timeout'};
    } catch (error) {
      debugPrint('Reward server request failed: $error');
      return {'ok': false, 'error': 'network_error'};
    }

    Map<String, dynamic>? decodedMap;
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map) {
        decodedMap = Map<String, dynamic>.from(decoded);
      }
    } catch (_) {
      decodedMap = null;
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final error =
          decodedMap?['error']?.toString() ?? _rewardHttpError(response);
      debugPrint(
        'Reward server rejected request: ${response.statusCode} $error',
      );
      if (_isRevenueSecurityError(error)) {
        await RevenueSecurityTelemetryService.instance.logEvent(
          type: 'reward_server_rejected',
          reason: error,
          severity: response.statusCode == 401 || response.statusCode == 403
              ? 'high'
              : 'medium',
          extra: <String, Object?>{
            'statusCode': response.statusCode,
          },
        );
      }
      return {
        'ok': false,
        if (decodedMap != null) ...decodedMap,
        'statusCode': response.statusCode,
        'error': error,
      };
    }

    return decodedMap;
  }

  bool _isRevenueSecurityError(String error) {
    return error == 'missing_app_check' ||
        error == 'invalid_app_check' ||
        error == 'unauthenticated' ||
        error == 'invalid_auth_header' ||
        error == 'receipt_invalid' ||
        error == 'integrity_failed';
  }

  String _rewardHttpError(http.Response response) {
    if (response.statusCode == 404) return 'endpoint_not_found';
    if (response.statusCode == 401) return 'unauthenticated';
    if (response.statusCode == 429) return 'rate_limited';
    return 'server_error';
  }

  Future<void> addPoints(int amount) async {
    if (amount <= 0) return;
    if (amount == rewardedMainPoints) {
      await claimRewardedAdPoints();
      return;
    }
    debugPrint(
      'addPoints($amount) ignored: reward points must be granted by server source.',
    );
  }

  Future<Map<String, dynamic>?> _claimRewardFromServer({
    required String source,
    String? questId,
  }) async {
    final payload = <String, dynamic>{
      'source': source,
      'clientNonce': _buildRewardProofNonce(),
      'clientIssuedAtMs': DateTime.now().millisecondsSinceEpoch,
      if (questId != null && questId.trim().isNotEmpty)
        'questId': questId.trim(),
    };

    final res = await _postAuthenticatedJson(AppConfig.rewardGrantUrl, payload);

    return res;
  }

  String _buildRewardProofNonce() {
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_';
    final buffer = StringBuffer(DateTime.now().microsecondsSinceEpoch);
    for (var index = 0; index < 24; index++) {
      buffer.write(chars[_random.nextInt(chars.length)]);
    }
    return buffer.toString();
  }

  Future<RewardClaimResult> claimRewardedAdPoints() async {
    final response = await _claimRewardFromServer(source: 'rewarded_ad');
    final result = RewardClaimResult.fromResponse(response);
    if (result.ok) {
      // Chỉ tăng counter nếu claim thành công
      await _incrementDailyRewardedAdCount();
      return result;
    }
    return result;
  }

  Future<bool> claimDailyCheckinPoints() async {
    final result = await claimDailyCheckinReward();
    return result.ok;
  }

  Future<RewardClaimResult> claimDailyCheckinReward() async {
    // Lần thử đầu tiên
    Map<String, dynamic>? response;
    try {
      response = await _claimRewardFromServer(source: 'daily_checkin');
    } catch (_) {
      response = null;
    }
    final firstResult = RewardClaimResult.fromResponse(response);

    // Nếu đã điểm danh rồi hoặc thành công → trả về ngay
    if (firstResult.ok || firstResult.alreadyClaimed) {
      return firstResult;
    }

    // Nếu lỗi mạng tạm thời → tự retry 1 lần sau 1.5 giây
    if (firstResult.networkIssue) {
      debugPrint('Daily checkin: network issue, retrying in 1.5s...');
      await Future<void>.delayed(const Duration(milliseconds: 1500));
      Map<String, dynamic>? retryResponse;
      try {
        retryResponse = await _claimRewardFromServer(source: 'daily_checkin');
      } catch (_) {
        retryResponse = null;
      }
      return RewardClaimResult.fromResponse(retryResponse);
    }

    return firstResult;
  }

  Future<Map<String, dynamic>?> recordDailyQuestProgress(String questId) {
    return _claimRewardFromServer(
      source: 'daily_quest_progress',
      questId: questId,
    );
  }

  @Deprecated('Point deductions must go through the reward server.')
  Future<bool> deductPoints(int amount) async {
    return false;
  }

  Future<RewardClaimResult> redeemProPlan({
    required String planId,
  }) async {
    if (planId.trim().isEmpty) {
      return const RewardClaimResult(ok: false, error: 'invalid_plan');
    }
    final houseId = await _houseService.getCurrentHouseId(preferFresh: true);
    if (houseId == null || houseId.isEmpty) {
      return const RewardClaimResult(ok: false, error: 'house_not_found');
    }

    final response = await _postAuthenticatedJson(
      AppConfig.rewardRedeemProUrl,
      {
        'houseId': houseId,
        'planId': planId,
      },
    );
    return RewardClaimResult.fromResponse(response);
  }
}

