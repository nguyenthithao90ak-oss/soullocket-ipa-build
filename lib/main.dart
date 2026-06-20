import 'dart:async';
import 'package:soullocket_app/app.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:tiktok_business_sdk/tiktok_business_sdk.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:soullocket_app/core/constants/app_config.dart';
import 'package:soullocket_app/utils/services/connectivity_service.dart';
import 'package:soullocket_app/utils/services/local_database_service.dart';
import 'package:soullocket_app/utils/services/music_service.dart';
import 'package:soullocket_app/utils/services/offline_cache_service.dart';
import 'package:soullocket_app/utils/services/security_service.dart';
import 'package:soullocket_app/utils/services/widget_service.dart';
import 'package:soullocket_app/utils/app_error_mapper.dart';
import 'package:soullocket_app/utils/services/error_logger_service.dart';
import 'package:soullocket_app/utils/services/revenue_security_telemetry_service.dart';
import 'package:soullocket_app/views/ui_prefs.dart';
import 'package:soullocket_app/utils/services/performance_profile_service.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('Handling background message: ${message.messageId ?? 'unknown'}');
  try {
    if (Firebase.apps.isEmpty) {
      await _initializeFirebaseBootstrap();
    }
    FirebaseDatabase.instance.setPersistenceEnabled(true);
  } catch (error, stackTrace) {
    debugPrint('FCM background bootstrap error: ${AppErrorMapper.resolve(
      error,
      fallbackMessage: L10nService().translate('core_err_fcm_bg_init_failed'),
    ).message}');
    unawaited(ErrorLoggerService.instance.logError(
      error,
      stackTrace,
      reason: 'fcm_background_bootstrap_error',
      fatal: false,
    ));
  }
}

const MethodChannel _bootstrapChannel = MethodChannel('soul_locket/bootstrap');
const String _signatureMethod = 'getAppSignatureStatus';
const String _signatureMismatchReasonCode = 'UNOFFICIAL_BUILD';

class _UnofficialBuildDetected implements Exception {
  const _UnofficialBuildDetected({
    required this.reasonCode,
    required this.status,
  });

  final String reasonCode;
  final String status;
}

class _AppSignatureStatus {
  const _AppSignatureStatus({
    required this.status,
    required this.reasonCode,
    required this.isTrusted,
  });

  final String status;
  final String reasonCode;
  final bool isTrusted;

  bool get shouldBlock => !isTrusted;
}

Future<_AppSignatureStatus> _loadAppSignatureStatus() async {
  if (kIsWeb) {
    return const _AppSignatureStatus(
      status: 'ok',
      reasonCode: 'web',
      isTrusted: true,
    );
  }

  final raw = await _bootstrapChannel.invokeMapMethod<String, dynamic>(
    _signatureMethod,
  );
  final status =
      (raw?['status'] as String? ?? 'package_info_unavailable').trim();
  final reasonCode =
      (raw?['reasonCode'] as String? ?? _signatureMismatchReasonCode).trim();
  final isTrusted = raw?['isTrusted'] == true;
  return _AppSignatureStatus(
    status: status,
    reasonCode: reasonCode.isEmpty ? _signatureMismatchReasonCode : reasonCode,
    isTrusted: isTrusted,
  );
}

Future<void> _verifyOfficialBuildSignature() async {
  if (kDebugMode || kIsWeb) {
    return;
  }
  final signatureStatus = await _loadAppSignatureStatus();
  if (signatureStatus.shouldBlock) {
    throw _UnofficialBuildDetected(
      reasonCode: signatureStatus.reasonCode,
      status: signatureStatus.status,
    );
  }
}

String _messageForSignatureStatus(String status) {
  switch (status) {
    case 'signature_mismatch':
      return L10nService().translate('core_err_signature_mismatch');
    case 'package_info_unavailable':
      return L10nService().translate('core_err_signature_verify_failed');
    default:
      return L10nService().translate('core_err_install_untrusted');
  }
}

