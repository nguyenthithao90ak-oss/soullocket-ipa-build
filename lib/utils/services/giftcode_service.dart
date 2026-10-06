import 'package:soullocket_app/utils/ui_copy.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:soullocket_app/core/constants/app_config.dart';
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
    final normalizedHouseId = houseId.trim();
    final sanitized = code.trim().toUpperCase();
    if (normalizedHouseId.isEmpty) {
      return GiftcodeResult(
        success: false,
        error: GiftcodeError.invalidCode,
        message: UiCopy.text('copy_a07a59e6014d'),
      );
    }
    if (sanitized.isEmpty) {
      return GiftcodeResult(
        success: false,
        message: UiCopy.text('copy_629ee4eb3ffb'),
      );
    }
    if (!AppConfig.isPurchaseEnabled) {
      return GiftcodeResult(
        success: false,
        error: GiftcodeError.permissionDenied,
        message: UiCopy.text('copy_a56679a47ac6'),
      );
    }

    try {
      final deviceId = await _securityService.getDeviceId();
      final requestPayload = {
        'houseId': normalizedHouseId,
        'code': sanitized,
        'deviceId': deviceId,
      };
      final callable = _functions.httpsCallable('redeemGiftcode');
      final response = await callable.call(requestPayload);
      if (response.data is! Map) {
        throw UiCopyException('copy_fa10fee8c01e');
      }
      final payload = Map<String, dynamic>.from(response.data as Map);
      final days = (payload['daysAdded'] as num?)?.toInt();

      return GiftcodeResult(
        success: true,
        daysAdded: days,
        message: (payload['message']?.toString().trim().isNotEmpty ?? false)
            ? payload['message'].toString()
            : UiCopy.text('copy_d3418d65b990'),
      );
    } on FirebaseFunctionsException catch (error) {
      if (_isDebugAppCheckFailure(error)) {
        try {
          final deviceId = await _securityService.getDeviceId();
          final callable = _functions.httpsCallable('redeemGiftcodeAdminDebug');
          final response = await callable.call({
            'houseId': normalizedHouseId,
            'code': sanitized,
            'deviceId': deviceId,
          });
          if (response.data is! Map) {
            throw UiCopyException('copy_fa10fee8c01e');
          }
          final payload = Map<String, dynamic>.from(response.data as Map);
          final days = (payload['daysAdded'] as num?)?.toInt();

          return GiftcodeResult(
            success: true,
            daysAdded: days,
            message: (payload['message']?.toString().trim().isNotEmpty ?? false)
                ? payload['message'].toString()
                : UiCopy.text('copy_c1cc9215ddc0'),
          );
        } catch (parseError) {
          debugPrint('[Giftcode] Không đọc được payload lỗi: $parseError');
        }
      }

      final normalizedMessage = error.message?.trim() ?? '';
      final mappedError = switch (error.code) {
        'already-exists' => GiftcodeError.alreadyUsed,
        'resource-exhausted' => GiftcodeError.limitReached,
        'permission-denied' => GiftcodeError.permissionDenied,
        'not-found' => GiftcodeError.notFound,
        'invalid-argument' => GiftcodeError.invalidCode,
        'unauthenticated' => GiftcodeError.verificationRequired,
        'failed-precondition'
            when normalizedMessage.toLowerCase().contains('app check') =>
          GiftcodeError.verificationRequired,
        _ => GiftcodeError.unknown,
      };
      final friendlyMessage = mappedError == GiftcodeError.verificationRequired
          ? UiCopy.text('copy_8cddfd33d936')
          : normalizedMessage;
      return GiftcodeResult(
        success: false,
        error: mappedError,
        message: friendlyMessage.isNotEmpty
            ? friendlyMessage
            : UiCopy.text('copy_d489eb4855bd'),
      );
    } catch (_) {
      return GiftcodeResult(
        success: false,
        error: GiftcodeError.unknown,
        message: UiCopy.text('copy_d489eb4855bd'),
      );
    }
  }

  Future<bool> isVip(String houseId) async {
    if (!AppConfig.isPurchaseEnabled) return false;
    final normalizedHouseId = houseId.trim();
    if (normalizedHouseId.isEmpty) return false;
    final snap = await _db.ref('houses/$normalizedHouseId/proUntil').get();
    final proUntil = (snap.value as num?)?.toInt() ?? 0;
    return proUntil > DateTime.now().millisecondsSinceEpoch;
  }

  Stream<DateTime?> streamVipExpiry(String houseId) {
    if (!AppConfig.isPurchaseEnabled) return Stream<DateTime?>.value(null);
    final normalizedHouseId = houseId.trim();
    if (normalizedHouseId.isEmpty) return Stream<DateTime?>.value(null);
    return _db.ref('houses/$normalizedHouseId/proUntil').onValue.map((event) {
      final val = (event.snapshot.value as num?)?.toInt() ?? 0;
      if (val == 0) return null;
      return DateTime.fromMillisecondsSinceEpoch(val);
    });
  }

  bool _isDebugAppCheckFailure(FirebaseFunctionsException error) {
    final code = error.code.trim().toLowerCase();
    return code == 'failed-precondition' ||
        code == 'permission-denied' ||
        code == 'unauthenticated';
  }
}
