import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'offline_cache_service.dart';

class ConsentService {
  static const currentPolicyVersion = '2026-09-09';
  static const policyVersionKey = 'il_consent_policy_version';
  static const recordedAtKey = 'il_consent_recorded_at';
  static final ValueNotifier<bool> optionalCollectionAllowed = ValueNotifier(
    false,
  );
  static Future<void>? _pendingChoiceWrite;
  static int _choiceRevision = 0;
  static const String tosAcceptedKey = 'il_tos_accepted';
  static const String privacyAcceptedKey = 'il_privacy_accepted';
  static const String cookieConsentKey = 'il_cookie_storage_consent';
  static const String securityDeviceSignalsConsentKey =
      'il_security_device_signals_consent';

  Future<bool> isTosAccepted() async {
    final prefs =
        OfflineCacheService.getPrefsSync() ??
        await SharedPreferences.getInstance();
    return prefs.getBool(tosAcceptedKey) ?? false;
  }

  Future<void> setTosAccepted(bool value) async {
    if (!value) optionalCollectionAllowed.value = false;
    final prefs =
        OfflineCacheService.getPrefsSync() ??
        await SharedPreferences.getInstance();
    await prefs.setBool(tosAcceptedKey, value);
    await refreshCollectionPermission();
  }

  Future<bool> isPrivacyAccepted() async {
    final prefs =
        OfflineCacheService.getPrefsSync() ??
        await SharedPreferences.getInstance();
    return prefs.getBool(privacyAcceptedKey) ?? false;
  }

  Future<void> setPrivacyAccepted(bool value) async {
    if (!value) optionalCollectionAllowed.value = false;
    final prefs =
        OfflineCacheService.getPrefsSync() ??
        await SharedPreferences.getInstance();
    await prefs.setBool(privacyAcceptedKey, value);
    await refreshCollectionPermission();
  }

  Future<String?> getCookieConsentLevel() async {
    final prefs =
        OfflineCacheService.getPrefsSync() ??
        await SharedPreferences.getInstance();
    final value = _normalizeCookieLevel(prefs.getString(cookieConsentKey));
    if (value == null) return null;
    return value;
  }

  Future<void> setCookieConsentLevel(String level) async {
    optionalCollectionAllowed.value = false;
    final prefs =
        OfflineCacheService.getPrefsSync() ??
        await SharedPreferences.getInstance();
    final value = _normalizeCookieLevel(level);
    if (value == null) {
      await prefs.remove(cookieConsentKey);
      return;
    }
    await prefs.setString(cookieConsentKey, value);
    await refreshCollectionPermission();
  }

  /// Chỉ gọi sau thao tác đồng ý thật; không gán phiên bản mới cho lựa chọn cũ.
  Future<void> recordStartupConsent(String level) {
    final normalized = _normalizeCookieLevel(level);
    if (normalized == null) throw ArgumentError.value(level, 'level');
    optionalCollectionAllowed.value = false;
    final revision = ++_choiceRevision;
    final previous = _pendingChoiceWrite;
    final completed = Completer<void>();
    _pendingChoiceWrite = completed.future;
    return () async {
      try {
        if (previous != null) await previous;
        await _recordChoice(normalized, revision);
      } finally {
        if (identical(_pendingChoiceWrite, completed.future)) {
          _pendingChoiceWrite = null;
        }
        completed.complete();
      }
    }();
  }

  Future<void> _recordChoice(String normalized, int revision) async {
    final prefs =
        OfflineCacheService.getPrefsSync() ??
        await SharedPreferences.getInstance();
    // Version là dấu hoàn tất: nếu lưu dở hoặc lỗi, không bật SDK tùy chọn.
    if (!await prefs.remove(policyVersionKey)) {
      throw StateError('Consent preferences could not be saved');
    }
    final written =
        await prefs.setBool(tosAcceptedKey, true) &&
        await prefs.setBool(privacyAcceptedKey, true) &&
        await prefs.setString(cookieConsentKey, normalized) &&
        await prefs.setString(
          recordedAtKey,
          DateTime.now().toUtc().toIso8601String(),
        );
    if (!written ||
        !await prefs.setString(policyVersionKey, currentPolicyVersion)) {
      throw StateError('Consent preferences could not be saved');
    }
    if (revision == _choiceRevision) await refreshCollectionPermission();
  }