List<String> _detailsForSignatureStatus(_UnofficialBuildDetected error) {
  return [
    _messageForSignatureStatus(error.status),
    L10nService().translate('core_err_reinstall_official'),
    if (kDebugMode) 'reasonCode=${error.reasonCode}; status=${error.status}',
  ];
}

Future<void> _purgeDeprecatedSecrets() async {
  await OfflineCacheService.initialize();
  final prefs = OfflineCacheService.getPrefsSync()!;
  await prefs.remove('gemini_api_key');
  try {
    const secureStorage = FlutterSecureStorage();
    await secureStorage.delete(key: 'gemini_api_key');
  } catch (_) {}
}

Future<void> _clearStaleIosAuthAfterFreshInstall() async {
  if (kIsWeb ||
      (defaultTargetPlatform != TargetPlatform.iOS &&
          defaultTargetPlatform != TargetPlatform.macOS)) {
    return;
  }

  await OfflineCacheService.initialize();
  final prefs = OfflineCacheService.getPrefsSync()!;
  const installMarkerKey = 'il_install_marker_v1';
  if (prefs.getBool(installMarkerKey) == true) {
    return;
  }

  final hasLocalAppState = prefs.getKeys().any(
        (key) => key.startsWith('il_') || key.startsWith('email_verify_'),
      );
  final staleUser = FirebaseAuth.instance.currentUser;
  final hasStaleAuth = staleUser != null;
  final shouldSignOut = !hasLocalAppState && hasStaleAuth;

  if (hasStaleAuth) {
    try {
      await FirebaseDatabase.instance
          .ref('debugFreshInstallCleanup/${staleUser.uid}')
          .push()
          .set({
        'platform': defaultTargetPlatform.name,
        'hasLocalAppState': hasLocalAppState,
        'hasStaleAuth': hasStaleAuth,
        'didSignOut': shouldSignOut,
        'localKeyCount': prefs.getKeys().length,
        'createdAtMs': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (e) {
      debugPrint('Fresh install cleanup log skipped: ${AppErrorMapper.resolve(
        e,
        fallbackMessage:
            L10nService().translate('core_err_log_fresh_install_failed'),
      ).message}');
    }
  }

  if (shouldSignOut) {
    await FirebaseAuth.instance.signOut();
    try {
      const secureStorage = FlutterSecureStorage();
      await secureStorage.deleteAll();
    } catch (_) {}
  }

  await prefs.setBool(installMarkerKey, true);
}

Future<void> _configureSystemUiForEdgeToEdge() async {
  if (kIsWeb) {
    return;
  }

  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  // ⚠️ Android 15 (SDK 35) deprecates statusBarColor & navigationBarColor.
  //     Edge-to-edge is now the system default; color-based inset APIs are
  //     no-ops and trigger Play Console warnings. We omit them entirely.
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      systemNavigationBarDividerColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
}

void main() {
  runZonedGuarded(() async {
    final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
    FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
    _configureRenderingDefaults();
    await _configureSystemUiForEdgeToEdge();
    GoogleFonts.config.allowRuntimeFetching = !kIsWeb;

    // Giữ dọc trên mobile; riêng macOS không khóa để cho phép xoay/ngang.
    if (!kIsWeb && defaultTargetPlatform != TargetPlatform.macOS) {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
    }

    FlutterError.onError = (details) {
      final errStr = details.exception.toString().toLowerCase();
      if (errStr.contains('unable to load asset') ||
          errStr.contains('không thể tải')) {
        debugPrint('Ignored fatal asset error in main: $errStr');
        return;
      }
      FlutterError.presentError(details);
      debugPrint(kDebugMode ? details.toString() : details.exceptionAsString());
      unawaited(ErrorLoggerService.instance.logError(
        details.exception,
        details.stack,
        reason: details.exceptionAsString(),
        fatal: false,
      ));
      unawaited(
        RevenueSecurityTelemetryService.instance.logSystemEvent(
          type: 'flutter_framework_error',
          reason: details.exceptionAsString(),
          extra: {
            'library': details.library,
            'context': details.context?.toDescription(),
          },
        ),
      );
    };

    PlatformDispatcher.instance.onError = (error, stackTrace) {
      final errStr = error.toString().toLowerCase();
      if (errStr.contains('unable to load asset') ||
          errStr.contains('không thể tải')) {
        debugPrint('Ignored async asset error in main: $errStr');
        return true;
      }
      final mappedError = AppErrorMapper.resolve(
        error,
        fallbackMessage: L10nService().translate('core_err_system_bg'),
      );
      unawaited(ErrorLoggerService.instance.logError(
        error,
        stackTrace,
        reason: 'platform_dispatcher',
        fatal: true,
      ));
      unawaited(
        RevenueSecurityTelemetryService.instance.logSystemEvent(
          type: 'platform_dispatcher_error',
          reason: mappedError.message,
        ),
      );
      return true;
    };

    try {
      await _verifyOfficialBuildSignature();
      await _initializeFirebaseBootstrap();
      await _clearStaleIosAuthAfterFreshInstall();
      unawaited(_initializeTikTokSdk());

      if (!kIsWeb) {
        FirebaseMessaging.onBackgroundMessage(
            _firebaseMessagingBackgroundHandler);
      }

      // Chạy song song 3 tác vụ độc lập trước khi render UI
      await Future.wait([
        UiPrefs.ensureLoaded(),
        L10nService().init(),
        PerformanceProfileService.instance.initialize(),
      ]);
      runApp(const MyApp());
      _scheduleDeferredBootstrap();
    } on _MissingBootstrapConfig {
      if (!kIsWeb) {
        FlutterNativeSplash.remove();
      }
      runApp(StartupErrorApp(
        title: L10nService().translate('core_err_missing_env_title'),
        message: kDebugMode
            ? L10nService().translate('core_err_missing_env_req')
            : L10nService().translate('core_err_app_not_ready'),
        details: [
          if (kDebugMode) L10nService().translate('core_err_missing_vars'),
          if (kDebugMode) L10nService().translate('core_err_pass_config_ci'),
          if (!kDebugMode) L10nService().translate('core_err_update_app'),
        ],
      ));
    } on _UnofficialBuildDetected catch (error) {
      if (!kIsWeb) {
        FlutterNativeSplash.remove();
      }
      runApp(StartupErrorApp(
        title: L10nService().translate('core_err_invalid_install_title'),
        message: L10nService().translate('core_err_official_release_only'),
        details: _detailsForSignatureStatus(error),
      ));
    } catch (error) {
      final bootstrapError = AppErrorMapper.resolve(
        error,
        fallbackMessage: L10nService().translate('core_err_app_start_failed'),
      );
      debugPrint('Bootstrap error: ${bootstrapError.message}');
      unawaited(
        RevenueSecurityTelemetryService.instance.logSystemEvent(
          type: 'bootstrap_error',
          reason: bootstrapError.message,
          extra: {
            'mappedMessage': bootstrapError.message,
          },
        ),
      );
      if (!kIsWeb) {
        FlutterNativeSplash.remove();
      }
      runApp(StartupErrorApp(
        title: bootstrapError.isNetworkError
            ? L10nService().translate('core_err_conn_start_title')
            : L10nService().translate('core_err_sys_start_title'),
        message: bootstrapError.isNetworkError
            ? L10nService().translate('core_err_conn_start_desc')
            : L10nService().translate('core_err_sys_start_desc'),
        details: [
          bootstrapError.message,
          bootstrapError.isNetworkError
              ? L10nService().translate('core_err_check_network')
              : L10nService().translate('core_err_try_again_contact'),
        ],
      ));
    }
  }, (error, stackTrace) {
    final mappedError = AppErrorMapper.resolve(
      error,
      fallbackMessage: L10nService().translate('core_err_uncaught_start'),
    );
    debugPrint('Uncaught zone error: ${mappedError.message}');
    unawaited(ErrorLoggerService.instance.logError(
      error,
      stackTrace,
      reason: 'uncaught_zone_error',
      fatal: true,
    ));
    unawaited(
      RevenueSecurityTelemetryService.instance.logSystemEvent(
        type: 'uncaught_zone_error',
        reason: mappedError.message,
      ),
    );
  });
}

Future<void> _initializeFirebaseBootstrap() async {
  if (kIsWeb) {
    _throwIfFirebaseEnvMissing();
    await Firebase.initializeApp(options: _firebaseOptionsFromEnv())
        .timeout(const Duration(seconds: 8));

    try {
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: 100 * 1024 * 1024, // 100 MB
      );
    } catch (e) {
      debugPrint('Firestore web persistence error: $e');
    }
  } else {
    await _initializeNativeFirebaseBootstrap();
  }

  if (Firebase.apps.isEmpty) {
    throw StateError(L10nService().translate('core_err_firebase_not_init'));
  }

  if (!kIsWeb) {
    try {
      FirebaseDatabase.instance.setPersistenceEnabled(true);
      // ⚡ Reduced from 10MB → 5MB to save RAM on startup
      FirebaseDatabase.instance.setPersistenceCacheSizeBytes(5000000);
    } catch (e) {
      debugPrint('Firebase persistence error: ${AppErrorMapper.resolve(
        e,
        fallbackMessage:
            L10nService().translate('core_err_firebase_cache_failed'),
      ).message}');
    }

    try {
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: 100 * 1024 * 1024, // 100 MB
      );
    } catch (e) {
      debugPrint('Firestore persistence error: $e');
    }

    await _initializeFirebaseAppCheck();
    await ErrorLoggerService.instance.initialize();
  }
}

