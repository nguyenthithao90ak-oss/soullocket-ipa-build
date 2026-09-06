import 'dart:async';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:soullocket_app/utils/app_error_mapper.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';

class CloudFunctionsHelper {
  static FirebaseFunctions? _functionsInstance;
  static const Duration _appCheckRetryDelay = Duration(milliseconds: 350);

  static FirebaseFunctions get _functions =>
      _functionsInstance ?? FirebaseFunctions.instance;

  @visibleForTesting
  static void setMockFunctions(FirebaseFunctions mock) {
    _functionsInstance = mock;
  }

  @visibleForTesting
  static bool isLikelyAppCheckFailure({
    required String code,
    required String message,
    required bool hasAuthenticatedUser,
    required bool authTokenRefreshSucceeded,
  }) {
    final normalizedCode = code.trim().toLowerCase();
    if (normalizedCode != 'failed-precondition' &&
        normalizedCode != 'permission-denied' &&
        normalizedCode != 'unauthenticated') {
      return false;
    }

    final normalizedMessage = message.toLowerCase();
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
    if (appCheckMarkers.any(normalizedMessage.contains)) {
      return true;
    }

    if (normalizedCode != 'unauthenticated' ||
        !hasAuthenticatedUser ||
        !authTokenRefreshSucceeded) {
      return false;
    }

    const authenticationMarkers = <String>[
      'user must be authenticated',
      'must be authenticated',
      'requires authentication',
      'requires login',
      'requires sign in',
      'đăng nhập',
      'sign in again',
      'login again',
    ];
    return !authenticationMarkers.any(normalizedMessage.contains);
  }

  static Future<bool> _warmUpAppCheck({bool forceRefresh = false}) async {
    try {
      final token = await FirebaseAppCheck.instance.getToken(forceRefresh);
      return (token ?? '').trim().isNotEmpty;
    } catch (error) {
      if (kDebugMode) {
        debugPrint(
          'CloudFunctionsHelper App Check warm-up failed: ${AppErrorMapper.resolve(error, fallbackMessage: L10nService().translate('core_err_appcheck_failed')).message}',
        );
      }
      return false;
    }
  }

  static Future<bool> _refreshAuthToken(User? user) async {
    if (user == null) {
      return false;
    }
    try {
      await user.getIdToken(true);
      return true;
    } catch (_) {
      return false;
    }
  }

  static String _appCheckMessage() => kDebugMode
      ? L10nService().translate('err_appcheck_debug_blocked')
      : L10nService().translate('err_appcheck_verifying_device');

  /// Gọi httpsCallable an toàn với bắt lỗi và timeout chuẩn.
  ///
  /// [functionName]: Tên Cloud Function
  /// [payload]: Data gửi lên
  /// [timeout]: Thời gian chờ tối đa
  /// [customErrorMessages]: Map các lỗi tuỳ chỉnh, ví dụ: {'permission-denied': 'Bạn không có quyền'}
  /// [fallbackErrorMessage]: Lỗi mặc định nếu không khớp với customErrorMessages
  static Future<HttpsCallableResult<T>> callSecure<T>(
    String functionName, {
    dynamic payload,
    Duration timeout = const Duration(seconds: 15),
    Map<String, String>? customErrorMessages,
    String? fallbackErrorMessage,
    bool throwOriginalException = false,
  }) async {
    try {
      final callable = _functions.httpsCallable(functionName);
      Future<HttpsCallableResult<T>> invoke() => callable
          .call<T>(payload)
          .timeout(
            timeout,
            onTimeout: () => throw TimeoutException('$functionName timed out'),
          );
      final user = FirebaseAuth.instance.currentUser;
      await _warmUpAppCheck();
      try {
        return await invoke();
      } on FirebaseFunctionsException catch (error) {
        final authTokenRefreshed =
            error.code.trim().toLowerCase() == 'unauthenticated'
            ? await _refreshAuthToken(user)
            : false;
        final isAppCheckFailure = isLikelyAppCheckFailure(
          code: error.code,
          message: '${error.message ?? ''} ${error.details ?? ''}',
          hasAuthenticatedUser: user != null,
          authTokenRefreshSucceeded: authTokenRefreshed,
        );
        if (!isAppCheckFailure) {
          rethrow;
        }

        final appCheckRefreshed = await _warmUpAppCheck(forceRefresh: true);
        if (!appCheckRefreshed) {
          throw const _AppCheckUnavailable();
        }
        await Future<void>.delayed(_appCheckRetryDelay);
        try {
          return await invoke();
        } on FirebaseFunctionsException catch (retryError) {
          final retryIsAppCheckFailure = isLikelyAppCheckFailure(
            code: retryError.code,
            message: '${retryError.message ?? ''} ${retryError.details ?? ''}',
            hasAuthenticatedUser: user != null,
            authTokenRefreshSucceeded: authTokenRefreshed,
          );
          if (retryIsAppCheckFailure) {
            throw const _AppCheckUnavailable();
          }
          rethrow;
        }
      }
    } on _AppCheckUnavailable {
      throw Exception(_appCheckMessage());
    } on FirebaseFunctionsException catch (e) {
      if (throwOriginalException) {
        rethrow;
      }
      final code = e.code.trim().toLowerCase();

      // Nếu có lỗi tuỳ chỉnh cho mã lỗi này
      if (customErrorMessages != null &&
          customErrorMessages.containsKey(code)) {
        throw Exception(customErrorMessages[code]);
      }

      // Xử lý chung các lỗi phổ biến
      switch (code) {
        case 'unauthenticated':
          throw Exception('Phiên đăng nhập không hợp lệ hoặc đã hết hạn.');
        case 'unavailable':
        case 'deadline-exceeded':
          throw Exception(
            'Không thể kết nối máy chủ. Vui lòng kiểm tra mạng và thử lại.',
          );
        case 'permission-denied':
          throw Exception('Bạn không có quyền thực hiện thao tác này.');
        default:
          final mapped = AppErrorMapper.resolve(
            e,
            fallbackMessage:
                fallbackErrorMessage ?? 'Đã có lỗi xảy ra từ máy chủ.',
          ).message;
          throw Exception(mapped);
      }
    } on TimeoutException {
      throw Exception(
        'Kết nối máy chủ bị quá hạn. Vui lòng kiểm tra mạng và thử lại.',
      );
    } catch (e) {
      throw Exception(fallbackErrorMessage ?? 'Đã có lỗi bất ngờ xảy ra.');
    }
  }
}

class _AppCheckUnavailable implements Exception {
  const _AppCheckUnavailable();
}
