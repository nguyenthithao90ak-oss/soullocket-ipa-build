import 'dart:async';

import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:soullocket_app/core/constants/app_config.dart';
import 'package:soullocket_app/core/sl_theme.dart';
import 'package:soullocket_app/services/connectivity_service.dart';
import 'package:soullocket_app/services/l10n_service.dart';
import 'package:soullocket_app/services/local_database_service.dart';
import 'package:soullocket_app/services/music_service.dart';
import 'package:soullocket_app/services/notification_service.dart';
import 'package:soullocket_app/services/offline_cache_service.dart';
import 'package:soullocket_app/services/security_service.dart';
import 'package:soullocket_app/services/widget_service.dart';
import 'package:soullocket_app/utils/app_error_mapper.dart';
import 'package:soullocket_app/utils/services/error_logger_service.dart';
import 'package:soullocket_app/utils/services/revenue_security_telemetry_service.dart';
import 'package:soullocket_app/views/app_entry.dart';
import 'package:soullocket_app/views/ui_prefs.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('Handling background message: ${message.messageId ?? 'unknown'}');
  try {
    if (Firebase.apps.isEmpty) {
      await _initializeFirebaseBootstrap();
    }
    FirebaseDatabase.instance.setPersistenceEnabled(true);
  } catch (error, stackTrace) {
    debugPrint('FCM background bootstrap error: $error');
    debugPrintStack(stackTrace: stackTrace);
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
  final status = (raw?['status'] as String? ?? 'package_info_unavailable').trim();
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
      return 'Bản cài đặt này không khớp chữ ký phát hành chính thức.';
    case 'package_info_unavailable':
      return 'Ứng dụng không xác minh được chữ ký cài đặt trên thiết bị này.';
    default:
      return 'Ứng dụng phát hiện bản cài đặt hiện tại không đáng tin cậy.';
  }
}