FirebaseOptions _firebaseOptionsFromEnv() {
  final authDomain = AppConfig.firebaseAuthDomain.trim();
  return FirebaseOptions(
    apiKey: AppConfig.firebaseApiKey,
    appId: AppConfig.firebaseAppId,
    messagingSenderId: AppConfig.firebaseMessagingSenderId,
    projectId: AppConfig.firebaseProjectId,
    storageBucket: AppConfig.firebaseStorageBucket,
    databaseURL: AppConfig.firebaseDatabaseUrl,
    authDomain: authDomain.isEmpty ? null : authDomain,
  );
}

Future<void> _initializeNativeFirebaseBootstrap() async {
  try {
    await _initializeDefaultNativeFirebaseApp();
    return;
  } catch (nativeError) {
    debugPrint('Firebase native init error: ${AppErrorMapper.resolve(
      nativeError,
      fallbackMessage:
          L10nService().translate('core_err_firebase_native_failed'),
    ).message}');
  }

  final fallbackOptions = await _resolveNativeFirebaseFallbackOptions();
  if (fallbackOptions == null) {
    _throwIfFirebaseEnvMissing();
    throw StateError(
      'Firebase native initialization failed and no Android fallback '
      'FirebaseOptions were available.',
    );
  }

  await Firebase.initializeApp(options: fallbackOptions)
      .timeout(const Duration(seconds: 12));
}

