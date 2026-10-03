import 'package:shared_preferences/shared_preferences.dart';

class PendingAdReward {
  const PendingAdReward(this.nonce, this.purpose, this.startedAt);
  final String nonce;
  final String purpose;
  final int? startedAt;

  bool expired(int nowMs) =>
      startedAt != null &&
      nowMs - startedAt! > const Duration(hours: 24).inMilliseconds;
}

/// Chỉ lưu thông tin để truy vấn SSV; dữ liệu local không cấp điểm/quyền.
class AdRewardReceiptStore {
  const AdRewardReceiptStore(this.prefs);
  final SharedPreferences prefs;

  PendingAdReward? read(String uid) {
    final nonce = prefs.getString('ad_pending_nonce_$uid');
    final purpose = prefs.getString('ad_pending_purpose_$uid');
    if (nonce == null || purpose == null) return null;
    return PendingAdReward(
      nonce,
      purpose,
      prefs.getInt('ad_pending_started_$uid'),
    );
  }

  Future<void> clearMatching(String uid, String nonce) async {
    // Receipt cũ về muộn không xóa nonce của lượt khác.
    if (prefs.getString('ad_pending_nonce_$uid') != nonce) return;
    await Future.wait([
      prefs.remove('ad_pending_nonce_$uid'),
      prefs.remove('ad_pending_purpose_$uid'),
      prefs.remove('ad_pending_started_$uid'),
    ]);
  }
}
