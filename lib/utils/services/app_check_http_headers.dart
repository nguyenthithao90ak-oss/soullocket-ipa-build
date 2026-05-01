import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';

class AppCheckHttpHeaders {
  AppCheckHttpHeaders._();

  static const String headerName = 'X-Firebase-AppCheck';

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

    try {
      final token = await FirebaseAppCheck.instance.getToken(forceRefresh);
      final normalizedToken = token?.trim() ?? '';
      if (normalizedToken.isNotEmpty) {
        mergedHeaders[headerName] = normalizedToken;
        return mergedHeaders;
      }
      if (requiredToken) {
        throw StateError('Firebase App Check token is empty.');
      }
    } catch (error) {
      if (kDebugMode) {
        debugPrint('App Check token unavailable for HTTP headers: $error');
      }
      if (requiredToken) {
        rethrow;
      }
    }

    return mergedHeaders;
  }
}
