import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:soullocket_app/utils/app_error_mapper.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';

import 'callable_app_check_guard.dart';

class CloudFunctionsHelper {
  static FirebaseFunctions? _functionsInstance;

  static FirebaseFunctions get _functions =>
      _functionsInstance ?? FirebaseFunctions.instance;

  @visibleForTesting
  static void setMockFunctions(FirebaseFunctions mock) {
    _functionsInstance = mock;
  }

  /// Gọi httpsCallable an toàn với bắt lỗi và timeout chuẩn.
  ///
  /// [functionName]: Tên Cloud Function
  /// [payload]: Data gửi lên
  /// [timeout]: Thời gian chờ tối đa của mỗi lần gọi
  /// [customErrorMessages]: Map các lỗi tuỳ chỉnh theo mã lỗi
  /// [fallbackErrorMessage]: Lỗi mặc định nếu không khớp với customErrorMessages
  /// [requireAppCheck]: Chuẩn bị App Check và thử lại xác thực tối đa một lần.
  static Future<HttpsCallableResult<T>> callSecure<T>(
    String functionName, {
    dynamic payload,
    Duration timeout = const Duration(seconds: 15),
    Map<String, String>? customErrorMessages,
    String? fallbackErrorMessage,
    bool throwOriginalException = false,
    bool requireAppCheck = false,
  }) async {
    try {
      final callable = _functions.httpsCallable(functionName);
      Future<HttpsCallableResult<T>> invoke() => callable
          .call<T>(payload)
          .timeout(
            timeout,
            onTimeout: () => throw TimeoutException('$functionName timed out'),
          );
      if (!requireAppCheck) return await invoke();

      final auth = FirebaseAuth.instance;
      final user = auth.currentUser;
      return await const CallableAppCheckGuard().call(
        action: () {
          // Không gửi thao tác của phiên cũ bằng tài khoản vừa đăng nhập khác.
          if (user == null || auth.currentUser?.uid != user.uid) {
            throw FirebaseAuthException(code: 'user-token-expired');
          }
          return invoke();
        },
        appCheckToken: (forceRefresh) =>
            FirebaseAppCheck.instance.getToken(forceRefresh),
        refreshAuthToken: () async {
          if (user == null || auth.currentUser?.uid != user.uid) return false;
          final token = await user.getIdToken(true);
          return auth.currentUser?.uid == user.uid &&
              token != null &&
              token.trim().isNotEmpty;
        },
      );
    } on CallableAppCheckException catch (error) {
      if (throwOriginalException && error.cause != null) throw error.cause!;
      throw AppErrorInfo(
        kind: AppErrorKind.server,
        message: L10nService().translate(
          kDebugMode
              ? 'err_appcheck_debug_blocked'
              : 'err_appcheck_verifying_device',
        ),
      );
    } on CallableVerificationException catch (error) {
      if (throwOriginalException) throw error.cause;
      throw AppErrorInfo(
        kind: AppErrorKind.server,
        message: L10nService().translate('err_request_verification_failed'),
      );
    } on FirebaseFunctionsException catch (error) {
      if (throwOriginalException) rethrow;
      final code = error.code.trim().toLowerCase();
      if (customErrorMessages?.containsKey(code) == true) {
        throw Exception(customErrorMessages![code]);
      }
      switch (code) {
        case 'unauthenticated':
          throw Exception(AppErrorMapper.authSyncMessage);
        case 'unavailable':
        case 'deadline-exceeded':
          throw Exception(AppErrorMapper.defaultNetworkMessage);
        case 'permission-denied':
          throw Exception(L10nService().translate('err_permission_denied'));
        default:
          throw Exception(
            AppErrorMapper.resolve(
              error,
              fallbackMessage: fallbackErrorMessage,
            ).message,
          );
      }
    } on FirebaseAuthException catch (error) {
      if (throwOriginalException) rethrow;
      throw Exception(AppErrorMapper.resolve(error).message);
    } on TimeoutException catch (error) {
      throw Exception(AppErrorMapper.resolve(error).message);
    } catch (error) {
      throw Exception(
        AppErrorMapper.resolve(
          error,
          fallbackMessage: fallbackErrorMessage,
        ).message,
      );
    }
  }
}
