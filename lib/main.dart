import 'dart:async';
import 'package:soullocket_app/app.dart';
import 'package:soullocket_app/core/sl_theme.dart';
import 'package:soullocket_app/utils/build_signature_service.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:tiktok_business_sdk/tiktok_business_sdk.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:soullocket_app/utils/services/secure_storage_service.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';

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
import 'package:soullocket_app/views/home/widgets/floating_bubble_widget.dart';
import 'package:soullocket_app/utils/services/performance_profile_service.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('Handling background message: ${message.messageId ?? 'unknown'}');
  try {
    if (Firebase.apps.isEmpty) {
      await _initializeFirebaseBootstrap();
    }
    FirebaseDatabase.instance.setPersistenceEnabled(true);

    // Hiển thị bong bóng tâm hồn / chat nếu app ở background
    final type = message.data['type']?.toString() ?? '';
    final screen = message.data['screen']?.toString() ?? '';
    if (type == 'soul_merge' ||
        screen == 'soul_merge' ||
        type == 'chat' ||
        screen == 'chat') {
      try {
        final granted = await FlutterOverlayWindow.isPermissionGranted();
        if (granted) {
          final active = await FlutterOverlayWindow.isActive();
          if (!active) {
            await FlutterOverlayWindow.showOverlay(
              enableDrag: true,
              height: 80,
              width: 80,
              alignment: OverlayAlignment.centerRight,
              overlayTitle: 'Bong bóng tâm hồn',
              overlayContent: 'Lời thì thầm đang kết nối...',
            );
          }
        }
      } catch (e) {
        debugPrint('Error showing overlay in background: $e');
      }
    }
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

/// Build signature verification đã chuyển sang BuildSignatureService (lib/utils/build_signature_service.dart)

const MethodChannel _bootstrapChannel = MethodChannel('soul_locket/bootstrap');

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
      unawaited(FirebaseDatabase.instance
          .ref('debugFreshInstallCleanup/${staleUser.uid}')
          .push()
          .set({
        'platform': defaultTargetPlatform.name,
        'hasLocalAppState': hasLocalAppState,
        'hasStaleAuth': hasStaleAuth,
        'didSignOut': shouldSignOut,
        'localKeyCount': prefs.getKeys().length,
        'createdAtMs': DateTime.now().millisecondsSinceEpoch,
      }));
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

@pragma('vm:entry-point')
void overlayMain() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await _initializeFirebaseBootstrap();
  } catch (e) {
    debugPrint('[Overlay] Firebase init error: $e');
  }

  String? houseId;
  String? role;
  String? partnerName;
  try {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/overlay_sync.json');
      if (await file.exists()) {
        final data = jsonDecode(await file.readAsString());
        houseId = data['houseId']?.toString();
        role = data['role']?.toString();
        partnerName = data['partnerName']?.toString();
      }
    } catch (_) {}

    if (houseId == null || houseId.isEmpty) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload(); // Đảm bảo lấy dữ liệu mới nhất từ isolate chính
      houseId =
          prefs.getString('overlay_house_id') ?? prefs.getString('il_house_id');
      role = prefs.getString('overlay_role') ??
          prefs.getString('il_role') ??
          'user1';
      partnerName = prefs.getString('overlay_partner_name');
    }

    if (houseId == null || houseId.isEmpty) {
      try {
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid != null) {
          final snap = await FirebaseDatabase.instance.ref('users/$uid').get();
          final userData = snap.value as Map?;
          if (userData != null) {
            houseId = userData['houseId']?.toString();
            role = userData['role']?.toString() ?? 'user1';
          }
        }
      } catch (e) {
        debugPrint('[Overlay] Fallback Firebase fetch error: $e');
      }
    }

    if (partnerName == null || partnerName.isEmpty) {
      // Đọc tên partner từ settings nếu có
      try {
        final houseIdLocal = houseId;
        if (houseIdLocal != null && houseIdLocal.isNotEmpty) {
          final snap = await FirebaseDatabase.instance
              .ref('houses/$houseIdLocal/settings')
              .child(role == 'user2' ? 'nameU1' : 'nameU2')
              .get();
          partnerName = snap.value?.toString();
        }
      } catch (_) {}
    }
  } catch (e) {
    debugPrint('[Overlay] prefs read error: $e');
  }

  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: FloatingBubbleWidget(
        initialHouseId: houseId,
        initialRole: role ?? 'user1',
        initialPartnerName: partnerName ?? 'Người ấy',
      ),
    ),
  );
}