  Future<void> refreshCollectionPermission() async {
    try {
      final prefs =
          OfflineCacheService.getPrefsSync() ??
          await SharedPreferences.getInstance();
      optionalCollectionAllowed.value =
          _hasValidConsent(prefs) &&
          _normalizeCookieLevel(prefs.getString(cookieConsentKey)) == 'all';
    } catch (_) {
      optionalCollectionAllowed.value = false;
      rethrow;
    }
  }

  bool _hasValidConsent(SharedPreferences prefs) =>
      prefs.getString(policyVersionKey) == currentPolicyVersion &&
      DateTime.tryParse(prefs.getString(recordedAtKey) ?? '') != null &&
      prefs.getBool(tosAcceptedKey) == true &&
      prefs.getBool(privacyAcceptedKey) == true &&
      _normalizeCookieLevel(prefs.getString(cookieConsentKey)) != null;

  Future<String?> getSecurityDeviceSignalsConsentStatus() async {
    final prefs =
        OfflineCacheService.getPrefsSync() ??
        await SharedPreferences.getInstance();
    return _normalizeConsentValue(
      prefs.getString(securityDeviceSignalsConsentKey),
    );
  }

  Future<bool> hasResolvedSecurityDeviceSignalsConsent() async {
    final status = await getSecurityDeviceSignalsConsentStatus();
    return status != null;
  }

  Future<bool> isSecurityDeviceSignalsAllowed() async {
    final status = await getSecurityDeviceSignalsConsentStatus();
    return status == 'accepted';
  }

  Future<void> setSecurityDeviceSignalsAllowed(bool value) async {
    final prefs =
        OfflineCacheService.getPrefsSync() ??
        await SharedPreferences.getInstance();
    await prefs.setString(
      securityDeviceSignalsConsentKey,
      value ? 'accepted' : 'declined',
    );
  }

  Future<bool> hasValidConsent() async {
    final prefs =
        OfflineCacheService.getPrefsSync() ??
        await SharedPreferences.getInstance();
    return _hasValidConsent(prefs);
  }

  bool isTosAcceptedSync() {
    final prefs = OfflineCacheService.getPrefsSync();
    if (prefs == null) return false;
    return prefs.getBool(tosAcceptedKey) ?? false;
  }

  bool isPrivacyAcceptedSync() {
    final prefs = OfflineCacheService.getPrefsSync();
    if (prefs == null) return false;
    return prefs.getBool(privacyAcceptedKey) ?? false;
  }

  String? getCookieConsentLevelSync() {
    final prefs = OfflineCacheService.getPrefsSync();
    if (prefs == null) return null;
    return _normalizeCookieLevel(prefs.getString(cookieConsentKey));
  }

  bool hasValidConsentSync() {
    final prefs = OfflineCacheService.getPrefsSync();
    return prefs != null && _hasValidConsent(prefs);
  }

  Future<void> clearAll() async {
    optionalCollectionAllowed.value = false;
    final prefs =
        OfflineCacheService.getPrefsSync() ??
        await SharedPreferences.getInstance();
    await prefs.remove(tosAcceptedKey);
    await prefs.remove(privacyAcceptedKey);
    await prefs.remove(cookieConsentKey);
    await prefs.remove(securityDeviceSignalsConsentKey);
    await prefs.remove(policyVersionKey);
    await prefs.remove(recordedAtKey);
  }

  String? _normalizeCookieLevel(String? value) {
    final normalized = _normalizeConsentValue(value);
    return normalized == 'essential' || normalized == 'all' ? normalized : null;
  }

  String? _normalizeConsentValue(String? value) {
    final normalized = value?.trim().toLowerCase();
    if (normalized == null || normalized.isEmpty) return null;
    return normalized;
  }
}
