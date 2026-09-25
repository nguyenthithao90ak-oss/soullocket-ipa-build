import 'dart:convert';

import 'package:crypto/crypto.dart';

String purchaseAccountToken(String uid) {
  final chars = sha256
      .convert(utf8.encode('soullocket-billing-v1:$uid'))
      .toString()
      .substring(0, 32)
      .split('');
  chars[12] = '5';
  chars[16] = ((int.parse(chars[16], radix: 16) & 3) | 8).toRadixString(16);
  final value = chars.join();
  return '${value.substring(0, 8)}-${value.substring(8, 12)}-'
      '${value.substring(12, 16)}-${value.substring(16, 20)}-'
      '${value.substring(20)}';
}

bool canReusePurchaseAccess({
  required String uid,
  required String? cachedUid,
  required int nowMs,
  required int? checkedAtMs,
  required int? expiresAtMs,
}) =>
    cachedUid == uid &&
    checkedAtMs != null &&
    nowMs >= checkedAtMs &&
    nowMs - checkedAtMs < 10000 &&
    (expiresAtMs == null || expiresAtMs > nowMs);

bool isPurchasePayloadUsable({
  required bool isVip,
  required bool isKnownLifetime,
  required int? expiresAtMs,
  required int nowMs,
}) => isVip && (expiresAtMs != null ? expiresAtMs > nowMs : isKnownLifetime);
