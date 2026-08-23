import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:soullocket_app/app.dart';
import 'package:soullocket_app/core/bootstrap/app_bootstrap.dart';
import 'package:soullocket_app/core/bootstrap/app_lifecycle.dart';
import 'package:soullocket_app/core/bootstrap/background_handlers.dart';
import 'package:soullocket_app/core/service_locator.dart';
import 'package:soullocket_app/utils/app_error_mapper.dart';
import 'package:soullocket_app/utils/build_signature_service.dart';
import 'package:soullocket_app/utils/services/core/background_tracking_service.dart';
import 'package:soullocket_app/utils/services/error_logger_service.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';
import 'package:soullocket_app/utils/services/offline_cache_service.dart';
import 'package:soullocket_app/utils/services/performance_profile_service.dart';
import 'package:soullocket_app/utils/services/revenue_security_telemetry_service.dart';
import 'package:soullocket_app/views/ui_prefs.dart';
import 'package:soullocket_app/services/remote_config_service.dart';

// Re-export các entry-point cần @pragma('vm:entry-point')
export 'package:soullocket_app/core/bootstrap/background_handlers.dart'
    show firebaseMessagingBackgroundHandler, overlayMain;

// ─────────────────────────────────────────────────────────────────────────────
// App entry point
// ─────────────────────────────────────────────────────────────────────────────

@pragma('vm:entry-point')
void main() {
  runZonedGuarded(() async {
    final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();

    // Tắt toàn bộ debugPrint trong bản Release để tránh rò rỉ log
    if (!kDebugMode) {
      debugPrint = (String? message, {int? wrapWidth}) {};
    }

    await Hive.initFlutter();
    unawaited(OfflineSyncQueue.instance.startListening());
    setupLocator();
    FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
    configureRenderingDefaults();
    await configureSystemUiForEdgeToEdge();
    GoogleFonts.config.allowRuntimeFetching = true;

    // Giữ dọc trên mobile; riêng macOS không khóa để cho phép xoay/ngang
    if (!kIsWeb && defaultTargetPlatform != TargetPlatform.macOS) {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
    }

    // ── Global error handlers ──────────────────────────────────────────────
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

    ErrorWidget.builder = buildDefaultErrorWidget;

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

    // ── Splash safety fallback (3s max) ───────────────────────────────────
    if (!kIsWeb) {
      Future.delayed(const Duration(seconds: 3), () {
        try {
          FlutterNativeSplash.remove();
        } catch (_) {}
      });
    }

    // ── Bootstrap ─────────────────────────────────────────────────────────
    try {
      await UiPrefs.ensureLoaded();
      await L10nService().init();

      try {
        await initializeFirebaseBootstrap()
            .timeout(const Duration(seconds: 3));
      } catch (e) {
        debugPrint('Firebase bootstrap timeout or error: $e');
      }
      
      try {
        await RemoteConfigService().initialize();
      } catch (e) {
        debugPrint('RemoteConfig init error: $e');
      }

      if (!kIsWeb) {
        try {
          FirebaseMessaging.onBackgroundMessage(
              firebaseMessagingBackgroundHandler);
        } catch (_) {}
      }

      runApp(const MyApp());
      scheduleDeferredBootstrap();

      // Tác vụ không chặn UI – chạy sau 500ms
      unawaited(
          Future<void>.delayed(const Duration(milliseconds: 500), () async {
        await BuildSignatureService.verifyOfficialBuildSignature();
        await clearStaleIosAuthAfterFreshInstall();
        if (!kIsWeb) {
          try {
            await BackgroundTrackingService.initialize();
          } catch (e) {
            debugPrint('Error initializing background tracking: $e');
          }
        }
        await PerformanceProfileService.instance.initialize();
      }));
    } on MissingBootstrapConfig {
      if (!kIsWeb) FlutterNativeSplash.remove();
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
      if (!kIsWeb) FlutterNativeSplash.remove();
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
          extra: {'mappedMessage': bootstrapError.message},
        ),
      );
      if (!kIsWeb) FlutterNativeSplash.remove();
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
  }, handleZoneError);
}