Future<void> _initializeDefaultNativeFirebaseApp() async {
  const attemptTimeouts = <Duration>[
    Duration(seconds: 10),
    Duration(seconds: 18),
  ];

  Object? lastError;
  StackTrace? lastStackTrace;

  for (var index = 0; index < attemptTimeouts.length; index++) {
    try {
      if (Firebase.apps.isNotEmpty) {
        return;
      }
      await Firebase.initializeApp().timeout(attemptTimeouts[index]);
      return;
    } catch (error, stackTrace) {
      lastError = error;
      lastStackTrace = stackTrace;
      if (Firebase.apps.isNotEmpty) {
        return;
      }
      debugPrint(
          'Firebase native init attempt ${index + 1} failed: ${AppErrorMapper.resolve(
        error,
        fallbackMessage: 'Không thể khởi tạo Firebase native.',
      ).message}');
      if (index < attemptTimeouts.length - 1) {
        await Future<void>.delayed(const Duration(milliseconds: 350));
      }
    }
  }

  if (lastError != null && lastStackTrace != null) {
    Error.throwWithStackTrace(lastError, lastStackTrace);
  }

  throw StateError('Firebase native initialization failed.');
}

Future<FirebaseOptions?> _resolveNativeFirebaseFallbackOptions() async {
  final nativeOptions = await _loadNativeFirebaseOptions();
  if (nativeOptions != null) {
    return nativeOptions;
  }

  if (_missingFirebaseBootstrapKeys().isEmpty) {
    return _firebaseOptionsFromEnv();
  }

  return null;
}

