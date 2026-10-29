import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DiaryCreateRequest {
  const DiaryCreateRequest({
    required this.fingerprint,
    required this.requestId,
    this.wasPending = false,
  });

  final String fingerprint;
  final String requestId;
  final bool wasPending;
}

/// Chỉ giữ mã mờ và hash của lượt gửi chưa rõ kết quả, không lưu nội dung bài.
class DiaryCreateRequestStore {
  DiaryCreateRequestStore(
    this._prefs, {
    String Function()? createRequestId,
    this.maxPending = 32,
  }) : _createRequestId = createRequestId ?? _randomRequestId;

  static const storageKey = 'diary_create_requests_v1';
  static Future<void> _mutationTail = Future<void>.value();
  final SharedPreferences _prefs;
  final String Function() _createRequestId;
  final int maxPending;

  static String _randomRequestId() {
    final random = Random.secure();
    return List.generate(
      16,
      (_) => random.nextInt(256),
    ).map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  }

  Future<T> _serialize<T>(Future<T> Function() operation) {
    final result = _mutationTail.then((_) => operation());
    _mutationTail = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return result;
  }

  Map<String, String> _read() {
    final raw = _prefs.getString(storageKey);
    if (raw == null) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) throw const FormatException();
      final result = <String, String>{};
      for (final entry in decoded.entries) {
        if (entry.key is! String ||
            !RegExp(r'^[a-f0-9]{64}$').hasMatch(entry.key as String) ||
            entry.value is! String ||
            !RegExp(
              r'^[A-Za-z0-9_-]{8,128}$',
            ).hasMatch(entry.value as String)) {
          throw const FormatException();
        }
        result[entry.key as String] = entry.value as String;
      }
      return result;
    } catch (_) {
      // Không tự bỏ biên nhận hỏng rồi tạo ID mới: server có thể đã lưu bài.
      throw StateError('diary_pending_request_invalid');
    }
  }

  Future<void> _write(Map<String, String> pending) async {
    final saved = pending.isEmpty
        ? await _prefs.remove(storageKey)
        : await _prefs.setString(storageKey, jsonEncode(pending));
    if (!saved) throw StateError('diary_pending_request_not_saved');
  }

  Future<DiaryCreateRequest> claim({
    required String uid,
    required String houseId,
    required Map<String, dynamic> payload,
  }) {
    if (uid.trim().isEmpty || houseId.trim().isEmpty || maxPending < 1) {
      throw ArgumentError('diary_pending_request_scope_required');
    }
    final keys = payload.keys.toList()..sort();
    final fingerprint = sha256
        .convert(
          utf8.encode(
            jsonEncode([
              uid,
              houseId,
              {for (final key in keys) key: payload[key]},
            ]),
          ),
        )
        .toString();
    return _serialize(() async {
      final pending = _read();
      final existing = pending[fingerprint];
      if (existing != null) {
        return DiaryCreateRequest(
          fingerprint: fingerprint,
          requestId: existing,
          wasPending: true,
        );
      }
      // Giữ trần local nhưng không âm thầm loại lượt cũ còn có thể đã commit.
      if (pending.length >= maxPending) {
        throw StateError('diary_pending_request_capacity');
      }
      final requestId = _createRequestId();
      if (!RegExp(r'^[A-Za-z0-9_-]{8,128}$').hasMatch(requestId)) {
        throw ArgumentError('diary_pending_request_id_invalid');
      }
      pending[fingerprint] = requestId;
      await _write(pending);
      return DiaryCreateRequest(fingerprint: fingerprint, requestId: requestId);
    });
  }

  Future<void> complete(DiaryCreateRequest request) => _serialize(() async {
    final pending = _read();
    if (pending[request.fingerprint] != request.requestId) return;
    pending.remove(request.fingerprint);
    await _write(pending);
  });
}
