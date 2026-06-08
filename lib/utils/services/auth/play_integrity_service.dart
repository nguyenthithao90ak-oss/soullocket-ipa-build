import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../../core/constants/app_config.dart';
import '../../utils/app_error_mapper.dart';
import '../app_check_http_headers.dart';
import '../revenue_security_telemetry_service.dart';
import 'auth_support.dart';

enum PlayIntegrityRiskLevel { allow, warn, block }

enum PlayIntegrityAssessmentStatus { verified, unavailable, failed }

class PlayIntegrityAssessment {
  const PlayIntegrityAssessment({
    required this.status,
    required this.riskLevel,
    required this.enforcement,
    required this.flow,
    required this.reasons,
    required this.signals,
    required this.requestHash,
    this.requestId,
    this.errorCode,
    this.message,
    this.packageName,
    this.evaluatedAtMillis,
  });

  final PlayIntegrityAssessmentStatus status;
  final PlayIntegrityRiskLevel riskLevel;
  final String enforcement;
  final String flow;
  final List<String> reasons;
  final Map<String, dynamic> signals;
  final String requestHash;
  final String? requestId;
  final String? errorCode;
  final String? message;
  final String? packageName;
  final int? evaluatedAtMillis;

  bool get isVerified => status == PlayIntegrityAssessmentStatus.verified;

  factory PlayIntegrityAssessment.fromJson(Map<String, dynamic> json) {
    final status = _statusFromString(json['status']?.toString());
    final riskLevel = _riskLevelFromString(json['riskLevel']?.toString());
    return PlayIntegrityAssessment(
      status: status,
      riskLevel: riskLevel,
      enforcement:
          _normalizeText(json['enforcement']) ?? _defaultEnforcement(riskLevel),
      flow: _normalizeText(json['flow']) ?? '',
      reasons: _normalizeStringList(json['reasons']),
      signals: _normalizeMap(json['signals']),
      requestHash: _normalizeText(json['requestHash']) ?? '',
      requestId: _normalizeText(json['requestId']),
      errorCode: _normalizeText(json['error']),
      message: _normalizeText(json['message']),
      packageName: _normalizeText(json['packageName']),
      evaluatedAtMillis: _toInt(json['evaluatedAtMillis']),
    );
  }

  factory PlayIntegrityAssessment.unavailable({
    required String flow,
    required String requestHash,
    required String reason,
    String? message,
    String? requestId,
    PlayIntegrityRiskLevel riskLevel = PlayIntegrityRiskLevel.warn,
  }) {
    return PlayIntegrityAssessment(
      status: PlayIntegrityAssessmentStatus.unavailable,
      riskLevel: riskLevel,
      enforcement: _defaultEnforcement(riskLevel),
      flow: flow,
      reasons: <String>[reason],
      signals: const <String, dynamic>{},
      requestHash: requestHash,
      requestId: requestId,
      errorCode: reason,
      message: message,
    );
  }

  factory PlayIntegrityAssessment.failure({
    required String flow,
    required String requestHash,
    required String reason,
    String? message,
    String? requestId,
    PlayIntegrityRiskLevel riskLevel = PlayIntegrityRiskLevel.warn,
  }) {
    return PlayIntegrityAssessment(
      status: PlayIntegrityAssessmentStatus.failed,
      riskLevel: riskLevel,
      enforcement: _defaultEnforcement(riskLevel),
      flow: flow,
      reasons: <String>[reason],
      signals: const <String, dynamic>{},
      requestHash: requestHash,
      requestId: requestId,
      errorCode: reason,
      message: message,
    );
  }

  static PlayIntegrityAssessmentStatus _statusFromString(String? value) {
    switch (value?.trim().toLowerCase()) {
      case 'verified':
        return PlayIntegrityAssessmentStatus.verified;
      case 'unavailable':
        return PlayIntegrityAssessmentStatus.unavailable;
      default:
        return PlayIntegrityAssessmentStatus.failed;
    }
  }

