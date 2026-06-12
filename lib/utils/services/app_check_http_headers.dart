import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../app_error_mapper.dart';

class AppCheckHttpHeaders {
  AppCheckHttpHeaders._();

  static const String headerName = 'X-Firebase-AppCheck';
  static const String appSignatureHeaderName = 'X-App-Signature';

  static const MethodChannel _bootstrapChannel = MethodChannel('soul_locket/bootstrap');

  /// Cache the app signature status across headers calls
  static String? _cachedSignatureHash;
  static DateTime? _lastSignatureFetch;
  static const Duration _signatureCacheTtl = Duration(minutes: 30);

  static Future<Map<String, String>> withOptionalToken(
    Map<String, String> headers, {
    bool forceRefresh = false,
  }) {
    return withToken(
      headers,
      forceRefresh: forceRefresh,
      requiredToken: false,
    );
  }

  static Future<Map<String, String>> withRequiredToken(
    Map<String, String> headers, {
    bool forceRefresh = false,
  }) {
    return withToken(
      headers,
      forceRefresh: forceRefresh,
      requiredToken: true,
    );
  }

  static Future<Map<String, String>> withToken(
    Map<String, String> headers, {
    bool forceRefresh = false,
    bool requiredToken = false,
  }) async {
    final mergedHeaders = Map<String, String>.from(headers);

    // ── 1. App Check token ─────────────────────────────────────
    await _addAppCheckToken(mergedHeaders, forceRefresh: forceRefresh, requiredToken: requiredToken);

    // ── 2. App Signature header (chống resign) ─────────────────
    await _addAppSignatureHeader(mergedHeaders);

    return mergedHeaders;
  }

  /// Add Firebase App Check token to headers.
  static Future<void> _addAppCheckToken(
    Map<String, String> headers, {
    bool forceRefresh = false,
    bool requiredToken = false,
  }) async {
    Future<String?> loadToken(bool refresh) {
      return FirebaseAppCheck.instance.getToken(refresh);
    }

    try {
      var token = await loadToken(forceRefresh);
      var normalizedToken = token?.trim() ?? '';

      if (normalizedToken.isEmpty && forceRefresh) {
        token = await loadToken(false);
        normalizedToken = token?.trim() ?? '';
      }

      if (normalizedToken.isNotEmpty) {
        headers[headerName] = normalizedToken;
        return;
      }
      if (requiredToken) {
        throw StateError('Firebase App Check token is empty.');
      }
    } catch (error) {
      if (forceRefresh && error.toString().contains('Too many attempts')) {
        try {
          final fallbackToken = await loadToken(false);
          final normalizedFallbackToken = fallbackToken?.trim() ?? '';
          if (normalizedFallbackToken.isNotEmpty) {
            headers[headerName] = normalizedFallbackToken;
            return;
          }
        } catch (_) {}
      }
      if (kDebugMode) {
        debugPrint('App Check token unavailable for HTTP headers: ${AppErrorMapper.resolve(error).message}');
      }
      if (requiredToken) {
        rethrow;
      }
    }
  }

  /// Add X-App-Signature header from native signature status.
  ///
  /// Giá trị là SHA-256 hash của chữ ký app thật (từ native Kotlin).
  /// Server sẽ kiểm tra hash này để phát hiện app đã bị resign.
  static Future<void> _addAppSignatureHeader(Map<String, String> headers) async {
    if (kIsWeb) return;

    // Use cached value if fresh enough
    if (_cachedSignatureHash != null && _lastSignatureFetch != null) {
      if (DateTime.now().difference(_lastSignatureFetch!) < _signatureCacheTtl) {
        headers[appSignatureHeaderName] = _cachedSignatureHash!;
        return;
      }
    }

    try {
      final result = await _bootstrapChannel
          .invokeMethod<Map>('getAppSignatureStatus')
          .timeout(const Duration(seconds: 3));

      if (result == null) return;

      final status = result['status']?.toString() ?? '';
      final reasonCode = result['reasonCode']?.toString() ?? '';
      final signatureSha256 = result['signatureSha256']?.toString() ?? '';

      if (status == 'ok' && signatureSha256.isNotEmpty) {
        // Hash the actual signature SHA-256 for the header
        final hash = sha256.convert(utf8.encode(signatureSha256)).toString();
        _cachedSignatureHash = hash;
        _lastSignatureFetch = DateTime.now();
        headers[appSignatureHeaderName] = hash;
      } else if (reasonCode == 'debug_build') {
        // Debug build: send a known debug marker instead
        final debugHash = sha256.convert(utf8.encode('debug_build')).toString();
        _cachedSignatureHash = debugHash;
        _lastSignatureFetch = DateTime.now();
        headers[appSignatureHeaderName] = debugHash;
      }
      // Nếu signature không match (unofficial_build): không gửi header — server sẽ nghi ngờ.
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to read app signature: ${AppErrorMapper.resolve(e).message}');
      }
    }
  }

  /// Xoá cache signature (gọi khi cần force refresh)
  static void invalidateSignatureCache() {
    _cachedSignatureHash = null;
    _lastSignatureFetch = null;
  }
}
