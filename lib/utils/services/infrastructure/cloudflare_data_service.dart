import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../../core/constants/app_config.dart';
import '../../app_error_mapper.dart';
import '../house_service.dart';

class CloudflareDataException implements Exception {
  const CloudflareDataException(this.statusCode, {this.retryAfter});

  final int statusCode;
  final Duration? retryAfter;

  @override
  String toString() => 'Cloudflare metadata request failed ($statusCode)';
}

class CloudflareDataService {
  CloudflareDataService()
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
  CloudflareDataService.forTesting({
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

  CloudflareDataService._(
    this._client,
    this._baseUrl,
    this._uidProvider,
    this._houseProvider,
    this._tokenProvider,
    this._appCheckTokenProvider,
    this._timeout,
  );

  static const int maxResponseBytes = 512 * 1024;
  static const Set<String> _resources = {
    'calendar',
    'notes',
    'gps/history',
    'health/cycle',
    'health/periods',
    'diaries',
    'memories',
    'capsules',
    'finances',
  };

  final http.Client _client;
  final Uri _baseUrl;
  final String? Function() _uidProvider;
  final Future<String?> Function() _houseProvider;
  final Future<String?> Function(bool) _tokenProvider;
  final Future<String?> Function(bool) _appCheckTokenProvider;
  final Duration _timeout;
  final _pending = <String, Future<Map<String, dynamic>>>{};
  final _aborts = <Completer<void>>{};
  bool _disposed = false;

  Future<Map<String, dynamic>> readPage({
    required String houseId,
    required String resource,
    Map<String, String> parameters = const {},
  }) async {
    if (_disposed) throw StateError('Cloudflare data service is disposed');
    if (_baseUrl.scheme != 'https' ||
        _baseUrl.host.isEmpty ||
        _baseUrl.userInfo.isNotEmpty ||
        _baseUrl.hasQuery ||
        _baseUrl.hasFragment ||
        (_baseUrl.path.isNotEmpty && _baseUrl.path != '/')) {
      throw ArgumentError('Invalid Cloudflare metadata origin');
    }
    if (!_resources.contains(resource) ||
        !RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(houseId)) {
      throw ArgumentError('Invalid metadata scope');
    }
    final uid = _uidProvider();
    if (uid == null) throw FirebaseAuthException(code: 'user-token-expired');
    await _requireScope(uid, houseId);
    final keys = parameters.keys.toList()..sort();
    final uri = _baseUrl.replace(
      path: '/api/v1/$resource',
      queryParameters: {
        for (final key in keys) key: parameters[key]!,
        'limit': (int.tryParse(parameters['limit'] ?? '') ?? 50)
            .clamp(1, 100)
            .toString(),
      },
    );
    final pendingKey = jsonEncode([uid, houseId, uri.toString()]);
    final existing = _pending[pendingKey];
    if (existing != null) return existing;
    final abort = Completer<void>();
    _aborts.add(abort);
    final operation = _read(uid, houseId, uri, abort).timeout(
      _timeout,
      onTimeout: () {
        if (!abort.isCompleted) abort.complete();
        throw TimeoutException('Metadata request timed out');
      },
    );
    _pending[pendingKey] = operation;
    try {
      return await operation;
    } finally {
      if (!abort.isCompleted) abort.complete();
      _aborts.remove(abort);
      if (identical(_pending[pendingKey], operation)) {
        _pending.remove(pendingKey);
      }
    }
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

  Future<Map<String, dynamic>> _read(
    String uid,
    String houseId,
    Uri uri,
    Completer<void> abort,
  ) async {
    try {
      for (var attempt = 0; attempt < 2; attempt++) {
        final token = await _tokenProvider(attempt > 0);
        await _requireScope(uid, houseId);
        if (abort.isCompleted) {
          throw TimeoutException('Metadata request timed out');
        }
        if (token == null || token.isEmpty) {
          throw FirebaseAuthException(code: 'user-token-expired');
        }
        final appCheckToken = await _appCheckTokenProvider(attempt > 0);
        await _requireScope(uid, houseId);
        if (abort.isCompleted) {
          throw TimeoutException('Metadata request timed out');
        }
        if (appCheckToken == null || appCheckToken.trim().isEmpty) {
          throw FirebaseException(
            plugin: 'firebase_app_check',
            code: 'app-check-token-missing',
          );
        }
        final request =
            http.AbortableRequest('GET', uri, abortTrigger: abort.future)
              ..followRedirects = false
              ..headers.addAll({
                'Authorization': 'Bearer $token',
                'X-Firebase-AppCheck': appCheckToken,
                'X-House-ID': houseId,
                'Accept': 'application/json',
              });
        final response = await _client.send(request).timeout(_timeout);
        final bytes = BytesBuilder(copy: false);
        await for (final chunk in response.stream.timeout(_timeout)) {
          if (bytes.length + chunk.length > maxResponseBytes) {
            throw const FormatException('Metadata response exceeds limit');
          }
          bytes.add(chunk);
        }
        await _requireScope(uid, houseId);
        if (response.statusCode == 401 && attempt == 0) continue;
        if (response.statusCode != 200) {
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
        final decoded = jsonDecode(utf8.decode(bytes.takeBytes()));
        if (decoded is! Map<String, dynamic> || !decoded.containsKey('data')) {
          throw const FormatException('Invalid metadata response');
        }
        return decoded;
      }
      throw const CloudflareDataException(401);
    } catch (error) {
      debugPrint(
        '[CloudflareData] Read failed: ${AppErrorMapper.resolve(error).kind.name}',
      );
      rethrow;
    }
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    for (final abort in _aborts) {
      if (!abort.isCompleted) abort.complete();
    }
    _aborts.clear();
    _pending.clear();
    _client.close();
  }
}
