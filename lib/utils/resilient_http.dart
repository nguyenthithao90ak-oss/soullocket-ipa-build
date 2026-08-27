import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

/// Resilient HTTP client with automatic retry + exponential backoff.
/// Drop-in replacement for http.get / http.post.
class ResilientHttp {
  ResilientHttp._();
  
  static const int _maxRetries = 2;
  static const Duration _baseDelay = Duration(milliseconds: 500);
  
  /// GET with automatic retry on transient failures.
  static Future<http.Response> get(Uri url, {Map<String, String>? headers}) async {
    return _retry(() => http.get(url, headers: headers));
  }
  
  /// POST with automatic retry on transient failures.
  static Future<http.Response> post(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  }) async {
    return _retry(() => http.post(url, headers: headers, body: body, encoding: encoding));
  }
  
  /// PUT with automatic retry on transient failures.
  static Future<http.Response> put(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  }) async {
    return _retry(() => http.put(url, headers: headers, body: body, encoding: encoding));
  }

  /// Core retry logic with exponential backoff.
  /// Only retries on network-level errors (SocketException, TimeoutException, ClientException).
  /// Does NOT retry on HTTP error status codes (4xx, 5xx) — those are business logic.
  static Future<http.Response> _retry(
    Future<http.Response> Function() action, {
    int maxRetries = _maxRetries,
  }) async {
    int attempt = 0;
    while (true) {
      try {
        return await action().timeout(const Duration(seconds: 15));
      } catch (e) {
        attempt++;
        final isRetryable = e is TimeoutException ||
            e is http.ClientException ||
            e.toString().contains('SocketException') ||
            e.toString().contains('Connection reset') ||
            e.toString().contains('Connection refused');
        
        if (!isRetryable || attempt > maxRetries) {
          rethrow;
        }
        
        final delay = _baseDelay * (1 << (attempt - 1)); // 500ms, 1s
        debugPrint('[ResilientHttp] Retry $attempt/$maxRetries after ${delay.inMilliseconds}ms: $e');
        await Future.delayed(delay);
      }
    }
  }
}