  static PlayIntegrityRiskLevel _riskLevelFromString(String? value) {
    switch (value?.trim().toLowerCase()) {
      case 'allow':
        return PlayIntegrityRiskLevel.allow;
      case 'block':
        return PlayIntegrityRiskLevel.block;
      default:
        return PlayIntegrityRiskLevel.warn;
    }
  }

  static String _defaultEnforcement(PlayIntegrityRiskLevel riskLevel) {
    switch (riskLevel) {
      case PlayIntegrityRiskLevel.allow:
        return 'allow';
      case PlayIntegrityRiskLevel.block:
        return 'block';
      case PlayIntegrityRiskLevel.warn:
        return 'step_up';
    }
  }

  static List<String> _normalizeStringList(Object? value) {
    if (value is! List) return const <String>[];
    final values = <String>[];
    for (final item in value) {
      final normalized = _normalizeText(item);
      if (normalized != null) {
        values.add(normalized);
      }
    }
    return values;
  }

  static Map<String, dynamic> _normalizeMap(Object? value) {
    if (value is! Map) return const <String, dynamic>{};
    final normalized = <String, dynamic>{};
    value.forEach((key, dynamic item) {
      final normalizedKey = _normalizeText(key);
      if (normalizedKey == null) return;
      normalized[normalizedKey] = item;
    });
    return normalized;
  }

  static String? _normalizeText(Object? value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }

  static int? _toInt(Object? value) {
    final normalized = int.tryParse(value?.toString() ?? '');
    return normalized;
  }
}

class PlayIntegrityService {
  PlayIntegrityService({
    firebase_auth.FirebaseAuth? firebaseAuth,
    HttpPost? httpPost,
    NowProvider? nowProvider,
    MethodChannel? methodChannel,
  })  : _firebaseAuth = firebaseAuth,
        _httpPost = httpPost ?? http.post,
        _nowProvider = nowProvider ?? DateTime.now,
        _methodChannel = methodChannel ?? _defaultMethodChannel;

  // Native contract for the Android owner:
  // channel: soul_locket/play_integrity
  // methods: prepareIntegrityToken(cloudProjectNumber),
  //          requestIntegrityToken(cloudProjectNumber, requestHash)
  static const MethodChannel _defaultMethodChannel =
      MethodChannel('soul_locket/play_integrity');
  static const String _prepareMethod = 'prepareIntegrityToken';
  static const String _requestMethod = 'requestIntegrityToken';
  static const Duration _requestTimeout = Duration(seconds: 4);
  static const Duration _warmUpTimeout = Duration(seconds: 4);
  static const Duration _serverTimeout = Duration(seconds: 20);

  final firebase_auth.FirebaseAuth? _firebaseAuth;
  final HttpPost _httpPost;
  final NowProvider _nowProvider;
  final MethodChannel _methodChannel;

  bool _prepared = false;

  firebase_auth.FirebaseAuth get _auth =>
      _firebaseAuth ?? firebase_auth.FirebaseAuth.instance;

