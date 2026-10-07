import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../../core/constants/app_config.dart';
import '../../app_error_mapper.dart';
import '../house_service.dart';
import '../infrastructure/cloudflare_data_service.dart';

/// Mục đã bị người kia sửa/xóa trước; [current] là bản hiện tại trên server (nếu còn).
class HouseListConflictException implements Exception {
  const HouseListConflictException(this.code, this.current);

  final String code;
  final Map<String, dynamic>? current;

  @override
  String toString() => 'House list conflict ($code)';
}

/// Danh sách đã đủ số mục tối đa của nhà.
class HouseListLimitException implements Exception {
  const HouseListLimitException();

  @override
  String toString() => 'House list limit reached';
}

/// Kết quả ghi: bản ghi theo đúng dạng màn hình đang dùng (`c`, `a`, `done`…) kèm `rev`.
class HouseListWriteResult {
  const HouseListWriteResult(this.id, this.record);

  final String id;
  final Map<String, dynamic> record;
}

/// Client Bucket list / Điều ước trên D1 qua Worker (mốc E, cùng khuôn Sổ tay D1).
/// Chỉ HTTPS, kiểm tra lại UID/nhà sau mỗi lần chờ, thử lại tối đa một lần khi token hết
/// hạn, không theo chuyển hướng, giới hạn kích thước phản hồi. Mỗi lệnh ghi gửi
/// `Idempotency-Key` tính từ nội dung nên bấm lại sau khi mất mạng không tạo bản trùng;
/// `expected_revision` chặn hai người âm thầm ghi đè nhau.
class HouseListD1Client {
  HouseListD1Client()
    : this._(
        http.Client(),
        Uri.parse(AppConfig.cloudflareWorkerUrl),
        () => FirebaseAuth.instance.currentUser?.uid,
        () => HouseService().getCurrentHouseId(),
        (refresh) async =>
            FirebaseAuth.instance.currentUser?.getIdToken(refresh),
        (refresh) => FirebaseAppCheck.instance.getToken(refresh),
        const Duration(seconds: 20),
      );

  @visibleForTesting
  HouseListD1Client.forTesting({
    required http.Client client,
    required Uri baseUrl,
    required String? Function() currentUid,
    required Future<String?> Function() currentHouseId,
    required Future<String?> Function(bool) tokenProvider,
    Future<String?> Function(bool)? appCheckTokenProvider,
    Duration timeout = const Duration(seconds: 20),
  }) : this._(
         client,
         baseUrl,
         currentUid,
         currentHouseId,
         tokenProvider,
         appCheckTokenProvider ?? (_) async => 'test-app-check',
         timeout,
       );

  HouseListD1Client._(
    this._client,
    this._baseUrl,
    this._uidProvider,
    this._houseProvider,
    this._tokenProvider,
    this._appCheckTokenProvider,
    this._timeout,
  );

  /// Loại danh sách Worker nhận; trùng tên node RTDB và cờ `settings/dataBackends/{kind}`.
  static const Set<String> kinds = {'bucket', 'wishlist'};
  static const int maxResponseBytes = 256 * 1024;
  static final RegExp _scopeId = RegExp(r'^[A-Za-z0-9_-]{1,128}$');
  static final RegExp _itemId = RegExp(r'^[A-Za-z0-9_-]{1,64}$');

  final http.Client _client;
  final Uri _baseUrl;
  final String? Function() _uidProvider;
  final Future<String?> Function() _houseProvider;
  final Future<String?> Function(bool) _tokenProvider;
  final Future<String?> Function(bool) _appCheckTokenProvider;
  final Duration _timeout;
  bool _disposed = false;

  /// Chuyển mục từ API sang dạng bản ghi màn hình đang đọc từ RTDB, kèm `rev` để ghi tiếp.
  static Map<String, dynamic> toScreenRecord(Map<String, dynamic> item) {
    final data = item['data'];
    return {
      if (data is Map) ...Map<String, dynamic>.from(data),
      'done': data is Map && data['done'] == true,
      'ts': data is Map && data['ts'] is num
          ? (data['ts'] as num).toInt()
          : (item['created_at'] as num?)?.toInt() ?? 0,
      'rev': (item['revision'] as num?)?.toInt() ?? 0,
    };
  }

