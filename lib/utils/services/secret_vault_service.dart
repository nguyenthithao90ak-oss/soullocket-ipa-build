import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as encrypt;

/// ============================================================
///  SecretVaultService — GRA (Logic/Data)
///  Két Sắt Bí Mật - Mã Hóa Cao Cấp AES (Giai đoạn Hoàn thiện)
///
///  Chức năng:
///  1. Khởi tạo khóa mã hóa AES-256 dựa trên Mật khẩu.
///  2. Khóa hình ảnh/video riêng tư.
///  3. Chỉ có Vân tay (LocalAuth) hoặc Mã PIN bí mật mới mở được.
/// ============================================================
class SecretVaultService {
  static final SecretVaultService _instance = SecretVaultService._internal();
  factory SecretVaultService() => _instance;
  SecretVaultService._internal();

  encrypt.Key? _encryptionKey;

  /// Hàm này mở khóa Két (Gọi FaceID/Vân tay bên UI thành công thì gọi tiếp hàm này)
  bool unlockVault(String pinCode) {
    if (pinCode.length < 4) return false;

    // Tạo khóa 32 bytes từ PIN bằng SHA-256
    final bytes = utf8.encode(pinCode);
    final digest = sha256.convert(bytes);
    _encryptionKey = encrypt.Key(Uint8List.fromList(digest.bytes));

    return true;
  }

  /// Mã hóa ảnh / nội dung trước khi tống xuống Database
  String encryptDataBeforeSave(String sensitiveData) {
    if (_encryptionKey == null) {
      throw Exception('⚠️ Vui lòng mở khóa két sắt trước khi lưu dữ liệu!');
    }

    // Tạo random IV cho mỗi lần mã hóa để chống phân tích pattern
    final iv = encrypt.IV.fromSecureRandom(16);
    final encrypter = encrypt.Encrypter(encrypt.AES(_encryptionKey!));
    final encrypted = encrypter.encrypt(sensitiveData, iv: iv);

    // Lưu IV kèm theo ciphertext (định dạng: ivBase64:ciphertextBase64)
    return '${iv.base64}:${encrypted.base64}';
  }

  /// Giải mã nội dung khi bấm vào xem
  String decryptDataForViewing(String encryptedData) {
    if (_encryptionKey == null) {
      throw Exception('⚠️ Lỗi truy cập trái phép. Két đang khóa!');
    }

    try {
      final encrypter = encrypt.Encrypter(encrypt.AES(_encryptionKey!));

      // Hỗ trợ cả dữ liệu mới (có random IV) và dữ liệu cũ (dùng IV tĩnh)
      if (encryptedData.contains(':')) {
        final parts = encryptedData.split(':');
        final iv = encrypt.IV.fromBase64(parts[0]);
        final ciphertext = parts[1];
        return encrypter.decrypt64(ciphertext, iv: iv);
      } else {
        // Fallback cho dữ liệu cũ mã hóa bằng IV toàn số 0
        final legacyIv = encrypt.IV.fromLength(16);
        return encrypter.decrypt64(encryptedData, iv: legacyIv);
      }
    } catch (e) {
      return 'DỮ LIỆU ĐÃ BỊ MÃ HÓA HOẶC SAI KHÓA - KHÔNG THỂ ĐỌC';
    }
  }

  void lockVault() {
    _encryptionKey = null; // Huỷ chìa khoá RAM lập tức
  }
}
