import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soullocket_app/core/constants/app_config.dart';
import 'package:soullocket_app/utils/services/app_check_http_headers.dart';
import 'package:soullocket_app/utils/app_error_mapper.dart';
import 'package:soullocket_app/utils/services/app_lifecycle_presence_guard.dart';
import 'package:soullocket_app/utils/services/house_service.dart';
import 'package:soullocket_app/utils/services/offline_cache_service.dart';
import 'package:soullocket_app/utils/services/purchase_service.dart';
import 'package:soullocket_app/utils/services/revenue_security_telemetry_service.dart';
import 'package:soullocket_app/utils/services/ad_suppression_guard.dart';
import 'package:soullocket_app/utils/services/texas_age_gate_service.dart';
import 'package:soullocket_app/utils/services/ad_unit_config.dart';
import 'package:flutter/material.dart';
import 'package:soullocket_app/utils/services/notification_service.dart';

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
  static const int dailyRewardedAdLimit = 10; // Giới hạn 10 quảng cáo/ngày
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
  static const int _autoInterstitialMinMinutes = 35;
  static const int _autoInterstitialMaxMinutes = 70;
  static const int _autoInterstitialRetryMinutes = 5;
  static const int _autoMandatoryRewardedChancePercent = 15;
  static const int _appOpenMaxPerDay = 8;
  static const List<String> _debugTestDeviceIds = <String>[
    'D9B28AB8E1553E4F327420FC9896415C',
    '370D8C7AC6D4262893C393843B5727CA',
  ];
  final HouseService _houseService = HouseService();
  final Random _random = Random();
  static bool _isRewardEndpointDisabled = false;

  static String? _androidRewardedMainId;
  static String? _androidRewardedCheckinId;
  static String? _androidRewardedSoulGameId;
  static String? _androidBannerId;
  static String? _androidInterstitialId;
  static String? _androidAppOpenId;

  static String? _iosRewardedMainId;
  static String? _iosRewardedCheckinId;
  static String? _iosRewardedSoulGameId;
  static String? _iosBannerId;
  static String? _iosInterstitialId;
  static String? _iosAppOpenId;

  static String get rewardedMainId {
    if (Platform.isIOS) {
      return _iosRewardedMainId ?? AdUnitConfig.rewardedMainId;
    }
    return _androidRewardedMainId ?? AdUnitConfig.rewardedMainId;
  }

  static String get rewardedCheckinId {
    if (Platform.isIOS) {
      return _iosRewardedCheckinId ?? AdUnitConfig.rewardedCheckinId;
    }
    return _androidRewardedCheckinId ?? AdUnitConfig.rewardedCheckinId;
  }

  static String get rewardedSoulGameId {
    if (Platform.isIOS) {
      return _iosRewardedSoulGameId ?? AdUnitConfig.rewardedSoulGameId;
    }
    return _androidRewardedSoulGameId ?? AdUnitConfig.rewardedSoulGameId;
  }

  static String get bannerId {
    if (Platform.isIOS) {
      return _iosBannerId ?? AdUnitConfig.bannerId;
    }
    return _androidBannerId ?? AdUnitConfig.bannerId;
  }

  static String get interstitialId {
    if (Platform.isIOS) {
      return _iosInterstitialId ?? AdUnitConfig.interstitialId;
    }
    return _androidInterstitialId ?? AdUnitConfig.interstitialId;
  }

  static String get appOpenId {
    if (Platform.isIOS) {
      return _iosAppOpenId ?? AdUnitConfig.appOpenId;
    }
    return _androidAppOpenId ?? AdUnitConfig.appOpenId;
  }

  // ─── REWARDED AD (CHÍNH) ─────────────────────────────────────
  RewardedAd? _rewardedAd;
  bool _isRewardedAdLoading = false;
  RewardedAd? _soulGameRewardedAd;
  bool _isSoulGameRewardedAdLoading = false;
  AppOpenAd? _appOpenAd;
  bool _isAppOpenLoading = false;
  bool _isShowingAppOpenAd = false;
  int _lastFullscreenAdShownMs = 0;
  static const int _fullscreenAdCooldownMs = 7 * 60 * 1000; // 7 minutes
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
    if (_initializeCompleter != null) {
      return _initializeCompleter!.future;
    }
    final completer = Completer<void>();
    _initializeCompleter = completer;
    if (kIsWeb) {
      completer.complete();
      return;
    }

    if (Platform.isIOS) {
      try {
        var status = await AppTrackingTransparency.trackingAuthorizationStatus;
        if (status == TrackingStatus.notDetermined) {
          await Future<void>.delayed(const Duration(milliseconds: 250));
          status = await AppTrackingTransparency.requestTrackingAuthorization();
        }
        debugPrint('AdMobService: iOS ATT Status = $status');
      } catch (attError) {
        debugPrint('AdMobService: Failed to request ATT permission: $attError');
      }
    }

    // Implement UMP Consent Flow
    final params = ConsentRequestParameters(
      consentDebugSettings: ConsentDebugSettings(
        debugGeography: DebugGeography.debugGeographyDisabled,
        // testIdentifiers: ['YOUR-DEVICE-ID'], // Uncomment and add your device ID for testing
      ),
    );

    var consentUpdateFailed = false;
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
          consentUpdateFailed = true;
          final errorInfo = AppErrorMapper.resolve(
            error,
            fallbackMessage: 'Không thể xử lý đồng ý quảng cáo lúc này.',
          );
          debugPrint('Consent Info Update Error: ${errorInfo.message}');
          if (!consentCompleter.isCompleted) {
            consentCompleter.complete();
          }
        },
      );
      await consentCompleter.future;
    } catch (e) {
      consentUpdateFailed = true;
      final errorInfo = AppErrorMapper.resolve(
        e,
        fallbackMessage: 'Không thể xử lý đồng ý quảng cáo lúc này.',
      );
      debugPrint('Error handling UMP Consent: ${errorInfo.message}');
    }

    try {
      final canRequestAds = await ConsentInformation.instance.canRequestAds();
      if (!canRequestAds) {
        debugPrint(
          'AdMobService: canRequestAds=false '
          '(consentUpdateFailed=$consentUpdateFailed, '
          'debugMode=$kDebugMode).',
        );
        if (!kDebugMode) {
          return;
        }
        debugPrint(
          'AdMobService: debug continues ads init after UMP canRequestAds=false.',
        );
      }

      // Đồng bộ ID Quảng cáo từ Firebase nhằm loại bỏ HardCode Source
      try {
        final snap = await FirebaseDatabase.instance
            .ref('app_config/admob_ids')
            .get()
            .timeout(const Duration(seconds: 4));
        if (snap.exists && snap.value is Map) {
          final map = Map<dynamic, dynamic>.from(snap.value as Map);
          debugPrint(
            'AdMobService: synced remote AdMob IDs '
            '(android=${map.keys.where((k) => !k.toString().startsWith('ios_')).length}, '
            'ios=${map.keys.where((k) => k.toString().startsWith('ios_')).length}).',
          );
          if (map['rewardedMainId'] != null) {
            AdUnitConfig.androidRewardedMainId =
                map['rewardedMainId'].toString();
          }
          if (map['rewardedCheckinId'] != null) {
            AdUnitConfig.androidRewardedCheckinId =
                map['rewardedCheckinId'].toString();
          }
          if (map['rewardedSoulGameId'] != null) {
            AdUnitConfig.androidRewardedSoulGameId =
                map['rewardedSoulGameId'].toString();
          }
          if (map['bannerId'] != null) {
            AdUnitConfig.androidBannerId = map['bannerId'].toString();
          }
          if (map['interstitialId'] != null) {
            AdUnitConfig.androidInterstitialId =
                map['interstitialId'].toString();
          }
          if (map['appOpenId'] != null) {
            AdUnitConfig.androidAppOpenId = map['appOpenId'].toString();
          }

          if (map['ios_rewardedMainId'] != null) {
            AdUnitConfig.iosRewardedMainId =
                map['ios_rewardedMainId'].toString();
          }
          if (map['ios_rewardedCheckinId'] != null) {
            AdUnitConfig.iosRewardedCheckinId =
                map['ios_rewardedCheckinId'].toString();
          }
          if (map['ios_rewardedSoulGameId'] != null) {
            AdUnitConfig.iosRewardedSoulGameId =
                map['ios_rewardedSoulGameId'].toString();
          }
          if (map['ios_bannerId'] != null) {
            AdUnitConfig.iosBannerId = map['ios_bannerId'].toString();
          }
          if (map['ios_interstitialId'] != null) {
            AdUnitConfig.iosInterstitialId =
                map['ios_interstitialId'].toString();
          }
          if (map['ios_appOpenId'] != null) {
            AdUnitConfig.iosAppOpenId = map['ios_appOpenId'].toString();
          }
        }
      } catch (e) {
        final errorInfo = AppErrorMapper.resolve(
          e,
          fallbackMessage: 'Không thể đồng bộ ID quảng cáo lúc này.',
        );
        debugPrint('Failed to sync AdMob IDs: ${errorInfo.message}');
      }

      if (kDebugMode) {
        await MobileAds.instance.updateRequestConfiguration(
          RequestConfiguration(testDeviceIds: _debugTestDeviceIds),
        );
      }
      await MobileAds.instance.initialize();
      debugPrint('AdMobService: MobileAds SDK initialized.');
      _sdkInitialized = true;
      // Áp dụng age gate từ Texas Age Signals API:
      // nếu user là minor, giới hạn quảng cáo child-directed + nội dung G
      unawaited(_applyAgeGateToAdSettings());
      // Trì hoãn tải quảng cáo nền 3s sau khi SDK ready
      // để không tranh CPU với UI rendering khi app khởi động
      Future<void>.delayed(const Duration(seconds: 3), () {
        if (!_sdkInitialized) return;
        _loadRewardedAd();
        _loadSoulGameRewardedAd();
        unawaited(loadInterstitialAd());
        unawaited(loadAppOpenAd());
      });
    } finally {
      if (!completer.isCompleted) {
        completer.complete();
      }
      _initializeCompleter = null;
    }
  }

  /// Áp dụng age gate từ Texas Age Signals API cho AdMob.
  /// Nếu user là minor (dưới 18 theo Texas SB 2420), set child-directed
  /// treatment và giới hạn maxAdContentRating = G.
  Future<void> _applyAgeGateToAdSettings() async {
    try {
      final ageGate = TexasAgeGateService();
      final classification = await ageGate.resolveAgeSignal();
      if (classification == AgeClassification.minor) {
        debugPrint(
            'AdMobService: minor detected, applying child-directed ad settings.');
        await MobileAds.instance.updateRequestConfiguration(
          RequestConfiguration(
            tagForChildDirectedTreatment: TagForChildDirectedTreatment.yes,
            maxAdContentRating: MaxAdContentRating.g,
          ),
        );
      } else if (classification == AgeClassification.adult) {
        debugPrint('AdMobService: adult confirmed, no ad restriction needed.');
      }
    } catch (e) {
      debugPrint('AdMobService: failed to apply age gate: $e');
    }
  }

  void _loadRewardedAd({int retryCount = 0}) {
    if (kIsWeb) return;
    if (!_sdkInitialized) return;
    if (_isRewardedAdLoading) return;
    _isRewardedAdLoading = true;

    RewardedAd.load(
      adUnitId: rewardedMainId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          debugPrint('AdMobService: rewarded main loaded.');
          _rewardedAd = ad;
          _isRewardedAdLoading = false;
        },
        onAdFailedToLoad: (error) {
          final errorInfo = AppErrorMapper.resolve(
            error,
            fallbackMessage: 'Quảng cáo thưởng chính chưa tải được.',
          );
          debugPrint(
              'AdMobService: rewarded main failed to load: ${errorInfo.message}');
          _rewardedAd = null;
          _isRewardedAdLoading = false;
          // Retry 2 lần, mỗi lần cách 10s
          if (retryCount < 2) {
            Future.delayed(const Duration(seconds: 10), () {
              _loadRewardedAd(retryCount: retryCount + 1);
            });
          }
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
          debugPrint('AdMobService: rewarded soul game loaded.');
          _soulGameRewardedAd = ad;
          _isSoulGameRewardedAdLoading = false;
        },
        onAdFailedToLoad: (error) {
          final errorInfo = AppErrorMapper.resolve(
            error,
            fallbackMessage: 'Quảng cáo thưởng Soul Game chưa tải được.',
          );
          debugPrint(
              'AdMobService: rewarded soul game failed to load: ${errorInfo.message}');
          _soulGameRewardedAd = null;
          _isSoulGameRewardedAdLoading = false;
        },
      ),
    );
  }

  void preloadRewardedAd() {
    _loadRewardedAd();
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
          final errorInfo = AppErrorMapper.resolve(
            error,
            fallbackMessage: 'Quảng cáo App Open chưa tải được.',
          );
          debugPrint(
              'AdMobService: app open failed to load: ${errorInfo.message}');
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
    if (kDebugMode) return false;
    if (AdSuppressionGuard.instance.isSuppressed) {
      debugPrint('AdMobService: App Open ad suppressed by AdSuppressionGuard.');
      return false;
    }
    if (hasRecentFullscreenAd(cooldown: const Duration(minutes: 10))) {
      return false;
    }
    await initialize();
    if (!_sdkInitialized) return false;
    if (_isShowingAppOpenAd) return false;
    if (_isAutoInterstitialSuppressed) return false;
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
        _sendAdImpressionPing('app_open', appOpenId);
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
        // FIXME: Không thể hiển thị App Open ad - không ảnh hưởng trải nghiệm chính
        debugPrint('AdMobService: App Open show failed: $e');
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
    final prefs = OfflineCacheService.getPrefsSync() ??
        await SharedPreferences.getInstance();
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

    final lastShownMs = prefs.getInt(_appOpenLastShownDatePrefsKey) ?? 0;
    final nowMs = DateTime.now().millisecondsSinceEpoch;

    if (lastShownMs == 0) {
      return true; // Lần đầu tiên
    }

    final hoursDiff = (nowMs - lastShownMs) / (1000 * 60 * 60);

    double requiredHours = 1.0;
    if (Platform.isAndroid) {
      try {
        final androidInfo = await DeviceInfoPlugin().androidInfo;
        if (androidInfo.version.sdkInt < 33) {
          requiredHours = 4.0;
        }
      } catch (e) {
        // FIXME: Không lấy được SDK version, fallback an toàn
        debugPrint('AdMobService: Không lấy được Android SDK version: $e, fallback 4h cooldown.');
        requiredHours = 4.0; // fallback an toàn nếu không lấy được info
      }
    }

    if (hoursDiff >= requiredHours) {
      return true;
    }

    return false;
  }

  Future<void> _incrementAppOpenShownCount() async {
    final prefs = OfflineCacheService.getPrefsSync() ??
        await SharedPreferences.getInstance();
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
    final prefs = OfflineCacheService.getPrefsSync() ??
        await SharedPreferences.getInstance();
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
    final prefs = OfflineCacheService.getPrefsSync() ??
        await SharedPreferences.getInstance();
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

  /// Tăng bộ đếm xem quảng cáo lên 1 trong chế độ debug
  Future<void> incrementDailyRewardedAdCountDebug() async {
    if (kDebugMode) {
      await _incrementDailyRewardedAdCount();
    }
  }

  // ─── REWARDED COOLDOWN ─────────────────────────────────────────
  int _lastRewardedShownMs = 0;
  int _lastSoulGameRewardedShownMs = 0;
  static const int _rewardedCooldownMs = 45000; // 45 seconds

  /// Hiển thị quảng cáo rewarded. Trả về true nếu user xem đủ.
  Future<bool> showRewardedAd({
    bool ignoreCooldown = false,
    Duration loadTimeout = const Duration(seconds: 5),
  }) async {
    if (kIsWeb) return false;
    if (kDebugMode) {
      debugPrint('AdMobService: auto-granted reward in debug mode.');
      return true;
    }
    if (await isProUser()) {
      debugPrint('AdMobService: rewarded skipped because user is Pro.');
      return false;
    }

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    if (!ignoreCooldown && nowMs - _lastRewardedShownMs < _rewardedCooldownMs) {
      debugPrint('AdMobService: Xem quảng cáo quá nhanh, đang chờ cooldown.');
      return false; // Chưa qua cooldown
    }

    await initialize();
    if (!_sdkInitialized) {
      debugPrint(
          'AdMobService: rewarded skipped because SDK is not initialized.');
      return false;
    }
    if (_rewardedAd == null) {
      _loadRewardedAd();
      final maxWaitMs = loadTimeout.inMilliseconds.clamp(0, 15000);
      final attempts = (maxWaitMs / 250).ceil().clamp(1, 60);
      debugPrint(
          'AdMobService: waiting for rewarded ad, timeout=${maxWaitMs}ms.');
      for (var i = 0; i < attempts && _rewardedAd == null; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
      if (_rewardedAd == null) {
        debugPrint('AdMobService: rewarded skipped because ad is not loaded.');
        return false;
      }
    }

    final completer = Completer<bool>();
    var didEarnReward = false;
    AppLifecyclePresenceGuard.arm();
    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) {
        debugPrint('AdMobService: rewarded showed.');
        _lastRewardedShownMs = DateTime.now().millisecondsSinceEpoch;
        _lastFullscreenAdShownMs = _lastRewardedShownMs;
        _sendAdImpressionPing('rewarded', rewardedMainId);
      },
      onAdDismissedFullScreenContent: (ad) async {
        debugPrint('AdMobService: rewarded dismissed (earned=$didEarnReward).');
        ad.dispose();
        _rewardedAd = null;
        _loadRewardedAd();
        AppLifecyclePresenceGuard.settle();
        // Delay to ensure that if onUserEarnedReward is scheduled slightly after dismissal, it has time to register.
        await Future<void>.delayed(const Duration(milliseconds: 150));
        if (!completer.isCompleted) completer.complete(didEarnReward);
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        final errorInfo = AppErrorMapper.resolve(
          error,
          fallbackMessage: 'Không thể hiển thị quảng cáo thưởng.',
        );
        debugPrint(
            'AdMobService: rewarded failed to show: ${errorInfo.message}');
        ad.dispose();
        _rewardedAd = null;
        _loadRewardedAd();
        AppLifecyclePresenceGuard.settle();
        if (!completer.isCompleted) completer.complete(false);
      },
    );

    try {
      _rewardedAd!.setImmersiveMode(true);
      _rewardedAd!.show(
        onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
          debugPrint('AdMobService: rewarded earned.');
          didEarnReward = true;
          if (!completer.isCompleted) {
            completer.complete(true);
          }
        },
      );
    } catch (error) {
      final errorInfo = AppErrorMapper.resolve(
        error,
        fallbackMessage: 'Không thể mở quảng cáo thưởng.',
      );
      debugPrint('AdMobService: rewarded show exception: ${errorInfo.message}');
      _rewardedAd?.dispose();
      _rewardedAd = null;
      _loadRewardedAd();
      AppLifecyclePresenceGuard.settle();
      if (!completer.isCompleted) completer.complete(false);
    }

    return completer.future.timeout(
      const Duration(seconds: 60),
      onTimeout: () {
        AppLifecyclePresenceGuard.settle();
        return false;
      },
    );
  }

  Future<bool> showSoulGameRewardedAd() async {
    if (kIsWeb) return false;
    if (kDebugMode) {
      debugPrint('AdMobService: auto-granted soul game reward in debug mode.');
      return true;
    }
    if (await isProUser()) return false;

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    if (nowMs - _lastSoulGameRewardedShownMs < _rewardedCooldownMs) {
      debugPrint(
          'AdMobService: Xem quảng cáo quá nhanh (Soul Game), đang chờ cooldown.');
      return false; // Chưa qua cooldown
    }

    await initialize();
    if (!_sdkInitialized) return false;
    if (_soulGameRewardedAd == null) {
      _loadSoulGameRewardedAd();
      for (var i = 0; i < 8 && _soulGameRewardedAd == null; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
      if (_soulGameRewardedAd == null) {
        return false;
      }
    }

    final completer = Completer<bool>();
    var didEarnReward = false;
    AppLifecyclePresenceGuard.arm();
    _soulGameRewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) {
        _lastSoulGameRewardedShownMs = DateTime.now().millisecondsSinceEpoch;
        _lastFullscreenAdShownMs = _lastRewardedShownMs;
        _sendAdImpressionPing('rewarded', rewardedSoulGameId);
      },
      onAdDismissedFullScreenContent: (ad) async {
        ad.dispose();
        _soulGameRewardedAd = null;
        _loadSoulGameRewardedAd();
        AppLifecyclePresenceGuard.settle();
        // Delay to ensure that if onUserEarnedReward is scheduled slightly after dismissal, it has time to register.
        await Future<void>.delayed(const Duration(milliseconds: 150));
        if (!completer.isCompleted) completer.complete(didEarnReward);
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _soulGameRewardedAd = null;
        _loadSoulGameRewardedAd();
        AppLifecyclePresenceGuard.settle();
        if (!completer.isCompleted) completer.complete(false);
      },
    );

      try {
        _soulGameRewardedAd!.setImmersiveMode(true);
        _soulGameRewardedAd!.show(
          onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
            didEarnReward = true;
            if (!completer.isCompleted) {
              completer.complete(true);
            }
          },
        );
      } catch (e) {
        // FIXME: Soul Game rewarded show failed
        debugPrint('AdMobService: Soul Game rewarded show failed: $e');
        _soulGameRewardedAd?.dispose();
        _soulGameRewardedAd = null;
        _loadSoulGameRewardedAd();
        AppLifecyclePresenceGuard.settle();
        if (!completer.isCompleted) completer.complete(false);
      }

    return completer.future.timeout(
      const Duration(seconds: 60),
      onTimeout: () {
        AppLifecyclePresenceGuard.settle();
        return false;
      },
    );
  }

  // ─── BANNER AD ───────────────────────────────────────────────
  Future<BannerAd?> createBannerAd({required Function(Ad) onAdLoaded}) async {
    if (kIsWeb) return null;
    if (kDebugMode) return null;
    await initialize();
    if (!_sdkInitialized) {
      debugPrint(
          'AdMobService: banner skipped because SDK is not initialized.');
      return null;
    }
    if (await isProUser()) return null; // No banner for PRO users

    final completer = Completer<BannerAd?>();
    late final BannerAd banner;
    banner = BannerAd(
      adUnitId: bannerId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          onAdLoaded(ad);
          _sendAdImpressionPing('banner', bannerId);
          if (!completer.isCompleted) {
            completer.complete(banner);
          }
        },
        onAdFailedToLoad: (ad, error) {
          final errorInfo = AppErrorMapper.resolve(
            error,
            fallbackMessage: 'Banner quảng cáo chưa tải được.',
          );
          debugPrint(
              'AdMobService: banner failed to load: ${errorInfo.message}');
          ad.dispose();
          if (!completer.isCompleted) {
            completer.complete(null);
          }
        },
      ),
    );
    await banner.load();
    return completer.future.timeout(
      const Duration(seconds: 12),
      onTimeout: () {
        debugPrint('AdMobService: banner load timed out.');
        banner.dispose();
        return null;
      },
    );
  }

  // ─── INTERSTITIAL AD ─────────────────────────────────────────
  InterstitialAd? _interstitialAd;
  Timer? _autoInterstitialTimer;
  bool _autoInterstitialSchedulerEnabled = false;
  bool _isShowingAutoInterstitial = false;
  bool _isAutoInterstitialSuppressed = false;

  void suppressAutoInterstitial() {
    _isAutoInterstitialSuppressed = true;
    _autoInterstitialTimer?.cancel();
    _autoInterstitialTimer = null;
    debugPrint('AdMobService: Auto Interstitial suppressed.');
  }

  void resumeAutoInterstitial() {
    _isAutoInterstitialSuppressed = false;
    debugPrint('AdMobService: Auto Interstitial resumed.');
    if (_autoInterstitialSchedulerEnabled) {
      _scheduleAutoInterstitialTimer();
    }
  }

  Future<void> loadInterstitialAd() async {
    if (kIsWeb) return;
    if (!_sdkInitialized) return;
    if (_interstitialAd != null) return;
    await InterstitialAd.load(
      adUnitId: interstitialId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) => _interstitialAd = ad,
        onAdFailedToLoad: (error) {
          final errorInfo = AppErrorMapper.resolve(
            error,
            fallbackMessage: 'Interstitial quảng cáo chưa tải được.',
          );
          debugPrint(
              'AdMobService: interstitial failed to load: ${errorInfo.message}');
          _interstitialAd = null;
        },
      ),
    );
  }

  Future<bool> showInterstitialAd() async {
    if (kIsWeb) return false;
    if (kDebugMode) return false;
    if (await isProUser()) return false;
    if (AdSuppressionGuard.instance.isSuppressed) {
      debugPrint(
          'AdMobService: Interstitial ad suppressed by AdSuppressionGuard.');
      return false;
    }

    // -- BẢO VỆ "TUYẾN PHÒNG THỦ" (CHỐNG HIỂN THỊ BẤT NGỜ / CLICK TẶC) --
    final context = NotificationService.navigatorKey.currentContext;
    if (context != null && context.mounted) {
      try {
        final viewInsets = MediaQuery.of(context).viewInsets;
        if (viewInsets.bottom > 0) {
          debugPrint(
              'AdMobService: Interstitial ad suppressed due to active keyboard.');
          return false;
        }
      } catch (e) {
        // FIXME: Không truy cập được MediaQuery - vẫn hiển thị ad
        debugPrint('AdMobService: Không truy cập được MediaQuery: $e');
      }
    }

    await initialize();
    if (!_sdkInitialized) return false;
    if (_interstitialAd == null) {
      await loadInterstitialAd();
    }

    // Nếu vẫn null (do tải lỗi), thì bỏ qua
    if (_interstitialAd == null) return false;

    final completer = Completer<bool>();
    AppLifecyclePresenceGuard.arm();
    _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) {
        _lastFullscreenAdShownMs = DateTime.now().millisecondsSinceEpoch;
        _sendAdImpressionPing('interstitial', interstitialId);
      },
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _interstitialAd = null;
        loadInterstitialAd(); // Nạp sẵn cái tiếp theo
        AppLifecyclePresenceGuard.settle();
        if (!completer.isCompleted) completer.complete(true);
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        ad.dispose();
        _interstitialAd = null;
        AppLifecyclePresenceGuard.settle();
        if (!completer.isCompleted) completer.complete(false);
      },
    );
    await _interstitialAd!.show();
    return completer.future.timeout(
      const Duration(seconds: 12),
      onTimeout: () {
        debugPrint('AdMobService: interstitial show timed out.');
        AppLifecyclePresenceGuard.settle();
        return false;
      },
    );
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
    await _ensureNextAutoInterstitialAt();
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
      final prefs = OfflineCacheService.getPrefsSync() ??
          await SharedPreferences.getInstance();
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
        _isAutoInterstitialSuppressed ||
        AdSuppressionGuard.instance.isSuppressed ||
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
            // Cộng 50 điểm thưởng cho người dùng
            unawaited(claimRewardedAdPoints());
          } else {
            // Thoát ngang quảng cáo bắt buộc -> Đặt thời gian hiện lại là 20 phút
            await _setNextAutoInterstitialAt(
              DateTime.now().add(const Duration(minutes: 20)),
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

        final shown = await showInterstitialAd();
        if (shown) {
          await _setNextAutoInterstitialAt(_generateNextAutoInterstitialAt());
          // Cộng 50 điểm thưởng cho người dùng
          unawaited(claimRewardedAdPoints());
        } else {
          // Lỗi hiển thị quảng cáo -> Thử lại sau 5 phút
          await _setNextAutoInterstitialAt(
            DateTime.now().add(
              const Duration(minutes: _autoInterstitialRetryMinutes),
            ),
          );
        }
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
    final prefs = OfflineCacheService.getPrefsSync() ??
        await SharedPreferences.getInstance();
    final nextAtMs = prefs.getInt(_autoInterstitialNextAtPrefsKey);
    if (nextAtMs == null || nextAtMs <= 0) return null;
    return DateTime.fromMillisecondsSinceEpoch(nextAtMs);
  }

  Future<void> _setNextAutoInterstitialAt(DateTime nextAt) async {
    final prefs = OfflineCacheService.getPrefsSync() ??
        await SharedPreferences.getInstance();
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
    if (!AppConfig.isPurchaseEnabled) {
      yield 0;
      return;
    }

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
    Map<String, dynamic> body, {
    bool requireAppCheck = true,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return {'ok': false, 'error': 'unauthenticated'};
    }
    if (endpoint.trim().isEmpty) {
      return {'ok': false, 'error': 'endpoint_not_configured'};
    }
    if (_isRewardEndpointDisabled) {
      return {'ok': false, 'error': 'endpoint_not_found'};
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
      final appCheckHeaders = requireAppCheck
          ? AppCheckHttpHeaders.withRequiredToken
          : AppCheckHttpHeaders.withOptionalToken;
      return appCheckHeaders(
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
      idToken = await readBearerToken(forceRefresh: false);
    } catch (tokenError) {
      final errorInfo = AppErrorMapper.resolve(
        tokenError,
        fallbackMessage: 'Không thể lấy token xác thực quảng cáo.',
      );
      debugPrint(
          'Failed to get Firebase ID token (checkin): ${errorInfo.message}');
      return {'ok': false, 'error': 'network_error'};
    }
    if (idToken.isEmpty) {
      return {'ok': false, 'error': 'unauthenticated'};
    }

    late final http.Response response;
    try {
      response = await postWithToken(idToken);
    } on StateError catch (error) {
      final errorInfo = AppErrorMapper.resolve(
        error,
        fallbackMessage: 'Thiếu token App Check để gửi yêu cầu thưởng.',
      );
      debugPrint(
          'Reward server blocked due to missing App Check token: ${errorInfo.message}');
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
          final retryInfo = AppErrorMapper.resolve(
            retryError,
            fallbackMessage: 'Yêu cầu máy chủ thưởng chưa hoàn tất.',
          );
          if (retryMessage.contains('parse header value')) {
            debugPrint(
              'Reward server request still failed after token refresh: ${retryInfo.message}',
            );
            return {'ok': false, 'error': 'invalid_auth_header'};
          }
          debugPrint('Reward server request failed: ${retryInfo.message}');
          return {'ok': false, 'error': 'network_error'};
        }
      } else {
        final errorInfo = AppErrorMapper.resolve(
          error,
          fallbackMessage: 'Yêu cầu máy chủ thưởng chưa hoàn tất.',
        );
        debugPrint('Reward server request failed: ${errorInfo.message}');
        return {'ok': false, 'error': 'network_error'};
      }
    } on TimeoutException catch (error) {
      final errorInfo = AppErrorMapper.resolve(
        error,
        fallbackMessage: 'Yêu cầu máy chủ thưởng bị quá thời gian.',
      );
      debugPrint('Reward server request timed out: ${errorInfo.message}');
      return {'ok': false, 'error': 'network_timeout'};
    } catch (error) {
      final errorInfo = AppErrorMapper.resolve(
        error,
        fallbackMessage: 'Yêu cầu máy chủ thưởng chưa hoàn tất.',
      );
      debugPrint('Reward server request failed: ${errorInfo.message}');
      return {'ok': false, 'error': 'network_error'};
    }

    Map<String, dynamic>? decodedMap;
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map) {
        decodedMap = Map<String, dynamic>.from(decoded);
      }
    } catch (e) {
      // FIXME: Không decode được JSON response từ server
      debugPrint('AdMobService: JSON decode failed: $e');
      decodedMap = null;
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final error =
          decodedMap?['error']?.toString() ?? _rewardHttpError(response);
      debugPrint(
        'Reward server rejected request: ${response.statusCode} $error',
      );
      if (response.statusCode == 404) {
        _isRewardEndpointDisabled = true;
      }
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

    final res = await _postAuthenticatedJson(
      AppConfig.rewardGrantUrl,
      payload,
      requireAppCheck: source != 'daily_checkin',
    );

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
    // Kiểm tra xem đã đạt giới hạn hàng ngày chưa
    final canWatch = await canWatchRewardedAdToday();
    if (!canWatch) {
      debugPrint(
          'AdMobService: Đã đạt giới hạn $dailyRewardedAdLimit quảng cáo/ngày.');
      return const RewardClaimResult(
        ok: false,
        error: 'local_daily_limit_estimate',
      );
    }

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
    } catch (e) {
      // FIXME: Lỗi claim daily checkin lần đầu
      debugPrint('AdMobService: Daily checkin initial claim failed: $e');
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
      } catch (e) {
        // FIXME: Lỗi retry claim daily checkin
        debugPrint('AdMobService: Daily checkin retry claim failed: $e');
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
    if (!AppConfig.isPurchaseEnabled) {
      return const RewardClaimResult(ok: false, error: 'purchase_disabled');
    }
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

  // ─── AD IMPRESSION PING ────────────────────────────────────────

  /// Gui ping len server xac nhan da show quang cao thanh cong.
  /// Giup server phat hien neu user tat quang cao bang cach patch client.
  Future<void> _sendAdImpressionPing(String adType, String adUnit) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      if (await isProUser()) return; // Khong can ping neu la PRO

      final endpoint = AppConfig.adImpressionPingUrl.trim();
      if (endpoint.isEmpty) return;

      final houseId = await _houseService.getCurrentHouseId();

      final payload = <String, dynamic>{
        'adType': adType,
        'adUnit': adUnit,
        'clientNonce': _buildRewardProofNonce(), // Dung lai ham nonce co san
        'clientIssuedAtMs': DateTime.now().millisecondsSinceEpoch,
        if (houseId != null && houseId.isNotEmpty) 'houseId': houseId,
      };

      // Gui ping bat dong bo, khong block luong chinh
      unawaited(_postAuthenticatedJson(
        endpoint,
        payload,
        requireAppCheck: false,
      ));
    } catch (e) {
      // FIXME: Ping lỗi không ảnh hưởng đến trải nghiệm người dùng
      debugPrint('AdMobService: Ad impression ping failed: $e');
    }
  }
}
