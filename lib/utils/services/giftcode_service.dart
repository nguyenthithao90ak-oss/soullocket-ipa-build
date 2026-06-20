import 'dart:io';

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
    if (!kIsWeb && (Platform.isIOS || Platform.isMacOS)) {
      return GiftcodeResult(
        success: false,
        error: GiftcodeError.permissionDenied,
        message: 'Giftcode không khả dụng trên iOS. Vui lòng sử dụng thanh toán trong ứng dụng.',
      );
    }

    final normalizedHouseId = houseId.trim();
    final sanitized = code.trim().toUpperCase();
    if (normalizedHouseId.isEmpty) {
      return GiftcodeResult(
        success: false,
        error: GiftcodeError.invalidCode,
        message: 'Không xác định được nhà để nhận mã quà tặng.',
      );
    }
    if (sanitized.isEmpty) {
      return GiftcodeResult(
        success: false,
        message: 'Vui lòng nhập mã quà tặng!',
      );
    }
    if (!AppConfig.isPurchaseEnabled) {
      return GiftcodeResult(
        success: false,
        error: GiftcodeError.permissionDenied,
        message: 'Giftcode chưa khả dụng trên phiên bản này.',
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
        throw Exception('Phản hồi mã quà tặng không hợp lệ.');
      }
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
            'houseId': normalizedHouseId,
            'code': sanitized,
            'deviceId': deviceId,
          });
          if (response.data is! Map) {
            throw Exception('Phản hồi mã quà tặng không hợp lệ.');
          }
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
        'unauthenticated' => GiftcodeError.verificationRequired,
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
