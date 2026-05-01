import 'package:cloud_functions/cloud_functions.dart';

class OtpService {
  static final OtpService _instance = OtpService._internal();
  factory OtpService() => _instance;
  OtpService._internal();

  /// Gửi yêu cầu lấy OTP 6 số qua Email
  Future<void> requestEmailOTP(String email) async {
    try {
      final callable =
          FirebaseFunctions.instance.httpsCallable('requestEmailOTP');
      await callable.call({'email': email});
    } on FirebaseFunctionsException catch (e) {
      throw e.message ?? 'Lỗi khi gửi mã xác nhận.';
    } catch (e) {
      throw 'Không thể kết nối máy chủ để gửi mã.';
    }
  }

  /// Xác thực mã 6 số. Nếu đúng trả về Custom Token để đăng nhập
  Future<String> verifyEmailOTP(String email, String otp) async {
    try {
      final callable =
          FirebaseFunctions.instance.httpsCallable('verifyEmailOTP');
      final result = await callable.call({'email': email, 'otp': otp});
      final data = result.data as Map;
      if (data['success'] == true) {
        return data['customToken'] as String;
      }
      throw 'Xác thực thất bại.';
    } on FirebaseFunctionsException catch (e) {
      throw e.message ?? 'Mã xác nhận sai hoặc đã hết hạn.';
    } catch (e) {
      throw 'Chưa thể xác thực mã lúc này.';
    }
  }
}