  /// Bỏ trường chỉ dùng trong app (`rev`, `key`) trước khi gửi lên Worker.
  static Map<String, Object?> apiData(Map<String, dynamic> record) => {
    for (final entry in record.entries)
      if (entry.key != 'rev' && entry.key != 'key' && entry.value != null)
        entry.key: entry.value,
  };

  Future<Map<String, Map<String, dynamic>>> list(
    String houseId,
    String kind,
  ) async {
    final body = await _send(houseId, kind, 'GET', '', null);
    final items = body['items'];
    if (items is! List) {
      throw const FormatException('Invalid house list response');
    }
    return {
      for (final item in items)
        if (item is Map<String, dynamic> && _itemId.hasMatch('${item['id']}'))
          item['id'].toString(): toScreenRecord(item),
    };
  }

  Future<HouseListWriteResult> save({
    required String houseId,
    required String kind,
    required String itemId,
    required int expectedRevision,
    required Map<String, Object?> data,
  }) => _write(houseId, kind, 'PUT', '/$itemId', {
    'expected_revision': expectedRevision,
    'data': data,
  });

  /// Đổi các trường được phép sửa nhanh (ví dụ `done`), giữ nguyên phần còn lại.
  Future<HouseListWriteResult> patch({
    required String houseId,
    required String kind,
    required String itemId,
    required int expectedRevision,
    required Map<String, Object?> set,
  }) => _write(houseId, kind, 'PATCH', '/$itemId', {
    'expected_revision': expectedRevision,
    'set': set,
  });

  Future<HouseListWriteResult> delete({
    required String houseId,
    required String kind,
    required String itemId,
    required int expectedRevision,
  }) => _write(houseId, kind, 'DELETE', '/$itemId', {
    'expected_revision': expectedRevision,
  });

  Future<HouseListWriteResult> restore({
    required String houseId,
    required String kind,
    required String itemId,
    required int expectedRevision,
  }) => _write(houseId, kind, 'POST', '/$itemId/restore', {
    'expected_revision': expectedRevision,
  });

  Future<HouseListWriteResult> _write(
    String houseId,
    String kind,
    String method,
    String route,
    Map<String, Object?> payload,
  ) async {
    final body = await _send(houseId, kind, method, route, payload);
    final item = body['item'];
    if (item is! Map<String, dynamic> || !_itemId.hasMatch('${item['id']}')) {
      throw const FormatException('Invalid house list response');
    }
    return HouseListWriteResult(item['id'].toString(), toScreenRecord(item));
  }

  /// Khóa idempotency cố định theo người gửi + nội dung lệnh: gửi lại đúng lệnh cũ dùng lại
  /// khóa (server trả kết quả đã lưu), lệnh khác tạo khóa khác.
  @visibleForTesting
  static String idempotencyKey(
    String uid,
    String houseId,
    String method,
    String route,
    Map<String, Object?> payload,
  ) {
    Object? canonical(Object? value) {
      if (value is Map) {
        final keys = value.keys.map((key) => key.toString()).toList()..sort();
        return [
          for (final key in keys) [key, canonical(value[key])],
        ];
      }
      return value;
    }

    final encoded = jsonEncode([
      uid,
      houseId,
      method,
      route,
      canonical(payload),
    ]);
    return sha256.convert(utf8.encode(encoded)).toString().substring(0, 40);
  }

  Future<void> _requireScope(String uid, String houseId) async {
    if (_disposed || _uidProvider() != uid) {
      throw FirebaseAuthException(code: 'user-token-expired');
    }
    final currentHouseId = await _houseProvider().timeout(_timeout);
    if (_disposed || _uidProvider() != uid || currentHouseId != houseId) {
      throw FirebaseAuthException(code: 'user-token-expired');
    }
  }

