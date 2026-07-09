import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';

import 'package:soullocket_app/utils/app_error_mapper.dart';

class StorageAppCheckHelper {
  const StorageAppCheckHelper();

  static const Duration retryDelay = Duration(milliseconds: 350);
  static const Duration _warmUpFailureCooldown = Duration(minutes: 5);
  static DateTime? _warmUpRetryAfter;
  static bool _warmUpCooldownLogged = false;

  bool isAppCheckFailure(
    FirebaseFunctionsException error, {
    bool allowUnauthenticatedWithoutMarkers = false,
  }) {
    final code = error.code.trim().toLowerCase();
    final isPossibleAppCheckCode = code == 'failed-precondition' ||
        code == 'permission-denied' ||
        code == 'unauthenticated';
    if (!isPossibleAppCheckCode) {
      return false;
    }

    final message =
        '${error.message ?? ''} ${error.details ?? ''}'.trim().toLowerCase();

    const appCheckMarkers = <String>[
      'app check',
      'appcheck',
      'debug token',
      'play integrity',
      'attestation',
      'firebase app check api',
      'x-firebase-appcheck',
      'recaptcha',
      'app attest',
      'device check',
      'missing appcheck token',
      'invalid appcheck token',
    ];
    final hasAppCheckMarker = appCheckMarkers.any(message.contains);
    if (hasAppCheckMarker) {
      return true;
    }

    if (!allowUnauthenticatedWithoutMarkers || code != 'unauthenticated') {
      return false;
    }

    const authRequiredMarkers = <String>[
      'user must be authenticated',
      'must be authenticated',
      'requires authentication',
      'requires login',
      'requires sign in',
      'dang nhap',
      'đăng nhập',
      'sign in again',
      'login again',
    ];
    return !authRequiredMarkers.any(message.contains);
  }

  Future<bool> warmUp({bool forceRefresh = false}) async {
    final retryAfter = _warmUpRetryAfter;
    if (retryAfter != null && DateTime.now().isBefore(retryAfter)) {
      return false;
    }

    try {
      final token = await FirebaseAppCheck.instance.getToken(forceRefresh);
      final hasToken = (token ?? '').trim().isNotEmpty;
      if (hasToken) {
        _warmUpRetryAfter = null;
        _warmUpCooldownLogged = false;
      }
      return hasToken;
    } catch (error) {
      if (_shouldCooldownAfter(error)) {
        _warmUpRetryAfter = DateTime.now().add(_warmUpFailureCooldown);
        if (kDebugMode && !_warmUpCooldownLogged) {
          _warmUpCooldownLogged = true;
          debugPrint(
            'StorageService App Check warm-up paused for '
            '${_warmUpFailureCooldown.inMinutes}m: ${AppErrorMapper.resolve(
              error,
              fallbackMessage: 'Không thể khởi động App Check.',
            ).message}',
          );
        }
        return false;
      }

      if (kDebugMode) {
        debugPrint(
            'StorageService App Check warm-up failed: ${AppErrorMapper.resolve(
          error,
          fallbackMessage: 'Không thể khởi động App Check.',
        ).message}');
      }
    }
    return false;
  }

  Future<T> callWithRetry<T>(
    Future<T> Function() action, {
    bool allowUnauthenticatedWithoutMarkers = false,
  }) async {
    await warmUp();
    try {
      return await action();
    } on FirebaseFunctionsException catch (error) {
      if (!isAppCheckFailure(
        error,
        allowUnauthenticatedWithoutMarkers: allowUnauthenticatedWithoutMarkers,
      )) {
        rethrow;
      }

      final refreshed = await warmUp(forceRefresh: true);
      if (refreshed) {
        await Future<void>.delayed(retryDelay);
      }
      return await action();
    }
  }

  static bool _shouldCooldownAfter(Object error) {
    final message = error.toString().toLowerCase();
    return message.contains('too many attempts') ||
        message.contains('app attestation failed') ||
        message.contains('code: 403');
  }
}
