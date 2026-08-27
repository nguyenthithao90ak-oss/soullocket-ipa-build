import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class ApiCacheManager {
  static const String _prefix = 'api_cache_';

  static Future<void> saveCache(String key, dynamic data, Duration expiration) async {
    final prefs = await SharedPreferences.getInstance();
    final cacheData = {
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'expiration': expiration.inMilliseconds,
      'data': data,
    };
    await prefs.setString('$_prefix$key', jsonEncode(cacheData));
  }

  static Future<dynamic> getCache(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final cachedString = prefs.getString('$_prefix$key');
    
    if (cachedString != null) {
      try {
        final cacheData = jsonDecode(cachedString) as Map<String, dynamic>;
        final timestamp = cacheData['timestamp'] as int;
        final expiration = cacheData['expiration'] as int;
        
        if (DateTime.now().millisecondsSinceEpoch - timestamp < expiration) {
          return cacheData['data'];
        } else {
          await prefs.remove('$_prefix$key');
        }
      } catch (e) {
        await prefs.remove('$_prefix$key');
      }
    }
    return null;
  }
}
