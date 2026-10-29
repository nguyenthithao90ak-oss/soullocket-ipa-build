import 'package:soullocket_app/utils/ui_copy.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';
import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:soullocket_app/core/constants/app_config.dart';
import 'app_check_http_headers.dart';
import 'auth_service.dart';
import 'offline_cache_service.dart';
import 'revenue_security_telemetry_service.dart';
import 'security_service.dart';
import 'package:flutter/foundation.dart';
import 'package:soullocket_app/utils/services/error_logger_service.dart';
import 'package:soullocket_app/utils/services/core/cloud_functions_helper.dart';

enum BreakupStatus {
  none,
  pending,
  scheduled,
  processing,
  canceled,
}

class BreakupApproval {
  final int ts;
  final String role;
  final String type;
  final String actorUid;

  const BreakupApproval({
    required this.ts,
    required this.role,
    required this.type,
    this.actorUid = '',
  });

  factory BreakupApproval.fromMap(Map<String, dynamic> map) {
    return BreakupApproval(
      ts: _toInt(map['ts']),
      role: (map['role'] ?? '').toString(),
      type: (map['type'] ?? '').toString(),
      actorUid: (map['actorUid'] ?? '').toString(),
    );
  }
}

class BreakupRequestData {
  final BreakupStatus status;
  final int requestedAt;
  final int expireAt;
  final int deleteAt;
  final String requestedByDevice;
  final String requestedByRole;
  final String requestedByName;
  final String requestedByUid;
  final bool pinRequired;
  final String reason;
  final int scheduledAt;
  final int processingAt;
  final int canceledAt;
  final String canceledByDevice;
  final String canceledByRole;
  final String canceledByName;
  final Map<String, BreakupApproval> approvals;

  const BreakupRequestData({
    required this.status,
    required this.requestedAt,
    required this.expireAt,
    required this.deleteAt,
    required this.requestedByDevice,
    required this.requestedByRole,
    required this.requestedByName,
    required this.requestedByUid,
    required this.pinRequired,
    required this.reason,
    required this.scheduledAt,
    required this.processingAt,
    required this.canceledAt,
    required this.canceledByDevice,
    required this.canceledByRole,
    required this.canceledByName,
    required this.approvals,
  });

  bool get isPending => status == BreakupStatus.pending;
  bool get isScheduled => status == BreakupStatus.scheduled;
  bool get isProcessing => status == BreakupStatus.processing;
  bool get isCanceled => status == BreakupStatus.canceled;
  bool get isActive => isPending || isScheduled || isProcessing;
  bool get approvedByPartner => approvals.values.any(
        (approval) =>
            approval.type == 'trusted_partner' &&
            approval.actorUid.isNotEmpty &&
            approval.actorUid != requestedByUid,
      );

  bool isApprovedBy(String deviceId) => approvals.containsKey(deviceId);

  BreakupRequestData copyWith({
    BreakupStatus? status,
    int? requestedAt,
    int? expireAt,
    int? deleteAt,
    String? requestedByDevice,
    String? requestedByRole,
    String? requestedByName,
    String? requestedByUid,
    bool? pinRequired,
    String? reason,
    int? scheduledAt,
    int? processingAt,
    int? canceledAt,
    String? canceledByDevice,
    String? canceledByRole,
    String? canceledByName,
    Map<String, BreakupApproval>? approvals,
  }) {
    return BreakupRequestData(
      status: status ?? this.status,
      requestedAt: requestedAt ?? this.requestedAt,
      expireAt: expireAt ?? this.expireAt,
      deleteAt: deleteAt ?? this.deleteAt,
      requestedByDevice: requestedByDevice ?? this.requestedByDevice,
      requestedByRole: requestedByRole ?? this.requestedByRole,
      requestedByName: requestedByName ?? this.requestedByName,
      requestedByUid: requestedByUid ?? this.requestedByUid,
      pinRequired: pinRequired ?? this.pinRequired,
      reason: reason ?? this.reason,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      processingAt: processingAt ?? this.processingAt,
      canceledAt: canceledAt ?? this.canceledAt,
      canceledByDevice: canceledByDevice ?? this.canceledByDevice,
      canceledByRole: canceledByRole ?? this.canceledByRole,
      canceledByName: canceledByName ?? this.canceledByName,
      approvals: approvals ?? this.approvals,
    );
  }

