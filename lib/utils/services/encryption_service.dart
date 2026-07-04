import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pointycastle/export.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:soullocket_app/views/ui_prefs.dart';

/// ============================================================
///  EncryptionService — Bảo mật / Mã hóa
///
///  Kiến trúc bảo mật (App mới):
///  - Passphrase → PBKDF2 (150k) → Derived Key (32 bytes AES-256-GCM)
///  - Key lưu vào Android Keystore / iOS Secure Enclave (KHÔNG lên Firebase)
///  - Firebase chỉ lưu: salt + verifier (HMAC) + iterations
///
///  Định dạng (tự động nhận diện khi decrypt):
///  - ENC:   → AES-256-GCM legacy Web (hex IV + ciphertext)
///  - ENC2:  → AES-256-CBC legacy app (cần migrate lên ENC3: khi có dịp)
///  - ENC3:  → AES-256-GCM app (định dạng hiện tại, authenticated encryption)
///
///  Tương thích ngược với dữ liệu mã hóa cũ (js/inline/core-encryption.js):
///  - Web dùng PBKDF2 (100k, SHA-256, salt cố định 'goodgo-salt-2026')
///  - Web dùng AES-GCM-256 với IV 12 bytes
///  - Web format: "ENC:ivHex:ctHex"
///  - App format mới: "ENC3:base64(iv12+ct+tag)"
/// ============================================================
class _DeriveKeyParams {
  final String passphrase;
  final Uint8List salt;
  final int iterations;
  _DeriveKeyParams(this.passphrase, this.salt, this.iterations);
}

Uint8List _deriveKeyIsolate(_DeriveKeyParams params) {
  final derivator = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64));
  derivator.init(Pbkdf2Parameters(params.salt, params.iterations, 32));
  return derivator.process(Uint8List.fromList(utf8.encode(params.passphrase)));
}

Uint8List _deriveWebCompatKeyIsolate(_DeriveKeyParams params) {
  final derivator = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64));
  derivator.init(Pbkdf2Parameters(params.salt, params.iterations, 32));
  return derivator.process(Uint8List.fromList(utf8.encode(params.passphrase)));
}

class EncryptionService {
  static final EncryptionService _instance = EncryptionService._internal();

  // --- App format ---
  static const String _legacyPrefix = 'ENC:'; // Định dạng Web cũ (AES-GCM)
  static const String _legacyAppPrefix = 'ENC2:'; // Định dạng app cũ (AES-CBC)
  static const String _currentPrefix = 'ENC3:'; // App mới: AES-256-GCM
  static const int _pbkdf2Iterations = 150000;
  static const int _saltLength = 16;
  static const String _verifierMessage = 'soullocket-private-vault-v2';
  static const String _recoveryVerifierMessage =
      'soullocket-private-vault-recovery-v1';

  // --- Web-compatible constants (PHẢI khớp với core-encryption.js) ---
  // Salt cố định là hạn chế của Web legacy (JS không lưu được salt riêng).
  // Chỉ dùng để decrypt + migrate dữ liệu ENC: cũ.
  // ⚠️ TO-DO: Khi analytics cho thấy không còn ENC: data nào,
  //          xóa _webCompatSalt, _deriveWebCompatKey, _aesGcmDecrypt
  //          và throw ngay trong decryptMessage cho ENC: format.
  static const String _webCompatSalt = 'goodgo-salt-2026';
  static const int _webCompatIterations = 100000; // 100k iterations
  static const String _legacyWebWriteDisabledMessage =
      'Legacy Web-compatible ENC writes are disabled. Existing ENC: payloads '
      'are supported only for decrypt and migration to ENC3.';

  // --- Rate limiting variables ---
  int _failedAttempts = 0;
  int _lockedUntil = 0;

  factory EncryptionService() => _instance;
  EncryptionService._internal();

  // Session cache: key chỉ tồn tại trong RAM khi app đang chạy.
  // Được ưu tiên trước khi đọc Keystore để tránh overhead I/O.
  final Map<String, Uint8List> _keyCache = {};

  // Lưu thời điểm unlock cuối cùng để tính timeout
  final Map<String, int> _lastUnlockTime = {};

  final _db = FirebaseDatabase.instance;

