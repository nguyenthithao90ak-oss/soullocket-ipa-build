import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'security_service.dart';

enum GiftcodeError {
  notFound,
  limitReached,
  alreadyUsed,
  permissionDenied,
  invalidCode,
  verificationRequired,
  unknown,
}

class GiftcodeResult {
  final bool success;
  final int? daysAdded;
  final GiftcodeError? error;
  final String message;

  GiftcodeResult({
    required this.success,
    this.daysAdded,
    this.error,
    required this.message,
  });
}

class GiftcodeService {
  static final GiftcodeService _instance = GiftcodeService._internal();
  factory GiftcodeService() => _instance;
  GiftcodeService._internal();

  final FirebaseDatabase _db = FirebaseDatabase.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  final SecurityService _securityService = SecurityService();

  Future<GiftcodeResult> redeemGiftcode({
    required String houseId,
    required String code,
  }) async {
    final sanitized = code.trim().toUpperCase();
    if (sanitized.isEmpty) {
      return GiftcodeResult(
        success: false,
        message: 'Vui lòng nhập mã quà tặng!',
      );
    }

    try {
      final deviceId = await _securityService.getDeviceId();
      final requestPayload = {
        'houseId': houseId,
        'code': sanitized,
        'deviceId': deviceId,
      };
      final callable = _functions.httpsCallable('redeemGiftcode');
      final response = await callable.call(requestPayload);
      final payload = Map<String, dynamic>.from(response.data as Map);
      final days = (payload['daysAdded'] as num?)?.toInt();

      return GiftcodeResult(
        success: true,
        daysAdded: days,
        message: (payload['message']?.toString().trim().isNotEmpty ?? false)
            ? payload['message'].toString()
            : 'Giftcode hợp lệ!',
      );
    } on FirebaseFunctionsException catch (error) {
      if (_isDebugAppCheckFailure(error)) {
        try {
          final deviceId = await _securityService.getDeviceId();
          final callable = _functions.httpsCallable('redeemGiftcodeAdminDebug');
          final response = await callable.call({
            'houseId': houseId,
            'code': sanitized,
            'deviceId': deviceId,
          });
          final payload = Map<String, dynamic>.from(response.data as Map);
          final days = (payload['daysAdded'] as num?)?.toInt();

          return GiftcodeResult(
            success: true,
            daysAdded: days,
            message: (payload['message']?.toString().trim().isNotEmpty ?? false)
                ? payload['message'].toString()
                : 'Mã quà tặng hợp lệ!',
          );
        } catch (_) {}
      }

      final normalizedMessage = error.message?.trim() ?? '';
      final mappedError = switch (error.code) {
        'already-exists' => GiftcodeError.alreadyUsed,
        'resource-exhausted' => GiftcodeError.limitReached,
        'permission-denied' => GiftcodeError.permissionDenied,
        'not-found' => GiftcodeError.notFound,
        'invalid-argument' => GiftcodeError.invalidCode,
        'failed-precondition'
            when normalizedMessage.toLowerCase().contains('app check') =>
          GiftcodeError.verificationRequired,
        _ => GiftcodeError.unknown,
      };
      final friendlyMessage = mappedError == GiftcodeError.verificationRequired
          ? 'Không thể xác minh thiết bị lúc này. Vui lòng cập nhật app hoặc thử lại sau.'
          : normalizedMessage;
      return GiftcodeResult(
        success: false,
        error: mappedError,
        message: friendlyMessage.isNotEmpty
            ? friendlyMessage
            : 'Hệ thống đang bận, vui lòng thử lại sau.',
      );
    } catch (_) {
      return GiftcodeResult(
        success: false,
        error: GiftcodeError.unknown,
        message: 'Hệ thống đang bận, vui lòng thử lại sau.',
      );
    }
  }

  Future<bool> isVip(String houseId) async {
    final snap = await _db.ref('houses/$houseId/proUntil').get();
    final proUntil = (snap.value as num?)?.toInt() ?? 0;
    return proUntil > DateTime.now().millisecondsSinceEpoch;
  }

  Stream<DateTime?> streamVipExpiry(String houseId) {
    return _db.ref('houses/$houseId/proUntil').onValue.map((event) {
      final val = (event.snapshot.value as num?)?.toInt() ?? 0;
      if (val == 0) return null;
      return DateTime.fromMillisecondsSinceEpoch(val);
    });
  }

  bool _isDebugAppCheckFailure(FirebaseFunctionsException error) {
    if (!kDebugMode) {
      return false;
    }
    final code = error.code.trim().toLowerCase();
    if (code != 'failed-precondition' &&
        code != 'permission-denied' &&
        code != 'unauthenticated') {
      return false;
    }
    final message =
        '${error.message ?? ''} ${error.details ?? ''}'.trim().toLowerCase();
    return message.contains('app check') ||
        message.contains('appcheck') ||
        message.contains('debug token') ||
        message.contains('play integrity') ||
        message.contains('attestation');
  }
}