Future<FirebaseOptions?> _loadNativeFirebaseOptions() async {
  if (kIsWeb) {
    return null;
  }

  try {
    final rawOptions = await _bootstrapChannel.invokeMapMethod<String, dynamic>(
      'getNativeFirebaseOptions',
    );
    if (rawOptions == null || rawOptions.isEmpty) {
      return null;
    }

    String readValue(String key) => (rawOptions[key] as String? ?? '').trim();

    final apiKey = readValue('apiKey');
    final appId = readValue('appId');
    final messagingSenderId = readValue('messagingSenderId');
    final projectId = readValue('projectId');

    if (apiKey.isEmpty ||
        appId.isEmpty ||
        messagingSenderId.isEmpty ||
        projectId.isEmpty) {
      return null;
    }

    final authDomain = readValue('authDomain');
    final storageBucket = readValue('storageBucket');
    final databaseUrl = readValue('databaseURL');

    return FirebaseOptions(
      apiKey: apiKey,
      appId: appId,
      messagingSenderId: messagingSenderId,
      projectId: projectId,
      authDomain: authDomain.isEmpty ? null : authDomain,
      storageBucket: storageBucket.isEmpty ? null : storageBucket,
      databaseURL: databaseUrl.isEmpty ? null : databaseUrl,
    );
  } catch (error) {
    debugPrint('Native Firebase options load error: ${AppErrorMapper.resolve(
      error,
      fallbackMessage:
          L10nService().translate('core_err_firebase_read_config_failed'),
    ).message}');
    return null;
  }
}

Future<void> _initializeFirebaseAppCheck() async {
  try {
    final webSiteKey = AppConfig.recaptchaV3SiteKey.trim();
    if (kIsWeb) {
      if (webSiteKey.isEmpty) {
        debugPrint('Firebase App Check skipped on web: missing site key');
        return;
      }
      await FirebaseAppCheck.instance
          .activate(providerWeb: ReCaptchaV3Provider(webSiteKey))
          .timeout(const Duration(seconds: 3));
      return;
    }
    await FirebaseAppCheck.instance
        .activate(
          providerAndroid: kDebugMode
              ? const AndroidDebugProvider()
              : const AndroidPlayIntegrityProvider(),
          providerApple: const AppleAppAttestWithDeviceCheckFallbackProvider(),
        )
        .timeout(const Duration(seconds: 3));
  } catch (e) {
    debugPrint('Firebase App Check init error: ${AppErrorMapper.resolve(
      e,
      fallbackMessage: L10nService().translate('core_err_appcheck_failed'),
    ).message}');
  }
}

Future<void> _requestIosTrackingAuthorization() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) {
    return;
  }

  try {
    final status = await AppTrackingTransparency.trackingAuthorizationStatus;
    if (status == TrackingStatus.notDetermined) {
      await AppTrackingTransparency.requestTrackingAuthorization();
    }
  } catch (e) {
    debugPrint('ATT request skipped: $e');
  }
}

