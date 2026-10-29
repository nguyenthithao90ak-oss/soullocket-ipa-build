import 'package:soullocket_app/utils/ui_copy.dart';
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
import 'package:soullocket_app/models/reward_missions.dart';
import 'package:flutter/widgets.dart';
import '../consent_service.dart';
import 'app_open_ad_presentation.dart';
import 'fullscreen_ad_presentation.dart';
import 'reward_request_scope.dart';
import 'ad_reward_receipt_store.dart';
import 'staggered_ad_preloader.dart';

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

enum SoulGameRewardedAdResult {
  rewarded,
  pro,
  unsupported,
  privacyDisabled,
  cooldown,
  unavailable,
  dismissed,
  busy,
  cancelled,
}

class AdMobService {
  static final AdMobService _instance = AdMobService._internal();
  factory AdMobService() => _instance;
  AdMobService._internal() {
    ConsentService.adRequestsAllowed.addListener(_onPrivacyChanged);
    _ensureAuthObserver();
  }

  /// Dùng SDK/dispatcher thật với danh tính và quyền giả trong kiểm thử local.
  @visibleForTesting
  AdMobService.forTesting({
    required String? Function() currentUid,
    required Future<bool> Function() readPro,
    DateTime Function()? now,
    bool supportsGameAds = true,
  }) : _currentUidOverride = currentUid,
       _readProOverride = readPro,
       _nowOverride = now,
       _supportsGameAdsOverride = supportsGameAds {
    _sdkInitialized = true;
    _requestConfigurationReady = true;
    _umpAllowsAds = true;
    ConsentService.adRequestsAllowed.addListener(_onPrivacyChanged);
  }

  String? Function()? _currentUidOverride;
  Future<bool> Function()? _readProOverride;
  DateTime Function()? _nowOverride;
  bool? _supportsGameAdsOverride;
  StreamSubscription<User?>? _authSubscription;
  String? _observedAuthUid;
  String? get _adUid => _currentUidOverride == null
      ? FirebaseAuth.instance.currentUser?.uid
      : _currentUidOverride!();
  DateTime _adNow() => _nowOverride?.call() ?? DateTime.now();

  void _ensureAuthObserver() {
    if (_currentUidOverride != null || _authSubscription != null) return;
    try {
      _authSubscription = FirebaseAuth.instance.authStateChanges().listen(
        _onAuthChanged,
      );
    } catch (error) {
      // Một số test/khởi động sớm tạo service trước Firebase.initializeApp().
      debugPrint('AdMobService: auth observer delayed: $error');
    }
  }

  void _onAuthChanged(User? user) {
    if (_currentUidOverride != null) return;
    final nextUid = user?.uid;
    if (nextUid == _observedAuthUid) return;
    _observedAuthUid = nextUid;
    _discardAds(resetConsent: false);
    if (nextUid != null && _canUseAds) {
      // Tài khoản thường mới nhận lại rewarded sớm; PRO sẽ bị _canLoadAdsFor
      // bỏ qua. Các định dạng còn lại được caller/màn active preload theo scope.
      unawaited(_loadRewardedAd());
    }
  }

  @visibleForTesting
  void disposeForTesting() {
    assert(_currentUidOverride != null);
    ConsentService.adRequestsAllowed.removeListener(_onPrivacyChanged);
    _discardAds();
    adRevision.dispose();
  }

  @visibleForTesting
  void handleIdentityChangeForTesting() {
    _discardAds(resetConsent: false);
  }

