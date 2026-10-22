import 'package:shared_preferences/shared_preferences.dart';

/// Đồng ý gửi dữ liệu cho nhà xử lý AI, tách biệt với consent phân tích/quảng cáo.
class AiDataConsent {
  static const version = 'cloudflare-v1-2026-10-21';
  static String key(String uid) => 'ai_data_consent_${version}_$uid';

  static Future<bool> hasConsent(String uid) async {
    if (uid.isEmpty) return false;
    return (await SharedPreferences.getInstance()).getBool(key(uid)) == true;
  }

  static Future<void> setConsent(String uid, bool accepted) async {
    if (uid.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final saved = accepted
        ? await prefs.setBool(key(uid), true)
        : await prefs.remove(key(uid));
    if (!saved) throw StateError('ai_data_consent_not_saved');
  }
}
