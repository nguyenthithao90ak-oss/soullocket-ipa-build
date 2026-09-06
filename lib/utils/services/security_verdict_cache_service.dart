import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

typedef SecurityVerdictPrefsProvider = Future<SharedPreferences> Function();

class CachedSecurityVerdict {
  const CachedSecurityVerdict({
    required this.levelKey,
    required this.code,
    required this.message,
    required this.payload,
    required this.expiresAtMs,
  });

  final String? levelKey;
  final String code;
  final String message;
  final Map<String, dynamic> payload;
  final int expiresAtMs;
}

class SecurityVerdictCacheService {
  SecurityVerdictCacheService({SecurityVerdictPrefsProvider? prefsProvider})
    : _prefsProvider = prefsProvider ?? SharedPreferences.getInstance;

  static final SecurityVerdictCacheService instance =
      SecurityVerdictCacheService();

  static const String _riskLevelKey = 'il_security_risk_level';
  static const String _riskCodeKey = 'il_security_risk_code';
  static const String _riskMessageKey = 'il_security_risk_message';
  static const String _riskPayloadKey = 'il_security_risk_payload';
  static const String _riskExpiresAtKey = 'il_security_risk_expires_at';

  final SecurityVerdictPrefsProvider _prefsProvider;

  Future<void> save({
    String? levelKey,
    String code = '',
    String message = '',
    Map<String, dynamic> payload = const <String, dynamic>{},
    Duration? ttl,
  }) async {
    if ((levelKey ?? '').trim().isEmpty &&
        code.trim().isEmpty &&
        message.trim().isEmpty &&
        payload.isEmpty &&
        (ttl == null || ttl <= Duration.zero)) {
      await clear();
      return;
    }

    final prefs = await _prefsProvider();
    final normalizedPayload = Map<String, dynamic>.from(payload);
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final expiresAtMs = _resolveExpiresAtMs(normalizedPayload, nowMs, ttl);

    normalizedPayload.putIfAbsent('detectedAtMs', () => nowMs);
    if (expiresAtMs > 0) {
      normalizedPayload['expiresAtMs'] = expiresAtMs;
      await prefs.setInt(_riskExpiresAtKey, expiresAtMs);
    } else {
      normalizedPayload.remove('expiresAtMs');
      await prefs.remove(_riskExpiresAtKey);
    }

    if ((levelKey ?? '').trim().isEmpty) {
      await prefs.remove(_riskLevelKey);
    } else {
      await prefs.setString(_riskLevelKey, levelKey!.trim().toLowerCase());
    }

    if (code.trim().isEmpty) {
      await prefs.remove(_riskCodeKey);
    } else {
      await prefs.setString(_riskCodeKey, code.trim().toLowerCase());
    }

    if (message.trim().isEmpty) {
      await prefs.remove(_riskMessageKey);
    } else {
      await prefs.setString(_riskMessageKey, message.trim());
    }

    if (normalizedPayload.isEmpty) {
      await prefs.remove(_riskPayloadKey);
    } else {
      await prefs.setString(_riskPayloadKey, jsonEncode(normalizedPayload));
    }
  }

  Future<CachedSecurityVerdict?> read() async {
    final prefs = await _prefsProvider();
    final expiresAtMs = prefs.getInt(_riskExpiresAtKey) ?? 0;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    if (expiresAtMs > 0 && nowMs >= expiresAtMs) {
      await clear();
      return null;
    }

    final rawLevel = (prefs.getString(_riskLevelKey) ?? '')
        .trim()
        .toLowerCase();
    final rawCode = (prefs.getString(_riskCodeKey) ?? '').trim().toLowerCase();
    final rawMessage = (prefs.getString(_riskMessageKey) ?? '').trim();
    final rawPayload = (prefs.getString(_riskPayloadKey) ?? '').trim();

    Map<String, dynamic> payload = const <String, dynamic>{};
    if (rawPayload.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawPayload);
        if (decoded is Map) {
          payload = Map<String, dynamic>.from(decoded);
        }
      } catch (error) {
        debugPrint(
          '[SecurityVerdictCacheService] Invalid cached verdict payload: $error',
        );
      }
    }

    final payloadExpiresAtMs = _readInt(payload['expiresAtMs']);
    if (payloadExpiresAtMs > 0 && nowMs >= payloadExpiresAtMs) {
      await clear();
      return null;
    }

    if (rawLevel.isEmpty &&
        rawCode.isEmpty &&
        rawMessage.isEmpty &&
        payload.isEmpty) {
      return null;
    }

    return CachedSecurityVerdict(
      levelKey: rawLevel.isEmpty ? null : rawLevel,
      code: rawCode,
      message: rawMessage,
      payload: payload,
      expiresAtMs: expiresAtMs > 0 ? expiresAtMs : payloadExpiresAtMs,
    );
  }

  Future<void> clear() async {
    final prefs = await _prefsProvider();
    await prefs.remove(_riskLevelKey);
    await prefs.remove(_riskCodeKey);
    await prefs.remove(_riskMessageKey);
    await prefs.remove(_riskPayloadKey);
    await prefs.remove(_riskExpiresAtKey);
  }

  int _resolveExpiresAtMs(
    Map<String, dynamic> payload,
    int nowMs,
    Duration? ttl,
  ) {
    if (ttl != null && ttl > Duration.zero) {
      return nowMs + ttl.inMilliseconds;
    }
    return _readInt(payload['expiresAtMs']);
  }
}

int _readInt(Object? raw) {
  if (raw is int) return raw;
  if (raw is double) return raw.toInt();
  if (raw is String) return int.tryParse(raw) ?? 0;
  return 0;
}