  static const int rewardedMainPoints = 50;
  static const int dailyRewardedAdLimit = 20;
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
  static const int _appOpenMaxPerDay = 8;
  static const List<String> _debugTestDeviceIds = <String>[
    'D9B28AB8E1553E4F327420FC9896415C',
    '370D8C7AC6D4262893C393843B5727CA',
  ];
  late final HouseService _houseService = HouseService();
  final Random _random = Random();
  // Một endpoint chưa deploy không được khóa các API thưởng khác cả phiên.
  static final Map<String, DateTime> _rewardEndpointRetryAfter = {};

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
    if (kDebugMode) return AdUnitConfig.rewardedMainId;
    if (Platform.isIOS) {
      return _iosRewardedMainId ?? AdUnitConfig.rewardedMainId;
    }
    return _androidRewardedMainId ?? AdUnitConfig.rewardedMainId;
  }

  static String get rewardedCheckinId {
    if (kDebugMode) return AdUnitConfig.rewardedCheckinId;
    if (Platform.isIOS) {
      return _iosRewardedCheckinId ?? AdUnitConfig.rewardedCheckinId;
    }
    return _androidRewardedCheckinId ?? AdUnitConfig.rewardedCheckinId;
  }

  static String get rewardedSoulGameId {
    if (kDebugMode) return AdUnitConfig.rewardedSoulGameId;
    if (Platform.isIOS) {
      return _iosRewardedSoulGameId ?? AdUnitConfig.rewardedSoulGameId;
    }
    return _androidRewardedSoulGameId ?? AdUnitConfig.rewardedSoulGameId;
  }

  static String get bannerId {
    if (kDebugMode) return AdUnitConfig.bannerId;
    if (Platform.isIOS) {
      return _iosBannerId ?? AdUnitConfig.bannerId;
    }
    return _androidBannerId ?? AdUnitConfig.bannerId;
  }

  static String get interstitialId {
    if (kDebugMode) return AdUnitConfig.interstitialId;
    if (Platform.isIOS) {
      return _iosInterstitialId ?? AdUnitConfig.interstitialId;
    }
    return _androidInterstitialId ?? AdUnitConfig.interstitialId;
  }

  static String get appOpenId {
    if (kDebugMode) return AdUnitConfig.appOpenId;
    if (Platform.isIOS) {
      return _iosAppOpenId ?? AdUnitConfig.appOpenId;
    }
    return _androidAppOpenId ?? AdUnitConfig.appOpenId;
  }

  // ─── REWARDED AD (CHÍNH) ─────────────────────────────────────
  RewardedAd? _rewardedAd;
  final _rewardedLoad = SharedAdLoad();
  bool get _isRewardedAdLoading => _rewardedLoad.isRunning;
  Timer? _rewardedRetryTimer;
  int _rewardedLoadId = 0;
  DateTime? _rewardedLoadedAt;
  RewardedAd? _soulGameRewardedAd;
  final _soulGameRewardedLoad = SharedAdLoad();
  bool get _isSoulGameRewardedAdLoading => _soulGameRewardedLoad.isRunning;
  int _soulGameRewardedLoadId = 0;
  DateTime? _soulGameRewardedLoadedAt;
  AppOpenAd? _appOpenAd;
  DateTime? _appOpenLoadedAt;
  bool _isAppOpenLoading = false;
  bool _isShowingAppOpenAd = false;
  int _lastFullscreenAdShownMs = 0;
  static const int _fullscreenAdCooldownMs = 7 * 60 * 1000; // 7 minutes
  Completer<void>? _initializeCompleter;
  int? _initializeEpoch;
  Completer<bool>? _appOpenLoadCompleter;
  bool _sdkInitialized = false;
  bool _requestConfigurationReady = false;
  bool _isShowingFullscreenAd = false;
  bool _nativeFullscreenVisible = false;
  bool _umpAllowsAds = false;
  bool _privacyOptionsOpen = false;
  int _privacyEpoch = 0;
  final Set<BannerAd> _banners = {};
  final ValueNotifier<int> adRevision = ValueNotifier(0);
  late final _startupAdPreloader = StaggeredAdPreloader(
    canPreload: () =>
        _canUseAds &&
        !_isShowingFullscreenAd &&
        !_nativeFullscreenVisible &&
        !_isRewardedAdLoading &&
        !_isSoulGameRewardedAdLoading &&
        !_isAppOpenLoading &&
        !_isInterstitialLoading,
    onError: (error, _) => debugPrint(
      'AdMob preload failed: ${AppErrorMapper.resolve(error).message}',
    ),
  );
  bool get _canUseAds =>
      _sdkInitialized &&
      _requestConfigurationReady &&
      _umpAllowsAds &&
      !_privacyOptionsOpen &&
      ConsentService.adRequestsAllowed.value;
  bool _isCurrentAdRequest(String? uid, int epoch) =>
      uid != null && _canUseAds && epoch == _privacyEpoch && _adUid == uid;

  Future<bool> _canLoadAdsFor(String? uid, int epoch) async {
    if (!_isCurrentAdRequest(uid, epoch)) return false;
    try {
      final pro = await isProUser().timeout(const Duration(seconds: 10));
      return !pro && _isCurrentAdRequest(uid, epoch);
    } catch (error) {
      // Quyền PRO chưa đọc được thì bỏ lượt preload và để lần sau kiểm tra lại.
      debugPrint(
        'AdMobService: preload eligibility failed: ${AppErrorMapper.resolve(error).message}',
      );
      return false;
    }
  }

  bool _canPresentAdFor(String? uid, int epoch, {bool blockKeyboard = false}) =>
      _isCurrentAdRequest(uid, epoch) &&
      WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed &&
      !AdSuppressionGuard.instance.isSuppressed &&
      (!blockKeyboard ||
          !WidgetsBinding.instance.platformDispatcher.views.any(
            (view) => view.viewInsets.bottom > 0,
          ));

  bool isBannerUsable(BannerAd ad) => _canUseAds && _banners.contains(ad);
  bool get canRequestAds => _canUseAds;
  bool get hasReadyInterstitialAd {
    final loadedAt = _interstitialLoadedAt;
    if (_interstitialAd == null || loadedAt == null) return false;
    return _adNow().difference(loadedAt) < const Duration(minutes: 55);
  }

  bool get supportsSoulGameRewardedAds =>
      !kIsWeb &&
      (_supportsGameAdsOverride ?? (Platform.isAndroid || Platform.isIOS));
  bool get soulGameAdsDisabledByPrivacy =>
      !ConsentService.adRequestsAllowed.value;

  void disposeBanner(BannerAd? banner) {
    if (banner != null && _banners.remove(banner)) {
      unawaited(banner.dispose());
    }
  }

  void _onPrivacyChanged() {
    if (ConsentService.adRequestsAllowed.value) {
      unawaited(initialize());
      return;
    }
    _discardAds();
  }

  void _discardAds({bool resetConsent = true}) {
    _privacyEpoch++;
    _startupAdPreloader.cancel();
    if (resetConsent) _requestConfigurationReady = false;
    _rewardedLoad.cancel();
    _rewardedRetryTimer?.cancel();
    _rewardedRetryTimer = null;
    _rewardedLoadId++;
    _rewardedLoadedAt = null;
    _interstitialLoadId++;
    _interstitialLoad.cancel();
    _interstitialLoadedAt = null;
    _soulGameRewardedLoad.cancel();
    _soulGameRewardedLoadId++;
    _soulGameRewardedLoadedAt = null;
    _isAppOpenLoading = false;
    final appOpenCompleter = _appOpenLoadCompleter;
    _appOpenLoadCompleter = null;
    if (appOpenCompleter != null && !appOpenCompleter.isCompleted) {
      appOpenCompleter.complete(false);
    }
    _appOpenLoadedAt = null;
    if (resetConsent) _umpAllowsAds = false;
    _autoInterstitialTimer?.cancel();
    _autoInterstitialTimer = null;
    _rewardedAd?.dispose();
    _rewardedAd = null;
    _soulGameRewardedAd?.dispose();
    _soulGameRewardedAd = null;
    _appOpenAd?.dispose();
    _appOpenAd = null;
    _interstitialAd?.dispose();
    _interstitialAd = null;
    for (final banner in _banners) {
      banner.dispose();
    }
    _banners.clear();
    adRevision.value++;
  }

  Future<void> showPrivacyOptions() async {
    if (kIsWeb ||
        _privacyOptionsOpen ||
        _initializeCompleter != null ||
        !ConsentService.adRequestsAllowed.value) {
      return;
    }
    _privacyOptionsOpen = true;
    _discardAds();
    final epoch = _privacyEpoch;
    var allowed = false;
    try {
      final completed = Completer<void>();
      ConsentForm.showPrivacyOptionsForm((error) {
        if (error != null) {
          if (!completed.isCompleted) {
            completed.completeError(StateError('Ad privacy form unavailable'));
          }
          return;
        }
        if (!completed.isCompleted) completed.complete();
      });
      // Người dùng có thể đọc biểu mẫu lâu; chỉ mở lại ads sau khi đóng form.
      await completed.future;
      allowed = await ConsentInformation.instance.canRequestAds();
    } finally {
      _privacyOptionsOpen = false;
    }
    if (epoch == _privacyEpoch && ConsentService.adRequestsAllowed.value) {
      _umpAllowsAds = allowed;
      if (allowed) await initialize();
      adRevision.value++;
    }
  }

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
    return _adNow().millisecondsSinceEpoch - lastShownMs <
        cooldown.inMilliseconds;
  }

  Future<void> initialize() async {
    _ensureAuthObserver();
    if (kIsWeb ||
        _privacyOptionsOpen ||
        !ConsentService.adRequestsAllowed.value) {
      return;
    }
    if (_canUseAds) return;
    if (_initializeCompleter != null) {
      final waitingEpoch = _initializeEpoch;
      await _initializeCompleter!.future;
      if (waitingEpoch != _privacyEpoch &&
          ConsentService.adRequestsAllowed.value) {
        await initialize();
      }
      return;
    }
    final completer = Completer<void>();
    final epoch = _privacyEpoch;
    _initializeCompleter = completer;
    _initializeEpoch = epoch;
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
      var consentFormStarted = false;
      ConsentInformation.instance.requestConsentInfoUpdate(
        params,
        () async {
          try {
            final available = await ConsentInformation.instance
                .isConsentFormAvailable();
            if (!ConsentService.adRequestsAllowed.value ||
                epoch != _privacyEpoch ||
                consentCompleter.isCompleted) {
              if (!consentCompleter.isCompleted) consentCompleter.complete();
              return;
            }
            if (available) {
              consentFormStarted = true;
              ConsentForm.loadAndShowConsentFormIfRequired((loadAndShowError) {
                if (loadAndShowError != null) {
                  debugPrint('Consent Form Error: $loadAndShowError');
                }
                if (!consentCompleter.isCompleted) {
                  consentCompleter.complete();
                }
              });
            } else {
              if (!consentCompleter.isCompleted) {
                consentCompleter.complete();
              }
            }
          } catch (_) {
            consentUpdateFailed = true;
            if (!consentCompleter.isCompleted) consentCompleter.complete();
          }
        },
        (FormError error) {
          consentUpdateFailed = true;
          final errorInfo = AppErrorMapper.resolve(
            error,
            fallbackMessage: UiCopy.text('copy_8cd3c308eb00'),
          );
          debugPrint('Consent Info Update Error: ${errorInfo.message}');
          if (!consentCompleter.isCompleted) {
            consentCompleter.complete();
          }
        },
      );
      await consentCompleter.future.timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          if (consentFormStarted) return consentCompleter.future;
          consentUpdateFailed = true;
          if (!consentCompleter.isCompleted) consentCompleter.complete();
        },
      );
    } catch (e) {
      consentUpdateFailed = true;
      final errorInfo = AppErrorMapper.resolve(
        e,
        fallbackMessage: UiCopy.text('copy_8cd3c308eb00'),
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
        return;
      }
      if (!ConsentService.adRequestsAllowed.value || epoch != _privacyEpoch) {
        return;
      }
      _umpAllowsAds = true;

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
            AdUnitConfig.androidRewardedMainId = map['rewardedMainId']
                .toString();
          }
          if (map['rewardedCheckinId'] != null) {
            AdUnitConfig.androidRewardedCheckinId = map['rewardedCheckinId']
                .toString();
          }
          if (map['rewardedSoulGameId'] != null) {
            AdUnitConfig.androidRewardedSoulGameId = map['rewardedSoulGameId']
                .toString();
          }
          if (map['bannerId'] != null) {
            AdUnitConfig.androidBannerId = map['bannerId'].toString();
          }
          if (map['interstitialId'] != null) {
            AdUnitConfig.androidInterstitialId = map['interstitialId']
                .toString();
          }
          if (map['appOpenId'] != null) {
            AdUnitConfig.androidAppOpenId = map['appOpenId'].toString();
          }

          if (map['ios_rewardedMainId'] != null) {
            AdUnitConfig.iosRewardedMainId = map['ios_rewardedMainId']
                .toString();
          }
          if (map['ios_rewardedCheckinId'] != null) {
            AdUnitConfig.iosRewardedCheckinId = map['ios_rewardedCheckinId']
                .toString();
          }
          if (map['ios_rewardedSoulGameId'] != null) {
            AdUnitConfig.iosRewardedSoulGameId = map['ios_rewardedSoulGameId']
                .toString();
          }
          if (map['ios_bannerId'] != null) {
            AdUnitConfig.iosBannerId = map['ios_bannerId'].toString();
          }
          if (map['ios_interstitialId'] != null) {
            AdUnitConfig.iosInterstitialId = map['ios_interstitialId']
                .toString();
          }
          if (map['ios_appOpenId'] != null) {
            AdUnitConfig.iosAppOpenId = map['ios_appOpenId'].toString();
          }
        }
      } catch (e) {
        final errorInfo = AppErrorMapper.resolve(
          e,
          fallbackMessage: UiCopy.text('copy_caacd24575fa'),
        );
        debugPrint('Failed to sync AdMob IDs: ${errorInfo.message}');
      }

      if (kDebugMode) {
        await MobileAds.instance.updateRequestConfiguration(
          RequestConfiguration(testDeviceIds: _debugTestDeviceIds),
        );
      }
      if (!ConsentService.adRequestsAllowed.value || epoch != _privacyEpoch) {
        return;
      }
      await _applyAgeGateToAdSettings();
      if (!ConsentService.adRequestsAllowed.value || epoch != _privacyEpoch) {
        return;
      }
      if (!_sdkInitialized) await MobileAds.instance.initialize();
      debugPrint('AdMobService: MobileAds SDK initialized.');
      _sdkInitialized = true;
      if (!ConsentService.adRequestsAllowed.value || epoch != _privacyEpoch) {
        return;
      }
      _requestConfigurationReady = true;
      adRevision.value++;
      _startupAdPreloader.start([
        () async {
          await loadAppOpenAd();
        },
        _loadRewardedAd,
        loadInterstitialAd,
      ]);
    } catch (error) {
      _umpAllowsAds = false;
      debugPrint(
        'AdMob consent initialization failed: ${AppErrorMapper.resolve(error).message}',
      );
    } finally {
      if (!completer.isCompleted) {
        completer.complete();
      }
      _initializeCompleter = null;
      _initializeEpoch = null;
    }
  }

  /// Giới hạn nội dung trước initialize, không tự coi tuổi chưa rõ là người lớn.
  Future<void> _applyAgeGateToAdSettings() async {
    final classification = await TexasAgeGateService().resolveAgeSignal();
    await MobileAds.instance.updateRequestConfiguration(
      requestConfigurationForAge(classification),
    );
  }

  @visibleForTesting
  static RequestConfiguration requestConfigurationForAge(
    AgeClassification classification,
  ) => RequestConfiguration(
    testDeviceIds: kDebugMode ? _debugTestDeviceIds : null,
    ageRestrictedTreatment: switch (classification) {
      AgeClassification.child => AgeRestrictedTreatment.child,
      AgeClassification.minor => AgeRestrictedTreatment.teen,
      _ => AgeRestrictedTreatment.unspecified,
    },
    maxAdContentRating: classification == AgeClassification.adult
        ? MaxAdContentRating.pg
        : MaxAdContentRating.g,
  );

  Future<void> _loadRewardedAd({int retryCount = 0}) =>
      _rewardedLoad.run(() async {
        if (kIsWeb || !_canUseAds) return;
        final epoch = _privacyEpoch;
        final uid = _adUid;
        if (!await _canLoadAdsFor(uid, epoch)) return;
        if (_rewardedAd != null &&
            (_rewardedLoadedAt == null ||
                _adNow().difference(_rewardedLoadedAt!) >=
                    const Duration(minutes: 55))) {
          unawaited(_rewardedAd!.dispose());
          _rewardedAd = null;
          _rewardedLoadedAt = null;
        }
        if (_rewardedAd != null) return;
        _rewardedRetryTimer?.cancel();
        _rewardedRetryTimer = null;
        final loadId = ++_rewardedLoadId;
        bool current() => epoch == _privacyEpoch && loadId == _rewardedLoadId;
        Future<void> load() async {
          final ad = await loadAdWithTimeout<RewardedAd>(
            debugLabel: 'rewarded main',
            canAccept: () => current() && _isCurrentAdRequest(uid, epoch),
            load: (loaded, failed) => RewardedAd.load(
              adUnitId: rewardedMainId,
              request: const AdRequest(),
              rewardedAdLoadCallback: RewardedAdLoadCallback(
                onAdLoaded: loaded,
                onAdFailedToLoad: failed,
              ),
            ),
          );
          if (!current()) {
            if (ad != null) unawaited(ad.dispose());
            return;
          }
          if (!_isCurrentAdRequest(uid, epoch)) {
            if (ad != null) unawaited(ad.dispose());
            return;
          }
          _rewardedAd = ad;
          _rewardedLoadedAt = ad == null ? null : _adNow();
          if (ad != null) {
            debugPrint('AdMobService: rewarded main loaded.');
          } else if (retryCount < 2) {
            _rewardedRetryTimer = Timer(const Duration(seconds: 10), () {
              _rewardedRetryTimer = null;
              if (current() &&
                  WidgetsBinding.instance.lifecycleState ==
                      AppLifecycleState.resumed) {
                unawaited(_loadRewardedAd(retryCount: retryCount + 1));
              }
            });
          }
        }

        await load();
      });

  Future<void> _loadSoulGameRewardedAd() => _soulGameRewardedLoad.run(() async {
    if (!supportsSoulGameRewardedAds || !_canUseAds) return;
    final epoch = _privacyEpoch;
    final uid = _adUid;
    if (!await _canLoadAdsFor(uid, epoch)) return;
    final loadedAt = _soulGameRewardedLoadedAt;
    if (_soulGameRewardedAd != null &&
        (loadedAt == null ||
            _adNow().difference(loadedAt) >= const Duration(minutes: 55))) {
      _soulGameRewardedAd?.dispose();
      _soulGameRewardedAd = null;
      _soulGameRewardedLoadedAt = null;
    }
    if (_soulGameRewardedAd != null) return;
    final loadId = ++_soulGameRewardedLoadId;

    bool isCurrentLoad() =>
        epoch == _privacyEpoch && loadId == _soulGameRewardedLoadId;

    final ad = await loadAdWithTimeout<RewardedAd>(
      debugLabel: 'rewarded soul game',
      timeout: const Duration(seconds: 15),
      canAccept: () => isCurrentLoad() && _isCurrentAdRequest(uid, epoch),
      load: (loaded, failed) => RewardedAd.load(
        adUnitId: rewardedSoulGameId,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: loaded,
          onAdFailedToLoad: failed,
        ),
      ),
    );
    if (!isCurrentLoad() || !_isCurrentAdRequest(uid, epoch)) {
      if (ad != null) unawaited(ad.dispose());
      return;
    }
    _soulGameRewardedAd = ad;
    _soulGameRewardedLoadedAt = ad == null ? null : _adNow();
    if (ad != null) debugPrint('AdMobService: rewarded soul game loaded.');
  });

  void preloadRewardedAd() {
    unawaited(_initializeAndPreloadRewardedAd());
  }

  Future<void> _initializeAndPreloadRewardedAd() async {
    await initialize();
    await _loadRewardedAd();
  }

  void preloadSoulGameRewardedAd() {
    unawaited(_initializeAndPreloadSoulGameRewardedAd());
  }

  Future<void> _initializeAndPreloadSoulGameRewardedAd() async {
    await initialize();
    await _loadSoulGameRewardedAd();
  }

  void preloadInterstitialAd() {
    unawaited(() async {
      await initialize();
      await loadInterstitialAd();
    }());
  }

  Future<bool> loadAppOpenAd() async {
    if (kIsWeb || !_canUseAds) return false;
    final epoch = _privacyEpoch;
    final uid = _adUid;
    if (!await _canLoadAdsFor(uid, epoch)) return false;
    if (_appOpenAd != null &&
        _appOpenLoadedAt != null &&
        _adNow().difference(_appOpenLoadedAt!) < const Duration(hours: 4)) {
      return true;
    }
    _appOpenAd?.dispose();
    _appOpenAd = null;
    if (_isAppOpenLoading) return _appOpenLoadCompleter?.future ?? false;
    _isAppOpenLoading = true;
    final completer = Completer<bool>();
    _appOpenLoadCompleter = completer;
    final ad = await loadAdWithTimeout<AppOpenAd>(
      debugLabel: 'app open',
      canAccept: () =>
          _isCurrentAdRequest(uid, epoch) &&
          identical(_appOpenLoadCompleter, completer),
      load: (loaded, failed) => AppOpenAd.load(
        adUnitId: appOpenId,
        request: const AdRequest(),
        adLoadCallback: AppOpenAdLoadCallback(
          onAdLoaded: loaded,
          onAdFailedToLoad: failed,
        ),
      ),
    );
    final current = identical(_appOpenLoadCompleter, completer);
    final usable = current && _isCurrentAdRequest(uid, epoch) && ad != null;
    if (usable) {
      _appOpenAd = ad;
      _appOpenLoadedAt = _adNow();
      debugPrint('AdMobService: App Open loaded.');
    } else if (ad != null) {
      unawaited(ad.dispose());
    }
    if (current) {
      _isAppOpenLoading = false;
      _appOpenLoadCompleter = null;
    }
    if (!completer.isCompleted) completer.complete(usable);
    return usable;
  }

  Future<bool> _withFullscreenLock(Future<bool> Function() show) async {
    if (_isShowingFullscreenAd || _nativeFullscreenVisible) return false;
    _isShowingFullscreenAd = true;
    try {
      return await show();
    } catch (error) {
      debugPrint(
        'Fullscreen ad failed: ${AppErrorMapper.resolve(error).message}',
      );
      return false;
    } finally {
      _isShowingFullscreenAd = false;
      if (!_nativeFullscreenVisible) AppLifecyclePresenceGuard.settle();
    }
  }

  Future<bool> showAppOpenAdIfEligible({bool Function()? canShow}) =>
      _withFullscreenLock(
        () => _showAppOpenAdIfEligible(canShowAtEntry: canShow),
      );

  Future<bool> _showAppOpenAdIfEligible({
    bool Function()? canShowAtEntry,
  }) async {
    if (kIsWeb || canShowAtEntry?.call() == false) return false;
    final uid = _adUid;
    final showEpoch = _privacyEpoch;
    final requestedAt = _adNow();
    final readyAd = _appOpenAd;
    final loadedAt = _appOpenLoadedAt;
    if (uid == null || AdSuppressionGuard.instance.isSuppressed) return false;
    if (hasRecentFullscreenAd(cooldown: const Duration(minutes: 10))) {
      return false;
    }
    if (readyAd == null ||
        loadedAt == null ||
        requestedAt.difference(loadedAt) >= const Duration(hours: 4)) {
      // Resume chỉ dùng ad sẵn sàng từ trước; tải mới dành cho lần mở kế tiếp.
      unawaited(() async {
        await initialize();
        await loadAppOpenAd();
      }());
      return false;
    }
    await initialize();
    if (!_canPresentAdFor(uid, showEpoch, blockKeyboard: true)) return false;
    if (_isShowingAppOpenAd || _isAutoInterstitialSuppressed) return false;
    if (!await _canLoadAdsFor(uid, showEpoch)) return false;
    if (!await _canShowAppOpenToday()) return false;
    final ad = readyAd;
    bool canShow() =>
        canShowAtEntry?.call() != false &&
        // Bỏ lượt resume nếu kiểm tra quyền/quota kéo dài tới lúc đã dùng Home.
        _adNow().difference(requestedAt) < const Duration(seconds: 2) &&
        identical(_appOpenAd, ad) &&
        _canPresentAdFor(uid, showEpoch, blockKeyboard: true) &&
        !_isAutoInterstitialSuppressed &&
        !hasRecentFullscreenAd(cooldown: const Duration(minutes: 10));
    if (!canShow()) return false;
    _isShowingAppOpenAd = true;
    AppLifecyclePresenceGuard.arm();
    return presentAppOpenAd(
      ad: ad,
      canShow: canShow,
      onShown: () {
        _nativeFullscreenVisible = true;
        _lastFullscreenAdShownMs = _adNow().millisecondsSinceEpoch;
        unawaited(_sendAdImpressionPing('app_open', ad.adUnitId));
      },
      recordShown: _incrementAppOpenShownCount,
      onClosed: () {
        _nativeFullscreenVisible = false;
        if (identical(_appOpenAd, ad)) {
          _appOpenAd = null;
          _appOpenLoadedAt = null;
        }
        _isShowingAppOpenAd = false;
        AppLifecyclePresenceGuard.settle();
        unawaited(loadAppOpenAd());
      },
    );
  }

  Future<bool> _canShowAppOpenToday() async {
    final prefs =
        OfflineCacheService.getPrefsSync() ??
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
    final nowMs = _adNow().millisecondsSinceEpoch;

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
        debugPrint(
          'AdMobService: Không lấy được Android SDK version: $e, fallback 4h cooldown.',
        );
        requiredHours = 4.0; // fallback an toàn nếu không lấy được info
      }
    }

    if (hoursDiff >= requiredHours) {
      return true;
    }

    return false;
  }

  Future<void> _incrementAppOpenShownCount() async {
    final prefs =
        OfflineCacheService.getPrefsSync() ??
        await SharedPreferences.getInstance();
    final todayDate = _getTodayDateKey();
    final storedDate = prefs.getString(_appOpenShownDatePrefsKey);
    final currentCount = storedDate == todayDate
        ? prefs.getInt(_appOpenShownCountPrefsKey) ?? 0
        : 0;
    await prefs.setString(_appOpenShownDatePrefsKey, todayDate);
    await prefs.setInt(_appOpenShownCountPrefsKey, currentCount + 1);
    await prefs.setInt(
      _appOpenLastShownDatePrefsKey,
      _adNow().millisecondsSinceEpoch,
    );
  }

  // ─── DAILY REWARDED AD LIMIT ──────────────────────────────────
  String _getTodayDateKey() {
    final now = _adNow();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  // Quota rewarded phải khớp ngày phần thưởng mà Functions dùng (UTC+7),
  // không phụ thuộc múi giờ cài trên thiết bị.
  String _getRewardDayKey() => rewardDayKey();

  /// Lấy số lần xem quảng cáo rewarded hôm nay
  Future<int> getDailyRewardedAdCount() async {
    final prefs =
        OfflineCacheService.getPrefsSync() ??
        await SharedPreferences.getInstance();
    final storedDate = prefs.getString(_dailyRewardedAdDatePrefsKey);
    final todayDate = _getRewardDayKey();

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
    final prefs =
        OfflineCacheService.getPrefsSync() ??
        await SharedPreferences.getInstance();
    final storedDate = prefs.getString(_dailyRewardedAdDatePrefsKey);
    final todayDate = _getRewardDayKey();

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
  RewardClaimResult? _lastRewardedAdFailure;
  RewardClaimResult? get lastRewardedAdFailure => _lastRewardedAdFailure;

  Duration get soulGameRewardedCooldownRemaining {
    if (_lastSoulGameRewardedShownMs <= 0) return Duration.zero;
    return Duration(
      milliseconds:
          (_rewardedCooldownMs -
                  (_adNow().millisecondsSinceEpoch -
                      _lastSoulGameRewardedShownMs))
              .clamp(0, _rewardedCooldownMs),
    );
  }

  /// Hiển thị quảng cáo rewarded. Trả về true nếu user xem đủ.
  Future<bool> showRewardedAd({
    bool ignoreCooldown = false,
    // Đồng bộ với timeout tải native để mạng chậm không bị bỏ qua sớm.
    Duration loadTimeout = const Duration(seconds: 12),
    String? verifiedPurpose,
    bool Function()? isCurrent,
  }) => _withFullscreenLock(
    () => _showRewardedAd(
      ignoreCooldown: ignoreCooldown,
      loadTimeout: loadTimeout,
      verifiedPurpose: verifiedPurpose,
      isCurrent: isCurrent ?? () => true,
    ),
  );

  Future<bool> _showRewardedAd({
    required bool ignoreCooldown,
    required Duration loadTimeout,
    String? verifiedPurpose,
    required bool Function() isCurrent,
  }) async {
    if (kIsWeb || !isCurrent()) return false;
    final rewardUid = _adUid;
    final showEpoch = _privacyEpoch;
    if (rewardUid == null) return false;
    _lastRewardedAdFailure = null;
    if (verifiedPurpose != null && await pendingAdRewardPurpose() != null) {
      return false;
    }
    if (await isProUser()) {
      debugPrint('AdMobService: rewarded skipped because user is Pro.');
      return false;
    }

    final nowMs = _adNow().millisecondsSinceEpoch;
    if (!ignoreCooldown && nowMs - _lastRewardedShownMs < _rewardedCooldownMs) {
      debugPrint('AdMobService: Xem quảng cáo quá nhanh, đang chờ cooldown.');
      return false; // Chưa qua cooldown
    }

    await initialize();
    if (!_canUseAds) {
      debugPrint(
        'AdMobService: rewarded skipped because SDK is not initialized.',
      );
      return false;
    }
    // Cùng chờ lượt preload và kiểm tra hạn trước khi lấy instance. Đọc cache
    // ngay sau unawaited(load) có thể lấy ad cũ trong lúc quyền PRO đang chờ.
    final adForShow = await prepareAdWithTimeout<RewardedAd>(
      timeout: Duration(
        milliseconds: loadTimeout.inMilliseconds.clamp(0, 15000),
      ),
      isCurrent: () => isCurrent() && _isCurrentAdRequest(rewardUid, showEpoch),
      prepare: (canContinue) async {
        await _loadRewardedAd();
        return canContinue() ? _rewardedAd : null;
      },
    );
    if (adForShow == null) return false;
    String? rewardNonce;
    try {
      if (verifiedPurpose != null) {
        final prepared = await _postAuthenticatedJson(
          AppConfig.adRewardStatusUrl,
          {
            'action': 'prepare',
            'purpose': verifiedPurpose,
            'adUnit': adForShow.adUnitId.split('/').last,
          },
          requireAppCheck: true,
          expectedUid: rewardUid,
        );
        if (prepared?['ok'] != true) {
          _lastRewardedAdFailure = RewardClaimResult.fromResponse(prepared);
          return false;
        }
        rewardNonce = List.generate(
          32,
          (_) => Random.secure().nextInt(256),
        ).map((b) => b.toRadixString(16).padLeft(2, '0')).join();
        if (!_canUseAds ||
            showEpoch != _privacyEpoch ||
            !identical(_rewardedAd, adForShow) ||
            _adUid != rewardUid) {
          return false;
        }
        await adForShow
            .setServerSideOptions(
              ServerSideVerificationOptions(
                userId: rewardUid,
                customData: jsonEncode({
                  'v': 1,
                  'nonce': rewardNonce,
                  'purpose': verifiedPurpose,
                }),
              ),
            )
            .timeout(const Duration(seconds: 5));
        _lastVerifiedRewardNonce = rewardNonce;
        _lastVerifiedRewardUid = rewardUid;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('ad_pending_nonce_$rewardUid', rewardNonce);
        await prefs.setString('ad_pending_purpose_$rewardUid', verifiedPurpose);
        await prefs.setInt(
          'ad_pending_started_$rewardUid',
          _adNow().millisecondsSinceEpoch,
        );
      } else {
        if (_rewardedAd == null) return false;
        await adForShow
            .setServerSideOptions(
              ServerSideVerificationOptions(userId: '', customData: ''),
            )
            .timeout(const Duration(seconds: 5));
      }
    } catch (error) {
      // Options đến muộn không được ghi vào instance mà lượt sau tái dùng.
      if (identical(_rewardedAd, adForShow)) {
        _rewardedAd = null;
        _rewardedLoadedAt = null;
      }
      unawaited(adForShow.dispose());
      unawaited(_loadRewardedAd());
      if (rewardNonce != null) {
        try {
          await _clearPendingReward(
            rewardUid,
            rewardNonce,
          ).timeout(const Duration(seconds: 5));
        } catch (_) {
          /* Biên nhận vẫn theo UID/nonce cũ nếu prefs lỗi. */
        }
      }
      _lastRewardedAdFailure = RewardClaimResult(
        ok: false,
        error: error is TimeoutException
            ? 'network_timeout'
            : 'reward_server_unavailable',
      );
      return false;
    }
    if (!isCurrent() ||
        !await _canLoadAdsFor(rewardUid, showEpoch) ||
        !_canPresentAdFor(rewardUid, showEpoch) ||
        !identical(_rewardedAd, adForShow)) {
      if (rewardNonce != null) {
        await _clearPendingReward(rewardUid, rewardNonce);
      }
      return false;
    }
    final ad = adForShow;
    AppLifecyclePresenceGuard.arm();
    final outcome = await presentRewardedAd(
      ad: ad,
      canShow: () =>
          isCurrent() &&
          _canPresentAdFor(rewardUid, showEpoch) &&
          identical(_rewardedAd, ad),
      onShown: () {
        _nativeFullscreenVisible = true;
        _lastRewardedShownMs = _adNow().millisecondsSinceEpoch;
        _lastFullscreenAdShownMs = _lastRewardedShownMs;
        unawaited(_sendAdImpressionPing('rewarded', ad.adUnitId));
      },
      onClosed: () {
        _nativeFullscreenVisible = false;
        if (identical(_rewardedAd, ad)) _rewardedAd = null;
        unawaited(_loadRewardedAd());
        AppLifecyclePresenceGuard.settle();
      },
    );
    if (outcome != FullscreenAdOutcome.rewarded && rewardNonce != null) {
      try {
        if (outcome == FullscreenAdOutcome.dismissed) {
          // Giữ SSV trễ sau đóng sớm; không khóa lượt xem tiếp theo.
          await AdRewardReceiptStore(await SharedPreferences.getInstance())
              .archiveMatching(rewardUid, rewardNonce)
              .timeout(const Duration(seconds: 5));
        } else {
          await _clearPendingReward(
            rewardUid,
            rewardNonce,
          ).timeout(const Duration(seconds: 5));
        }
      } catch (error) {
        debugPrint(
          'AdMobService: receipt cleanup failed: ${AppErrorMapper.resolve(error).message}',
        );
      }
    }
    return outcome == FullscreenAdOutcome.rewarded && _adUid == rewardUid;
  }

  /// Hiển thị quảng cáo hồi sinh và trả về lý do chính xác khi không thể dùng.
  /// PRO được coi là đã nhận phần thưởng mà không mở quảng cáo.
  Future<SoulGameRewardedAdResult> showSoulGameRewardedAdResult({
    bool Function()? isCurrent,
  }) async {
    if (_isShowingFullscreenAd || _nativeFullscreenVisible) {
      return SoulGameRewardedAdResult.busy;
    }
    _isShowingFullscreenAd = true;
    try {
      return await _showSoulGameRewardedAdResult(isCurrent ?? () => true);
    } catch (error) {
      debugPrint(
        'AdMobService: Soul Game rewarded flow failed: '
        '${AppErrorMapper.resolve(error).message}',
      );
      return SoulGameRewardedAdResult.cancelled;
    } finally {
      _isShowingFullscreenAd = false;
      if (!_nativeFullscreenVisible) AppLifecyclePresenceGuard.settle();
    }
  }

  Future<bool> showSoulGameRewardedAd() async {
    final result = await showSoulGameRewardedAdResult();
    return result == SoulGameRewardedAdResult.rewarded ||
        result == SoulGameRewardedAdResult.pro;
  }

  Future<SoulGameRewardedAdResult> _showSoulGameRewardedAdResult(
    bool Function() isCurrent,
  ) async {
    if (!isCurrent()) return SoulGameRewardedAdResult.cancelled;
    if (!supportsSoulGameRewardedAds) {
      return SoulGameRewardedAdResult.unsupported;
    }
    final rewardUid = _adUid;
    final showEpoch = _privacyEpoch;
    if (rewardUid == null) return SoulGameRewardedAdResult.cancelled;
    if (await isProUser()) {
      return _adUid == rewardUid
          ? SoulGameRewardedAdResult.pro
          : SoulGameRewardedAdResult.cancelled;
    }
    if (soulGameAdsDisabledByPrivacy) {
      return SoulGameRewardedAdResult.privacyDisabled;
    }

    final cooldown = soulGameRewardedCooldownRemaining;
    if (cooldown > Duration.zero) {
      debugPrint(
        'AdMobService: Soul Game rewarded cooldown remaining '
        '${cooldown.inSeconds}s.',
      );
      return SoulGameRewardedAdResult.cooldown;
    }

    await initialize();
    if (!_canUseAds) {
      return soulGameAdsDisabledByPrivacy
          ? SoulGameRewardedAdResult.privacyDisabled
          : SoulGameRewardedAdResult.unavailable;
    }
    // Kiểm tra tuổi thọ ngay trước khi hiển thị. App có thể nằm nền lâu hơn
    // thời gian hợp lệ của một rewarded đã preload; không đưa quảng cáo cũ
    // vào luồng hồi sinh rồi mới chờ SDK báo lỗi.
    final ad = await prepareAdWithTimeout<RewardedAd>(
      timeout: const Duration(seconds: 15),
      isCurrent: () => isCurrent() && _isCurrentAdRequest(rewardUid, showEpoch),
      prepare: (canContinue) async {
        await _loadSoulGameRewardedAd();
        return canContinue() ? _soulGameRewardedAd : null;
      },
    );
    if (ad == null) {
      return soulGameAdsDisabledByPrivacy
          ? SoulGameRewardedAdResult.privacyDisabled
          : SoulGameRewardedAdResult.unavailable;
    }
    if (!isCurrent() || !_canPresentAdFor(rewardUid, showEpoch)) {
      return SoulGameRewardedAdResult.cancelled;
    }
    AppLifecyclePresenceGuard.arm();
    final outcome = await presentRewardedAd(
      ad: ad,
      canShow: () =>
          isCurrent() &&
          _canPresentAdFor(rewardUid, showEpoch) &&
          identical(_soulGameRewardedAd, ad),
      onShown: () {
        _nativeFullscreenVisible = true;
        _lastSoulGameRewardedShownMs = _adNow().millisecondsSinceEpoch;
        _lastFullscreenAdShownMs = _lastSoulGameRewardedShownMs;
        unawaited(_sendAdImpressionPing('rewarded', ad.adUnitId));
      },
      onClosed: () {
        _nativeFullscreenVisible = false;
        if (identical(_soulGameRewardedAd, ad)) {
          _soulGameRewardedAd = null;
          _soulGameRewardedLoadedAt = null;
        }
        unawaited(_loadSoulGameRewardedAd());
        AppLifecyclePresenceGuard.settle();
      },
    );
    if (_adUid != rewardUid) {
      return SoulGameRewardedAdResult.cancelled;
    }
    return switch (outcome) {
      FullscreenAdOutcome.rewarded => SoulGameRewardedAdResult.rewarded,
      FullscreenAdOutcome.dismissed => SoulGameRewardedAdResult.dismissed,
      FullscreenAdOutcome.unavailable => SoulGameRewardedAdResult.unavailable,
    };
  }

  // ─── BANNER AD ───────────────────────────────────────────────
  Future<BannerAd?> createBannerAd({
    required Function(Ad) onAdLoaded,
    VoidCallback? onAdInvalidated,
  }) async {
    if (kIsWeb) return null;
    final uid = _adUid;
    final epoch = _privacyEpoch;
    await initialize();
    if (!_canUseAds) {
      debugPrint(
        'AdMobService: banner skipped because SDK is not initialized.',
      );
      return null;
    }
    if (!await _canLoadAdsFor(uid, epoch)) return null;

    final completer = Completer<BannerAd?>();
    late final BannerAd banner;
    banner = BannerAd(
      adUnitId: bannerId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (!_isCurrentAdRequest(uid, epoch) || !_banners.contains(banner)) {
            disposeBanner(banner);
            if (!completer.isCompleted) completer.complete(null);
            return;
          }
          onAdLoaded(ad);
          if (!completer.isCompleted) {
            completer.complete(banner);
          }
        },
        onAdImpression: (ad) {
          // Tải xong chưa có nghĩa đã hiển thị; bỏ callback cũ sau rút consent.
          if (epoch != _privacyEpoch ||
              _adUid != uid ||
              !isBannerUsable(banner)) {
            return;
          }
          unawaited(_sendAdImpressionPing('banner', ad.adUnitId));
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint(
            'AdMobService: banner failed to load: ${adFailureDetails(error)}',
          );
          final wasUsable = isBannerUsable(banner);
          disposeBanner(banner);
          if (!completer.isCompleted) {
            completer.complete(null);
          } else if (wasUsable) {
            // Banner đã hiện có thể lỗi ở lượt refresh; màn phải bỏ view cũ
            // và có cơ hội tải lại thay vì giữ một instance đã dispose.
            onAdInvalidated?.call();
          }
        },
      ),
    );
    _banners.add(banner);
    Future<void> load() async {
      try {
        await banner.load();
      } catch (error) {
        disposeBanner(banner);
        if (!completer.isCompleted) completer.complete(null);
        debugPrint(
          'Banner load failed: ${AppErrorMapper.resolve(error).message}',
        );
      }
    }

    unawaited(load());
    return completer.future.timeout(
      const Duration(seconds: 12),
      onTimeout: () {
        debugPrint('AdMobService: banner load timed out.');
        disposeBanner(banner);
        return null;
      },
    );
  }

  // ─── INTERSTITIAL AD ─────────────────────────────────────────
  InterstitialAd? _interstitialAd;
  final _interstitialLoad = SharedAdLoad();
  bool get _isInterstitialLoading => _interstitialLoad.isRunning;
  int _interstitialLoadId = 0;
  DateTime? _interstitialLoadedAt;
  Timer? _autoInterstitialTimer;
  bool _autoInterstitialSchedulerEnabled = false;
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

  Future<void> loadInterstitialAd() => _interstitialLoad.run(() async {
    if (kIsWeb || !_canUseAds) return;
    final epoch = _privacyEpoch;
    final uid = _adUid;
    if (!await _canLoadAdsFor(uid, epoch)) return;
    if (_interstitialAd != null &&
        (_interstitialLoadedAt == null ||
            _adNow().difference(_interstitialLoadedAt!) >=
                const Duration(minutes: 55))) {
      unawaited(_interstitialAd!.dispose());
      _interstitialAd = null;
      _interstitialLoadedAt = null;
    }
    if (_interstitialAd != null) return;
    final loadId = ++_interstitialLoadId;
    bool current() => epoch == _privacyEpoch && loadId == _interstitialLoadId;
    final ad = await loadAdWithTimeout<InterstitialAd>(
      debugLabel: 'interstitial',
      canAccept: () => current() && _isCurrentAdRequest(uid, epoch),
      load: (loaded, failed) => InterstitialAd.load(
        adUnitId: interstitialId,
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: loaded,
          onAdFailedToLoad: failed,
        ),
      ),
    );
    if (!current() || !_isCurrentAdRequest(uid, epoch)) {
      if (ad != null) unawaited(ad.dispose());
      return;
    }
    _interstitialAd = ad;
    _interstitialLoadedAt = ad == null ? null : _adNow();
  });

  Future<bool> showInterstitialAd({
    bool Function()? isCurrent,
    Duration preparationTimeout = const Duration(seconds: 10),
  }) => _withFullscreenLock(
    () => _showInterstitialAd(
      isCurrent: isCurrent ?? () => true,
      preparationTimeout: preparationTimeout,
    ),
  );

  Future<bool> showReadyInterstitialAd({
    bool Function()? isCurrent,
    VoidCallback? onShown,
  }) => _withFullscreenLock(
    () => _showReadyInterstitialAd(
      isCurrent: isCurrent ?? () => true,
      onShown: onShown,
    ),
  );

  Future<bool> _showReadyInterstitialAd({
    required bool Function() isCurrent,
    VoidCallback? onShown,
  }) async {
    if (kIsWeb || !isCurrent() || !hasReadyInterstitialAd) return false;
    final uid = _adUid;
    final showEpoch = _privacyEpoch;
    final ad = _interstitialAd;
    if (uid == null || ad == null) return false;
    final eligible = await prepareAdWithTimeout<bool>(
      timeout: const Duration(seconds: 2),
      isCurrent: isCurrent,
      prepare: (_) => _canLoadAdsFor(uid, showEpoch),
    );
    if (eligible != true) return false;
    bool canShow() =>
        isCurrent() &&
        identical(_interstitialAd, ad) &&
        _canPresentAdFor(uid, showEpoch, blockKeyboard: true) &&
        !hasRecentFullscreenAd();
    if (!canShow()) return false;
    AppLifecyclePresenceGuard.arm();
    final outcome = await presentInterstitialAd(
      ad: ad,
      canShow: canShow,
      onShown: () {
        _nativeFullscreenVisible = true;
        _lastFullscreenAdShownMs = _adNow().millisecondsSinceEpoch;
        unawaited(_sendAdImpressionPing('interstitial', ad.adUnitId));
        onShown?.call();
      },
      onClosed: () {
        _nativeFullscreenVisible = false;
        if (identical(_interstitialAd, ad)) {
          _interstitialAd = null;
          _interstitialLoadedAt = null;
        }
        unawaited(loadInterstitialAd());
        AppLifecyclePresenceGuard.settle();
      },
    );
    return outcome != FullscreenAdOutcome.unavailable;
  }

  Future<bool> _showInterstitialAd({
    required bool Function() isCurrent,
    required Duration preparationTimeout,
  }) async {
    if (kIsWeb || !isCurrent() || hasRecentFullscreenAd()) return false;
    final uid = _adUid;
    final showEpoch = _privacyEpoch;
    if (uid == null) return false;
    final ad = await prepareAdWithTimeout<InterstitialAd>(
      timeout: preparationTimeout,
      isCurrent: isCurrent,
      prepare: (canContinue) async {
        if (await isProUser() || !canContinue()) return null;
        if (AdSuppressionGuard.instance.isSuppressed) return null;
        await initialize();
        if (!canContinue() ||
            !_canPresentAdFor(uid, showEpoch, blockKeyboard: true)) {
          return null;
        }
        await loadInterstitialAd();
        if (!canContinue()) return null;
        if (!await _canLoadAdsFor(uid, showEpoch) || !canContinue()) {
          return null;
        }
        return _interstitialAd;
      },
    );
    if (ad == null) return false;
    bool canShow() =>
        isCurrent() &&
        identical(_interstitialAd, ad) &&
        _canPresentAdFor(uid, showEpoch, blockKeyboard: true) &&
        !hasRecentFullscreenAd();
    if (!canShow()) return false;
    AppLifecyclePresenceGuard.arm();
    final outcome = await presentInterstitialAd(
      ad: ad,
      canShow: canShow,
      onShown: () {
        _nativeFullscreenVisible = true;
        _lastFullscreenAdShownMs = _adNow().millisecondsSinceEpoch;
        unawaited(_sendAdImpressionPing('interstitial', ad.adUnitId));
      },
      onClosed: () {
        _nativeFullscreenVisible = false;
        if (identical(_interstitialAd, ad)) {
          _interstitialAd = null;
          _interstitialLoadedAt = null;
        }
        unawaited(loadInterstitialAd());
        AppLifecyclePresenceGuard.settle();
      },
    );
    return outcome != FullscreenAdOutcome.unavailable;
  }

  Future<void> startAutoInterstitialScheduler() async {
    if (kIsWeb) return;
    await initialize();
    if (!_canUseAds) return;
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
    if (!_canUseAds) return;
    if (FirebaseAuth.instance.currentUser == null) return;
    if (await isProUser()) {
      await pauseAutoInterstitialScheduler();
      return;
    }
    await _ensureNextAutoInterstitialAt();
    await _scheduleAutoInterstitialTimer();
  }

  Future<void> stopAutoInterstitialScheduler({
    bool clearPersisted = false,
  }) async {
    _autoInterstitialSchedulerEnabled = false;
    _autoInterstitialTimer?.cancel();
    _autoInterstitialTimer = null;
    if (clearPersisted) {
      final prefs =
          OfflineCacheService.getPrefsSync() ??
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

    final now = _adNow();
    if (!nextAt.isAfter(now)) {
      unawaited(_handleAutoInterstitialDue());
      return;
    }

    _autoInterstitialTimer = Timer(nextAt.difference(now), () {
      unawaited(_handleAutoInterstitialDue());
    });
  }

  Future<void> _handleAutoInterstitialDue() async {
    // Timer chỉ nạp sẵn; quảng cáo toàn màn hình chỉ mở ở điểm chuyển màn phù hợp.
    // Rewarded chỉ được mở sau thao tác chủ động của người dùng, không từ timer.
    if (!_autoInterstitialSchedulerEnabled || !_canUseAds) return;
    await loadInterstitialAd();
    await _setNextAutoInterstitialAt(_generateNextAutoInterstitialAt());
    if (_autoInterstitialSchedulerEnabled && _canUseAds) {
      await _scheduleAutoInterstitialTimer();
    }
  }

  Future<void> _ensureNextAutoInterstitialAt() async {
    final current = await _readNextAutoInterstitialAt();
    if (current == null) {
      await _setNextAutoInterstitialAt(_generateNextAutoInterstitialAt());
    }
  }

  DateTime _generateNextAutoInterstitialAt() {
    final offsetMinutes =
        _autoInterstitialMinMinutes +
        _random.nextInt(
          (_autoInterstitialMaxMinutes - _autoInterstitialMinMinutes) + 1,
        );
    return _adNow().add(Duration(minutes: offsetMinutes));
  }

  Future<DateTime?> _readNextAutoInterstitialAt() async {
    final prefs =
        OfflineCacheService.getPrefsSync() ??
        await SharedPreferences.getInstance();
    final nextAtMs = prefs.getInt(_autoInterstitialNextAtPrefsKey);
    if (nextAtMs == null || nextAtMs <= 0) return null;
    return DateTime.fromMillisecondsSinceEpoch(nextAtMs);
  }

  Future<void> _setNextAutoInterstitialAt(DateTime nextAt) async {
    final prefs =
        OfflineCacheService.getPrefsSync() ??
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
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final snap = await userRef
        .child('points')
        .get()
        .timeout(const Duration(seconds: 10));
    if (FirebaseAuth.instance.currentUser?.uid != uid) {
      throw RewardScopeChanged('unauthenticated');
    }
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
    return access.expiresAtMs ?? DateTime.utc(9999).millisecondsSinceEpoch;
  }

  Stream<int> streamCurrentProUntil() {
    // Lỗi mạng không đóng stream; dùng cùng resolver quyền với quảng cáo.
    late final StreamController<int> controller;
    Timer? timer;
    var cancelled = false;
    var loading = false;
    int? lastExpiry;
    var hadError = false;
    Future<void> refresh() async {
      if (cancelled || loading) return;
      loading = true;
      try {
        final expiry = await getCurrentProUntil();
        if (!cancelled && (expiry != lastExpiry || hadError)) {
          controller.add(expiry);
          lastExpiry = expiry;
          hadError = false;
        }
      } catch (error, stack) {
        hadError = true;
        if (!cancelled) controller.addError(error, stack);
      } finally {
        loading = false;
      }
    }

    controller = StreamController<int>(
      onListen: () {
        unawaited(refresh());
        timer = Timer.periodic(
          const Duration(seconds: 2),
          (_) => unawaited(refresh()),
        );
      },
      onCancel: () {
        cancelled = true;
        timer?.cancel();
      },
    );
    return controller.stream;
  }

  Future<bool> isProUser() async {
    if (_readProOverride != null) return _readProOverride!();
    final access = await PurchaseService().getVipAccessInfo();
    return access.isVip;
  }

  Future<Map<String, dynamic>?> _postAuthenticatedJson(
    String endpoint,
    Map<String, dynamic> body, {
    bool requireAppCheck = true,
    String? expectedUid,
    String? expectedHouseId,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || (expectedUid != null && user.uid != expectedUid)) {
      return {'ok': false, 'error': 'unauthenticated'};
    }
    if (endpoint.trim().isEmpty) {
      return {'ok': false, 'error': 'endpoint_not_configured'};
    }
    final scope = RewardRequestScope(
      uid: user.uid,
      currentUid: () => FirebaseAuth.instance.currentUser?.uid,
      houseId: expectedHouseId,
      currentHouseId: expectedHouseId == null
          ? null
          : () => _houseService
                .getCurrentHouseId(preferFresh: true)
                .timeout(const Duration(seconds: 10)),
    );
    final endpointKey = endpoint.trim();
    final retryAfter = _rewardEndpointRetryAfter[endpointKey];
    if (retryAfter != null && DateTime.now().isBefore(retryAfter)) {
      return {'ok': false, 'error': 'endpoint_not_found'};
    }
    _rewardEndpointRetryAfter.remove(endpointKey);

    Future<String> readBearerToken({required bool forceRefresh}) async {
      final rawToken =
          await user
              .getIdToken(forceRefresh)
              .timeout(const Duration(seconds: 10), onTimeout: () => null) ??
          '';
      return rawToken.replaceAll(RegExp(r'\s+'), '');
    }

    Future<http.Response> postWithToken(String idToken) {
      final appCheckHeaders = requireAppCheck
          ? AppCheckHttpHeaders.withRequiredToken
          : AppCheckHttpHeaders.withOptionalToken;
      // SDK tự làm mới token hết hạn. Không ép attestation lại mỗi lần poll.
      // Timeout gồm cả lấy App Check, không chỉ phần HTTP phía sau.
      return appCheckHeaders({
        'Content-Type': 'application/json; charset=utf-8',
        'Authorization': 'Bearer $idToken',
      }, forceRefresh: false).timeout(const Duration(seconds: 10)).then((
        headers,
      ) async {
        await scope.ensureCurrent();
        return http
            .post(
              Uri.parse(endpoint.trim()),
              headers: headers,
              body: jsonEncode(body),
            )
            .timeout(const Duration(seconds: 20));
      });
    }

    String idToken;
    try {
      idToken = await readBearerToken(forceRefresh: false);
    } catch (tokenError) {
      final errorInfo = AppErrorMapper.resolve(
        tokenError,
        fallbackMessage: UiCopy.text('copy_249f14d0744b'),
      );
      debugPrint(
        'Failed to get Firebase ID token (checkin): ${errorInfo.message}',
      );
      return {'ok': false, 'error': 'network_error'};
    }
    if (idToken.isEmpty) {
      return {'ok': false, 'error': 'unauthenticated'};
    }

    late final http.Response response;
    try {
      response = await postWithToken(idToken);
    } on StateError catch (error) {
      if (error is RewardScopeChanged) {
        return {'ok': false, 'error': error.code};
      }
      final errorInfo = AppErrorMapper.resolve(
        error,
        fallbackMessage: UiCopy.text('copy_5d1bf9bf2cf5'),
      );
      debugPrint(
        'Reward server blocked due to missing App Check token: ${errorInfo.message}',
      );
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
            'Failed to refresh Firebase ID token on retry: $retryTokenError',
          );
          return {'ok': false, 'error': 'network_error'};
        }
        if (idToken.isEmpty) {
          return {'ok': false, 'error': 'unauthenticated'};
        }
        try {
          response = await postWithToken(idToken);
        } on StateError catch (retryAppCheckError) {
          if (retryAppCheckError is RewardScopeChanged) {
            return {'ok': false, 'error': retryAppCheckError.code};
          }
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
            fallbackMessage: UiCopy.text('copy_4d8803e82af4'),
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
          fallbackMessage: UiCopy.text('copy_4d8803e82af4'),
        );
        debugPrint('Reward server request failed: ${errorInfo.message}');
        return {'ok': false, 'error': 'network_error'};
      }
    } on TimeoutException catch (error) {
      final errorInfo = AppErrorMapper.resolve(
        error,
        fallbackMessage: UiCopy.text('copy_2ba6f354b50c'),
      );
      debugPrint('Reward server request timed out: ${errorInfo.message}');
      return {'ok': false, 'error': 'network_timeout'};
    } catch (error) {
      final errorInfo = AppErrorMapper.resolve(
        error,
        fallbackMessage: UiCopy.text('copy_4d8803e82af4'),
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

    if (FirebaseAuth.instance.currentUser?.uid != user.uid) {
      return {'ok': false, 'error': 'unauthenticated'};
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final error =
          decodedMap?['error']?.toString() ?? _rewardHttpError(response);
      debugPrint(
        'Reward server rejected request: ${response.statusCode} $error',
      );
      if (response.statusCode == 404) {
        _rewardEndpointRetryAfter[endpointKey] = DateTime.now().add(
          const Duration(minutes: 1),
        );
      }
      if (_isRevenueSecurityError(error)) {
        await RevenueSecurityTelemetryService.instance.logEvent(
          type: 'reward_server_rejected',
          reason: error,
          severity: response.statusCode == 401 || response.statusCode == 403
              ? 'high'
              : 'medium',
          extra: <String, Object?>{'statusCode': response.statusCode},
        );
      }
      return {
        'ok': false,
        ...?decodedMap,
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
    String? expectedUid,
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
      requireAppCheck: true,
      expectedUid: expectedUid,
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

  String? _lastVerifiedRewardNonce;
  String? _lastVerifiedRewardUid;

  Future<String?> pendingAdRewardPurpose() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    final store = AdRewardReceiptStore(await SharedPreferences.getInstance());
    if (FirebaseAuth.instance.currentUser?.uid != uid) return null;
    return store.read(uid)?.purpose;
  }

  Future<void> _clearPendingReward(String uid, String nonce) async {
    await AdRewardReceiptStore(
      await SharedPreferences.getInstance(),
    ).clearMatching(uid, nonce);
    if (_lastVerifiedRewardUid == uid && _lastVerifiedRewardNonce == nonce) {
      _lastVerifiedRewardNonce = null;
      _lastVerifiedRewardUid = null;
    }
  }

  Future<RewardClaimResult?> recoverPendingAdReward() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    final store = AdRewardReceiptStore(await SharedPreferences.getInstance());
    if (FirebaseAuth.instance.currentUser?.uid != uid) return null;
    final pending = store.read(uid);
    RewardClaimResult? activeResult;
    var granted = 0;
    for (final receipt in [?pending, ...store.archived(uid)]) {
      final active = pending?.nonce == receipt.nonce;
      final response = await _waitForVerifiedReward(
        receipt.purpose,
        nonceOverride: receipt.nonce,
        attempts: active ? 8 : 1,
      );
      if (FirebaseAuth.instance.currentUser?.uid != uid) return null;
      if (response?['error'] == 'reward_pending' &&
          receipt.expired(DateTime.now().millisecondsSinceEpoch)) {
        await _clearPendingReward(uid, receipt.nonce);
      }
      final result = RewardClaimResult.fromResponse(response);
      if (result.ok) granted += result.granted;
      if (active) activeResult = result;
      if (!result.ok && result.error != 'reward_pending') break;
    }
    if (granted > 0) return RewardClaimResult(ok: true, granted: granted);
    return activeResult;
  }

  Future<RewardClaimResult> claimRewardedAdPoints() async {
    final receipt = await _waitForVerifiedReward('points');
    return RewardClaimResult.fromResponse(receipt);
  }

  Future<Map<String, dynamic>?> _waitForVerifiedReward(
    String purpose, {
    String? nonceOverride,
    int attempts = 8,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return {'ok': false, 'error': 'unauthenticated'};
    final prefs = await SharedPreferences.getInstance();
    final savedPurpose = prefs.getString('ad_pending_purpose_$uid');
    final nonce = _lastVerifiedRewardUid == uid && savedPurpose == purpose
        ? _lastVerifiedRewardNonce
        : null;
    final pending =
        nonceOverride ??
        nonce ??
        (savedPurpose == purpose
            ? prefs.getString('ad_pending_nonce_$uid')
            : null);
    if (pending == null) return {'ok': false, 'error': 'missing_proof'};
    Map<String, dynamic>? response;
    for (var attempt = 0; attempt < attempts; attempt++) {
      if (FirebaseAuth.instance.currentUser?.uid != uid) return null;
      response = await _postAuthenticatedJson(
        AppConfig.adRewardStatusUrl,
        {'action': 'status', 'nonce': pending},
        requireAppCheck: true,
        expectedUid: uid,
      );
      // Kết quả cũ chỉ thuộc tài khoản đã bắt đầu xem quảng cáo.
      if (FirebaseAuth.instance.currentUser?.uid != uid) return null;
      if (response?['ok'] == true) {
        if (response?['purpose'] != purpose) {
          return {'ok': false, 'error': 'invalid_proof'};
        }
        if (prefs.getString('ad_pending_nonce_$uid') == pending ||
            nonceOverride != null) {
          await _clearPendingReward(uid, pending);
          if (purpose == 'points') {
            await _incrementDailyRewardedAdCount();
          }
        }
        return FirebaseAuth.instance.currentUser?.uid == uid ? response : null;
      }
      if (response?['error'] != 'reward_pending') return response;
      if (attempt + 1 < attempts) {
        await Future<void>.delayed(const Duration(seconds: 2));
      }
    }
    return response;
  }

  Future<int?> unlockCountdownStyleWithAd(
    String style, {
    bool quick = false,
    bool Function()? isCurrent,
  }) async {
    final purpose = '${quick ? 'countdown_day' : 'countdown'}:$style';
    if (!await showRewardedAd(verifiedPurpose: purpose, isCurrent: isCurrent)) {
      return null;
    }
    final receipt = await _waitForVerifiedReward(purpose);
    if (receipt?['ok'] != true) return null;
    return (receipt?['expiresAt'] as num?)?.toInt();
  }

  Future<Set<String>> verifiedCountdownStyles() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return {};
    final response = await _postAuthenticatedJson(
      AppConfig.adRewardStatusUrl,
      {'action': 'styles'},
      requireAppCheck: true,
      expectedUid: uid,
    );
    if (FirebaseAuth.instance.currentUser?.uid != uid) return {};
    if (response?['ok'] != true) return {};
    return (response?['styles'] as List? ?? []).whereType<String>().toSet();
  }

  Future<bool> claimDailyCheckinPoints() async {
    final result = await claimDailyCheckinReward();
    return result.ok;
  }

  Future<RewardClaimResult> claimDailyCheckinReward() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const RewardClaimResult(ok: false, error: 'unauthenticated');
    }
    // Lần thử đầu tiên
    Map<String, dynamic>? response;
    try {
      response = await _claimRewardFromServer(
        source: 'daily_checkin',
        expectedUid: uid,
      );
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
      if (FirebaseAuth.instance.currentUser?.uid != uid) {
        return const RewardClaimResult(ok: false, error: 'unauthenticated');
      }
      Map<String, dynamic>? retryResponse;
      try {
        retryResponse = await _claimRewardFromServer(
          source: 'daily_checkin',
          expectedUid: uid,
        );
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
    String? expectedUid,
  }) async {
    if (!AppConfig.isPurchaseEnabled) {
      return const RewardClaimResult(ok: false, error: 'purchase_disabled');
    }
    if (planId.trim().isEmpty) {
      return const RewardClaimResult(ok: false, error: 'invalid_plan');
    }
    final uid = expectedUid ?? FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || FirebaseAuth.instance.currentUser?.uid != uid) {
      return const RewardClaimResult(ok: false, error: 'unauthenticated');
    }
    try {
      final houseId = await _houseService
          .getCurrentHouseId(preferFresh: true)
          .timeout(const Duration(seconds: 10));
      if (FirebaseAuth.instance.currentUser?.uid != uid) {
        return const RewardClaimResult(ok: false, error: 'unauthenticated');
      }
      if (houseId == null || houseId.isEmpty) {
        return const RewardClaimResult(ok: false, error: 'house_not_found');
      }
      final response = await _postAuthenticatedJson(
        AppConfig.rewardRedeemProUrl,
        {'houseId': houseId, 'planId': planId},
        expectedUid: uid,
        expectedHouseId: houseId,
      );
      final result = RewardClaimResult.fromResponse(response);
      if (result.ok && FirebaseAuth.instance.currentUser?.uid == uid) {
        try {
          await PurchaseService().getVipAccessInfo(forceRefresh: true);
        } catch (_) {
          // Server đã cấp quyền: lỗi refresh UI không biến giao dịch thành thất bại.
          debugPrint(
            'AdMobService: PRO granted; entitlement refresh will retry on stream.',
          );
        }
      }
      return result;
    } on TimeoutException {
      return const RewardClaimResult(ok: false, error: 'network_timeout');
    } catch (_) {
      return const RewardClaimResult(ok: false, error: 'network_error');
    }
  }

  // ─── AD IMPRESSION PING ────────────────────────────────────────

  /// Gui ping len server xac nhan da show quang cao thanh cong.
  /// Giup server phat hien neu user tat quang cao bang cach patch client.
  Future<void> _sendAdImpressionPing(String adType, String adUnit) async {
    if (_currentUidOverride != null) return;
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
      unawaited(
        _postAuthenticatedJson(endpoint, payload, requireAppCheck: false),
      );
    } catch (e) {
      // FIXME: Ping lỗi không ảnh hưởng đến trải nghiệm người dùng
      debugPrint('AdMobService: Ad impression ping failed: $e');
    }
  }
}
