import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';

const Duration _memoryShareAppCheckRetryDelay = Duration(milliseconds: 350);

class MemoryLimits {
  const MemoryLimits({
    required this.shareMaxItems,
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

    return MemoryLimits(
      shareMaxItems: _readLimitInt(
        data['shareMaxItems'],
        fallbackMemoryLimits.shareMaxItems,
      ).clamp(1, 100).toInt(),
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
  final int shareDefaultTtlDays;
  final int shareMaxTtlDays;
  final int imageFreeDailyLimit;
  final int imageProDailyLimit;
}

const MemoryLimits fallbackMemoryLimits = MemoryLimits(
  shareMaxItems: 24,
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
  MemoryShareService({
    FirebaseFunctions? functions,
    FirebaseAuth? auth,
  })  : _functions = functions ?? FirebaseFunctions.instance,
        _auth = auth ?? FirebaseAuth.instance;

  static int get maxPhotosPerShare => fallbackMemoryLimits.shareMaxItems;
  static const String defaultShareTitle = 'Kỷ niệm của chúng mình';
  static const String defaultShareDescription =
      'SoulLocket lưu giữ những khoảnh khắc riêng tư của hai bạn và biến chúng thành album kỷ niệm dễ chia sẻ.';
  static const String defaultBrandLabel = 'SoulLocket Memories';
  static const String defaultTheme = 'soullocket_dream';

  final FirebaseFunctions _functions;
  final FirebaseAuth _auth;
  final FirebaseDatabase _database;

  Future<MemoryShareResult> createShareLink({
    required String houseId,
    required List<Map<String, dynamic>> photos,
    int expiryDays = 7,
  }) async {
    final normalizedHouseId = houseId.trim();
    if (normalizedHouseId.isEmpty) {
      throw Exception('Chưa có mã nhà để tạo liên kết.');
    }

    final safePhotos = _sanitizePhotos(photos);
    if (safePhotos.isEmpty) {
      throw Exception('Chưa có ảnh hợp lệ để tạo liên kết.');
    }
    if (safePhotos.length > maxPhotosPerShare) {
      throw Exception('Mỗi liên kết chỉ hỗ trợ tối đa $maxPhotosPerShare ảnh.');
    }
    final resolvedExpiryDays = expiryDays.clamp(1, 183).toInt();

    HttpsCallableResult<dynamic>? response;
    try {
      response = await _callWithAuthAndAppCheckRetry(() {
        final callable = _functions.httpsCallable('createMemoryShareLink');
        return callable.call(<String, dynamic>{
          'houseId': normalizedHouseId,
          'photos': safePhotos,
          'expiryDays': resolvedExpiryDays,
          'title': defaultShareTitle,
          'description': defaultShareDescription,
          'brandLabel': defaultBrandLabel,
          'theme': defaultTheme,
        });
      });
    } on FirebaseFunctionsException catch (error) {
      if (_isAuthFailure(error)) {
        return _createDirectShareLink(
          houseId: normalizedHouseId,
          photos: safePhotos,
          expiryDays: resolvedExpiryDays,
        );
      }
      rethrow;
    }
    final raw = response.data;
    if (raw is! Map) {
      throw Exception('Phản hồi tạo liên kết không hợp lệ.');
    }
    final data = Map<String, dynamic>.from(raw);
    final token = data['token']?.toString().trim() ?? '';
    if (token.isEmpty) {
      throw Exception('Máy chủ chưa trả mã liên kết.');
    }

    return MemoryShareResult(
      token: token,
      url: _buildPublicUrl(token, data['url']?.toString().trim() ?? ''),
      expiresAt: _readInt(data['expiresAt']),
      photoCount: _readInt(data['photoCount'], fallback: safePhotos.length),
    );
  }

  List<Map<String, dynamic>> _sanitizePhotos(
      List<Map<String, dynamic>> photos) {
    final sanitized = <Map<String, dynamic>>[];
    for (final photo in photos) {
      if (sanitized.length >= maxPhotosPerShare) {
        break;
      }
      final url = _firstShareableUrl(photo);
      if (url.isEmpty) {
        continue;
      }
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
        : const ['url', 'downloadUrl', 'previewUrl', 'thumbUrl', 'thumbnailUrl'];
    for (final key in keys) {
      final value = photo[key]?.toString().trim() ?? '';
      if (_isShareableUrl(value)) {
        return value;
      }
    }
    return '';
  }

  bool _isShareableUrl(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null) {
      return false;
    }
    return uri.hasScheme && (uri.scheme == 'https' || uri.scheme == 'http');
  }

  String _buildPublicUrl(String token, String serverUrl) {
    if (serverUrl.isNotEmpty) {
      return serverUrl;
    }
    return 'https://soullockket.web.app/'
        'memory-share?token=${Uri.encodeQueryComponent(token)}';
  }

  Future<MemoryShareResult> _createDirectShareLink({
    required String houseId,
    required List<Map<String, dynamic>> photos,
    required int expiryDays,
  }) async {
    final resolvedExpiryDays = expiryDays.clamp(1, 183).toInt();
    final now = DateTime.now().millisecondsSinceEpoch;
    final token = _generateShareToken();
    final expiresAt = now + Duration(days: resolvedExpiryDays).inMilliseconds;
    final uid = _auth.currentUser?.uid.trim() ?? '';
    final share = <String, dynamic>{
      'houseId': houseId,
      if (uid.isNotEmpty) 'createdBy': uid,
      'createdAt': now,
      'expiresAt': expiresAt,
      'ttlDays': resolvedExpiryDays,
      'revoked': false,
      'photoCount': photos.length,
      'title': defaultShareTitle,
      'description': defaultShareDescription,
      'brandLabel': defaultBrandLabel,
      'theme': defaultTheme,
      'photos': photos,
    };
    await _database.ref().update({
      'memory_shares/$token': share,
      'houses/$houseId/memoryShares/$token': <String, dynamic>{
        'createdAt': now,
        'expiresAt': expiresAt,
        'ttlDays': resolvedExpiryDays,
        'photoCount': photos.length,
        'revoked': false,
        if (uid.isNotEmpty) 'createdBy': uid,
      },
    });
    return MemoryShareResult(
      token: token,
      url: _buildPublicUrl(token, ''),
      expiresAt: expiresAt,
      photoCount: photos.length,
    );
  }

  String _generateShareToken() {
    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_';
    final random = Random.secure();
    return List<String>.generate(
      24,
      (_) => chars[random.nextInt(chars.length)],
      growable: false,
    ).join();
  }

  Future<bool> _warmUpAuthToken({bool forceRefresh = false}) async {
    final user = _auth.currentUser;
    if (user == null) {
      return false;
    }
    try {
      final token = await user.getIdToken(forceRefresh);
      return (token ?? '').trim().isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _warmUpAppCheck({bool forceRefresh = false}) async {
    try {
      final token = await FirebaseAppCheck.instance.getToken(forceRefresh);
      return (token ?? '').trim().isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  bool _isAuthFailure(FirebaseFunctionsException error) {
    return error.code.trim().toLowerCase() == 'unauthenticated' &&
        !_isAppCheckFailure(error);
  }

  bool _isAppCheckFailure(FirebaseFunctionsException error) {
    final code = error.code.trim().toLowerCase();
    if (code != 'failed-precondition' &&
        code != 'permission-denied' &&
        code != 'unauthenticated') {
      return false;
    }
    final message =
        '${error.message ?? ''} ${error.details ?? ''}'.trim().toLowerCase();
    const appCheckMarkers = <String>[
      'app check',
      'appcheck',
      'debug token',
      'play integrity',
      'attestation',
      'firebase app check api',
      'x-firebase-appcheck',
      'recaptcha',
      'app attest',
      'device check',
      'missing appcheck token',
      'invalid appcheck token',
    ];
    return appCheckMarkers.any(message.contains);
  }

  Future<HttpsCallableResult<dynamic>> _callWithAuthAndAppCheckRetry(
    Future<HttpsCallableResult<dynamic>> Function() action,
  ) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception(
          'Phiên đăng nhập đã hết. Vui lòng đăng nhập lại rồi thử lại.');
    }

    await _warmUpAuthToken();
    await _warmUpAppCheck();

    try {
      return await action();
    } on FirebaseFunctionsException catch (error) {
      if (_isAppCheckFailure(error)) {
        final refreshed = await _warmUpAppCheck(forceRefresh: true);
        if (refreshed) {
          await Future<void>.delayed(_memoryShareAppCheckRetryDelay);
        }
        return action();
      }

      if (_isAuthFailure(error)) {
        final refreshed = await _warmUpAuthToken(forceRefresh: true);
        if (refreshed) {
          await Future<void>.delayed(_memoryShareAppCheckRetryDelay);
          return action();
        }
      }
      rethrow;
    }
  }

  static int _readInt(Object? value, {int fallback = 0}) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }
}
