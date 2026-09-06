import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../core/constants/app_config.dart';
import 'admob_service.dart';

class MemoryLimits {
  const MemoryLimits({
    required this.shareMaxItems,
    required this.shareFreeMaxItems,
    required this.shareProMaxItems,
    required this.shareDefaultTtlDays,
    required this.shareMaxTtlDays,
    required this.imageFreeDailyLimit,
    required this.imageProDailyLimit,
  });

  factory MemoryLimits.fromMap(Map<dynamic, dynamic> data) {
    final shareMaxTtlDays = _readLimitInt(
      data['shareMaxTtlDays'],
      fallbackMemoryLimits.shareMaxTtlDays,
    ).clamp(1, 365).toInt();

    final shareFreeMaxItems = _readLimitInt(
      data['shareFreeMaxItems'],
      fallbackMemoryLimits.shareFreeMaxItems,
    ).clamp(1, 500).toInt();

    final shareProMaxItems = _readLimitInt(
      data['shareProMaxItems'],
      fallbackMemoryLimits.shareProMaxItems,
    ).clamp(1, 1000).toInt();

    return MemoryLimits(
      shareMaxItems: _readLimitInt(
        data['shareMaxItems'],
        fallbackMemoryLimits.shareMaxItems,
      ).clamp(1, 1000).toInt(),
      shareFreeMaxItems: shareFreeMaxItems,
      shareProMaxItems: shareProMaxItems,
      shareDefaultTtlDays: _readLimitInt(
        data['shareDefaultTtlDays'],
        fallbackMemoryLimits.shareDefaultTtlDays,
      ).clamp(1, shareMaxTtlDays).toInt(),
      shareMaxTtlDays: shareMaxTtlDays,
      imageFreeDailyLimit: _readLimitInt(
        data['imageFreeDailyLimit'],
        fallbackMemoryLimits.imageFreeDailyLimit,
      ).clamp(0, 1000).toInt(),
      imageProDailyLimit: _readLimitInt(
        data['imageProDailyLimit'],
        fallbackMemoryLimits.imageProDailyLimit,
      ).clamp(0, 1000).toInt(),
    );
  }

  final int shareMaxItems;
  final int shareFreeMaxItems;
  final int shareProMaxItems;
  final int shareDefaultTtlDays;
  final int shareMaxTtlDays;
  final int imageFreeDailyLimit;
  final int imageProDailyLimit;
}

const MemoryLimits fallbackMemoryLimits = MemoryLimits(
  shareMaxItems: 24,
  shareFreeMaxItems: 50,
  shareProMaxItems: 200,
  shareDefaultTtlDays: 7,
  shareMaxTtlDays: 183,
  imageFreeDailyLimit: 10,
  imageProDailyLimit: 30,
);

int _readLimitInt(Object? value, int fallback) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

class MemoryShareResult {
  const MemoryShareResult({
    required this.token,
    required this.url,
    required this.expiresAt,
    required this.photoCount,
  });

  final String token;
  final String url;
  final int expiresAt;
  final int photoCount;
}

class MemoryShareService {
  MemoryShareService({FirebaseAuth? auth})
    : _auth = auth ?? FirebaseAuth.instance;

  static int get maxPhotosPerShare => fallbackMemoryLimits.shareMaxItems;
  static const String defaultShareTitle = 'Kỷ niệm của chúng mình';
  static const String defaultShareDescription =
      'SoulLocket lưu giữ những khoảnh khắc riêng tư của hai bạn và biến chúng thành album kỷ niệm dễ chia sẻ.';
  static const String defaultBrandLabel = 'SoulLocket Memories';
  static const String defaultTheme = 'soullocket_dream';

  final FirebaseAuth _auth;

  static MemoryLimits? _cachedLimits;
  static DateTime? _lastFetchTime;

  Future<MemoryLimits> fetchLimits() async {
    if (_cachedLimits != null && _lastFetchTime != null) {
      if (DateTime.now().difference(_lastFetchTime!) <
          const Duration(hours: 1)) {
        return _cachedLimits!;
      }
    }
    try {
      final resp = await _workerPost('/api/getMemoryLimits', {});
      final raw = resp['result'];
      if (raw is Map) {
        _cachedLimits = MemoryLimits.fromMap(raw);
        _lastFetchTime = DateTime.now();
        return _cachedLimits!;
      }
    } catch (error) {
      debugPrint('[MemoryShareService] Cannot load sharing limits: $error');
    }
    return fallbackMemoryLimits;
  }

