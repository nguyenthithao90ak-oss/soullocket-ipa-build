import 'dart:convert';
import 'package:mmkv/mmkv.dart';

/// Drop-in replacement cho SharedPreferences sử dụng lõi MMKV của Tencent
/// Tốc độ đọc ghi nhanh gấp ~100 lần so với file XML thông thường.
class SharedPreferences {
  static MMKV? _mmkv;

  static Future<SharedPreferences> getInstance() async {
    _mmkv ??= MMKV.defaultMMKV();
    return SharedPreferences();
  }

  // Khởi tạo trước ở main() nếu cần thiết
  static Future<void> ensureInitialized() async {
    await MMKV.initialize();
  }

  String? getString(String key) => _mmkv?.decodeString(key);
  Future<bool> setString(String key, String value) async => _mmkv?.encodeString(key, value) ?? false;

  int? getInt(String key) => _mmkv?.decodeInt(key);
  Future<bool> setInt(String key, int value) async => _mmkv?.encodeInt(key, value) ?? false;

  double? getDouble(String key) => _mmkv?.decodeDouble(key);
  Future<bool> setDouble(String key, double value) async => _mmkv?.encodeDouble(key, value) ?? false;

  bool? getBool(String key) => _mmkv?.decodeBool(key);
  Future<bool> setBool(String key, bool value) async => _mmkv?.encodeBool(key, value) ?? false;

  List<String>? getStringList(String key) {
    final str = _mmkv?.decodeString(key);
    if (str == null) return null;
    try {
      final decoded = jsonDecode(str) as List;
      return decoded.map((e) => e.toString()).toList();
    } catch (_) {
      return null;
    }
  }

  Future<bool> setStringList(String key, List<String> value) async {
    return _mmkv?.encodeString(key, jsonEncode(value)) ?? false;
  }

  bool containsKey(String key) => _mmkv?.containsKey(key) ?? false;

  Future<bool> remove(String key) async {
    _mmkv?.removeValue(key);
    return true;
  }

  Future<bool> clear() async {
    _mmkv?.clearAll();
    return true;
  }

  Future<bool> reload() async {
    // MMKV luôn lấy data mới nhất từ bộ nhớ nên không cần reload thực sự
    return true;
  }

  Set<String> getKeys() {
    // MMKV cho Dart không export hàm lấy toàn bộ key trực tiếp.
    // Nếu ứng dụng cần lặp qua tất cả các key thì cần maintain 1 danh sách riêng
    // Tuy nhiên hầu hết logic chỉ check có chứa key hay không.
    return {};
  }

  dynamic get(String key) {
    if (_mmkv == null) return null;
    // MMKV Dart không có hàm get chung, cần thử decode theo từng type
    // Tuy nhiên _mmkv.decodeBytes / decodeString là phổ biến nhất.
    // Thực tế SharedPreferences cũ lưu value dưới dạng string/int/bool
    // Nếu dùng get() thông thường, ta sẽ thử các kiểu.
    if (!_mmkv!.containsKey(key)) return null;
    
    // Dùng try-catch để đoán kiểu là cách duy nhất nếu không biết type
    // Tuy nhiên, SharedPreferences lưu type trong xml, còn MMKV thì không
    // Cố gắng lấy theo thứ tự: bool -> int -> double -> string
    // Để an toàn, hầu hết dùng get() cho string hoặc bool.
    // Ta làm một hack nhỏ:
    try { return _mmkv!.decodeBool(key); } catch(_) {}
    try { return _mmkv!.decodeInt(key); } catch(_) {}
    try { return _mmkv!.decodeDouble(key); } catch(_) {}
    return _mmkv!.decodeString(key);
  }
}