  factory BreakupRequestData.fromMap(Map<String, dynamic> map) {
    final rawApprovals = _toMap(map['approvals']);
    final approvals = <String, BreakupApproval>{};
    rawApprovals.forEach((key, value) {
      approvals[key] = BreakupApproval.fromMap(_toMap(value));
    });

    return BreakupRequestData(
      status: BreakupService._statusFromString(
        (map['status'] ?? '').toString(),
      ),
      requestedAt: _toInt(map['requestedAt']),
      expireAt: _toInt(map['expireAt']),
      deleteAt: _toInt(map['deleteAt']),
      requestedByDevice: (map['requestedByDevice'] ?? '').toString(),
      requestedByRole: (map['requestedByRole'] ?? '').toString(),
      requestedByName: (map['requestedByName'] ?? '').toString(),
      requestedByUid: (map['requestedByUid'] ?? '').toString(),
      pinRequired: _toBool(map['pinRequired']),
      reason: (map['reason'] ?? '').toString(),
      scheduledAt: _toInt(map['scheduledAt']),
      processingAt: _toInt(map['processingAt']),
      canceledAt: _toInt(map['canceledAt']),
      canceledByDevice: (map['canceledByDevice'] ?? '').toString(),
      canceledByRole: (map['canceledByRole'] ?? '').toString(),
      canceledByName: (map['canceledByName'] ?? '').toString(),
      approvals: approvals,
    );
  }
}

class BreakupTrustedDevicesMeta {
  final String currentDeviceId;
  final Set<String> trustedDeviceIds;

  const BreakupTrustedDevicesMeta({
    required this.currentDeviceId,
    required this.trustedDeviceIds,
  });

  bool get isCurrentTrusted => trustedDeviceIds.contains(currentDeviceId);
  bool get hasOtherTrusted =>
      trustedDeviceIds.any((deviceId) => deviceId != currentDeviceId);
}

class BreakupActionResult {
  final bool success;
  final String message;
  final BreakupRequestData? request;

  BreakupActionResult({
    required this.success,
    required this.message,
    this.request,
  });
}

class BreakupService {
  static final BreakupService _instance = BreakupService._internal();
  factory BreakupService() => _instance;
  BreakupService._internal();

  final FirebaseDatabase _db = FirebaseDatabase.instance;

  bool _isDeletingPermanently = false;

  DatabaseReference _requestRef(String houseId) =>
      _db.ref('houses/$houseId/security/breakup_request');

  Stream<BreakupRequestData?> streamBreakupRequest(String houseId) {
    return _requestRef(houseId).onValue.map((event) {
      if (event.snapshot.value == null) return null;
      final map = _toMap(event.snapshot.value);
      if (map.isEmpty) return null;
      return BreakupRequestData.fromMap(map);
    });
  }

  Future<BreakupRequestData?> getBreakupRequest(String houseId) async {
    try {
      final snap =
          await _requestRef(houseId).get().timeout(const Duration(seconds: 3));
      if (!snap.exists || snap.value == null) return null;
      final map = _toMap(snap.value);
      if (map.isEmpty) return null;
      return BreakupRequestData.fromMap(map);
    } catch (e, stackTrace) {
      debugPrint(
          '[BreakupService] Error getting breakup request for $houseId: $e');
      // Timeout và lỗi mạng là bình thường khi mạng yếu — không ghi lên Crashlytics
      final msg = e.toString().toLowerCase();
      final isExpected = e is TimeoutException ||
          msg.contains('timeout') ||
          msg.contains('network') ||
          msg.contains('permission-denied') ||
          msg.contains('unavailable') ||
          msg.contains('cancelled');
      if (!isExpected) {
        unawaited(ErrorLoggerService.instance.logError(
          e,
          stackTrace,
          reason: 'Failed to get breakup request for house: $houseId',
        ));
      }
      return null;
    }
  }

  Future<String> getCurrentDeviceId() async {
    return SecurityService().getDeviceId();
  }