  Future<MemoryShareResult> createShareLink({
    required String houseId,
    required List<Map<String, dynamic>> photos,
    int expiryDays = 7,
    String? password,
  }) async {
    final normalizedHouseId = houseId.trim();
    if (normalizedHouseId.isEmpty) {
      throw Exception('Chưa có mã nhà để tạo liên kết.');
    }

    final limits = await fetchLimits();
    final isPro = await AdMobService().isProUser();
    final maxItems = isPro ? limits.shareProMaxItems : limits.shareFreeMaxItems;
    if (photos.length > maxItems) {
      throw Exception(
        'Mỗi liên kết chỉ hỗ trợ tối đa $maxItems ảnh đối với tài khoản ${isPro ? 'PRO' : 'thường'}.',
      );
    }
    final safePhotos = _sanitizePhotos(photos, maxItems);
    if (safePhotos.isEmpty) {
      throw Exception('Chưa có ảnh hợp lệ để tạo liên kết.');
    }
    final resolvedExpiryDays = expiryDays
        .clamp(1, limits.shareMaxTtlDays)
        .toInt();

    final payload = <String, dynamic>{
      'houseId': normalizedHouseId,
      'photos': safePhotos,
      'expiryDays': resolvedExpiryDays,
      'title': defaultShareTitle,
      'description': defaultShareDescription,
      'brandLabel': defaultBrandLabel,
      'theme': defaultTheme,
      if (password != null && password.trim().isNotEmpty)
        'password': password.trim(),
    };
    final response = await _workerPost('/api/createMemoryShareLink', payload);
    final raw = response['result'];
    if (raw is! Map) throw Exception('Phản hồi tạo liên kết không hợp lệ.');
    final data = Map<String, dynamic>.from(raw);
    final token = data['token']?.toString().trim() ?? '';
    if (token.isEmpty) throw Exception('Máy chủ chưa trả mã liên kết.');

    return MemoryShareResult(
      token: token,
      url: _buildPublicUrl(token, data['url']?.toString().trim() ?? ''),
      expiresAt: _readInt(data['expiresAt']),
      photoCount: _readInt(data['photoCount'], fallback: safePhotos.length),
    );
  }

  Future<void> revokeShareLink(String token) async {
    final normalizedToken = token.trim();
    if (normalizedToken.isEmpty)
      throw Exception('Thiếu token liên kết để thu hồi.');
    await _workerPost('/api/revokeMemoryShareLink', {'token': normalizedToken});
  }

  List<Map<String, dynamic>> _sanitizePhotos(
    List<Map<String, dynamic>> photos,
    int maxItems,
  ) {
    final sanitized = <Map<String, dynamic>>[];
    for (final photo in photos) {
      if (sanitized.length >= maxItems) break;
      final url = _firstShareableUrl(photo);
      if (url.isEmpty) continue;
      final previewUrl = _firstShareableUrl(photo, preferPreview: true);
      sanitized.add(<String, dynamic>{
        'id': photo['id']?.toString().trim() ?? '',
        'url': url,
        'previewUrl': previewUrl.isNotEmpty ? previewUrl : url,
        'ts': _readInt(photo['ts'] ?? photo['timestamp'] ?? photo['date']),
        'authorName': photo['authorName']?.toString().trim() ?? '',
      });
    }
    return sanitized;
  }

  String _firstShareableUrl(
    Map<String, dynamic> photo, {
    bool preferPreview = false,
  }) {
    final keys = preferPreview
        ? const ['previewUrl', 'thumbUrl', 'thumbnailUrl', 'url', 'downloadUrl']
        : const [
            'url',
            'downloadUrl',
            'previewUrl',
            'thumbUrl',
            'thumbnailUrl',
          ];
    for (final key in keys) {
      final value = photo[key]?.toString().trim() ?? '';
      if (_isShareableUrl(value)) return value;
    }
    return '';
  }

  bool _isShareableUrl(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null) return false;
    return uri.hasScheme && (uri.scheme == 'https' || uri.scheme == 'http');
  }

  String _buildPublicUrl(String token, String serverUrl) {
    if (serverUrl.isNotEmpty) return serverUrl;
    return AppConfig.webUri(
      'memory-share',
      queryParameters: <String, String>{'token': token},
    ).toString();
  }

  Future<String> _getIdToken() async {
    final user = _auth.currentUser;
    if (user == null)
      throw Exception('Phiên đăng nhập đã hết. Vui lòng đăng nhập lại.');
    return await user.getIdToken() ?? '';
  }

  Future<Map<String, dynamic>> _workerPost(
    String path,
    Map<String, dynamic> body,
  ) async {
    final idToken = await _getIdToken();
    final response = await http.post(
      Uri.parse('${AppConfig.cloudflareWorkerUrl}$path'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $idToken',
      },
      body: jsonEncode(body),
    );
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200) {
      final msg =
          (decoded['error'] as Map?)?['message'] ?? 'Lỗi không xác định.';
      throw Exception(msg);
    }
    return decoded;
  }

  static int _readInt(Object? value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }
}
