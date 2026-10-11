/// Ranh giới dữ liệu của một phiên upload ghi âm.
///
/// Scope này cố ý không phụ thuộc `State.mounted`: upload có thể tiếp tục sau
/// khi màn hình bị dispose, nhưng không được tiếp tục nếu tài khoản hoặc House
/// hiện tại đã khác phiên bắt đầu.
class VoiceUploadScope {
  const VoiceUploadScope({required this.ownerUid, required this.houseId});

  final String? ownerUid;
  final String houseId;

  bool matches({required String? currentUid, required String currentHouseId}) {
    final expectedUid = ownerUid?.trim() ?? '';
    final expectedHouseId = houseId.trim();
    return expectedUid.isNotEmpty &&
        currentUid == expectedUid &&
        currentHouseId.trim() == expectedHouseId;
  }
}