  bool get _isAndroidSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<bool> warmUp({bool force = false}) async {
    if (!_isAndroidSupported) return false;
    if (_prepared && !force) return true;
    try {
      await _methodChannel.invokeMethod<void>(
        _prepareMethod,
        <String, Object?>{
          'cloudProjectNumber': AppConfig.playIntegrityCloudProjectNumber,
        },
      ).timeout(_warmUpTimeout);
      _prepared = true;
      return true;
    } on MissingPluginException {
      _prepared = false;
      return false;
    } on TimeoutException {
      _prepared = false;
      debugPrint('PlayIntegrity warmUp timed out.');
      return false;
    } on PlatformException catch (error) {
      _prepared = false;
      debugPrint('PlayIntegrity warmUp failed: ${AppErrorMapper.resolve(
        error,
        fallbackMessage: 'Không thể khởi tạo Play Integrity.',
      ).message}');
      return false;
    }
  }

  Future<Map<String, dynamic>?> buildIntegrityPayload({
    required String flow,
    String? uid,
    String? houseId,
    Map<String, dynamic> payload = const <String, dynamic>{},
    bool autoWarmUp = true,
  }) async {
    final normalizedFlow = flow.trim().toLowerCase();
    final nowMillis = _nowProvider().millisecondsSinceEpoch;
    final requestId = _buildRequestId(nowMillis);
    final normalizedPayload =
        _normalizeJsonValue(payload) as Map<String, dynamic>;
    final currentUser = _auth.currentUser;
    final requestBody = <String, dynamic>{
      'flow': normalizedFlow,
      'requestId': requestId,
      'issuedAtMillis': nowMillis,
      if ((uid ?? currentUser?.uid)?.trim().isNotEmpty == true)
        'uid': (uid ?? currentUser?.uid)!.trim(),
      if (houseId?.trim().isNotEmpty == true) 'houseId': houseId!.trim(),
      if (normalizedPayload.isNotEmpty) 'payload': normalizedPayload,
    };
    final requestHash = buildRequestHash(requestBody);
    if (normalizedFlow.isEmpty || !_isAndroidSupported) {
      return null;
    }
    if (autoWarmUp) {
      final prepared = await warmUp();
      if (!prepared) {
        return null;
      }
    }
    final integrityToken = await _requestIntegrityToken(requestHash: requestHash);
    if (integrityToken == null || integrityToken.isEmpty) {
      return null;
    }
    return <String, dynamic>{
      ...requestBody,
      'requestHash': requestHash,
      'integrityToken': integrityToken,
    };
  }

  Future<PlayIntegrityAssessment> assess({
    required String flow,
    String? uid,
    String? houseId,
    Map<String, dynamic> payload = const <String, dynamic>{},
    bool autoWarmUp = true,
  }) async {
    final normalizedFlow = flow.trim().toLowerCase();
    final nowMillis = _nowProvider().millisecondsSinceEpoch;
    final requestId = _buildRequestId(nowMillis);
    final normalizedPayload =
        _normalizeJsonValue(payload) as Map<String, dynamic>;
    final currentUser = _auth.currentUser;
    final requestBody = <String, dynamic>{
      'flow': normalizedFlow,
      'requestId': requestId,
      'issuedAtMillis': nowMillis,
      if ((uid ?? currentUser?.uid)?.trim().isNotEmpty == true)
        'uid': (uid ?? currentUser?.uid)!.trim(),
      if (houseId?.trim().isNotEmpty == true) 'houseId': houseId!.trim(),
      if (normalizedPayload.isNotEmpty) 'payload': normalizedPayload,
    };
    final requestHash = buildRequestHash(requestBody);

    if (normalizedFlow.isEmpty) {
      return PlayIntegrityAssessment.failure(
        flow: '',
        requestHash: requestHash,
        requestId: requestId,
        reason: 'missing_flow',
        message: kDebugMode
            ? 'Flow Play Integrity không được để trống.'
            : 'Thiết bị chưa sẵn sàng để kiểm tra an toàn.',
      );
    }

    if (!_isAndroidSupported) {
      return PlayIntegrityAssessment.unavailable(
        flow: normalizedFlow,
        requestHash: requestHash,
        requestId: requestId,
        reason: 'unsupported_platform',
        message: kDebugMode
            ? 'Play Integrity hiện chỉ áp dụng cho Android.'
            : 'Tính năng kiểm tra an toàn hiện chưa áp dụng trên thiết bị này.',
        riskLevel: PlayIntegrityRiskLevel.allow,
      );
    }

    if (autoWarmUp) {
      final prepared = await warmUp();
      if (!prepared) {
        return PlayIntegrityAssessment.unavailable(
          flow: normalizedFlow,
          requestHash: requestHash,
          requestId: requestId,
          reason: 'native_bridge_unavailable',
          message: kDebugMode
              ? 'Chưa có Android bridge cho Play Integrity. Cần owner native nối method channel.'
              : 'Thiết bị chưa sẵn sàng để kiểm tra an toàn.',
        );
      }
    }

    final integrityToken = await _requestIntegrityToken(
      requestHash: requestHash,
    );
    if (integrityToken == null || integrityToken.isEmpty) {
      return PlayIntegrityAssessment.failure(
        flow: normalizedFlow,
        requestHash: requestHash,
        requestId: requestId,
        reason: 'integrity_token_missing',
        message: kDebugMode
            ? 'Không lấy được Play Integrity token từ Android.'
            : 'Không kiểm tra được độ an toàn của thiết bị.',
      );
    }

    final endpoint = AppConfig.playIntegrityVerifyUrl.trim();
    if (endpoint.isEmpty) {
      return PlayIntegrityAssessment.failure(
        flow: normalizedFlow,
        requestHash: requestHash,
        requestId: requestId,
        reason: 'endpoint_not_configured',
        message: kDebugMode
            ? 'Chưa cấu hình endpoint verify Play Integrity.'
            : 'Hệ thống kiểm tra an toàn hiện chưa sẵn sàng.',
      );
    }

    try {
      var authHeaders = <String, String>{
        'Content-Type': 'application/json',
      };
      String? idToken;
      if (currentUser != null) {
        idToken = await currentUser.getIdToken();
      }
      if ((idToken ?? '').isNotEmpty) {
        authHeaders['Authorization'] = 'Bearer $idToken';
      }
      authHeaders = await AppCheckHttpHeaders.withRequiredToken(
        authHeaders,
        forceRefresh: true,
      );

      final response = await _httpPost(
        Uri.parse(endpoint),
        headers: authHeaders,
        body: jsonEncode(<String, dynamic>{
          ...requestBody,
          'requestHash': requestHash,
          'integrityToken': integrityToken,
        }),
      ).timeout(_serverTimeout);

      final decoded = _decodeResponseBody(response.body);
      if (response.statusCode == 200 && decoded['ok'] == true) {
        return PlayIntegrityAssessment.fromJson(decoded);
      }

      final reason =
          _stringOrFallback(decoded['error'], 'verify_play_integrity_failed');
      unawaited(
        RevenueSecurityTelemetryService.instance.logEvent(
          type: 'play_integrity_failed',
          reason: reason,
          severity: response.statusCode >= 500 ? 'medium' : 'high',
          extra: <String, Object?>{
            'statusCode': response.statusCode,
            'flow': normalizedFlow,
          },
        ),
      );
      return PlayIntegrityAssessment.failure(
        flow: normalizedFlow,
        requestHash: requestHash,
        requestId: requestId,
        reason: reason,
        message: _stringOrFallback(
          decoded['message'],
          kDebugMode
              ? 'Máy chủ Play Integrity trả về phản hồi lỗi.'
              : 'Hệ thống kiểm tra an toàn đang gặp sự cố. Hãy thử lại sau.',
        ),
        riskLevel: response.statusCode >= 500
            ? PlayIntegrityRiskLevel.warn
            : PlayIntegrityRiskLevel.block,
      );
    } on TimeoutException {
      unawaited(
        RevenueSecurityTelemetryService.instance.logEvent(
          type: 'play_integrity_failed',
          reason: 'verify_timeout',
          severity: 'medium',
          extra: <String, Object?>{
            'flow': normalizedFlow,
          },
        ),
      );
      return PlayIntegrityAssessment.failure(
        flow: normalizedFlow,
        requestHash: requestHash,
        requestId: requestId,
        reason: 'verify_timeout',
        message: kDebugMode
            ? 'Máy chủ verify Play Integrity phản hồi quá chậm.'
            : 'Hệ thống kiểm tra an toàn phản hồi quá chậm. Hãy thử lại sau.',
      );
    } catch (error) {
      debugPrint('PlayIntegrity assess failed: ${AppErrorMapper.resolve(
        error,
        fallbackMessage: 'Không thể kiểm tra Play Integrity.',
      ).message}');
      unawaited(
        RevenueSecurityTelemetryService.instance.logEvent(
          type: 'play_integrity_failed',
          reason: error is StateError ? 'missing_app_check' : 'verify_request_failed',
          severity: 'high',
          extra: <String, Object?>{
            'flow': normalizedFlow,
          },
        ),
      );
      return PlayIntegrityAssessment.failure(
        flow: normalizedFlow,
        requestHash: requestHash,
        requestId: requestId,
        reason: 'verify_request_failed',
        message: kDebugMode
            ? 'Không gửi được request verify Play Integrity.'
            : 'Không gửi được yêu cầu kiểm tra an toàn. Hãy kiểm tra mạng rồi thử lại.',
      );
    }
  }

  Future<String?> _requestIntegrityToken({
    required String requestHash,
  }) async {
    try {
      final token = await _methodChannel.invokeMethod<String>(
        _requestMethod,
        <String, Object?>{
          'cloudProjectNumber': AppConfig.playIntegrityCloudProjectNumber,
          'requestHash': requestHash,
        },
      ).timeout(_requestTimeout);
      final normalized = token?.trim() ?? '';
      return normalized.isEmpty ? null : normalized;
    } on MissingPluginException {
      _prepared = false;
      return null;
    } on PlatformException catch (error) {
      debugPrint(
        'PlayIntegrity request token failed: ${error.code} ${error.message}',
      );
      return null;
    } on TimeoutException {
      return null;
    }
  }

  String buildRequestHash(Map<String, dynamic> requestBody) {
    final canonical = _stableStringify(_normalizeJsonValue(requestBody));
    return sha256.convert(utf8.encode(canonical)).toString();
  }

  static String _buildRequestId(int nowMillis) {
    final entropy = nowMillis ^ Object().hashCode;
    final suffix = entropy.abs().toRadixString(36).padLeft(6, '0');
    return '${nowMillis.toRadixString(36)}-$suffix';
  }

  static Map<String, dynamic> _decodeResponseBody(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      if (decoded is Map) {
        return decoded.map(
          (key, value) => MapEntry(key.toString(), value),
        );
      }
    } catch (_) {}
    return <String, dynamic>{};
  }

  static String _stringOrFallback(Object? value, String fallback) {
    final normalized = value?.toString().trim() ?? '';
    return normalized.isEmpty ? fallback : normalized;
  }

  static Object? _normalizeJsonValue(Object? value) {
    if (value == null || value is num || value is bool || value is String) {
      return value;
    }
    if (value is List) {
      return value.map(_normalizeJsonValue).toList(growable: false);
    }
    if (value is Map) {
      final normalized = <String, dynamic>{};
      final entries = value.entries.toList()
        ..sort(
          (left, right) => left.key.toString().compareTo(right.key.toString()),
        );
      for (final entry in entries) {
        normalized[entry.key.toString()] = _normalizeJsonValue(entry.value);
      }
      return normalized;
    }
    return value.toString();
  }

  static String _stableStringify(Object? value) {
    if (value == null || value is num || value is bool || value is String) {
      return jsonEncode(value);
    }
    if (value is List) {
      final items = value.map(_stableStringify).join(',');
      return '[$items]';
    }
    if (value is Map) {
      final keys = value.keys.map((key) => key.toString()).toList()..sort();
      final entries = keys.map((key) {
        final encodedKey = jsonEncode(key);
        final encodedValue = _stableStringify(value[key]);
        return '$encodedKey:$encodedValue';
      }).join(',');
      return '{$entries}';
    }
    return jsonEncode(value.toString());
  }
}
