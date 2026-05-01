import 'package:flutter/foundation.dart';

class OfflineCachePolicy {
  const OfflineCachePolicy();

  static const int maxCacheAgeMs = 7 * 24 * 60 * 60 * 1000;

  static const Set<String> databaseBackedKeys = {
    'community_unified_feed',
  };

  bool shouldUseDatabase(String key) {
    return !kIsWeb && databaseBackedKeys.contains(key);
  }

  bool isExpired(int timestampMs, {int? nowMs}) {
    final now = nowMs ?? DateTime.now().millisecondsSinceEpoch;
    return now - timestampMs > maxCacheAgeMs;
  }
}
