import 'dart:async';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

import 'package:soullocket_app/utils/app_error_mapper.dart';

class ErrorLoggerService {
  static final ErrorLoggerService instance = ErrorLoggerService._internal();

  ErrorLoggerService._internal();

  Future<void> initialize() async {
    if (kDebugMode) {
      // In debug mode: disable Crashlytics entirely — do NOT attach error
      // handlers so the SDK never processes errors and shows no debug overlays.
      await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(false);
      return;
    }

    // NOTE: Error handlers are already set up in main.dart (FlutterError.onError &
    // PlatformDispatcher.instance.onError). Those handlers filter asset errors,
    // log via ErrorLoggerService.instance.logError() (which calls Crashlytics),
    // AND send to RevenueSecurityTelemetryService. We do NOT replace them here
    // to avoid losing the telemetry pipeline.
    //
    // We only enable Crashlytics collection so the main.dart error handlers'
    // calls to logError() actually get forwarded to Crashlytics.

    await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true);
  }

  Future<void> logError(dynamic error, StackTrace? stack, {String? reason, bool fatal = false}) async {
    final errStr = error.toString().toLowerCase();
    if (errStr.contains('unable to load asset') || errStr.contains('không thể tải')) {
      debugPrint('Ignored asset loading error from logger: $errStr');
      return;
    }
    debugPrint('Logging error: ${AppErrorMapper.resolve(error).message}');
    await FirebaseCrashlytics.instance.recordError(
      error,
      stack,
      reason: reason,
      fatal: fatal,
    );
  }

  Future<void> setUserId(String userId) async {
    await FirebaseCrashlytics.instance.setUserIdentifier(userId);
  }

  Future<void> log(String message) async {
    await FirebaseCrashlytics.instance.log(message);
  }

  Future<void> setCustomKey(String key, dynamic value) async {
    await FirebaseCrashlytics.instance.setCustomKey(key, value);
  }
}