List<String> _detailsForSignatureStatus(_UnofficialBuildDetected error) {
  return [
    _messageForSignatureStatus(error.status),
    'Hãy gỡ bản hiện tại và cài lại từ nguồn phát hành chính thức của bạn.',
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

Future<void> _configureSystemUiForEdgeToEdge() async {
  if (kIsWeb) {
    return;
  }

  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  if (defaultTargetPlatform == TargetPlatform.iOS) {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );
  }
}

void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    _configureRenderingDefaults();
    await _configureSystemUiForEdgeToEdge();
    GoogleFonts.config.allowRuntimeFetching = !kIsWeb;
    if (!kIsWeb) {
      // Không preserve splash screen nữa để app vào thẳng LoadingScaffold
      // FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
    }

    // Giữ dọc trên mobile; riêng macOS không khóa để cho phép xoay/ngang.
    if (!kIsWeb && defaultTargetPlatform != TargetPlatform.macOS) {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
    }

    FlutterError.onError = (details) {
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
      unawaited(ErrorLoggerService.instance.logError(
        error,
        stackTrace,
        reason: 'platform_dispatcher',
        fatal: true,
      ));
      unawaited(
        RevenueSecurityTelemetryService.instance.logSystemEvent(
          type: 'platform_dispatcher_error',
          reason: error.toString(),
          extra: {
            'stack': stackTrace.toString().split('\n').take(8).join('\n'),
          },
        ),
      );
      return true;
    };

    try {
      await _verifyOfficialBuildSignature();
      await _initializeFirebaseBootstrap();
      await _requestIosTrackingAuthorization();

      if (!kIsWeb) {
        FirebaseMessaging.onBackgroundMessage(
            _firebaseMessagingBackgroundHandler);
      }

      await UiPrefs.ensureLoaded();
      runApp(const MyApp());
      _scheduleDeferredBootstrap();
    } on _MissingBootstrapConfig catch (error) {
      if (!kIsWeb) {
        FlutterNativeSplash.remove();
      }
      runApp(StartupErrorApp(
        title: 'Thiếu cấu hình môi trường',
        message: kDebugMode
            ? 'Thiếu cấu hình môi trường bắt buộc.'
            : 'Ứng dụng chưa sẵn sàng để khởi động trên thiết bị này.',
        details: [
          if (kDebugMode)
            'Các biến chưa được truyền: ${error.missingKeys.join(', ')}',
          if (kDebugMode)
            'Hãy truyền cấu hình qua CI/CD hoặc --dart-define-from-file trước khi chạy lại.',
          if (!kDebugMode)
            'Hãy cập nhật ứng dụng hoặc cài lại bản mới nhất rồi thử lại.',
        ],
      ));
    } on _UnofficialBuildDetected catch (error) {
      if (!kIsWeb) {
        FlutterNativeSplash.remove();
      }
      runApp(StartupErrorApp(
        title: 'Bản cài đặt không hợp lệ',
        message: 'Ứng dụng chỉ cho phép chạy trên bản phát hành chính thức.',
        details: _detailsForSignatureStatus(error),
      ));
    } catch (error, stackTrace) {
      final bootstrapError = AppErrorMapper.resolve(
        error,
        fallbackMessage:
            'Không thể khởi động ứng dụng lúc này. Vui lòng thử lại sau.',
      );
      debugPrint('Bootstrap error: $error');
      debugPrintStack(stackTrace: stackTrace);
      unawaited(
        RevenueSecurityTelemetryService.instance.logSystemEvent(
          type: 'bootstrap_error',
          reason: error.toString(),
          extra: {
            'stack': stackTrace.toString().split('\n').take(8).join('\n'),
            'mappedMessage': bootstrapError.message,
          },
        ),
      );
      if (!kIsWeb) {
        FlutterNativeSplash.remove();
      }
      runApp(StartupErrorApp(
        title: bootstrapError.isNetworkError
            ? 'Lỗi kết nối khi khởi động'
            : 'Lỗi hệ thống khi khởi động',
        message: bootstrapError.isNetworkError
            ? 'Ứng dụng chưa thể khởi động vì kết nối mạng chưa ổn định.'
            : 'Ứng dụng chưa thể khởi động do lỗi hệ thống.',
        details: [
          bootstrapError.message,
          bootstrapError.isNetworkError
              ? 'Hãy kiểm tra Wi‑Fi hoặc dữ liệu di động rồi mở lại ứng dụng.'
              : 'Vui lòng thử lại sau. Nếu lỗi lặp lại, hãy liên hệ hỗ trợ.',
        ],
      ));
    }
  }, (error, stackTrace) {
    debugPrint('Uncaught zone error: $error');
    unawaited(ErrorLoggerService.instance.logError(
      error,
      stackTrace,
      reason: 'uncaught_zone_error',
      fatal: true,
    ));
    unawaited(
      RevenueSecurityTelemetryService.instance.logSystemEvent(
        type: 'uncaught_zone_error',
        reason: error.toString(),
        extra: {
          'stack': stackTrace.toString().split('\n').take(8).join('\n'),
        },
      ),
    );
  });
}

Future<void> _initializeFirebaseBootstrap() async {
  if (kIsWeb) {
    _throwIfFirebaseEnvMissing();
    await Firebase.initializeApp(options: _firebaseOptionsFromEnv())
        .timeout(const Duration(seconds: 8));
  } else {
    await _initializeNativeFirebaseBootstrap();
  }

  if (Firebase.apps.isEmpty) {
    throw StateError('Firebase chưa được khởi tạo.');
  }

  if (!kIsWeb) {
    try {
      FirebaseDatabase.instance.setPersistenceEnabled(true);
      // ⚡ Reduced from 10MB → 5MB to save RAM on startup
      FirebaseDatabase.instance.setPersistenceCacheSizeBytes(5000000);
    } catch (e) {
      debugPrint('Firebase persistence error: $e');
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
  } catch (nativeError, stackTrace) {
    debugPrint('Firebase native init error: $nativeError');
    debugPrintStack(stackTrace: stackTrace);
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
      debugPrint('Firebase native init attempt ${index + 1} failed: $error');
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
    debugPrint('Native Firebase options load error: $error');
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
    debugPrint('Firebase App Check init error: $e');
  }
}

Future<void> _requestIosTrackingAuthorization() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) {
    return;
  }

  // Temporary App Store submission guard for the current iPhone-only release.
  // This function is intentionally disabled so the submitted iOS build does not
  // request ATT permission while NSUserTrackingUsageDescription is removed.
  //
  // To restore the previous ATT + iPad-enabled behavior in a future release:
  // 1) In this file, remove the `return;` below and restore the ATT request
  //    block that uses AppTrackingTransparency.
  // 2) In ios/Runner/Info.plist, add NSUserTrackingUsageDescription back.
  // 3) In ios/Runner.xcodeproj/project.pbxproj, change every
  //    TARGETED_DEVICE_FAMILY = 1;
  //    back to:
  //    TARGETED_DEVICE_FAMILY = "1,2";
  // 4) Build and upload a new iOS binary, then update App Store Connect
  //    privacy answers/screenshots to match that restored behavior.
  return;

  // try {
  //   final status = await AppTrackingTransparency.trackingAuthorizationStatus;
  //   if (status == TrackingStatus.notDetermined) {
  //     await AppTrackingTransparency.requestTrackingAuthorization();
  //   }
  // } catch (e) {
  //   debugPrint('ATT request skipped: $e');
  // }
}

