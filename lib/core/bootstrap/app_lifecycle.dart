import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:soullocket_app/core/bootstrap/app_bootstrap.dart';
import 'package:soullocket_app/utils/app_error_mapper.dart';
import 'package:soullocket_app/utils/services/connectivity_service.dart';
import 'package:soullocket_app/utils/services/error_logger_service.dart';
import 'package:soullocket_app/utils/services/infrastructure/storage_service.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';
import 'package:soullocket_app/utils/services/local_database_service.dart';
import 'package:soullocket_app/utils/services/music_service.dart';
import 'package:soullocket_app/utils/services/offline_cache_service.dart';
import 'package:soullocket_app/utils/services/revenue_security_telemetry_service.dart';
import 'package:soullocket_app/utils/services/security_service.dart';
import 'package:soullocket_app/utils/services/widget_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// System UI
// ─────────────────────────────────────────────────────────────────────────────

Future<void> configureSystemUiForEdgeToEdge() async {
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

void configureRenderingDefaults() {
  final imageCache = PaintingBinding.instance.imageCache;
  if (kIsWeb) {
    imageCache.maximumSize = 100;
    imageCache.maximumSizeBytes = 80 << 20; // 80 MB
  } else if (defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS) {
    // iOS: giới hạn thấp để tránh bị hệ thống kill vì dùng quá nhiều RAM (tránh OOM Crash)
    imageCache.maximumSize = 100;
    imageCache.maximumSizeBytes = 50 << 20; // Giảm từ 150MB xuống 50MB
  } else {
    // Android: Giảm từ 256MB xuống 80MB để tránh tràn RAM khi lướt nhiều ảnh
    imageCache.maximumSize = 150;
    imageCache.maximumSizeBytes = 80 << 20; // 80 MB
  }
  SchedulerBinding.instance.scheduleWarmUpFrame();
}

// ─────────────────────────────────────────────────────────────────────────────
// Secret & Auth cleanup
// ─────────────────────────────────────────────────────────────────────────────

Future<void> purgeDeprecatedSecrets() async {
  await OfflineCacheService.initialize();
  final prefs = OfflineCacheService.getPrefsSync()!;
  await prefs.remove('gemini_api_key');
  try {
    const secureStorage = FlutterSecureStorage();
    await secureStorage.delete(key: 'gemini_api_key');
  } catch (error) {
    debugPrint('Không thể xóa Gemini key cũ khỏi secure storage: $error');
  }
}

Future<void> clearStaleIosAuthAfterFreshInstall() async {
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
      unawaited(
        FirebaseDatabase.instance
            .ref('debugFreshInstallCleanup/${staleUser.uid}')
            .push()
            .set({
              'platform': defaultTargetPlatform.name,
              'hasLocalAppState': hasLocalAppState,
              'hasStaleAuth': hasStaleAuth,
              'didSignOut': shouldSignOut,
              'localKeyCount': prefs.getKeys().length,
              'createdAtMs': DateTime.now().millisecondsSinceEpoch,
            }),
      );
    } catch (e) {
      debugPrint(
        'Fresh install cleanup log skipped: ${AppErrorMapper.resolve(e, fallbackMessage: L10nService().translate('core_err_log_fresh_install_failed')).message}',
      );
    }
  }

  if (shouldSignOut) {
    await FirebaseAuth.instance.signOut();
    try {
      const secureStorage = FlutterSecureStorage();
      await secureStorage.deleteAll();
    } catch (error) {
      debugPrint('Không thể xóa secure storage sau fresh install: $error');
    }
  }

  await prefs.setBool(installMarkerKey, true);
}

// ─────────────────────────────────────────────────────────────────────────────
// Deferred Bootstrap (chạy sau khi UI đã hiển thị)
// ─────────────────────────────────────────────────────────────────────────────