  Future<BreakupTrustedDevicesMeta> getTrustedDevicesMeta({
    required String houseId,
    String? currentUid,
  }) async {
    final currentDeviceId = await getCurrentDeviceId();
    final trustedDeviceIds = <String>{};

    try {
      final houseDevicesSnap = await _db
          .ref('houses/$houseId/security/devices')
          .get()
          .timeout(const Duration(seconds: 3));
      _collectTrustedDeviceIds(houseDevicesSnap.value, trustedDeviceIds);

      if (trustedDeviceIds.isEmpty &&
          currentUid != null &&
          currentUid.trim().isNotEmpty) {
        final globalSnap = await _db
            .ref('security/devices/${currentUid.trim()}')
            .get()
            .timeout(const Duration(seconds: 3));
        _collectTrustedDeviceIds(globalSnap.value, trustedDeviceIds);
      }
    } catch (e, stackTrace) {
      debugPrint('[BreakupService] Error getting trusted devices: $e');
      unawaited(ErrorLoggerService.instance.logError(
        e,
        stackTrace,
        reason: 'Failed to get trusted devices meta for house: $houseId',
      ));
    }

    return BreakupTrustedDevicesMeta(
      currentDeviceId: currentDeviceId,
      trustedDeviceIds: trustedDeviceIds,
    );
  }

  Future<BreakupActionResult> requestBreakup({
    required String houseId,
    required String role,
    required String userName,
    required String userUid,
    required bool pinRequired,
    bool isSingleRelationship = false,
  }) async {
    final existing = await getBreakupRequest(houseId);
    if (existing != null && existing.isPending) {
      return BreakupActionResult(
        success: false,
        message: L10nService().translate('breakup_pending'),
        request: existing,
      );
    }
    if (existing != null && existing.isScheduled) {
      return BreakupActionResult(
        success: false,
        message:
            L10nService().format('breakup_scheduled', {'value1': _formatDateTime(existing.deleteAt)}),
        request: existing,
      );
    }
    if (existing != null && existing.isProcessing) {
      return BreakupActionResult(
        success: false,
        message: L10nService().translate('breakup_processing'),
        request: existing,
      );
    }

    final response = await CloudFunctionsHelper.callSecure<dynamic>(
      'requestBreakupSecure',
      requireAppCheck: true,
      payload: <String, dynamic>{
        'houseId': houseId,
        'userName': userName,
        'pinRequired': pinRequired,
      },
      fallbackErrorMessage: L10nService().translate('breakup_req_sent'),
    );
    final data = _toMap(response.data);
    final request = _requestFromResponse(data);
    if (data['success'] != true || request == null) {
      return BreakupActionResult(
        success: false,
        message: (data['message'] ?? '').toString().trim().isNotEmpty
            ? data['message'].toString()
            : L10nService().translate('breakup_req_sent'),
        request: request,
      );
    }

    final isSingle = request.isScheduled && request.expireAt <= 0;
    final message = isSingle
        ? L10nService().format(
            'breakup_single_scheduled',
            {'value1': _formatDateTime(request.deleteAt)},
          )
        : L10nService().format(
            'breakup_notice_pending_short',
            {'deadline': _formatDateTime(request.expireAt)},
          );

    return BreakupActionResult(
      success: true,
      message: message,
      request: request,
    );
  }