void _scheduleDeferredBootstrap() {
  SchedulerBinding.instance.addPostFrameCallback((_) {
    unawaited(Future<void>(() async {
      try {
        await Future.wait([
          _initializeDeferredFirebaseAppCheck(),
          _purgeDeprecatedSecretsDeferred(),
          _warmUpOfflineCache(),
          _warmUpLocalDatabase(),
          _warmUpWidgetService(),
        ]);
        unawaited(_warmUpBackgroundServices());
      } catch (error, stackTrace) {
        debugPrint('Deferred bootstrap error: $error');
        debugPrintStack(stackTrace: stackTrace);
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
    debugPrint('Deprecated secrets cleanup error: $e');
  }
}

Future<void> _warmUpOfflineCache() async {
  try {
    await OfflineCacheService.initialize();
  } catch (e) {
    debugPrint('Prefs init error: $e');
  }
}

Future<void> _warmUpLocalDatabase() async {
  try {
    await LocalDatabaseService().initialize();
  } catch (e) {
    debugPrint('LocalDB init error: $e');
  }
}

Future<void> _warmUpWidgetService() async {
  if (kIsWeb) return;
  try {
    await WidgetService.ensureInitialized();
  } catch (e) {
    debugPrint('Widget bootstrap error: $e');
  }
}

Future<void> _warmUpBackgroundServices() async {
  try {
    await L10nService().init();
  } catch (e) {
    debugPrint('L10n init error: $e');
  }

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
    debugPrint('$label: $e');
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

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final appStateListenable = Listenable.merge([
      L10nService(),
      UiPrefs.notifier,
    ]);
    final baseTextTheme = ThemeData(useMaterial3: true).textTheme;
    return ListenableBuilder(
      listenable: appStateListenable,
      builder: (context, _) {
        return MaterialApp(
          title: 'SoulLocket',
          navigatorKey: NotificationService.navigatorKey,
          locale: L10nService().locale,
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('vi', 'VN'),
            Locale('en', 'US'),
          ],
          scrollBehavior: const SoulLocketScrollBehavior(),
          themeAnimationDuration: const Duration(milliseconds: 160),
          themeAnimationCurve: Curves.easeOutCubic,
          builder: (context, child) {
            final mediaQuery = MediaQuery.of(context);
            final screenWidth = mediaQuery.size.width;
            final textScaler = SLResponsive.textScalerFor(context);
            final content = MediaQuery(
              data: mediaQuery.copyWith(textScaler: textScaler),
              child: L10nScope(
                notifier: L10nService(),
                child: child ?? const SizedBox.shrink(),
              ),
            );

            if (kIsWeb) {
              final maxWidth = SLResponsive.maxContentWidthForWidth(screenWidth);
              final outerPadding = SLResponsive.horizontalPaddingForWidth(screenWidth);
              return Container(
                color: const Color(0xFFFDFDFD),
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: outerPadding),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: maxWidth),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 30,
                              offset: const Offset(0, 0),
                            ),
                          ],
                        ),
                        child: RepaintBoundary(
                          child: ClipRect(child: content),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }
            return ColoredBox(
              color: SLColors.bgMain,
              child: content,
            );
          },
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: SLColors.primary,
              primary: SLColors.primary,
              secondary: SLColors.secondary,
              tertiary: SLColors.accentPurple,
              surface: SLColors.bgCard,
              surfaceContainerHighest: SLColors.bgSubtle,
              error: SLColors.danger,
            ),
            useMaterial3: true,
            scaffoldBackgroundColor: SLColors.bgMain,
            canvasColor: SLColors.bgMain,
            cardColor: SLColors.bgCard,
            dividerColor: SLColors.border,
            shadowColor: Colors.black.withOpacity(0.08),
            splashFactory: InkRipple.splashFactory,
                color: SLColors.textTertiary,
                fontWeight: FontWeight.w700,
              ),
              labelStyle: SLTheme.quicksand(
                color: SLColors.textSecond,
                fontWeight: FontWeight.w700,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: SLRadius.lgAll,
                borderSide: const BorderSide(color: SLColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: SLRadius.lgAll,
                borderSide:
                    const BorderSide(color: SLColors.primary, width: 1.6),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: SLRadius.lgAll,
                borderSide: const BorderSide(color: SLColors.danger),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: SLRadius.lgAll,
                borderSide:
                    const BorderSide(color: SLColors.danger, width: 1.6),
              ),
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                foregroundColor: SLColors.textInverse,
                backgroundColor: SLColors.primary,
                disabledForegroundColor: SLColors.textInverse.withOpacity(0.7),
                disabledBackgroundColor: SLColors.primary.withOpacity(0.45),
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 14,
                ),
                textStyle: SLTheme.quicksand(
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: SLRadius.pillAll,
                ),
              ),
            ),
            outlinedButtonTheme: OutlinedButtonThemeData(
              style: OutlinedButton.styleFrom(
                foregroundColor: SLColors.textPrimary,
                side: const BorderSide(color: SLColors.border),
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 14,
                ),
                textStyle: SLTheme.quicksand(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: SLRadius.pillAll,
                ),
              ),
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: SLColors.primary,
                textStyle: SLTheme.quicksand(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ),
            navigationBarTheme: NavigationBarThemeData(
              backgroundColor: SLColors.bgElevated.withOpacity(0.96),
              surfaceTintColor: Colors.transparent,
              indicatorColor: SLColors.primarySoft,
              labelTextStyle: WidgetStateProperty.resolveWith((states) {
                final selected = states.contains(WidgetState.selected);
                return SLTheme.quicksand(
                  fontSize: 11.5,
                  fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                  color: selected ? SLColors.textPrimary : SLColors.textSecond,
                );
              }),
            ),
            snackBarTheme: SnackBarThemeData(
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: SLRadius.lgAll),
              backgroundColor: SLColors.textPrimary,
              contentTextStyle: SLTheme.quicksand(
                color: SLColors.textInverse,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          debugShowCheckedModeBanner: false,
          home: const AppEntry(),
        );
      },
    );
  }
}

