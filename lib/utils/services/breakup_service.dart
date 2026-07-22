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

  const BreakupApproval({
    required this.ts,
    required this.role,
    required this.type,
  });

  factory BreakupApproval.fromMap(Map<String, dynamic> map) {
    return BreakupApproval(
      ts: _toInt(map['ts']),
      role: (map['role'] ?? '').toString(),
      type: (map['type'] ?? '').toString(),
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
  bool get approvedByPartner =>
      approvals.keys.any((deviceId) => deviceId != requestedByDevice);

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

  const BreakupActionResult({
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
      final snap = await _requestRef(houseId)
          .get()
          .timeout(const Duration(seconds: 3));
      if (!snap.exists || snap.value == null) return null;
      final map = _toMap(snap.value);
      if (map.isEmpty) return null;
      return BreakupRequestData.fromMap(map);
    } catch (e, stackTrace) {
      debugPrint('[BreakupService] Error getting breakup request for $houseId: $e');
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
        message: 'Yêu cầu hiện đang chờ xác nhận từ thiết bị bên kia.',
        request: existing,
      );
    }
    if (existing != null && existing.isScheduled) {
      return BreakupActionResult(
        success: false,
        message:
            'Dữ liệu đã được lên lịch xóa vào ${_formatDateTime(existing.deleteAt)}.',
        request: existing,
      );
    }
    if (existing != null && existing.isProcessing) {
      return BreakupActionResult(
        success: false,
        message: 'Hệ thống đang xử lý xóa dữ liệu. Không thể tạo yêu cầu mới.',
        request: existing,
      );
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final expireAt = isSingleRelationship ? 0 : now + (30 * 86400000);
    final deleteAt = isSingleRelationship ? now + (3 * 86400000) : 0;
    final deviceMeta = await getTrustedDevicesMeta(
      houseId: houseId,
      currentUid: userUid,
    );
    final deviceId = deviceMeta.currentDeviceId;

    final payload = <String, dynamic>{
      'status': isSingleRelationship ? 'scheduled' : 'pending',
      'requestedAt': now,
      'expireAt': expireAt,
      'deleteAt': deleteAt,
      'requestedByDevice': deviceId,
      'requestedByRole': role,
      'requestedByName': userName,
      'requestedByUid': userUid,
      'pinRequired': pinRequired,
      'reason': isSingleRelationship ? 'single_scheduled_3_days' : '',
      'scheduledAt': isSingleRelationship ? now : 0,
      'processingAt': 0,
      'canceledAt': 0,
      'canceledByDevice': '',
      'canceledByRole': '',
      'canceledByName': '',
      'approvals': {
        deviceId: {
          'ts': now,
          'role': role,
          'type': 'owner_request',
        },
      },
    };

    await _requestRef(houseId).set(payload);
    final request = BreakupRequestData.fromMap(payload);

    final message = isSingleRelationship
        ? 'Tài khoản độc thân không cần chờ bạn kia xác nhận. Dữ liệu đã được lên lịch xóa vào ${_formatDateTime(deleteAt)} và bạn vẫn có thể rút lại trước mốc này.'
        : deviceMeta.hasOtherTrusted
            ? 'Yêu cầu đã được gửi. Một thiết bị tin cậy khác có thể xác nhận ngay. Sau khi được xác nhận, hệ thống sẽ chờ thêm 1 ngày trước khi xóa hoàn toàn và bạn vẫn có thể rút lại trong khoảng này.'
            : 'Yêu cầu đã được ghi nhận. Nếu không có thiết bị tin cậy khác xác nhận, hệ thống sẽ chờ đến ${_formatDateOnly(expireAt)}, sau đó lên lịch xóa thêm 1 ngày để bạn kịp rút lại.';

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
      return const BreakupActionResult(
        success: false,
        message: 'Không còn yêu cầu chia tay đang chờ xác nhận.',
      );
    }

    final meta = await getTrustedDevicesMeta(
      houseId: houseId,
      currentUid: currentUid,
    );
    if (!meta.isCurrentTrusted) {
      return const BreakupActionResult(
        success: false,
        message: 'Thiết bị hiện tại chưa được tin cậy để xác nhận.',
      );
    }
    if (meta.currentDeviceId == request.requestedByDevice) {
      return const BreakupActionResult(
        success: false,
        message: 'Không thể tự xác nhận bằng chính thiết bị đã gửi yêu cầu.',
      );
    }
    if (request.isApprovedBy(meta.currentDeviceId)) {
      return const BreakupActionResult(
        success: false,
        message: 'Thiết bị này đã xác nhận trước đó.',
      );
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final deleteAt = now + 86400000;
    final ref = _requestRef(houseId);

    await ref.child('approvals/${meta.currentDeviceId}').set({
      'ts': now,
      'role': role,
      'type': 'trusted_partner',
      'name': userName,
    });
    await ref.update({
      'status': 'scheduled',
      'reason': 'partner_approved',
      'scheduledAt': now,
      'deleteAt': deleteAt,
    });

    final next = await getBreakupRequest(houseId);
    return BreakupActionResult(
      success: true,
      message:
          'Đã xác nhận chia tay. Dữ liệu sẽ bị xóa vào ${_formatDateTime(deleteAt)} nếu không rút lại trước hạn.',
      request: next,
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
      return const BreakupActionResult(
        success: false,
        message: 'Không có yêu cầu nào để rút lại.',
      );
    }
    if (request.isCanceled) {
      return const BreakupActionResult(
        success: false,
        message: 'Yêu cầu này đã được rút lại trước đó.',
      );
    }
    if (request.isProcessing) {
      return const BreakupActionResult(
        success: false,
        message: 'Hệ thống đang xử lý xóa, không thể rút lại.',
      );
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    if (request.isScheduled &&
        request.deleteAt > 0 &&
        request.deleteAt <= now) {
      return const BreakupActionResult(
        success: false,
        message: 'Đã qua thời điểm được phép rút lại.',
      );
    }

    final deviceMeta = await getTrustedDevicesMeta(
      houseId: houseId,
      currentUid: currentUid,
    );
    await _requestRef(houseId).update({
      'status': 'canceled',
      'canceledAt': now,
      'canceledByDevice': deviceMeta.currentDeviceId,
      'canceledByRole': role,
      'canceledByName': userName,
    });

    final next = await getBreakupRequest(houseId);
    return BreakupActionResult(
      success: true,
      message: 'Đã rút lại yêu cầu chia tay.',
      request: next,
    );
  }

  Future<BreakupRequestData?> evaluateBreakupRequest(String houseId) async {
    final request = await getBreakupRequest(houseId);
    if (request == null || request.isCanceled) {
      return request;
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final ref = _requestRef(houseId);

    if (request.isPending) {
      final approvedByPartner = request.approvedByPartner;
      final expired = request.expireAt > 0 && now >= request.expireAt;

      if (!approvedByPartner && !expired) {
        return request;
      }

      final latest = await getBreakupRequest(houseId);
      if (latest == null || !latest.isPending) {
        return latest;
      }

      final deleteAt = now + 86400000;
      await ref.update({
        'status': 'scheduled',
        'reason': approvedByPartner ? 'partner_approved' : 'expired_30_days',
        'scheduledAt': now,
        'deleteAt': deleteAt,
      });
      return getBreakupRequest(houseId);
    }

    if (request.isScheduled) {
      if (request.deleteAt <= 0 || now < request.deleteAt) {
        return request;
      }

      final latest = await getBreakupRequest(houseId);
      if (latest == null || !latest.isScheduled) {
        return latest;
      }

      await ref.update({
        'status': 'processing',
        'processingAt': now,
      });
      await executePermanentBreakupDelete(houseId);
      return getBreakupRequest(houseId);
    }

    if (request.isProcessing) {
      await executePermanentBreakupDelete(houseId);
      return getBreakupRequest(houseId);
    }

    return request;
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
      throw 'Chưa cấu hình máy chủ xóa dữ liệu chung.';
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw 'Phiên đăng nhập không còn hợp lệ. Vui lòng đăng nhập lại.';
    }

    try {
      final idToken = await user.getIdToken(true) ?? '';
      if (idToken.isEmpty) {
        throw 'Phiên đăng nhập không còn hợp lệ. Vui lòng đăng nhập lại.';
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
          throw 'Phiên đăng nhập đã hết hạn hoặc không còn quyền xóa dữ liệu chung.';
        }
        if (errorCode == 'breakup_not_ready') {
          throw 'Dữ liệu chung chưa đến thời điểm được phép xóa.';
        }
        if (errorCode == 'missing_breakup_request') {
          throw 'Không tìm thấy yêu cầu chia tay hợp lệ trên máy chủ.';
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
        throw 'Máy chủ chưa thể xóa dữ liệu chung lúc này.';
      }

      final decoded = _tryDecodeJson(response.body);
      if (decoded['ok'] != true) {
        throw 'Máy chủ trả về phản hồi xóa dữ liệu không hợp lệ.';
      }
    } on TimeoutException {
      unawaited(
        RevenueSecurityTelemetryService.instance.logEvent(
          type: 'breakup_cleanup_failed',
          reason: 'timeout',
          severity: 'medium',
        ),
      );
      throw 'Máy chủ xóa dữ liệu phản hồi quá chậm. Vui lòng thử lại khi mạng ổn định hơn.';
    } catch (e) {
      if (e is String) rethrow;
      unawaited(
        RevenueSecurityTelemetryService.instance.logEvent(
          type: 'breakup_cleanup_failed',
          reason: e is StateError ? 'missing_app_check' : 'request_failed',
          severity: 'high',
        ),
      );
      throw 'Không thể hoàn tất xóa dữ liệu chung trên máy chủ.';
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

  static String _formatDateOnly(int ms) {
    if (ms <= 0) return 'không xác định';
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    final day = dt.day.toString().padLeft(2, '0');
    final month = dt.month.toString().padLeft(2, '0');
    return '$day/$month/${dt.year}';
  }

  static String _formatDateTime(int ms) {
    if (ms <= 0) return 'không xác định';
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    final day = dt.day.toString().padLeft(2, '0');
    final month = dt.month.toString().padLeft(2, '0');
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$day/$month/${dt.year} lúc $hour:$minute';
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
