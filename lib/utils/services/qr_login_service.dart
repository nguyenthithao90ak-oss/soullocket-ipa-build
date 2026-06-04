import 'dart:async';
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
  static final Set<int> _tokenCharCodes = _tokenChars.codeUnits.toSet();

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
    final normalizedToken = _normalizeToken(token);
    if (normalizedToken == null) return const Stream<DatabaseEvent>.empty();
    unawaited(_removeTokenIfExpired(normalizedToken));
    return _db.ref('qr_logins/$normalizedToken').onValue;
  }

  /// Khởi tạo node trên Firebase cho Token này
  Future<void> initTokenNode(String token) async {
    final normalizedToken = _normalizeToken(token);
    if (normalizedToken == null) return;
    unawaited(_removeTokenIfExpired(normalizedToken));
    final expiresAt = DateTime.now()
        .add(const Duration(seconds: tokenTtlSeconds))
        .millisecondsSinceEpoch;
    await _db.ref('qr_logins/$normalizedToken').set({
      'status': 'waiting',
      'created_at': ServerValue.timestamp,
      'expires_at': expiresAt,
      'device_info': 'Flutter App',
    });
  }

  /// Hủy Token khi không dùng nữa
  Future<void> disposeToken(String token) async {
    final normalizedToken = _normalizeToken(token);
    if (normalizedToken == null) return;
    await _db.ref('qr_logins/$normalizedToken').remove();
  }

  Future<void> consumeToken(String token) async {
    await disposeToken(token);
  }

  /// Xác nhận (Authorize) một Token (Dành cho thiết bị đã đăng nhập)
  /// Sẽ đẩy thông tin đăng nhập cần thiết qua Firebase (đã mã hóa hoặc bảo mật)
  Future<void> authorizeToken(String token, String houseId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Bạn chưa đăng nhập!');
    final normalizedToken = _normalizeToken(token);
    final normalizedHouseId = _normalizeHouseId(houseId);
    if (normalizedToken == null || normalizedHouseId == null) {
      throw Exception('Mã QR không hợp lệ.');
    }
    final ref = _db.ref('qr_logins/$normalizedToken');
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
      data['houseId'] = normalizedHouseId;
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

  String? _normalizeToken(String token) {
    final normalized = token.trim();
    if (normalized.length != tokenLength) return null;
    for (final codeUnit in normalized.codeUnits) {
      if (!_tokenCharCodes.contains(codeUnit)) return null;
    }
    return normalized;
  }

  String? _normalizeHouseId(String houseId) {
    final normalized = houseId.trim();
    if (normalized.isEmpty || normalized.length > 128) return null;
    if (normalized.contains('/') ||
        normalized.contains('\\') ||
        normalized.contains('.') ||
        normalized.contains('#') ||
        normalized.contains(r'$') ||
        normalized.contains('[') ||
        normalized.contains(']')) {
      return null;
    }
    return normalized;
  }

  Future<void> _removeTokenIfExpired(String token) async {
    try {
      final ref = _db.ref('qr_logins/$token');
      final snapshot = await ref.get();
      final value = snapshot.value;
      if (value is! Map) return;
      final data = Map<Object?, Object?>.from(value);
      final expiresAt = (data['expires_at'] as num?)?.toInt() ?? 0;
      if (expiresAt > 0 && DateTime.now().millisecondsSinceEpoch > expiresAt) {
        await ref.remove();
      }
    } catch (_) {}
  }
}
