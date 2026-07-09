import 'dart:async';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:soullocket_app/utils/app_error_mapper.dart';

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
      final response = await callable.call<T>(payload).timeout(
            timeout,
            onTimeout: () => throw TimeoutException('$functionName timed out'),
          );
      return response;
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
              'Không thể kết nối máy chủ. Vui lòng kiểm tra mạng và thử lại.');
        case 'permission-denied':
          throw Exception('Bạn không có quyền thực hiện thao tác này.');
        default:
          final mapped = AppErrorMapper.resolve(e,
                  fallbackMessage:
                      fallbackErrorMessage ?? 'Đã có lỗi xảy ra từ máy chủ.')
              .message;
          throw Exception(mapped);
      }
    } on TimeoutException {
      throw Exception(
          'Kết nối máy chủ bị quá hạn. Vui lòng kiểm tra mạng và thử lại.');
    } catch (e) {
      throw Exception(fallbackErrorMessage ?? 'Đã có lỗi bất ngờ xảy ra.');
    }
  }
}
