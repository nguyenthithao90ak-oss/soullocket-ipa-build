import 'dart:async';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

import 'package:soullocket_app/utils/app_error_mapper.dart';
import 'consent_service.dart';

class ErrorLoggerService {
  static final ErrorLoggerService instance = ErrorLoggerService._internal();

  ErrorLoggerService._internal();

  bool _collectionEnabled = false;
  bool get _canRecord =>
      !kIsWeb &&
      !kDebugMode &&
      _collectionEnabled &&
      ConsentService.optionalCollectionAllowed.value;

  Future<void> initialize() async {
    await setCollectionAllowed(ConsentService.optionalCollectionAllowed.value);
  }

  Future<void> setCollectionAllowed(bool allowed) async {
    _collectionEnabled = false;
    if (kIsWeb) return;
    final sdk = FirebaseCrashlytics.instance;
    await sdk.setCrashlyticsCollectionEnabled(false);
    // Không gửi báo cáo native đã lưu trong thời gian chưa đồng ý.
    await sdk.deleteUnsentReports();
    if (allowed &&
        !kDebugMode &&
        ConsentService.optionalCollectionAllowed.value) {
      await sdk.setCrashlyticsCollectionEnabled(true);
      _collectionEnabled = ConsentService.optionalCollectionAllowed.value;
    } else {
      await sdk.setUserIdentifier('');
    }
  }

  Future<void> logError(
    dynamic error,
    StackTrace? stack, {
    String? reason,
    bool fatal = false,
  }) async {
    if (!_canRecord) return;
    if (kIsWeb) {
      debugPrint(
        'Crashlytics logging skipped on Web: ${AppErrorMapper.resolve(error).message}',
      );
      return;
    }
    final errStr = error.toString().toLowerCase();
    if (errStr.contains('unable to load asset') ||
        errStr.contains('không thể tải')) {
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
    if (!_canRecord) return;
    await FirebaseCrashlytics.instance.setUserIdentifier(userId);
  }

  Future<void> log(String message) async {
    if (!_canRecord) return;
    await FirebaseCrashlytics.instance.log(message);
  }

  Future<void> setCustomKey(String key, dynamic value) async {
    if (!_canRecord) return;
    await FirebaseCrashlytics.instance.setCustomKey(key, value);
  }
}