  Future<BreakupActionResult> approveBreakup({
    required String houseId,
    required String role,
    required String userName,
    String? currentUid,
  }) async {
    final request = await getBreakupRequest(houseId);
    if (request == null || !request.isPending) {
      return BreakupActionResult(
        success: false,
        message: L10nService().translate('breakup_no_pending'),
      );
    }

    final uid =
        (currentUid ?? FirebaseAuth.instance.currentUser?.uid ?? '').trim();
    if (uid.isNotEmpty && uid == request.requestedByUid) {
      return BreakupActionResult(
        success: false,
        message: L10nService().translate('breakup_same_device'),
        request: request,
      );
    }

    final response = await CloudFunctionsHelper.callSecure<dynamic>(
      'approveBreakupSecure',
      requireAppCheck: true,
      payload: <String, dynamic>{
        'houseId': houseId,
        'userName': userName,
      },
      fallbackErrorMessage: L10nService().translate('breakup_no_pending'),
    );
    final data = _toMap(response.data);
    final next = _requestFromResponse(data);
    final success = data['success'] == true && next != null;
    return BreakupActionResult(
      success: success,
      message: success
          ? L10nService().translate('breakup_processing')
          : ((data['message'] ?? '').toString().trim().isNotEmpty
              ? data['message'].toString()
              : L10nService().translate('breakup_no_pending')),
      request: next ?? request,
    );
  }
  Future<BreakupActionResult> cancelBreakupRequest({
    required String houseId,
    required String role,
    required String userName,
    String? currentUid,
  }) async {
    final request = await getBreakupRequest(houseId);
    if (request == null || request.status == BreakupStatus.none) {
      return BreakupActionResult(
        success: false,
        message: L10nService().translate('breakup_no_request'),
      );
    }
    if (request.isCanceled) {
      return BreakupActionResult(
        success: false,
        message: L10nService().translate('breakup_already_canceled'),
      );
    }
    if (request.isProcessing) {
      return BreakupActionResult(
        success: false,
        message: L10nService().translate('breakup_cancel_processing'),
      );
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    if (request.isScheduled &&
        request.deleteAt > 0 &&
        request.deleteAt <= now) {
      return BreakupActionResult(
        success: false,
        message: L10nService().translate('breakup_cancel_expired'),
      );
    }

    final response = await CloudFunctionsHelper.callSecure<dynamic>(
      'cancelBreakupSecure',
      requireAppCheck: true,
      payload: <String, dynamic>{
        'houseId': houseId,
        'userName': userName,
      },
      fallbackErrorMessage: L10nService().translate('breakup_no_request'),
    );
    final data = _toMap(response.data);
    final next = _requestFromResponse(data);
    final success = data['success'] == true && next != null;
    return BreakupActionResult(
      success: success,
      message: success
          ? L10nService().translate('breakup_canceled')
          : ((data['message'] ?? '').toString().trim().isNotEmpty
              ? data['message'].toString()
              : L10nService().translate('breakup_no_request')),
      request: next ?? request,
    );
  }

  Future<BreakupRequestData?> evaluateBreakupRequest(String houseId) async {
    final request = await getBreakupRequest(houseId);
    if (request == null || request.isCanceled) {
      return request;
    }

    try {
      final response = await CloudFunctionsHelper.callSecure<dynamic>(
        'evaluateBreakupSecure',
        requireAppCheck: true,
        payload: <String, dynamic>{'houseId': houseId},
        fallbackErrorMessage: L10nService().translate('breakup_processing'),
      );
      final data = _toMap(response.data);
      final evaluated = _requestFromResponse(data) ?? request;
      if (evaluated.isProcessing) {
        await executePermanentBreakupDelete(houseId);
        return getBreakupRequest(houseId);
      }
      return evaluated;
    } catch (_) {
      // Giữ trạng thái hiển thị khi mạng hoặc App Check tạm thời lỗi.
      return request;
    }
  }

  Future<void> executePermanentBreakupDelete(String houseId) async {
    if (_isDeletingPermanently) return;
    _isDeletingPermanently = true;

    try {
      await _deleteSharedHouseDataFromServer(houseId);
      await _clearLocalBreakupState();
    } finally {
      _isDeletingPermanently = false;
    }
  }

  void _collectTrustedDeviceIds(dynamic raw, Set<String> trustedDeviceIds) {
    final map = _toMap(raw);
    map.forEach((deviceId, value) {
      final item = _toMap(value);
      final status = (item['status'] ?? '').toString().trim().toLowerCase();
      if (status == 'trusted' || status == 'approved') {
        trustedDeviceIds.add(deviceId);
      }
    });
  }

  Future<void> _deleteSharedHouseDataFromServer(String houseId) async {
    final endpoint = AppConfig.sharedHouseCleanupUrl.trim();
    if (endpoint.isEmpty) {
      throw UiCopy.text('copy_00424b79713a');
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw UiCopy.text('copy_e9918327e062');
    }

    try {
      final idToken = await user.getIdToken(true) ?? '';
      if (idToken.isEmpty) {
        throw UiCopy.text('copy_e9918327e062');
      }

      final response = await http
          .post(
            Uri.parse(endpoint),
            headers: await AppCheckHttpHeaders.withRequiredToken({
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $idToken',
            }, forceRefresh: true),
            body: jsonEncode({
              'houseId': houseId,
              'source': 'flutter_breakup_flow',
            }),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode != 200) {
        final decoded = _tryDecodeJson(response.body);
        final errorCode = (decoded['error'] ?? '').toString();
        if (response.statusCode == 401 || response.statusCode == 403) {
          unawaited(
            RevenueSecurityTelemetryService.instance.logEvent(
              type: 'breakup_cleanup_failed',
              reason: errorCode.isEmpty ? 'unauthorized' : errorCode,
              severity: 'high',
              extra: <String, Object?>{
                'statusCode': response.statusCode,
              },
            ),
          );
          throw UiCopy.text('copy_e53f3ec41f00');
        }
        if (errorCode == 'breakup_not_ready') {
          throw UiCopy.text('copy_95c61e218f76');
        }
        if (errorCode == 'missing_breakup_request') {
          throw UiCopy.text('copy_ebbdba7c33a3');
        }
        if (errorCode == 'house_not_found') {
          return;
        }
        unawaited(
          RevenueSecurityTelemetryService.instance.logEvent(
            type: 'breakup_cleanup_failed',
            reason: errorCode.isEmpty ? 'server_rejected' : errorCode,
            severity: 'medium',
            extra: <String, Object?>{
              'statusCode': response.statusCode,
            },
          ),
        );
        throw UiCopy.text('copy_50239b6763ba');
      }

      final decoded = _tryDecodeJson(response.body);
      if (decoded['ok'] != true) {
        throw UiCopy.text('copy_a3331075bc8d');
      }
    } on TimeoutException {
      unawaited(
        RevenueSecurityTelemetryService.instance.logEvent(
          type: 'breakup_cleanup_failed',
          reason: 'timeout',
          severity: 'medium',
        ),
      );
      throw UiCopy.text('copy_42db6bb0a724');
    } catch (e) {
      if (e is String) rethrow;
      unawaited(
        RevenueSecurityTelemetryService.instance.logEvent(
          type: 'breakup_cleanup_failed',
          reason: e is StateError ? 'missing_app_check' : 'request_failed',
          severity: 'high',
        ),
      );
      throw UiCopy.text('copy_e3a4bbba60b0');
    }
  }

  Future<void> _clearLocalBreakupState() async {
    final prefs = OfflineCacheService.getPrefsSync() ??
        await SharedPreferences.getInstance();
    await prefs.remove('il_house_id');
    await prefs.remove('il_auth_uid');
    await prefs.remove('il_rel_mode');
    await AuthService().signOut();
  }

  BreakupRequestData? _requestFromResponse(Map<String, dynamic> data) {
    final map = _toMap(data['request']);
    if (map.isEmpty) return null;
    return BreakupRequestData.fromMap(map);
  }

  Map<String, dynamic> _tryDecodeJson(String raw) {
    if (raw.trim().isEmpty) return const {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      if (decoded is Map) {
        return decoded.map(
          (key, value) => MapEntry(key.toString(), value),
        );
      }
      return const {};
    } catch (_) {
      return const {};
    }
  }

  static BreakupStatus _statusFromString(String value) {
    switch (value.trim().toLowerCase()) {
      case 'pending':
        return BreakupStatus.pending;
      case 'scheduled':
        return BreakupStatus.scheduled;
      case 'processing':
        return BreakupStatus.processing;
      case 'canceled':
        return BreakupStatus.canceled;
      default:
        return BreakupStatus.none;
    }
  }

  static String _formatDateTime(int ms) {
    if (ms <= 0) return UiCopy.text('copy_124547b8c7e0');
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    final day = dt.day.toString().padLeft(2, '0');
    final month = dt.month.toString().padLeft(2, '0');
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return UiCopy.text('copy_03dc788a1b2c', {'value1': day, 'value2': month, 'value3': dt.year, 'value4': hour, 'value5': minute});
  }
}

Map<String, dynamic> _toMap(dynamic value) {
  if (value is Map) {
    return value.map(
      (key, nestedValue) => MapEntry(key.toString(), nestedValue),
    );
  }
  return <String, dynamic>{};
}

int _toInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

bool _toBool(dynamic value) {
  if (value is bool) return value;
  final raw = (value ?? '').toString().trim().toLowerCase();
  return raw == 'true' || raw == '1';
}