@pragma('vm:entry-point')
void main() {
  runZonedGuarded(() async {
    final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
    FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
    _configureRenderingDefaults();
    await _configureSystemUiForEdgeToEdge();
    GoogleFonts.config.allowRuntimeFetching = true;

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

    ErrorWidget.builder = (FlutterErrorDetails details) {
      return Container(
        color: SLColors.bgMain,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.favorite,
              color: SLColors.primary,
              size: 44,
            ),
            const SizedBox(height: 12),
            Text(
              'Có lỗi nhỏ xảy ra. Hãy thử lại sau nhé!',
              textAlign: TextAlign.center,
              style: GoogleFonts.quicksand(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: SLColors.textPrimary,
                decoration: TextDecoration.none,
              ),
            ),
          ],
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
      await UiPrefs.ensureLoaded();
      await L10nService().init();

      await BuildSignatureService.verifyOfficialBuildSignature();
      await _initializeFirebaseBootstrap();
      await _clearStaleIosAuthAfterFreshInstall();

      if (!kIsWeb) {
        FirebaseMessaging.onBackgroundMessage(
            _firebaseMessagingBackgroundHandler);
      }

      await PerformanceProfileService.instance.initialize();
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
    } on UnofficialBuildDetected catch (error) {
      if (!kIsWeb) {
        FlutterNativeSplash.remove();
      }
      runApp(StartupErrorApp(
        title: L10nService().translate('core_err_invalid_install_title'),
        message: L10nService().translate('core_err_official_release_only'),
        details: BuildSignatureService.detailsForError(error),
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
      // ⚡ Increased from 5MB → 40MB to significantly improve offline chat/diary caching and reduce bandwidth
      FirebaseDatabase.instance.setPersistenceCacheSizeBytes(41943040);
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

    unawaited(_initializeFirebaseAppCheck());
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
      .timeout(const Duration(seconds: 3));
}

Future<void> _initializeDefaultNativeFirebaseApp() async {
  const attemptTimeouts = <Duration>[
    Duration(seconds: 2),
    Duration(seconds: 4),
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
    if (kDebugMode) {
      try {
        const debugToken = '8a3fcdfe-ea37-49f1-baf9-279463826649';
        await SecureStorageService.instance
            .write('appcheck_debug_token', debugToken);
        // Also write to SharedPreferences for AppCheck native plugin
        await SharedPreferences.getInstance().then((prefs) => prefs.setString(
            'com.google.firebase.appcheck.debug.DebugAppCheckProvider.SECRET_KEY',
            debugToken));
      } catch (_) {}
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

Future<void> _initializeGoogleMobileAds() async {
  if (kIsWeb) {
    return;
  }

  try {
    await MobileAds.instance.initialize();
    debugPrint('Google Mobile Ads initialized successfully');
  } catch (e) {
    debugPrint('Google Mobile Ads init error: ${AppErrorMapper.resolve(
      e,
      fallbackMessage: 'Could not initialize Google Mobile Ads',
    ).message}');
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
        ]);
        unawaited(_warmUpBackgroundServices());
        unawaited(_initializeGoogleMobileAds());
        unawaited(_requestIosTrackingAuthorization());
        unawaited(_initializeTikTokSdk());
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
    imageCache.maximumSize = 180;
    imageCache.maximumSizeBytes = 120 << 20; // 120 MB
  } else {
    imageCache.maximumSize = 400;
    imageCache.maximumSizeBytes = 256 << 20; // 256 MB
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