Future<void> _initializeTikTokSdk() async {
  if (kIsWeb) {
    return;
  }

  final bool isIos = defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS;

  final appId =
      (isIos ? AppConfig.tiktokIosAppId : AppConfig.tiktokAndroidAppId).trim();
  final accessToken = (isIos
          ? AppConfig.tiktokIosAccessToken
          : AppConfig.tiktokAndroidAccessToken)
      .trim();
  final ttAppId =
      (isIos ? AppConfig.tiktokIosTtAppId : AppConfig.tiktokAndroidTtAppId)
          .trim();

  if (appId.isEmpty || accessToken.isEmpty || ttAppId.isEmpty) {
    debugPrint('TikTok Business SDK skipped: missing credentials in config');
    return;
  }

  try {
    await TiktokBusinessSdk().initTiktokBusinessSdk(
      accessToken: accessToken,
      appId: appId,
      ttAppId: ttAppId,
      openDebug: kDebugMode,
      enableAutoIapTrack: true,
    );
    debugPrint(
        'TikTok Business SDK initialized successfully [${isIos ? "iOS" : "Android"}]');
  } catch (e) {
    debugPrint('TikTok Business SDK init error: $e');
  }
}

void _scheduleDeferredBootstrap() {
  SchedulerBinding.instance.addPostFrameCallback((_) {
    unawaited(Future<void>(() async {
      try {
        PlatformDispatcher.instance.onError = (error, stackTrace) {
          final mappedError = AppErrorMapper.resolve(
            error,
            fallbackMessage: 'Lỗi nền hệ thống.',
          );
          unawaited(ErrorLoggerService.instance.logError(
            error,
            stackTrace,
            reason: 'platform_dispatcher',
            fatal: true,
          ));
          unawaited(
            RevenueSecurityTelemetryService.instance.logSystemEvent(
              type: 'platform_dispatcher_error',
              reason: mappedError.message,
            ),
          );
          return true;
        };
        await Future.wait([
          _initializeDeferredFirebaseAppCheck(),
          _purgeDeprecatedSecretsDeferred(),
          _warmUpOfflineCache(),
          _warmUpLocalDatabase(),
          _warmUpWidgetService(),
          _requestIosTrackingAuthorization(),
        ]);
        unawaited(_warmUpBackgroundServices());
      } catch (error, stackTrace) {
        debugPrint('Deferred bootstrap error: ${AppErrorMapper.resolve(
          error,
          fallbackMessage: L10nService().translate('core_err_bg_task_failed'),
        ).message}');
        unawaited(ErrorLoggerService.instance.logError(
          error,
          stackTrace,
          reason: 'deferred_bootstrap_error',
          fatal: false,
        ));
      }
    }));
  });
}

Future<void> _initializeDeferredFirebaseAppCheck() async {
  if (!kIsWeb) return;
  await _initializeFirebaseAppCheck();
}

Future<void> _purgeDeprecatedSecretsDeferred() async {
  try {
    await _purgeDeprecatedSecrets();
  } catch (e) {
    debugPrint('Deprecated secrets cleanup error: ${AppErrorMapper.resolve(
      e,
      fallbackMessage: L10nService().translate('core_err_clean_secrets_failed'),
    ).message}');
  }
}

Future<void> _warmUpOfflineCache() async {
  try {
    await OfflineCacheService.initialize();
  } catch (e) {
    debugPrint('Prefs init error: ${AppErrorMapper.resolve(
      e,
      fallbackMessage: L10nService().translate('core_err_init_prefs_failed'),
    ).message}');
  }
}

Future<void> _warmUpLocalDatabase() async {
  try {
    await LocalDatabaseService().initialize();
  } catch (e) {
    debugPrint('LocalDB init error: ${AppErrorMapper.resolve(
      e,
      fallbackMessage: L10nService().translate('core_err_init_local_db_failed'),
    ).message}');
  }
}

