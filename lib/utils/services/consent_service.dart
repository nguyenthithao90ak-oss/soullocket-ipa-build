import 'package:shared_preferences/shared_preferences.dart';

import 'offline_cache_service.dart';

class ConsentService {
  static const String tosAcceptedKey = 'il_tos_accepted';
  static const String privacyAcceptedKey = 'il_privacy_accepted';
  static const String cookieConsentKey = 'il_cookie_storage_consent';
  static const String securityDeviceSignalsConsentKey =
      'il_security_device_signals_consent';

  Future<bool> isTosAccepted() async {
    final prefs = OfflineCacheService.getPrefsSync() ??
        await SharedPreferences.getInstance();
    return prefs.getBool(tosAcceptedKey) ?? false;
  }

  Future<void> setTosAccepted(bool value) async {
    final prefs = OfflineCacheService.getPrefsSync() ??
        await SharedPreferences.getInstance();
    await prefs.setBool(tosAcceptedKey, value);
  }

  Future<bool> isPrivacyAccepted() async {
    final prefs = OfflineCacheService.getPrefsSync() ??
        await SharedPreferences.getInstance();
    return prefs.getBool(privacyAcceptedKey) ?? false;
  }

  Future<void> setPrivacyAccepted(bool value) async {
    final prefs = OfflineCacheService.getPrefsSync() ??
        await SharedPreferences.getInstance();
    await prefs.setBool(privacyAcceptedKey, value);
  }

  Future<String?> getCookieConsentLevel() async {
    final prefs = OfflineCacheService.getPrefsSync() ??
        await SharedPreferences.getInstance();
    final value = _normalizeConsentValue(prefs.getString(cookieConsentKey));
    if (value == null) return null;
    return value;
  }

  Future<void> setCookieConsentLevel(String level) async {
    final prefs = OfflineCacheService.getPrefsSync() ??
        await SharedPreferences.getInstance();
    final value = _normalizeConsentValue(level);
    if (value == null) {
      await prefs.remove(cookieConsentKey);
      return;
    }
    await prefs.setString(cookieConsentKey, value);
  }

  Future<String?> getSecurityDeviceSignalsConsentStatus() async {
    final prefs = OfflineCacheService.getPrefsSync() ??
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
    final prefs = OfflineCacheService.getPrefsSync() ??
        await SharedPreferences.getInstance();
    await prefs.setString(
      securityDeviceSignalsConsentKey,
      value ? 'accepted' : 'declined',
    );
  }

  Future<bool> hasValidConsent() async {
    final tosAccepted = await isTosAccepted();
    if (!tosAccepted) return false;
    final privacyAccepted = await isPrivacyAccepted();
    if (!privacyAccepted) return false;
    final cookieLevel = await getCookieConsentLevel();
    return cookieLevel != null && cookieLevel.trim().isNotEmpty;
  }

  Future<void> clearAll() async {
    final prefs = OfflineCacheService.getPrefsSync() ??
        await SharedPreferences.getInstance();
    await prefs.remove(tosAcceptedKey);
    await prefs.remove(privacyAcceptedKey);
    await prefs.remove(cookieConsentKey);
    await prefs.remove(securityDeviceSignalsConsentKey);
  }

  String? _normalizeConsentValue(String? value) {
    final normalized = value?.trim().toLowerCase();
    if (normalized == null || normalized.isEmpty) return null;
    return normalized;
  }
}
