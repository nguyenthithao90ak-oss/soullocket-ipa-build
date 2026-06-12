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

    // Pass all uncaught "fatal" errors from the framework to Crashlytics
    FlutterError.onError = (errorDetails) {
      final errStr = errorDetails.exception.toString().toLowerCase();
      if (errStr.contains('unable to load asset') || errStr.contains('không thể tải')) {
        debugPrint('Ignored fatal asset error in ErrorLoggerService: $errStr');
        return;
      }
      FirebaseCrashlytics.instance.recordFlutterFatalError(errorDetails);
    };

    // Pass all uncaught asynchronous errors that aren't handled by the Flutter framework to Crashlytics
    PlatformDispatcher.instance.onError = (error, stack) {
      final errStr = error.toString().toLowerCase();
      if (errStr.contains('unable to load asset') || errStr.contains('không thể tải')) {
        debugPrint('Ignored async asset error in ErrorLoggerService: $errStr');
        return true;
      }
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };

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
