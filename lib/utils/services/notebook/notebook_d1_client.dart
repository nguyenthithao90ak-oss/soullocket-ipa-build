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

/// Ghi chú đã bị người kia sửa/xóa trước; [current] là bản hiện tại trên server (nếu còn).
class NotebookConflictException implements Exception {
  const NotebookConflictException(this.code, this.current);

  final String code;
  final Map<String, dynamic>? current;

  @override
  String toString() => 'Notebook conflict ($code)';
}

/// Nhà đã đủ số ghi chú tối đa.
class NotebookLimitException implements Exception {
  const NotebookLimitException();

  @override
  String toString() => 'Notebook limit reached';
}

/// Kết quả ghi: bản ghi theo đúng dạng màn Sổ tay đang dùng (`c`, `a`, `time`…) kèm `rev`.
class NotebookWriteResult {
  const NotebookWriteResult(this.id, this.record);

  final String id;
  final Map<String, dynamic> record;
}

/// Client Sổ tay trên D1 qua Worker (pilot mốc D). Cùng lớp bảo vệ với
/// [CloudflareDataService]: chỉ HTTPS, kiểm tra lại UID/nhà sau mỗi lần chờ, thử lại tối đa
/// một lần khi token hết hạn, không theo chuyển hướng, giới hạn kích thước phản hồi.
/// Mỗi lệnh ghi gửi `Idempotency-Key` tính từ nội dung, nên bấm lưu lại sau khi mất mạng
/// không tạo bản trùng; `expected_revision` chặn hai người âm thầm ghi đè nhau.
class NotebookD1Client {
  NotebookD1Client()
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
  NotebookD1Client.forTesting({
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

  NotebookD1Client._(
    this._client,
    this._baseUrl,
    this._uidProvider,
    this._houseProvider,
    this._tokenProvider,
    this._appCheckTokenProvider,
    this._timeout,
  );

  static const int maxResponseBytes = 256 * 1024;
  static final RegExp _scopeId = RegExp(r'^[A-Za-z0-9_-]{1,128}$');
  static final RegExp _noteId = RegExp(r'^[A-Za-z0-9_-]{1,64}$');

  final http.Client _client;
  final Uri _baseUrl;
  final String? Function() _uidProvider;
  final Future<String?> Function() _houseProvider;
  final Future<String?> Function(bool) _tokenProvider;
  final Future<String?> Function(bool) _appCheckTokenProvider;
  final Duration _timeout;
  bool _disposed = false;

  /// Chuyển ghi chú từ API sang dạng bản ghi màn Sổ tay đang đọc từ RTDB.
  static Map<String, dynamic> toScreenRecord(Map<String, dynamic> note) => {
    'c': note['content']?.toString() ?? '',
    'a': note['author_name']?.toString() ?? '',
    'time': note['display_time']?.toString() ?? '',
    'tag': note['tag']?.toString() ?? '',
    'color': note['color']?.toString() ?? 'yellow',
    'pinned': note['pinned'] == true,
    'done': note['done'] == true,
    'ts': (note['created_at'] as num?)?.toInt() ?? 0,
    'updatedTs': (note['updated_at'] as num?)?.toInt() ?? 0,
    'rev': (note['revision'] as num?)?.toInt() ?? 0,
  };

  Future<Map<String, Map<String, dynamic>>> list(String houseId) async {
    final body = await _send(houseId, 'GET', '', null);
    final notes = body['notes'];
    if (notes is! List)
      throw const FormatException('Invalid notebook response');
    return {
      for (final item in notes)
        if (item is Map<String, dynamic> && _noteId.hasMatch('${item['id']}'))
          item['id'].toString(): toScreenRecord(item),
    };
  }

  Future<NotebookWriteResult> save({
    required String houseId,
    required String noteId,
    required int expectedRevision,
    required String content,
    required String tag,
    required String color,
    String? authorName,
    String? displayTime,
    int? createdAt,
  }) {
    return _write(houseId, 'PUT', '/$noteId', {
      'expected_revision': expectedRevision,
      'content': content,
      'tag': tag,
      'color': color,
      if (expectedRevision == 0) ...{
        'author_name': ?authorName,
        'display_time': ?displayTime,
        'created_at': ?createdAt,
      },
    });
  }

  Future<NotebookWriteResult> setFlag({
    required String houseId,
    required String noteId,
    required int expectedRevision,
    required String field,
    required bool value,
  }) {
    if (field != 'pinned' && field != 'done') {
      throw ArgumentError('Unsupported notebook flag');
    }
    return _write(houseId, 'PATCH', '/$noteId', {
      'expected_revision': expectedRevision,
      field: value,
    });
  }

  Future<NotebookWriteResult> delete({
    required String houseId,
    required String noteId,
    required int expectedRevision,
  }) => _write(houseId, 'DELETE', '/$noteId', {
    'expected_revision': expectedRevision,
  });

  Future<NotebookWriteResult> restore({
    required String houseId,
    required String noteId,
    required int expectedRevision,
  }) => _write(houseId, 'POST', '/$noteId/restore', {
    'expected_revision': expectedRevision,
  });

  Future<NotebookWriteResult> _write(
    String houseId,
    String method,
    String route,
    Map<String, Object?> payload,
  ) async {
    final body = await _send(houseId, method, route, payload);
    final note = body['note'];
    if (note is! Map<String, dynamic> || !_noteId.hasMatch('${note['id']}')) {
      throw const FormatException('Invalid notebook response');
    }
    return NotebookWriteResult(note['id'].toString(), toScreenRecord(note));
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
    final keys = payload.keys.toList()..sort();
    final canonical = jsonEncode([
      uid,
      houseId,
      method,
      route,
      [
        for (final key in keys) [key, payload[key]],
      ],
    ]);
    return sha256.convert(utf8.encode(canonical)).toString().substring(0, 40);
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
    String method,
    String route,
    Map<String, Object?>? payload,
  ) async {
    if (_disposed) throw StateError('Notebook client is disposed');
    if (_baseUrl.scheme != 'https' ||
        _baseUrl.host.isEmpty ||
        _baseUrl.userInfo.isNotEmpty ||
        _baseUrl.hasQuery ||
        _baseUrl.hasFragment ||
        (_baseUrl.path.isNotEmpty && _baseUrl.path != '/')) {
      throw ArgumentError('Invalid notebook origin');
    }
    if (!_scopeId.hasMatch(houseId)) {
      throw ArgumentError('Invalid notebook scope');
    }
    final uid = _uidProvider();
    if (uid == null) throw FirebaseAuthException(code: 'user-token-expired');
    await _requireScope(uid, houseId);
    final uri = _baseUrl.replace(path: '/api/v1/notebook$route');
    final key = payload == null
        ? null
        : idempotencyKey(uid, houseId, method, route, payload);
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
            throw const FormatException('Notebook response exceeds limit');
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
            throw const NotebookLimitException();
          }
          final current = decoded['note'];
          throw NotebookConflictException(
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
          throw const FormatException('Invalid notebook response');
        }
        return decoded;
      }
      throw const CloudflareDataException(401);
    } catch (error) {
      if (error is! NotebookConflictException &&
          error is! NotebookLimitException) {
        debugPrint(
          '[NotebookD1] Request failed: ${AppErrorMapper.resolve(error).kind.name}',
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
