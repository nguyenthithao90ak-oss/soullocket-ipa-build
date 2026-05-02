import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  static final SecureStorageService instance = SecureStorageService._internal();
  
  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock_this_device),
  );

  SecureStorageService._internal();

  // Keys for sensitive data
  static const String keyAuthToken = 'il_auth_token';
  static const String keyUserPin = 'il_custom_lock';
  static const String keyPinSalt = 'il_custom_lock_salt';
  static const String keyAuthUid = 'il_auth_uid';

  Future<void> write(String key, String value) async {
    await _storage.write(key: key, value: value);
  }

  Future<String?> read(String key) async {
    return await _storage.read(key: key);
  }

  Future<void> delete(String key) async {
    await _storage.delete(key: key);
  }

  Future<void> deleteAll() async {
    await _storage.deleteAll();
  }

  /// Migrates a key from SharedPreferences to SecureStorage if it exists
  Future<void> migrateFromPrefs(String key, String? value) async {
    if (value != null && value.isNotEmpty) {
      await write(key, value);
    }
  }
}
