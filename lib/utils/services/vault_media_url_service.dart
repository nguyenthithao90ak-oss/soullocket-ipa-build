import 'dart:async';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

class VaultMediaUrlResult {
  const VaultMediaUrlResult({required this.url, required this.expiresAt});

  final String url;
  final int expiresAt;
}

class VaultMediaUrlService {
  VaultMediaUrlService._();
  static final instance = VaultMediaUrlService._();

  final _cache = <String, VaultMediaUrlResult>{};
  final _inFlight = <String, Future<String>>{};
  int _cacheGeneration = 0;

  /// Resolve a storagePath to a signed URL.
  /// Returns the signed URL string.
  /// Caches results until expiry.
  Future<String> resolveUrl({
    required String storagePath,
    required String houseId,
    required String mediaId,
  }) async {
    final normalizedPath = storagePath.trim();
    final normalizedHouseId = houseId.trim();
    final normalizedMediaId = mediaId.trim();
    if (normalizedPath.isEmpty ||
        normalizedHouseId.isEmpty ||
        normalizedMediaId.isEmpty) {
      return '';
    }

    final cacheKey = '$normalizedHouseId/$normalizedMediaId/$normalizedPath';
    final cached = _cache[cacheKey];
    if (cached != null &&
        cached.expiresAt >
            DateTime.now().millisecondsSinceEpoch +
                const Duration(minutes: 1).inMilliseconds) {
      return cached.url;
    }

    final pending = _inFlight[cacheKey];
    if (pending != null) return pending;

    final generation = _cacheGeneration;
    final request = _fetchSignedUrl(
      cacheKey: cacheKey,
      generation: generation,
      storagePath: normalizedPath,
      houseId: normalizedHouseId,
      mediaId: normalizedMediaId,
    );
    _inFlight[cacheKey] = request;
    try {
      return await request;
    } finally {
      if (identical(_inFlight[cacheKey], request)) {
        _inFlight.remove(cacheKey);
      }
    }
  }

  Future<String> _fetchSignedUrl({
    required String cacheKey,
    required int generation,
    required String storagePath,
    required String houseId,
    required String mediaId,
  }) async {
    try {
      final callable = FirebaseFunctions.instance.httpsCallable(
        'generateReadUrl',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 15)),
      );
      final result = await callable.call<Map<String, dynamic>>({
        'storagePath': storagePath,
        'houseId': houseId,
        'mediaId': mediaId,
      });

      final data = result.data;
      final url = data['url']?.toString().trim() ?? '';
      final rawExpiresAt = data['expiresAt'];
      final expiresAt = rawExpiresAt is num
          ? rawExpiresAt.toInt()
          : int.tryParse(rawExpiresAt?.toString() ?? '') ?? 0;

      if (generation == _cacheGeneration &&
          url.isNotEmpty &&
          expiresAt > DateTime.now().millisecondsSinceEpoch) {
        _cache[cacheKey] = VaultMediaUrlResult(url: url, expiresAt: expiresAt);
      }
      return url;
    } catch (e) {
      debugPrint('[VaultMedia] Failed to resolve URL: $e');
      return '';
    }
  }

  /// Dữ liệu rất cũ không có storagePath vẫn cần hiển thị để người dùng
  /// có thể tải/xóa. Dữ liệu mới tuyệt đối không dùng URL công khai này.
  static bool isPublicUrl(String? url) {
    if (url == null || url.isEmpty) return false;
    return url.startsWith('http://') || url.startsWith('https://');
  }

  void clearCache() {
    _cache.clear();
    _cacheGeneration++;
  }
}
