import 'dart:async';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

class VaultMediaUrlResult {
  final String url;
  final int expiresAt;
  VaultMediaUrlResult({required this.url, required this.expiresAt});
}

class VaultMediaUrlService {
  VaultMediaUrlService._();
  static final instance = VaultMediaUrlService._();

  final _cache = <String, VaultMediaUrlResult>{};

  /// Resolve a storagePath to a signed URL.
  /// Returns the signed URL string.
  /// Caches results until expiry.
  Future<String> resolveUrl({
    required String storagePath,
    required String houseId,
  }) async {
    final cacheKey = '$houseId/$storagePath';
    final cached = _cache[cacheKey];
    if (cached != null && cached.expiresAt > DateTime.now().millisecondsSinceEpoch + 60000) {
      return cached.url;
    }

    try {
      final callable = FirebaseFunctions.instance.httpsCallable(
        'generateReadUrl',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 15)),
      );
      final result = await callable.call<Map<String, dynamic>>({
        'storagePath': storagePath,
        'houseId': houseId,
      });

      final data = result.data;
      final url = (data['url'] ?? '') as String;
      final expiresAt = (data['expiresAt'] ?? 0) as int;

      if (url.isNotEmpty) {
        _cache[cacheKey] = VaultMediaUrlResult(url: url, expiresAt: expiresAt);
      }
      return url;
    } catch (e) {
      debugPrint('[VaultMedia] Failed to resolve URL: $e');
      return '';
    }
  }

  /// Check if a URL string looks like a public R2 URL (legacy entry)
  static bool isPublicUrl(String? url) {
    if (url == null || url.isEmpty) return false;
    return url.startsWith('http://') || url.startsWith('https://');
  }

  void clearCache() => _cache.clear();
}