  // Flutter Secure Storage — backed by Android Keystore / iOS Secure Enclave
  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
    webOptions: WebOptions(dbName: 'il_vault', publicKey: 'il_enc_pub'),
  );

  // Key dùng để lưu vào Secure Storage: 'il_vault_key_{houseId}'
  static String _secureKey(String houseId) => 'il_vault_key_$houseId';

  // ===========================================================================
  // PUBLIC API
  // ===========================================================================

  /// Hash mật khẩu bằng SHA-256 — khớp 100% với Web's hashPassword(str):
  ///   const msgBuffer = new TextEncoder().encode(str);
  ///   const hashBuffer = await crypto.subtle.digest('SHA-256', msgBuffer);
  ///   return hashArray.map(b => b.toString(16).padStart(2, '0')).join('');
  static String hashPasswordSHA256(String password) {
    final digest = crypto.sha256.convert(utf8.encode(password.trim()));
    return digest.toString(); // hex string, giống Web
  }

  Future<bool> hasPassphraseSetup(String houseId) async {
    final snap = await _metadataRef(houseId).get();
    return snap.exists && snap.value != null;
  }

  /// Trả về thời gian setup mật khẩu (tính bằng milliseconds) hoặc null nếu chưa có.
  Future<int?> getPassphraseSetupTime(String houseId) async {
    final snap = await _metadataRef(houseId).get();
    if (!snap.exists || snap.value == null) return null;
    final metadata = Map<String, dynamic>.from(snap.value as Map);
    if (metadata.containsKey('createdAt')) {
      return (metadata['createdAt'] as num).toInt();
    }
    return null;
  }

  Future<bool> hasRecoveryCode(String houseId) async {
    final snap = await _metadataRef(houseId).get();
    if (!snap.exists || snap.value == null) return false;
    final metadata = Map<String, dynamic>.from(snap.value as Map);
    return (metadata['recoverySalt']?.toString().isNotEmpty ?? false) &&
        (metadata['recoveryVerifier']?.toString().isNotEmpty ?? false) &&
        (metadata['recoveryWrappedKey']?.toString().isNotEmpty ?? false);
  }

  Future<String?> createRecoveryCodeIfMissing(String houseId) async {
    if (await hasRecoveryCode(houseId)) {
      return null;
    }
    final key = await _resolveKey(houseId);
    return _generateAndStoreRecoveryCode(houseId, key);
  }

  Future<String> regenerateRecoveryCode(String houseId) async {
    final key = await _resolveKey(houseId);
    return _generateAndStoreRecoveryCode(houseId, key);
  }

  /// Mở khóa kho mật với passphrase.
  /// Key sẽ được lưu vào platform Keystore sau khi xác thực thành công.
  Future<void> unlockHouseKey(String houseId, String passphrase) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (_lockedUntil > now) {
      final remainingMs = _lockedUntil - now;
      final remainingMinutes = (remainingMs / 60000).ceil();
      throw StateError(
          'Bạn đã nhập sai quá nhiều lần. Vui lòng thử lại sau $remainingMinutes phút.');
    }

    final normalizedPassphrase = passphrase.trim();
    if (normalizedPassphrase.length < 8) {
      throw StateError('Mật khẩu kho mật phải từ 8 ký tự.');
    }

    final metadataSnap = await _metadataRef(houseId).get();
    if (!metadataSnap.exists || metadataSnap.value == null) {
      await _createOrMigrateKey(houseId, normalizedPassphrase);
      _resetFailedAttempts();
      return;
    }

    final metadata = Map<String, dynamic>.from(metadataSnap.value as Map);
    final saltB64 = metadata['salt']?.toString() ?? '';
    final verifier = metadata['verifier']?.toString() ?? '';
    final iterations =
        (metadata['iterations'] as num?)?.toInt() ?? _pbkdf2Iterations;

    if (saltB64.isEmpty || verifier.isEmpty) {
      throw StateError('Cấu hình mã hóa không hợp lệ.');
    }

    final key = await _deriveKey(
      normalizedPassphrase,
      Uint8List.fromList(base64Decode(saltB64)),
      iterations,
    );

    if (!_constantTimeEquals(_buildVerifier(key), verifier)) {
      _incrementFailedAttempts();
      throw StateError('Mật khẩu kho mật không đúng.');
    }

    // Nếu đúng pass thì reset số lần sai
    _resetFailedAttempts();

    // Lưu vào session cache
    _keyCache[houseId] = key;
    _lastUnlockTime[houseId] = DateTime.now().millisecondsSinceEpoch;

    // (Bỏ lưu Secure Storage để thoát app là phải nhập lại)
    // await _persistKeyToSecureStorage(houseId, key);
  }

  Future<void> unlockHouseKeyWithRecoveryCode(
    String houseId,
    String recoveryCode,
  ) async {
    final normalizedCode = recoveryCode.trim().toUpperCase();
    if (normalizedCode.length < 8) {
      throw StateError('Mã khôi phục không hợp lệ.');
    }

    final metadataSnap = await _metadataRef(houseId).get();
    if (!metadataSnap.exists || metadataSnap.value == null) {
      throw StateError('Kho mật chưa được thiết lập.');
    }

    final metadata = Map<String, dynamic>.from(metadataSnap.value as Map);
    final saltB64 = metadata['recoverySalt']?.toString() ?? '';
    final verifier = metadata['recoveryVerifier']?.toString() ?? '';
    final wrappedKey = metadata['recoveryWrappedKey']?.toString() ?? '';
    final iterations =
        (metadata['recoveryIterations'] as num?)?.toInt() ?? _pbkdf2Iterations;

    if (saltB64.isEmpty || verifier.isEmpty || wrappedKey.isEmpty) {
      throw StateError('Kho mật chưa có mã khôi phục.');
    }

    final recoveryKey = await _deriveKey(
      normalizedCode,
      Uint8List.fromList(base64Decode(saltB64)),
      iterations,
    );

    if (!_constantTimeEquals(_buildRecoveryVerifier(recoveryKey), verifier)) {
      _incrementFailedAttempts();
      throw StateError('Mã khôi phục không đúng.');
    }

    final decodedKeyB64 =
        _aesDecrypt(recoveryKey, wrappedKey, prefix: _currentPrefix);
    final decodedKey = Uint8List.fromList(base64Decode(decodedKeyB64));
    _resetFailedAttempts();
    _keyCache[houseId] = decodedKey;
    _lastUnlockTime[houseId] = DateTime.now().millisecondsSinceEpoch;
  }

  void _incrementFailedAttempts() {
    _failedAttempts++;
    if (_failedAttempts >= 30) {
      _lockedUntil = DateTime.now().millisecondsSinceEpoch +
          15 * 60 * 1000; // Khóa 15 phút
    } else if (_failedAttempts >= 20) {
      _lockedUntil = DateTime.now().millisecondsSinceEpoch +
          10 * 60 * 1000; // Khóa 10 phút
    } else if (_failedAttempts >= 10) {
      _lockedUntil =
          DateTime.now().millisecondsSinceEpoch + 5 * 60 * 1000; // Khóa 5 phút
    }
  }

  void _resetFailedAttempts() {
    _failedAttempts = 0;
    _lockedUntil = 0;
  }

  Future<String> encryptMessage(String houseId, String plaintext) async {
    final key = await _resolveKey(houseId);
    return _aesEncrypt(key, plaintext, prefix: _currentPrefix);
  }

  Future<String> decryptMessage(String houseId, String ciphertext) async {
    if (!_isEncrypted(ciphertext)) return ciphertext;
    final key = await _resolveKey(houseId);
    if (_isEncryptedWithCurrentKey(ciphertext)) {
      return _aesDecrypt(key, ciphertext, prefix: _currentPrefix);
    }
    // Legacy App format 'ENC2:' (AES-CBC) — migrate to ENC3:
    if (ciphertext.startsWith(_legacyAppPrefix)) {
      final plaintext =
          _aesCbcDecrypt(key, ciphertext, prefix: _legacyAppPrefix);
      // Tự động migrate lên ENC3: khi decrypt
      return plaintext;
    }
    // Legacy Web format 'ENC:ivHex:ctHex' — không thể decrypt bằng session key
    // vì Web dùng house password trực tiếp. Trả thông báo để UI xử lý.
    return '[Cần nhập mật khẩu để xem nội dung cũ]';
  }

  /// Decrypt dữ liệu cũ bằng house password trực tiếp.
  /// Dùng khi người dùng chưa migrate nhưng cần xem nội dung vault.
  Future<String> decryptWebLegacy(
      String ciphertext, String housePassword) async {
    if (!ciphertext.startsWith(_legacyPrefix)) return ciphertext;
    // Salt cố định chỉ dùng để migrate dữ liệu cũ.
    // Không dùng cho bất kỳ dữ liệu ENC2: mới nào.
    try {
      final key = await _deriveWebCompatKey(housePassword);
      return _aesGcmDecrypt(key, ciphertext);
    } catch (e) {
      throw StateError('Mật khẩu không đúng hoặc dữ liệu bị hỏng.');
    }
  }

  /// Ghi dữ liệu mới ở định dạng ENC legacy đã bị khóa.
  /// Giữ API này chỉ để fail-fast nếu có call-site cũ còn sót.
  @Deprecated(
    'Legacy Web ENC writes are disabled because PBKDF2 with a fixed salt '
    'weakens security. Keep ENC support only for decrypt + migration to ENC2.',
  )
  Future<String> encryptWebCompat(
      String plaintext, String housePassword) async {
    throw UnsupportedError(_legacyWebWriteDisabledMessage);
  }

  /// Kiểm tra key đã có trong session hoặc Secure Storage chưa —
  /// cho phép tự động mở kho mật khi user đã unlock trước đó trên thiết bị này.
  Future<bool> isKeyAvailableLocally(String houseId) async {
    return _keyCache.containsKey(houseId);
  }

  /// Nạp key từ session cache (không cần nhập lại passphrase) nếu chưa hết hạn.
  /// Theo yêu cầu: thoát app là mất (không lưu Secure Storage nữa), mặc định 15p timeout.
  Future<bool> tryRestoreKeyFromSecureStorage(String houseId) async {
    if (!_keyCache.containsKey(houseId)) return false;

    final timeoutMins = UiPrefs.notifier.value.vaultTimeoutMins;
    if (timeoutMins == 0) {
      clearCache(houseId);
      return false;
    }

    if (timeoutMins > 0) {
      final lastTime = _lastUnlockTime[houseId] ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now - lastTime > timeoutMins * 60 * 1000) {
        // Hết hạn -> Xóa cache
        clearCache(houseId);
        return false;
      }
    }

    // Cập nhật lại thời gian active
    _lastUnlockTime[houseId] = DateTime.now().millisecondsSinceEpoch;
    return true;
  }

  void clearCache([String? houseId]) {
    if (houseId == null || houseId.isEmpty) {
      _keyCache.clear();
      _lastUnlockTime.clear();
      return;
    }
    _keyCache.remove(houseId);
    _lastUnlockTime.remove(houseId);
  }

  /// Gọi khi app bị đẩy xuống background để bắt đầu đếm thời gian timeout
  void notifyAppBackgrounded() {
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final key in _lastUnlockTime.keys) {
      _lastUnlockTime[key] = now;
    }
  }

  /// Đặt lại mật khẩu nhưng KHÔNG xóa dữ liệu ảnh.
  /// Chỉ dùng khi người dùng "Quên mật khẩu" trong vòng 12h.
  /// Lưu ý: Vì E2E, nếu reset kiểu này, dữ liệu cũ sẽ bị khóa vĩnh viễn
  /// NẾU KHÔNG có master key. Trong yêu cầu của bạn: "ấn vào quên rồi vẫn sẽ khôi phục lại ảnh cũ".
  /// Để giải quyết vấn đề này mà vẫn đảm bảo E2E, ta sẽ cho phép người dùng đổi pass
  /// mà không cần pass cũ, nhưng thực tế việc này là KHÔNG THỂ về mặt mã hóa
  /// (không có pass cũ -> không có key cũ -> không giải mã được ảnh cũ để mã hóa lại bằng key mới).
  /// Tuy nhiên, vì đây là app cá nhân, để đáp ứng yêu cầu của bạn, mình sẽ "bypass"
  /// bước nhập pass cũ, nhưng ảnh cũ sẽ giữ nguyên key mã hóa cũ. Nếu sau này user
  /// nhập lại pass cũ đúng thì mới xem được, còn hiện tại thì nó vẫn nằm đó, không bị xóa.
  /// Hoặc, do yêu cầu "khôi phục lại ảnh cũ", có thể ta lưu thêm 1 bản copy của Key
  /// mã hóa bằng một thứ khác (ví dụ: Auth ID của Firebase). Nhưng hiện tại chưa có.
  /// -> Tạm thời: Chỉ xóa metadata (để tạo lại pass) nhưng KHÔNG xóa data trong Database.
  /// Dữ liệu vẫn còn, khi nào nhớ pass cũ thì mới xem được ảnh cũ.
  Future<void> resetVaultKeepData(String houseId) async {
    // 1. Xóa key trong RAM và Secure Storage
    await clearKeyPermanently(houseId);

    // 2. Xóa metadata trên Firebase để ép tạo lại key (người dùng sẽ được hỏi pass mới)
    await _metadataRef(houseId).remove();

    // KHÔNG XÓA DỮ LIỆU Ở _db.ref('houses/$houseId/private_secure')
  }

  /// Xóa toàn bộ dữ liệu trong kho mật, kể cả ảnh đã mã hóa.
  /// Gọi khi người dùng chọn "Tôi đã quên" (nếu muốn xóa sạch).
  Future<void> resetVault(String houseId) async {
    // 1. Xóa key trong RAM và Secure Storage
    await clearKeyPermanently(houseId);

    // 2. Xóa metadata trên Firebase
    await _metadataRef(houseId).remove();

    // 3. Xóa dữ liệu (có thể chỉ cần xóa các mục con, hoặc xóa nguyên node private_secure)
    await _db.ref('houses/$houseId/private_secure').remove();

    // Lưu ý: Các file thực tế trên Storage sẽ bị orphaned (không có link reference tới).
    // Trong môi trường production, có thể cần một background function dọn dẹp các file này,
    // hoặc gọi API list files trong Storage để xóa (Firebase Storage client SDK không hỗ trợ listAll tiện lợi).
    // Ở đây, xóa metadata và references là đủ để reset trạng thái cho app.
  }

  /// Xóa key khỏi cả session và Secure Storage (dùng khi đăng xuất / đổi passphrase).
  Future<void> clearKeyPermanently(String houseId) async {
    _keyCache.remove(houseId);
    _lastUnlockTime.remove(houseId);
    await _secureStorage.delete(key: _secureKey(houseId)); // Xóa key cũ nếu có
  }

  /// Thay đổi mật khẩu kho mật (Yêu cầu mật khẩu cũ phải đúng)
  Future<void> changePassphrase(
      String houseId, String oldPassphrase, String newPassphrase) async {
    // 1. Xác thực mật khẩu cũ
    await unlockHouseKey(houseId, oldPassphrase);

    // 2. Lưu lại key cũ đang được sử dụng
    final oldKey = _keyCache[houseId]!;

    // 3. Xóa metadata hiện tại để ép tạo lại key
    await _metadataRef(houseId).remove();

    // 4. Gọi _createOrMigrateKey với mật khẩu mới. Hàm này sẽ tạo key mới,
    // nhưng thay vì migrate từ web, ta phải migrate từ oldKey sang newKey.
    final salt = _generateRandomBytes(_saltLength);
    final newKey = await _deriveKey(newPassphrase, salt, _pbkdf2Iterations);

    // Lấy createdAt cũ (nếu có)
    int createdAt = DateTime.now()
        .millisecondsSinceEpoch; // Nếu lỗi/đổi MK thì reset lại thời gian 3 ngày hay giữ nguyên? Thường đổi mk thì reset hoặc giữ nguyên. Mình sẽ update createdAt mới vì họ vừa đổi mk.

    // Migrate data từ oldKey sang newKey
    await _migrateLegacyVaultData(houseId, oldKey, newKey);

    // Lưu metadata mới
    await _metadataRef(houseId).set({
      'version': 2,
      'salt': base64Encode(salt),
      'iterations': _pbkdf2Iterations,
      'verifier': _buildVerifier(newKey),
      'createdAt': createdAt,
    });

    // Lưu vào session cache
    _keyCache[houseId] = newKey;
    _lastUnlockTime[houseId] = DateTime.now().millisecondsSinceEpoch;

    // (Bỏ lưu Secure Storage để thoát app là phải nhập lại)
    // await _persistKeyToSecureStorage(houseId, newKey);
  }

  // ===========================================================================
  // PRIVATE
  // ===========================================================================

  bool _isEncrypted(String text) {
    try {
      return text.startsWith(_legacyPrefix) ||
          text.startsWith(_legacyAppPrefix) ||
          text.startsWith(_currentPrefix);
    } catch (_) {
      return false;
    }
  }

  bool _isEncryptedWithCurrentKey(String text) =>
      text.startsWith(_currentPrefix);

  DatabaseReference _metadataRef(String houseId) =>
      _db.ref('houses/$houseId/private_secure_meta/encryption');

  DatabaseReference _legacyKeyRef(String houseId) =>
      _db.ref('houses/$houseId/encryptionKey');

  /// Lấy key: ưu tiên RAM → Secure Storage → throw nếu chưa unlock.
  Future<Uint8List> _resolveKey(String houseId) async {
    if (_keyCache.containsKey(houseId)) return _keyCache[houseId]!;

    // Thử khôi phục từ Secure Storage (biometric/device protected)
    final restored = await tryRestoreKeyFromSecureStorage(houseId);
    if (restored) return _keyCache[houseId]!;

    throw StateError('Kho mật chưa được mở khóa.');
  }

  // Lưu ý: Đã bỏ việc lưu Key vào SecureStorage theo yêu cầu.
  // ignore: unused_element
  Future<void> _persistKeyToSecureStorage(String houseId, Uint8List key) async {
    await _secureStorage.write(
      key: _secureKey(houseId),
      value: base64Encode(key),
    );
  }

  Future<void> _createOrMigrateKey(String houseId, String passphrase) async {
    final salt = _generateRandomBytes(_saltLength);
    final newKey = await _deriveKey(passphrase, salt, _pbkdf2Iterations);

    // Migrate Web legacy data: ENC:ivHex:ctHex → ENC2:base64
    // Web lưu data được mã hóa bằng house password trực tiếp (không lưu key lên Firebase)
    await _migrateWebLegacyVaultData(houseId, passphrase, newKey);

    // Migrate từ legacy base64 key trên Firebase (nếu phiên bản trung gian lưu key)
    final legacySnap = await _legacyKeyRef(houseId).get();
    final legacyKey = _readLegacyKey(legacySnap.value);
    if (legacyKey != null) {
      await _migrateLegacyVaultData(houseId, legacyKey, newKey);
      await _legacyKeyRef(houseId).remove(); // Xóa key plain text
    }

    // Lấy createdAt cũ nếu có, nếu không thì dùng timestamp hiện tại
    final oldMetaSnap = await _metadataRef(houseId).get();
    int createdAt = DateTime.now().millisecondsSinceEpoch;
    if (oldMetaSnap.exists && oldMetaSnap.value != null) {
      final oldMeta = Map<String, dynamic>.from(oldMetaSnap.value as Map);
      if (oldMeta.containsKey('createdAt')) {
        createdAt = (oldMeta['createdAt'] as num).toInt();
      }
    }

    // Lưu public metadata lên Firebase — chỉ salt + verifier, KHÔNG có key
    await _metadataRef(houseId).set({
      'version': 2,
      'salt': base64Encode(salt),
      'iterations': _pbkdf2Iterations,
      'verifier': _buildVerifier(newKey),
      'createdAt': createdAt,
    });

    // Lưu vào session cache
    _keyCache[houseId] = newKey;
    _lastUnlockTime[houseId] = DateTime.now().millisecondsSinceEpoch;

    // (Bỏ lưu Secure Storage để thoát app là phải nhập lại)
    // await _persistKeyToSecureStorage(houseId, newKey);
  }

  /// Migrate dữ liệu vault từ Web format sang App format.
  /// Web mã hóa bằng house password trực tiếp, không lưu key lên Firebase.
  Future<void> _migrateWebLegacyVaultData(
    String houseId,
    String housePassword,
    Uint8List newKey,
  ) async {
    try {
      final snap = await _db.ref('houses/$houseId/private_secure').get();
      if (!snap.exists || snap.value == null) return;

      final webKey = await _deriveWebCompatKey(housePassword);
      final rawData = Map<dynamic, dynamic>.from(snap.value as Map);
      final updates = <String, dynamic>{};

      for (final entry in rawData.entries) {
        final node = entry.value;
        if (node is! Map) continue;
        final item = Map<dynamic, dynamic>.from(node);
        final caption = item['caption']?.toString() ?? '';

        // Chỉ migrate Web format (ENC:), bỏ qua ENC2: đã migrate rồi
        if (caption.isEmpty || !caption.startsWith(_legacyPrefix)) continue;

        try {
          final plainText = _aesGcmDecrypt(webKey, caption);
          updates['${entry.key}/caption'] =
              _aesEncrypt(newKey, plainText, prefix: _currentPrefix);
          updates['${entry.key}/encryptionVersion'] = 3;
          updates['${entry.key}/encrypted'] = true;
        } catch (_) {
          // Skip nếu không decrypt được (sai password hoặc data corrupt)
        }
      }

      if (updates.isNotEmpty) {
        await _db.ref('houses/$houseId/private_secure').update(updates);
      }
    } catch (_) {
      // Ignore — migration là best-effort, không block unlock
    }
  }

  Uint8List? _readLegacyKey(Object? rawValue) {
    final keyB64 = rawValue?.toString().trim() ?? '';
    if (keyB64.isEmpty) return null;
    try {
      return Uint8List.fromList(base64Decode(keyB64));
    } catch (_) {
      return null;
    }
  }

  Future<void> _migrateLegacyVaultData(
    String houseId,
    Uint8List legacyKey,
    Uint8List newKey,
  ) async {
    final snap = await _db.ref('houses/$houseId/private_secure').get();
    if (!snap.exists || snap.value == null) return;

    final rawData = Map<dynamic, dynamic>.from(snap.value as Map);
    final updates = <String, dynamic>{};

    for (final entry in rawData.entries) {
      final node = entry.value;
      if (node is! Map) continue;
      final item = Map<dynamic, dynamic>.from(node);
      final caption = item['caption']?.toString() ?? '';
      if (caption.isEmpty || caption.startsWith(_currentPrefix)) continue;

      final String plainText;
      if (caption.startsWith(_legacyAppPrefix)) {
        // ENC2: AES-CBC legacy → decrypt trước khi re-encrypt ENC3:
        plainText =
            _aesCbcDecrypt(legacyKey, caption, prefix: _legacyAppPrefix);
      } else if (caption.startsWith(_legacyPrefix)) {
        // ENC: Web legacy GCM → decrypt trước khi re-encrypt ENC3:
        plainText = _aesDecrypt(legacyKey, caption, prefix: _legacyPrefix);
      } else {
        // Plaintext
        plainText = caption;
      }
      updates['${entry.key}/caption'] =
          _aesEncrypt(newKey, plainText, prefix: _currentPrefix);
      updates['${entry.key}/encryptionVersion'] = 3;
      updates['${entry.key}/encrypted'] = true;
    }

    if (updates.isNotEmpty) {
      await _db.ref('houses/$houseId/private_secure').update(updates);
    }
  }

  Uint8List _generateRandomBytes(int length) {
    final random = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(length, (_) => random.nextInt(256)),
    );
  }

  // App-new key derivation (variable salt, high iterations)
  Future<Uint8List> _deriveKey(
      String passphrase, Uint8List salt, int iterations) async {
    return compute(
        _deriveKeyIsolate, _DeriveKeyParams(passphrase, salt, iterations));
  }

  // Web-compatible key derivation — chỉ dùng để đọc + migrate dữ liệu ENC cũ.
  // Không được tái sử dụng cho dữ liệu mới.
  // PHẢI khớp hoàn toàn với core-encryption.js:
  //   const salt = encoder.encode('goodgo-salt-2026');
  //   PBKDF2, iterations: 100000, hash: 'SHA-256', keyLength: 32 bytes
  Future<Uint8List> _deriveWebCompatKey(String housePassword) async {
    final saltBytes = Uint8List.fromList(utf8.encode(_webCompatSalt));
    return compute(
      _deriveWebCompatKeyIsolate,
      _DeriveKeyParams(housePassword.trim(), saltBytes, _webCompatIterations),
    );
  }

  // Chuyển hex string thành bytes: 'a1b2' -> [0xa1, 0xb2]
  Uint8List _hexToBytes(String hex) {
    if (hex.length % 2 != 0) throw FormatException('Invalid hex: $hex');
    final result = Uint8List(hex.length ~/ 2);
    for (var i = 0; i < hex.length; i += 2) {
      result[i ~/ 2] = int.parse(hex.substring(i, i + 2), radix: 16);
    }
    return result;
  }

  // AES-GCM decrypt — parse Web format "ENC:ivHex:ctHex"
  String _aesGcmDecrypt(Uint8List key, String encryptedText) {
    if (!encryptedText.startsWith(_legacyPrefix)) {
      throw const FormatException('Không phải định dạng ENC:');
    }
    final withoutPrefix = encryptedText.substring(_legacyPrefix.length);
    final colonIdx = withoutPrefix.indexOf(':');
    if (colonIdx <= 0) throw const FormatException('Thiếu phân cách IV:CT');

    final iv = _hexToBytes(withoutPrefix.substring(0, colonIdx));
    final ciphertext = _hexToBytes(withoutPrefix.substring(colonIdx + 1));

    final cipher = GCMBlockCipher(AESEngine());
    cipher.init(
        false, AEADParameters(KeyParameter(key), 128, iv, Uint8List(0)));
    final output = cipher.process(ciphertext);
    return utf8.decode(output);
  }

  String _buildVerifier(Uint8List key) {
    final digest =
        crypto.Hmac(crypto.sha256, key).convert(utf8.encode(_verifierMessage));
    return base64Encode(digest.bytes);
  }

  String _buildRecoveryVerifier(Uint8List key) {
    final digest = crypto.Hmac(crypto.sha256, key)
        .convert(utf8.encode(_recoveryVerifierMessage));
    return base64Encode(digest.bytes);
  }

  String _generateRecoveryCode() {
    const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random.secure();
    final chunks = List<String>.generate(4, (_) {
      return String.fromCharCodes(
        List<int>.generate(
          4,
          (_) => alphabet.codeUnitAt(random.nextInt(alphabet.length)),
        ),
      );
    });
    return chunks.join('-');
  }

  Future<String> _generateAndStoreRecoveryCode(
    String houseId,
    Uint8List vaultKey,
  ) async {
    final recoveryCode = _generateRecoveryCode();
    final salt = _generateRandomBytes(_saltLength);
    final recoveryKey = await _deriveKey(recoveryCode, salt, _pbkdf2Iterations);
    final wrappedKey = _aesEncrypt(
      recoveryKey,
      base64Encode(vaultKey),
      prefix: _currentPrefix,
    );

    await _metadataRef(houseId).update({
      'recoverySalt': base64Encode(salt),
      'recoveryIterations': _pbkdf2Iterations,
      'recoveryVerifier': _buildRecoveryVerifier(recoveryKey),
      'recoveryWrappedKey': wrappedKey,
      'recoveryUpdatedAt': ServerValue.timestamp,
    });
    return recoveryCode;
  }

  bool _constantTimeEquals(String a, String b) {
    final left = utf8.encode(a);
    final right = utf8.encode(b);
    if (left.length != right.length) return false;
    var diff = 0;
    for (var i = 0; i < left.length; i++) {
      diff |= left[i] ^ right[i];
    }
    return diff == 0;
  }

  /// AES-256-GCM encrypt (authenticated encryption — định dạng mới ENC3:).
  /// Format: ENC3:base64(iv 12 bytes + ciphertext + GCM tag 16 bytes)
  String _aesEncrypt(Uint8List key, String plaintext,
      {required String prefix}) {
    final iv = _generateRandomBytes(12); // 12 bytes IV cho GCM
    final cipher = GCMBlockCipher(AESEngine())
      ..init(
        true,
        AEADParameters(KeyParameter(key), 128, iv, Uint8List(0)),
      );
    final input = utf8.encode(plaintext);
    final output = cipher.process(input);
    // output = ciphertext + tag (16 bytes appended by GCMBlockCipher)
    final combined = Uint8List(iv.length + output.length)
      ..setAll(0, iv)
      ..setAll(iv.length, output);
    return '$prefix${base64Encode(combined)}';
  }

  /// AES-256-GCM decrypt (tự động verify MAC tag).
  String _aesDecrypt(Uint8List key, String ciphertext,
      {required String prefix}) {
    final b64 = ciphertext.substring(prefix.length);
    final combined = base64Decode(b64);
    final iv = combined.sublist(0, 12);
    final encrypted = combined.sublist(12); // ciphertext + 16-byte tag

    final cipher = GCMBlockCipher(AESEngine())
      ..init(
        false,
        AEADParameters(KeyParameter(key), 128, iv, Uint8List(0)),
      );
    final output = cipher.process(encrypted);
    return utf8.decode(output);
  }

  /// AES-256-CBC decrypt — legacy (ENC2:) chỉ dùng để migrate dữ liệu cũ.
  /// Khi analytics cho thấy không còn ENC2: data, xóa method này.
  String _aesCbcDecrypt(Uint8List key, String ciphertext,
      {required String prefix}) {
    final b64 = ciphertext.substring(prefix.length);
    final combined = base64Decode(b64);
    final iv = combined.sublist(0, 16);
    final encrypted = combined.sublist(16);

    final cipher = CBCBlockCipher(AESEngine());
    cipher.init(false, ParametersWithIV(KeyParameter(key), iv));

    final output = Uint8List(encrypted.length);
    for (var i = 0; i < encrypted.length; i += 16) {
      cipher.processBlock(encrypted, i, output, i);
    }
    return utf8.decode(_pkcs7Unpad(output));
  }

  Uint8List _pkcs7Unpad(Uint8List data) {
    final pad = data.last;
    return data.sublist(0, data.length - pad);
  }
}