Future<void> _warmUpWidgetService() async {
  if (kIsWeb) return;
  try {
    await WidgetService.ensureInitialized();
  } catch (e) {
    debugPrint('Widget bootstrap error: ${AppErrorMapper.resolve(
      e,
      fallbackMessage: L10nService().translate('core_err_init_widget_failed'),
    ).message}');
  }
}

Future<void> _warmUpBackgroundServices() async {
  unawaited(_runBackgroundWarmUpTask(
    'Music init error',
    () => MusicService().init(),
  ));
  unawaited(_runBackgroundWarmUpTask(
    'Connectivity init error',
    () => ConnectivityService().initialize(),
  ));
  unawaited(_runBackgroundWarmUpTask(
    'Security warm-up error',
    () => SecurityService().isProxyOrVpnActive(),
  ));
}

Future<void> _runBackgroundWarmUpTask(
  String label,
  Future<void> Function() task,
) async {
  try {
    await task();
  } catch (e) {
    debugPrint('$label: ${AppErrorMapper.resolve(
      e,
      fallbackMessage: 'Không thể chạy tác vụ khởi động nền.',
    ).message}');
  }
}

void _configureRenderingDefaults() {
  final imageCache = PaintingBinding.instance.imageCache;
  if (kIsWeb) {
    imageCache.maximumSize = 120;
    imageCache.maximumSizeBytes = 64 << 20;
  } else {
    imageCache.maximumSize = 220;
    imageCache.maximumSizeBytes = 128 << 20;
  }
  SchedulerBinding.instance.scheduleWarmUpFrame();
}

class _MissingBootstrapConfig implements Exception {
  final List<String> missingKeys;

  const _MissingBootstrapConfig(this.missingKeys);
}

void _throwIfFirebaseEnvMissing() {
  final missingKeys = _missingFirebaseBootstrapKeys();
  if (missingKeys.isNotEmpty) {
    throw _MissingBootstrapConfig(missingKeys);
  }
}

List<String> _missingFirebaseBootstrapKeys() {
  if (!kIsWeb && kDebugMode) return [];

  final entries = <String, String>{
    'FIREBASE_API_KEY': AppConfig.firebaseApiKey,
    'FIREBASE_AUTH_DOMAIN': AppConfig.firebaseAuthDomain,
    'FIREBASE_DATABASE_URL': AppConfig.firebaseDatabaseUrl,
    'FIREBASE_PROJECT_ID': AppConfig.firebaseProjectId,
    'FIREBASE_STORAGE_BUCKET': AppConfig.firebaseStorageBucket,
    'FIREBASE_MESSAGING_SENDER_ID': AppConfig.firebaseMessagingSenderId,
    'FIREBASE_APP_ID': AppConfig.firebaseAppId,
  };

  final placeholderByKey = <String, Set<String>>{
    'FIREBASE_API_KEY': {'your-firebase-api-key'},
    'FIREBASE_AUTH_DOMAIN': {'your-project.firebaseapp.com'},
    'FIREBASE_DATABASE_URL': {
      'https://your-project-default-rtdb.firebaseio.com'
    },
    'FIREBASE_PROJECT_ID': {'your-project-id'},
    'FIREBASE_STORAGE_BUCKET': {'your-project.appspot.com'},
    'FIREBASE_MESSAGING_SENDER_ID': {'123456789000'},
    'FIREBASE_APP_ID': {'1:123456789000:web:abcdef1234567890'},
  };

  return entries.entries
      .where((entry) {
        final value = entry.value.trim();
        if (value.isEmpty) return true;
        final placeholders = placeholderByKey[entry.key];
        return placeholders != null && placeholders.contains(value);
      })
      .map((entry) => entry.key)
      .toList();
}
