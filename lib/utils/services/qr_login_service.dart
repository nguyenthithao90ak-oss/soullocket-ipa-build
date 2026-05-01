import 'dart:math';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// ============================================================
///  QRLoginService — GRA (Logic/Bảo mật)
///  Dịch vụ Đăng nhập bằng mã QR
///
///  Cơ chế:
///  1. Thiết bị muốn đăng nhập (B) tạo 1 Token tạm, chờ ở node /qr_logins/{token}
///  2. Thiết bị đã đăng nhập (A) quét mã QR chứa Token này.
///  3. Thiết bị A xác nhận và đẩy thông tin nhà (houseId) + mã xác thực tạm vào node đó.
///  4. Thiết bị B nhận được data và tự động đăng nhập.
/// ============================================================
class QRLoginService {
  static const int tokenLength = 32;
  static const int tokenTtlSeconds = 15;
  static const String _tokenChars =
      'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_';

  static final QRLoginService _instance = QRLoginService._internal();
  factory QRLoginService() => _instance;
  QRLoginService._internal();

  final _db = FirebaseDatabase.instance;
  final _auth = FirebaseAuth.instance;

  /// Tạo một Token đăng nhập mới (Dành cho màn hình Login)
  String generateToken() {
    final random = Random.secure();
    return List.generate(
      tokenLength,
      (index) => _tokenChars[random.nextInt(_tokenChars.length)],
    ).join();
  }

  /// Bắt đầu chờ đợi sự xác nhận từ thiết bị khác
  Stream<DatabaseEvent> watchToken(String token) {
    return _db.ref('qr_logins/$token').onValue;
  }

  /// Khởi tạo node trên Firebase cho Token này
  Future<void> initTokenNode(String token) async {
    final expiresAt = DateTime.now()
        .add(const Duration(seconds: tokenTtlSeconds))
        .millisecondsSinceEpoch;
    await _db.ref('qr_logins/$token').set({
      'status': 'waiting',
      'created_at': ServerValue.timestamp,
      'expires_at': expiresAt,
      'device_info': 'Flutter App',
    });
  }

  /// Hủy Token khi không dùng nữa
  Future<void> disposeToken(String token) async {
    await _db.ref('qr_logins/$token').remove();
  }

  Future<void> consumeToken(String token) async {
    await disposeToken(token);
  }

  /// Xác nhận (Authorize) một Token (Dành cho thiết bị đã đăng nhập)
  /// Sẽ đẩy thông tin đăng nhập cần thiết qua Firebase (đã mã hóa hoặc bảo mật)
  Future<void> authorizeToken(String token, String houseId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("Bạn chưa đăng nhập!");
    final ref = _db.ref('qr_logins/$token');
    final now = DateTime.now().millisecondsSinceEpoch;
    var isExpired = false;
    var isInvalid = false;

    final result = await ref.runTransaction((current) {
      if (current is! Map) {
        isInvalid = true;
        return Transaction.abort();
      }

      final data = Map<Object?, Object?>.from(current);
      final status = data['status']?.toString();
      final expiresAt = (data['expires_at'] as num?)?.toInt() ?? 0;

      if (status != 'waiting') {
        isInvalid = true;
        return Transaction.abort();
      }

      if (expiresAt <= 0 || now > expiresAt) {
        isExpired = true;
        return Transaction.abort();
      }

      data['status'] = 'authorized';
      data['houseId'] = houseId;
      data['auth_uid'] = user.uid;
      data['confirmed_at'] = ServerValue.timestamp;
      return Transaction.success(data);
    });

    if (isExpired) {
      await ref.remove();
      throw Exception('Mã QR đã hết hạn.');
    }

    if (isInvalid || !result.committed) {
      throw Exception('Mã QR không hợp lệ hoặc đã được sử dụng.');
    }

    Future.delayed(const Duration(seconds: 5), () async {
      await ref.remove();
    });
  }
}
