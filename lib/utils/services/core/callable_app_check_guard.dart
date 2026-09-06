import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';

class CallableAppCheckException implements Exception {
  const CallableAppCheckException(this.cause);

  final Object? cause;
}

class CallableVerificationException implements Exception {
  const CallableVerificationException(this.cause);

  final FirebaseFunctionsException cause;
}

/// Chuẩn bị App Check và chỉ thử lại khi máy chủ đã từ chối xác thực.
/// Không gửi lại thao tác ghi sau timeout hoặc lỗi mạng không rõ kết quả.
class CallableAppCheckGuard {
  const CallableAppCheckGuard();

  Future<T> call<T>({
    required Future<T> Function() action,
    required Future<String?> Function(bool forceRefresh) appCheckToken,
    required Future<bool> Function() refreshAuthToken,
    Duration tokenTimeout = const Duration(seconds: 8),
  }) async {
    Future<void> prepareToken(bool forceRefresh) async {
      String? token;
      try {
        token = await appCheckToken(forceRefresh).timeout(tokenTimeout);
      } on TimeoutException {
        rethrow;
      } on FirebaseException catch (error) {
        if (error.code == 'network-request-failed' ||
            error.code == 'unavailable') {
          rethrow;
        }
        throw CallableAppCheckException(error);
      } catch (error) {
        throw CallableAppCheckException(error);
      }
      if (token == null || token.trim().isEmpty) {
        throw const CallableAppCheckException(null);
      }
    }

    await prepareToken(false);
    try {
      return await action();
    } on FirebaseFunctionsException catch (error) {
      final explicitAppCheckFailure = _isExplicitAppCheckFailure(error);
      if (error.code != 'unauthenticated' && !explicitAppCheckFailure) {
        rethrow;
      }
      if (!explicitAppCheckFailure &&
          !await refreshAuthToken().timeout(tokenTimeout)) {
        rethrow;
      }
      await prepareToken(true);
      try {
        return await action();
      } on FirebaseFunctionsException catch (retryError) {
        if (_isExplicitAppCheckFailure(retryError)) {
          throw CallableAppCheckException(retryError);
        }
        if (retryError.code == 'unauthenticated') {
          // HTTP 401 dùng chung cho Auth và App Check; không kết luận hết phiên
          // chỉ dựa vào mã này sau khi đã làm mới token.
          throw CallableVerificationException(retryError);
        }
        rethrow;
      }
    }
  }

  bool _isExplicitAppCheckFailure(FirebaseFunctionsException error) {
    if (!const {
      'unauthenticated',
      'permission-denied',
      'failed-precondition',
    }.contains(error.code)) {
      return false;
    }
    final message = '${error.message ?? ''} ${error.details ?? ''}'
        .toLowerCase();
    return const [
      'app check',
      'appcheck',
      'attestation',
      'play integrity',
      'debug token',
    ].any(message.contains);
  }
}