  Future<Map<String, dynamic>> _send(
    String houseId,
    String kind,
    String method,
    String route,
    Map<String, Object?>? payload,
  ) async {
    if (_disposed) throw StateError('House list client is disposed');
    if (_baseUrl.scheme != 'https' ||
        _baseUrl.host.isEmpty ||
        _baseUrl.userInfo.isNotEmpty ||
        _baseUrl.hasQuery ||
        _baseUrl.hasFragment ||
        (_baseUrl.path.isNotEmpty && _baseUrl.path != '/')) {
      throw ArgumentError('Invalid house list origin');
    }
    if (!_scopeId.hasMatch(houseId) || !kinds.contains(kind)) {
      throw ArgumentError('Invalid house list scope');
    }
    final uid = _uidProvider();
    if (uid == null) throw FirebaseAuthException(code: 'user-token-expired');
    await _requireScope(uid, houseId);
    final fullRoute = '/$kind$route';
    final uri = _baseUrl.replace(path: '/api/v1/lists$fullRoute');
    final key = payload == null
        ? null
        : idempotencyKey(uid, houseId, method, fullRoute, payload);
    try {
      for (var attempt = 0; attempt < 2; attempt++) {
        final token = await _tokenProvider(attempt > 0).timeout(_timeout);
        await _requireScope(uid, houseId);
        if (token == null || token.isEmpty) {
          throw FirebaseAuthException(code: 'user-token-expired');
        }
        final appCheckToken = await _appCheckTokenProvider(
          attempt > 0,
        ).timeout(_timeout);
        await _requireScope(uid, houseId);
        if (appCheckToken == null || appCheckToken.trim().isEmpty) {
          throw FirebaseException(
            plugin: 'firebase_app_check',
            code: 'app-check-token-missing',
          );
        }
        final request = http.Request(method, uri)
          ..followRedirects = false
          ..headers.addAll({
            'Authorization': 'Bearer $token',
            'X-Firebase-AppCheck': appCheckToken,
            'X-House-ID': houseId,
            'Accept': 'application/json',
            'Idempotency-Key': ?key,
            if (payload != null) 'Content-Type': 'application/json',
          });
        if (payload != null) request.body = jsonEncode(payload);
        final response = await _client.send(request).timeout(_timeout);
        final bytes = BytesBuilder(copy: false);
        await for (final chunk in response.stream.timeout(_timeout)) {
          if (bytes.length + chunk.length > maxResponseBytes) {
            throw const FormatException('House list response exceeds limit');
          }
          bytes.add(chunk);
        }
        await _requireScope(uid, houseId);
        // Lần 2 dùng lại cùng khóa idempotency nên không ghi trùng.
        if (response.statusCode == 401 && attempt == 0) continue;
        final decoded = bytes.isEmpty
            ? null
            : jsonDecode(utf8.decode(bytes.takeBytes()));
        if (response.statusCode == 409 && decoded is Map<String, dynamic>) {
          if (decoded['error'] == 'limit_reached') {
            throw const HouseListLimitException();
          }
          final current = decoded['item'];
          throw HouseListConflictException(
            decoded['error']?.toString() ?? 'revision_conflict',
            current is Map<String, dynamic> ? toScreenRecord(current) : null,
          );
        }
        if (response.statusCode != 200 && response.statusCode != 201) {
          final retrySeconds = int.tryParse(
            response.headers['retry-after'] ?? '',
          );
          throw CloudflareDataException(
            response.statusCode,
            retryAfter: retrySeconds != null && retrySeconds >= 0
                ? Duration(seconds: retrySeconds)
                : null,
          );
        }
        if (decoded is! Map<String, dynamic>) {
          throw const FormatException('Invalid house list response');
        }
        return decoded;
      }
      throw const CloudflareDataException(401);
    } catch (error) {
      if (error is! HouseListConflictException &&
          error is! HouseListLimitException) {
        debugPrint(
          '[HouseListD1] Request failed: ${AppErrorMapper.resolve(error).kind.name}',
        );
      }
      rethrow;
    }
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _client.close();
  }
}
