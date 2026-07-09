import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  static final SecureStorageService instance = SecureStorageService._internal();

  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(),
    iOptions: IOSOptions(
        accessibility: KeychainAccessibility.first_unlock_this_device),
  );

  SecureStorageService._internal();

  // Keys for sensitive data
  static const String keyAuthToken = 'il_auth_token';
  static const String keyUserPin = 'il_custom_lock';
  static const String keyPinSalt = 'il_custom_lock_salt';
  static const String keyAuthUid = 'il_auth_uid';
  static const String keyHouseId = 'il_house_id';
  static const String keyRole = 'il_role';
  static const String keyRelMode = 'il_rel_mode';
  Future<void> write(String key, String value) async {
    try {
      await _storage.write(key: key, value: value).timeout(const Duration(seconds: 2));
    } catch (_) {}
  }

  Future<String?> read(String key) async {
    try {
      return await _storage.read(key: key).timeout(const Duration(seconds: 2));
    } catch (_) {
      return null;
    }
  }

  Future<void> delete(String key) async {
    try {
      await _storage.delete(key: key).timeout(const Duration(seconds: 2));
    } catch (_) {}
  }

  Future<void> deleteAll() async {
    try {
      await _storage.deleteAll().timeout(const Duration(seconds: 2));
    } catch (_) {}
  }

  /// Migrates a key from SharedPreferences to SecureStorage if it exists
  Future<void> migrateFromPrefs(String key, String? value) async {
    if (value != null && value.isNotEmpty) {
      await write(key, value);
    }
  }
}
