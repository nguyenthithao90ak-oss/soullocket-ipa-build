typedef AppleDeletionGrant = ({String? subject, String authorizationCode});

/// Xin grant mới từ Apple và thu hồi đúng tài khoản, không thay Firebase auth_time.
/// Không lưu hoặc ghi log mã Apple dùng một lần.
Future<void> revokeAppleDeletionGrant({
  required String uid,
  required String appleSubject,
  required String? Function() currentUid,
  required Future<AppleDeletionGrant> Function() acquire,
  required Future<void> Function(String) revoke,
}) async {
  void checkSession() {
    if (uid.isEmpty || currentUid() != uid) {
      throw StateError('apple_deletion_session_changed');
    }
  }

  checkSession();
  if (appleSubject.isEmpty) throw StateError('apple_deletion_identity_missing');
  final grant = await acquire();
  checkSession();
  if (grant.subject != appleSubject) {
    throw StateError('apple_deletion_identity_mismatch');
  }
  if (grant.authorizationCode.trim().isEmpty) {
    throw StateError('apple_deletion_code_missing');
  }
  await revoke(grant.authorizationCode);
  checkSession();
}
