/// Ràng buộc yêu cầu thưởng với phiên đã bắt đầu, kể cả khi chờ token/retry.
class RewardRequestScope {
  const RewardRequestScope({
    required this.uid,
    required this.currentUid,
    this.houseId,
    this.currentHouseId,
  });

  final String uid;
  final String? Function() currentUid;
  final String? houseId;
  final Future<String?> Function()? currentHouseId;

  Future<void> ensureCurrent() async {
    if (currentUid() != uid) throw RewardScopeChanged('unauthenticated');
    if (houseId != null && currentHouseId != null) {
      final activeHouse = await currentHouseId!();
      if (currentUid() != uid) throw RewardScopeChanged('unauthenticated');
      if (activeHouse != houseId) throw RewardScopeChanged('house_mismatch');
    }
  }
}

class RewardScopeChanged extends StateError {
  RewardScopeChanged(this.code) : super(code);
  final String code;
}
