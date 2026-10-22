/// Đồng ý theo từng tài khoản/nhà; không tái sử dụng lựa chọn của tài khoản cũ.
String healthConsentKey(String uid, String houseId) =>
    'il_health_consent_v2_${uid}_$houseId';

/// Chặn snapshot cache cũ/không rõ người sở hữu, kể cả trước khi server trả lỗi.
bool canDisplayHealthData(Object? raw, String? uid) {
  if (uid == null || uid.isEmpty || raw is! Map) return false;
  final owner = raw['ownerUid'];
  return owner is String &&
      owner.isNotEmpty &&
      (owner == uid || raw['shareWithPartner'] == true);
}