void scheduleDeferredBootstrap() {
  SchedulerBinding.instance.addPostFrameCallback((_) {
    unawaited(
      Future<void>(() async {
        try {
          PlatformDispatcher.instance.onError = (error, stackTrace) {
            final mappedError = AppErrorMapper.resolve(
              error,
              fallbackMessage: 'Lỗi nền hệ thống.',
            );
            unawaited(
              ErrorLoggerService.instance.logError(
                error,
                stackTrace,
                reason: 'platform_dispatcher',
                fatal: true,
              ),
            );
            unawaited(
              RevenueSecurityTelemetryService.instance.logSystemEvent(
                type: 'platform_dispatcher_error',
                reason: mappedError.message,
              ),
            );
            return true;
          };
          await Future.wait([
            initializeDeferredFirebaseAppCheck(),
            _purgeDeprecatedSecretsDeferred(),
            _warmUpOfflineCache(),
            _warmUpLocalDatabase(),
            _warmUpWidgetService(),
            _warmUpGoogleFonts(),
            StorageService.instance.purgeStaleCache(),
          ]);
          unawaited(_warmUpBackgroundServices());

          // Delay heavy SDK initializations to ensure smooth first frames
          unawaited(
            Future.delayed(const Duration(seconds: 3), () {
              unawaited(_initializeGoogleMobileAds());
              unawaited(_requestIosTrackingAuthorization());
            }),
          );
        } catch (error, stackTrace) {
          debugPrint(
            'Deferred bootstrap error: ${AppErrorMapper.resolve(error, fallbackMessage: L10nService().translate('core_err_bg_task_failed')).message}',
          );
          unawaited(
            ErrorLoggerService.instance.logError(
              error,
              stackTrace,
              reason: 'deferred_bootstrap_error',
              fatal: false,
            ),
          );
        }
      }),
    );
  });
}

Future<void> _purgeDeprecatedSecretsDeferred() async {
  try {
    await purgeDeprecatedSecrets();
  } catch (e) {
    debugPrint(
      'Deprecated secrets cleanup error: ${AppErrorMapper.resolve(e, fallbackMessage: L10nService().translate('core_err_clean_secrets_failed')).message}',
    );
  }
}

Future<void> _warmUpGoogleFonts() async {
  try {
    await GoogleFonts.pendingFonts([
      GoogleFonts.quicksand(),
      GoogleFonts.dancingScript(),
      GoogleFonts.caveat(),
      GoogleFonts.nunito(),
    ]);
  } catch (e) {
    debugPrint('GoogleFonts pre-warm info: $e');
  }
}

Future<void> _warmUpOfflineCache() async {
  try {
    await OfflineCacheService.initialize();
  } catch (e) {
    debugPrint(
      'Prefs init error: ${AppErrorMapper.resolve(e, fallbackMessage: L10nService().translate('core_err_init_prefs_failed')).message}',
    );
  }
}

Future<void> _warmUpLocalDatabase() async {
  try {
    await LocalDatabaseService().initialize();
  } catch (e) {
    debugPrint(
      'LocalDB init error: ${AppErrorMapper.resolve(e, fallbackMessage: L10nService().translate('core_err_init_local_db_failed')).message}',
    );
  }
}

Future<void> _warmUpWidgetService() async {
  if (kIsWeb) return;
  try {
    await WidgetService.ensureInitialized();
  } catch (e) {
    debugPrint(
      'Widget bootstrap error: ${AppErrorMapper.resolve(e, fallbackMessage: L10nService().translate('core_err_init_widget_failed')).message}',
    );
  }
}

Future<void> _warmUpBackgroundServices() async {
  unawaited(
    _runBackgroundWarmUpTask('Music init error', () => MusicService().init()),
  );
  unawaited(
    _runBackgroundWarmUpTask(
      'Connectivity init error',
      () => ConnectivityService().initialize(),
    ),
  );
  unawaited(
    _runBackgroundWarmUpTask(
      'Security warm-up error',
      () => SecurityService().isProxyOrVpnActive(),
    ),
  );
}

Future<void> _runBackgroundWarmUpTask(
  String label,
  Future<void> Function() task,
) async {
  try {
    await task();
  } catch (e) {
    debugPrint(
      '$label: ${AppErrorMapper.resolve(e, fallbackMessage: 'Không thể chạy tác vụ khởi động nền.').message}',
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SDK Initializations (chạy deferred)
// ─────────────────────────────────────────────────────────────────────────────

Future<void> _initializeGoogleMobileAds() async {
  if (kIsWeb) {
    return;
  }

  try {
    await MobileAds.instance.initialize();
    debugPrint('Google Mobile Ads initialized successfully');
  } catch (e) {
    debugPrint(
      'Google Mobile Ads init error: ${AppErrorMapper.resolve(e, fallbackMessage: 'Could not initialize Google Mobile Ads').message}',
    );
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