class StartupErrorApp extends StatelessWidget {
  final String title;
  final String message;
  final List<String> details;

  const StartupErrorApp({
    super.key,
    required this.title,
    required this.message,
    required this.details,
  });

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) {
      FlutterNativeSplash.remove();
    }
    return MaterialApp(
      scrollBehavior: const SoulLocketScrollBehavior(),
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: SLColors.bgSubtle,
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Padding(
              padding: SLSpacing.all24,
              child: Container(
                padding: SLSpacing.all24,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: const Color(0xFFFFD6E7)),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFB83280).withOpacity(0.08),
                      blurRadius: 24,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFE4F0),
                            borderRadius: SLRadius.lgAll,
                          ),
                          child: const Icon(
                            Icons.warning_amber_rounded,
                            color: Color(0xFFD81B60),
                            size: 32,
                          ),
                        ),
                        SLSpacing.w16,
                        Expanded(
                          child: Text(
                            title,
                            style: SLTheme.quicksand(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFF3A1330),
                            ),
                          ),
                        ),
                      ],
                    ),
                    SLSpacing.h16,
                    Text(
                      message,
                      style: SLTheme.quicksand(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF6B4A5D),
                        height: 1.5,
                      ),
                    ),
                    SLSpacing.h16,
                    ...details.map(
                      (detail) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(top: 6),
                              child: Icon(
                                Icons.circle,
                                size: 8,
                                color: Color(0xFFD81B60),
                              ),
                            ),
                            SLSpacing.w8,
                            Expanded(
                              child: Text(
                                detail,
                                style: SLTheme.quicksand(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF6B4A5D),
                                  height: 1.45,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SoulLocketScrollBehavior extends MaterialScrollBehavior {
  const SoulLocketScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => const {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.stylus,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.unknown,
      };

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    if (kIsWeb) {
      return const ClampingScrollPhysics(
        parent: RangeMaintainingScrollPhysics(),
      );
    }

    switch (getPlatform(context)) {
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        );
      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.windows:
        return const ClampingScrollPhysics(
          parent: RangeMaintainingScrollPhysics(),
        );
    }
  }
}
