import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

import '../app_error_mapper.dart';

class RevenueSecurityTelemetryService {
  RevenueSecurityTelemetryService._();

  static final RevenueSecurityTelemetryService instance =
      RevenueSecurityTelemetryService._();
  static bool _disabledForSession = false;
  static bool _permissionDeniedLogged = false;

  Future<void> logEvent({
    required String type,
    required String reason,
    String severity = 'medium',
    Map<String, Object?> extra = const <String, Object?>{},
  }) async {
    if (_disabledForSession) return;

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await _writeEvent(
        uid: user.uid,
        type: type,
        reason: reason,
        severity: severity,
        extra: extra,
      );
    } catch (error) {
      _handleWriteError(error);
    }
  }

  Future<void> logSystemEvent({
    required String type,
    required String reason,
    String severity = 'high',
    Map<String, Object?> extra = const <String, Object?>{},
  }) async {
    if (_disabledForSession) return;

    try {
      final user = FirebaseAuth.instance.currentUser;
      await _writeEvent(
        uid: user?.uid,
        type: type,
        reason: reason,
        severity: severity,
        extra: extra,
      );
    } catch (error) {
      _handleWriteError(error);
    }
  }

  Future<void> _writeEvent({
    required String type,
    required String reason,
    required String severity,
    required Map<String, Object?> extra,
    String? uid,
  }) async {
    if (_disabledForSession) return;

    final normalizedType = type.trim();
    final normalizedReason = reason.trim();
    final normalizedSeverity = severity.trim().isEmpty ? 'medium' : severity.trim();
    final normalizedUid = uid?.trim();
    if (normalizedType.isEmpty || normalizedReason.isEmpty) return;

    final sanitizedExtra = <String, Object?>{};
    extra.forEach((key, value) {
      final normalizedKey = key.trim();
      if (normalizedKey.isNotEmpty && value != null) {
        sanitizedExtra[normalizedKey] = value;
      }
    });

    await FirebaseDatabase.instance
        .ref('admin_system/revenue_security_events')
        .push()
        .set({
      'ts': ServerValue.timestamp,
      if (normalizedUid != null && normalizedUid.isNotEmpty) 'uid': normalizedUid,
      'type': normalizedType,
      'reason': normalizedReason,
      'severity': normalizedSeverity,
      if (sanitizedExtra.isNotEmpty) 'extra': sanitizedExtra,
    });
  }

  void _handleWriteError(Object error) {
    final message = error.toString().toLowerCase();
    if (message.contains('permission denied')) {
      _disabledForSession = true;
      if (kDebugMode && !_permissionDeniedLogged) {
        _permissionDeniedLogged = true;
        debugPrint(
          'Revenue security telemetry disabled for this session: ${AppErrorMapper.resolve(
            error,
            fallbackMessage: 'Không thể ghi telemetry bảo mật doanh thu.',
          ).message}',
        );
      }
      return;
    }

    if (kDebugMode) {
      debugPrint('Revenue security telemetry skipped: ${AppErrorMapper.resolve(
        error,
        fallbackMessage: 'Không thể ghi telemetry bảo mật doanh thu.',
      ).message}');
    }
  }
}
