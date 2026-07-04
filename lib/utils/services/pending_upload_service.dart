import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'offline_cache_service.dart';

class PendingUploadSummary {
  final String key;
  final int createdAt;
  final int updatedAt;
  final int retryCount;
  final String lastError;
  final String category;

  const PendingUploadSummary({
    required this.key,
    required this.createdAt,
    required this.updatedAt,
    required this.retryCount,
    required this.lastError,
    required this.category,
  });
}

class PendingUploadService {
  PendingUploadService._();

  static final PendingUploadService instance = PendingUploadService._();
  static const String _prefix = 'il_pending_upload_v1_';
  static const String _metaKey = '__pendingUploadMeta';
  static const String _payloadKey = 'payload';

  Future<void> save(
    String key,
    Map<String, dynamic> payload, {
    String category = 'generic',
  }) async {
    final prefs = OfflineCacheService.getPrefsSync() ??
        await SharedPreferences.getInstance();
    final now = DateTime.now().millisecondsSinceEpoch;
    final current = await _readEnvelope(prefs, key);
    final currentMeta = current?[_metaKey];
    final createdAt =
        currentMeta is Map ? ((currentMeta['createdAt'] as int?) ?? now) : now;
    final retryCount =
        currentMeta is Map ? ((currentMeta['retryCount'] as int?) ?? 0) : 0;

    await prefs.setString(
      '$_prefix$key',
      jsonEncode(<String, dynamic>{
        _metaKey: <String, dynamic>{
          'version': 2,
          'createdAt': createdAt,
          'updatedAt': now,
          'retryCount': retryCount,
          'lastError': '',
          'category': category.trim().isEmpty ? 'generic' : category.trim(),
        },
        _payloadKey: payload,
      }),
    );
  }

  Future<Map<String, dynamic>?> load(String key) async {
    final prefs = OfflineCacheService.getPrefsSync() ??
        await SharedPreferences.getInstance();
    final envelope = await _readEnvelope(prefs, key);
    if (envelope == null) {
      return null;
    }
    final payload = envelope[_payloadKey];
    if (payload is Map) {
      return Map<String, dynamic>.from(payload);
    }
    if (envelope.containsKey(_metaKey)) {
      await clear(key);
      return null;
    }
    return Map<String, dynamic>.from(envelope);
  }

  Future<List<PendingUploadSummary>> listSummaries() async {
    final prefs = OfflineCacheService.getPrefsSync() ??
        await SharedPreferences.getInstance();
    final keys = prefs
        .getKeys()
        .where((key) => key.startsWith(_prefix))
        .toList(growable: false)
      ..sort();
    final summaries = <PendingUploadSummary>[];
    for (final storageKey in keys) {
      final key = storageKey.substring(_prefix.length);
      final envelope = await _readEnvelope(prefs, key);
      if (envelope == null) continue;
      final meta = envelope[_metaKey];
      if (meta is Map) {
        summaries.add(PendingUploadSummary(
          key: key,
          createdAt: (meta['createdAt'] as int?) ?? 0,
          updatedAt: (meta['updatedAt'] as int?) ?? 0,
          retryCount: (meta['retryCount'] as int?) ?? 0,
          lastError: meta['lastError']?.toString() ?? '',
          category: meta['category']?.toString() ?? 'generic',
        ));
      } else {
        summaries.add(PendingUploadSummary(
          key: key,
          createdAt: 0,
          updatedAt: 0,
          retryCount: 0,
          lastError: '',
          category: 'legacy',
        ));
      }
    }
    return summaries;
  }

  Future<void> markFailed(String key, Object error) async {
    final prefs = OfflineCacheService.getPrefsSync() ??
        await SharedPreferences.getInstance();
    final envelope = await _readEnvelope(prefs, key);
    if (envelope == null) return;
    final payload = envelope[_payloadKey];
    final meta = envelope[_metaKey];
    if (payload is! Map || meta is! Map) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    await prefs.setString(
      '$_prefix$key',
      jsonEncode(<String, dynamic>{
        _metaKey: <String, dynamic>{
          ...Map<String, dynamic>.from(meta),
          'updatedAt': now,
          'retryCount': ((meta['retryCount'] as int?) ?? 0) + 1,
          'lastError': error.toString(),
        },
        _payloadKey: Map<String, dynamic>.from(payload),
      }),
    );
  }

  Future<void> clear(String key) async {
    final prefs = OfflineCacheService.getPrefsSync() ??
        await SharedPreferences.getInstance();
    await prefs.remove('$_prefix$key');
  }

  Future<Map<String, dynamic>?> _readEnvelope(
    SharedPreferences prefs,
    String key,
  ) async {
    final raw = prefs.getString('$_prefix$key');
    if (raw == null || raw.isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        await clear(key);
        return null;
      }
      return Map<String, dynamic>.from(decoded);
    } catch (_) {
      await clear(key);
      return null;
    }
  }
}
