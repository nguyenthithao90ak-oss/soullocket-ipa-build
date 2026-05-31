import 'package:cloud_functions/cloud_functions.dart';

class OtpService {
  static final OtpService _instance = OtpService._internal();
  factory OtpService() => _instance;
  OtpService._internal();

  /// Gửi yêu cầu lấy OTP 6 số qua Email
  Future<void> requestEmailOTP(String email) async {
    try {
      final normalizedEmail = email.trim();
      if (normalizedEmail.isEmpty) throw 'Vui lòng nhập email.';
      final callable =
          FirebaseFunctions.instance.httpsCallable('requestEmailOTP');
      await callable.call({'email': normalizedEmail});
    } on FirebaseFunctionsException catch (e) {
      throw e.message ?? 'Lỗi khi gửi mã xác nhận.';
    } catch (e) {
      throw 'Không thể kết nối máy chủ để gửi mã.';
    }
  }

  /// Xác thực mã 6 số. Nếu đúng trả về Custom Token để đăng nhập
  Future<String> verifyEmailOTP(String email, String otp) async {
    try {
      final normalizedEmail = email.trim();
      final normalizedOtp = otp.trim();
      if (normalizedEmail.isEmpty || normalizedOtp.isEmpty) {
        throw 'Vui lòng nhập email và mã xác nhận.';
      }
      final callable =
          FirebaseFunctions.instance.httpsCallable('verifyEmailOTP');
      final result = await callable.call({
        'email': normalizedEmail,
        'otp': normalizedOtp,
      });
      if (result.data is! Map) throw 'Phản hồi xác thực không hợp lệ.';
      final data = result.data as Map;
      if (data['success'] == true) {
        final customToken = data['customToken']?.toString().trim() ?? '';
        if (customToken.isNotEmpty) return customToken;
      }
      throw 'Xác thực thất bại.';
    } on FirebaseFunctionsException catch (e) {
      throw e.message ?? 'Mã xác nhận sai hoặc đã hết hạn.';
    } catch (e) {
      throw 'Chưa thể xác thực mã lúc này.';
    }
  }
}
