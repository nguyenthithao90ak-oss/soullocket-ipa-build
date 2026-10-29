import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'offline_cache_service.dart';

class PendingUploadSummary {
  final String key;
  final int createdAt;
  final int updatedAt;
  final int retryCount;
  final String lastError;
  final String category;
  final String ownerUid;

  const PendingUploadSummary({
    required this.key,
    required this.createdAt,
    required this.updatedAt,
    required this.retryCount,
    required this.lastError,
    required this.category,
    required this.ownerUid,
  });
}

class PendingUploadService {
  PendingUploadService._()
    : _currentUid = (() => FirebaseAuth.instance.currentUser?.uid),
      _preferences = (() async =>
          OfflineCacheService.getPrefsSync() ??
          await SharedPreferences.getInstance());

  @visibleForTesting
  PendingUploadService.forTesting({
    required String? Function() currentUid,
    required Future<SharedPreferences> Function() preferences,
  }) : _currentUid = currentUid,
       _preferences = preferences;

  final String? Function() _currentUid;
  final Future<SharedPreferences> Function() _preferences;

  static final PendingUploadService instance = PendingUploadService._();
  // Bản v1 không có chủ sở hữu: giữ trên đĩa, không tự gán cho người đăng nhập.
  static const String _prefix = 'il_pending_upload_v3_';
  static const String _metaKey = '__pendingUploadMeta';
  static const String _payloadKey = 'payload';
  Future<void> _operations = Future<void>.value();

  String? get currentUid => _currentUid();

  String _owner({String? expectedUid}) {
    final uid = currentUid;
    if (uid == null ||
        uid.isEmpty ||
        (expectedUid != null && expectedUid != uid)) {
      throw StateError('Pending upload account changed');
    }
    return uid;
  }

  bool _isCurrent(String uid) => currentUid == uid;
  String _ownerPrefix(String uid) => '$_prefix${Uri.encodeComponent(uid)}:';
  String _storageKey(String uid, String key) => '${_ownerPrefix(uid)}$key';

  Future<void> _serialize(Future<void> Function() action) {
    final next = _operations.then((_) => action());
    _operations = next.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return next;
  }

  Future<void> save(
    String key,
    Map<String, dynamic> payload, {
    String category = 'generic',
    String? expectedUid,
  }) async {
    final uid = _owner(expectedUid: expectedUid);
    // Chụp payload ngay; caller không thể đổi Map trong lúc chờ lượt ghi.
    final captured = jsonDecode(jsonEncode(payload));
    await _serialize(() async {
      final prefs = await _preferences();
      _owner(expectedUid: uid);
      final now = DateTime.now().millisecondsSinceEpoch;
      final currentMeta = _readEnvelope(prefs, uid, key)?[_metaKey];
      final saved = await prefs.setString(
        _storageKey(uid, key),
        jsonEncode(<String, dynamic>{
          _metaKey: <String, dynamic>{
            'version': 3,
            'ownerUid': uid,
            'createdAt': currentMeta is Map
                ? currentMeta['createdAt'] ?? now
                : now,
            'updatedAt': now,
            'retryCount': currentMeta is Map
                ? currentMeta['retryCount'] ?? 0
                : 0,
            'lastError': '',
            'category': category.trim().isEmpty ? 'generic' : category.trim(),
          },
          _payloadKey: captured,
        }),
      );
      if (!saved) throw StateError('Unable to persist pending upload');
      _owner(expectedUid: uid);
    });
  }

  Future<Map<String, dynamic>?> load(String key, {String? expectedUid}) async {
    final uid = currentUid;
    if (uid == null || (expectedUid != null && expectedUid != uid)) return null;
    final prefs = await _preferences();
    if (!_isCurrent(uid)) return null;
    final payload = _readEnvelope(prefs, uid, key)?[_payloadKey];
    return payload is Map ? Map<String, dynamic>.from(payload) : null;
  }

  Future<List<PendingUploadSummary>> listSummaries() async {
    final uid = currentUid;
    if (uid == null) return [];
    final prefs = await _preferences();
    if (!_isCurrent(uid)) return [];
    final prefix = _ownerPrefix(uid);
    final keys =
        prefs
            .getKeys()
            .where((key) => key.startsWith(prefix))
            .toList(growable: false)
          ..sort();
    final summaries = <PendingUploadSummary>[];
    for (final storageKey in keys) {
      final key = storageKey.substring(prefix.length);
      final envelope = _readEnvelope(prefs, uid, key);
      if (envelope == null) continue;
      final meta = envelope[_metaKey];
      if (meta is Map) {
        summaries.add(
          PendingUploadSummary(
            key: key,
            createdAt: (meta['createdAt'] as int?) ?? 0,
            updatedAt: (meta['updatedAt'] as int?) ?? 0,
            retryCount: (meta['retryCount'] as int?) ?? 0,
            lastError: meta['lastError']?.toString() ?? '',
            category: meta['category']?.toString() ?? 'generic',
            ownerUid: uid,
          ),
        );
      }
    }
    return summaries;
  }

  Future<void> markFailed(
    String key,
    Object error, {
    String? expectedUid,
  }) async {
    final uid = _owner(expectedUid: expectedUid);
    await _serialize(() async {
      final prefs = await _preferences();
      _owner(expectedUid: uid);
      final envelope = _readEnvelope(prefs, uid, key);
      final payload = envelope?[_payloadKey];
      final meta = envelope?[_metaKey];
      if (payload is! Map || meta is! Map) return;
      final saved = await prefs.setString(
        _storageKey(uid, key),
        jsonEncode(<String, dynamic>{
          _metaKey: <String, dynamic>{
            ...Map<String, dynamic>.from(meta),
            'updatedAt': DateTime.now().millisecondsSinceEpoch,
            'retryCount': ((meta['retryCount'] as int?) ?? 0) + 1,
            'lastError': error.toString(),
          },
          _payloadKey: Map<String, dynamic>.from(payload),
        }),
      );
      if (!saved) throw StateError('Unable to persist pending upload failure');
      _owner(expectedUid: uid);
    });
  }

  Future<void> clear(String key, {String? expectedUid}) async {
    final uid = _owner(expectedUid: expectedUid);
    await _serialize(() async {
      final prefs = await _preferences();
      _owner(expectedUid: uid);
      if (!await prefs.remove(_storageKey(uid, key))) {
        throw StateError('Unable to clear pending upload');
      }
    });
  }

  Map<String, dynamic>? _readEnvelope(
    SharedPreferences prefs,
    String uid,
    String key,
  ) {
    final raw = prefs.get(_storageKey(uid, key));
    if (raw is! String || raw.isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final meta = decoded[_metaKey];
      if (meta is! Map ||
          meta['version'] != 3 ||
          meta['ownerUid'] != uid ||
          meta['createdAt'] is! int ||
          meta['updatedAt'] is! int ||
          meta['retryCount'] is! int ||
          (meta['retryCount'] as int) < 0 ||
          decoded[_payloadKey] is! Map)
        return null;
      return Map<String, dynamic>.from(decoded);
    } catch (_) {
      return null;
    }
  }
}
