import 'dart:async';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class VaultMediaUrlResult {
  const VaultMediaUrlResult({required this.url, required this.expiresAt});

  final String url;
  final int expiresAt;
}

class VaultMediaUrlService {
  VaultMediaUrlService._()
    : _currentUid = (() => FirebaseAuth.instance.currentUser?.uid),
      _loadUrl = _loadFromCallable {
    _scopeUid = _currentUid();
    // Singleton sống cùng ứng dụng; xóa cả khi đăng xuất rồi đăng nhập lại cùng UID.
    _authSubscription = FirebaseAuth.instance
        .authStateChanges()
        .map((user) => user?.uid)
        .listen(_syncAccount);
  }

  @visibleForTesting
  VaultMediaUrlService.forTesting(
    this._currentUid,
    this._loadUrl, {
    Stream<String?>? authChanges,
  }) {
    _scopeUid = _currentUid();
    _authSubscription = authChanges?.listen(_syncAccount);
  }

  static final instance = VaultMediaUrlService._();

  final String? Function() _currentUid;
  final Future<VaultMediaUrlResult> Function(Map<String, dynamic>) _loadUrl;
  String? _scopeUid;
  StreamSubscription<String?>? _authSubscription;

  void _syncAccount(String? uid) {
    if (_scopeUid == uid) return;
    clearCache();
    _scopeUid = uid;
  }

  Future<void> dispose() async {
    clearCache();
    await _authSubscription?.cancel();
    _authSubscription = null;
  }

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
    final uid = _currentUid();
    _syncAccount(uid);
    if (uid == null || uid.isEmpty) return '';
    final normalizedPath = storagePath.trim();
    final normalizedHouseId = houseId.trim();
    final normalizedMediaId = mediaId.trim();
    if (normalizedPath.isEmpty ||
        normalizedHouseId.isEmpty ||
        normalizedMediaId.isEmpty) {
      return '';
    }

    final cacheKey =
        '$uid/$normalizedHouseId/$normalizedMediaId/$normalizedPath';
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
      uid: uid,
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
    required String uid,
    required String storagePath,
    required String houseId,
    required String mediaId,
  }) async {
    try {
      final result = await _loadUrl({
        'storagePath': storagePath,
        'houseId': houseId,
        'mediaId': mediaId,
      });

      // Không trả kết quả cũ sau khi khóa Hầm, rời màn hình hoặc đổi tài khoản.
      if (generation != _cacheGeneration || uid != _currentUid()) return '';
      final url = result.url.trim();
      final uri = Uri.tryParse(url);
      if (uri == null ||
          uri.scheme != 'https' ||
          uri.host.isEmpty ||
          uri.userInfo.isNotEmpty ||
          result.expiresAt <= DateTime.now().millisecondsSinceEpoch) {
        return '';
      }
      _cache[cacheKey] = VaultMediaUrlResult(
        url: url,
        expiresAt: result.expiresAt,
      );
      return url;
    } catch (_) {
      // Lỗi provider có thể chứa URL đã ký; không đưa credential vào log.
      debugPrint('[VaultMedia] Failed to resolve URL');
      return '';
    }
  }

  static Future<VaultMediaUrlResult> _loadFromCallable(
    Map<String, dynamic> payload,
  ) async {
    final callable = FirebaseFunctions.instance.httpsCallable(
      'generateReadUrl',
      options: HttpsCallableOptions(timeout: const Duration(seconds: 15)),
    );
    final result = await callable.call<Map<String, dynamic>>(payload);
    final data = result.data;
    final rawExpiresAt = data['expiresAt'];
    return VaultMediaUrlResult(
      url: data['url']?.toString().trim() ?? '',
      expiresAt: rawExpiresAt is num
          ? rawExpiresAt.toInt()
          : int.tryParse(rawExpiresAt?.toString() ?? '') ?? 0,
    );
  }

  /// Dữ liệu rất cũ không có storagePath vẫn cần hiển thị để người dùng
  /// có thể tải/xóa. Dữ liệu mới tuyệt đối không dùng URL công khai này.
  static bool isPublicUrl(String? url) {
    if (url == null || url.isEmpty) return false;
    return url.startsWith('http://') || url.startsWith('https://');
  }

  void clearCache() {
    _cache.clear();
    _inFlight.clear();
    _cacheGeneration++;
  }
}
