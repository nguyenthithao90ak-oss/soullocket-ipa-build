import 'dart:convert';

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

  List<PendingAdReward> archived(String uid) {
    try {
      final raw = jsonDecode(
        prefs.getString('ad_pending_archive_$uid') ?? '[]',
      );
      if (raw is! List) return [];
      return raw
          .whereType<Map>()
          .where((item) => item['nonce'] is String && item['purpose'] is String)
          .map(
            (item) => PendingAdReward(
              item['nonce'] as String,
              item['purpose'] as String,
              (item['startedAt'] as num?)?.toInt(),
            ),
          )
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _saveArchive(String uid, List<PendingAdReward> values) => prefs
      .setString(
        'ad_pending_archive_$uid',
        jsonEncode(
          values
              .map(
                (item) => {
                  'nonce': item.nonce,
                  'purpose': item.purpose,
                  'startedAt': item.startedAt,
                },
              )
              .toList(),
        ),
      )
      .then((_) {});

  Future<void> archiveMatching(String uid, String nonce) async {
    final pending = read(uid);
    if (pending?.nonce != nonce) return;
    final values = archived(uid)
        .where(
          (item) =>
              item.nonce != nonce &&
              item.startedAt != null &&
              DateTime.now().millisecondsSinceEpoch - item.startedAt! <
                  const Duration(hours: 48).inMilliseconds,
        )
        .toList();
    values.add(pending!);
    await _saveArchive(
      uid,
      values.skip(values.length > 100 ? values.length - 100 : 0).toList(),
    );
    // Không xoá một biên nhận mới nếu người dùng đã bắt đầu lượt khác trong
    // lúc danh sách lưu trữ đang được ghi.
    if (prefs.getString('ad_pending_nonce_$uid') != nonce) return;
    await Future.wait([
      prefs.remove('ad_pending_nonce_$uid'),
      prefs.remove('ad_pending_purpose_$uid'),
      prefs.remove('ad_pending_started_$uid'),
    ]);
  }

  Future<void> clearMatching(String uid, String nonce) async {
    // Receipt cũ về muộn không xóa nonce của lượt khác.
    if (prefs.getString('ad_pending_nonce_$uid') == nonce) {
      await Future.wait([
        prefs.remove('ad_pending_nonce_$uid'),
        prefs.remove('ad_pending_purpose_$uid'),
        prefs.remove('ad_pending_started_$uid'),
      ]);
    }
    await _saveArchive(
      uid,
      archived(uid).where((item) => item.nonce != nonce).toList(),
    );
  }
}
