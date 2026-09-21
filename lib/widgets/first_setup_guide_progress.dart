import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

enum SetupGuideStatus { unseen, inProgress, dismissed, completed }

/// Chỉ lưu tiến độ đọc trên máy; không thay đổi dữ liệu hay quyền của House.
class SetupGuideProgress {
  final SharedPreferences prefs;
  final String key;

  SetupGuideProgress(this.prefs, this.key);

  static String scopedKey(String uid, String houseId, String topic) =>
      'il_setup_guide_v3_${base64Url.encode(utf8.encode(jsonEncode([uid, houseId, topic])))}';

  Map<String, dynamic> get _data {
    try {
      final value = jsonDecode(prefs.getString(key) ?? '{}');
      return value is Map<String, dynamic> ? value : {};
    } catch (_) {
      return {};
    }
  }

  SetupGuideStatus get status {
    final name = _data['status'];
    return SetupGuideStatus.values.firstWhere(
      (value) => value.name == name,
      orElse: () => SetupGuideStatus.unseen,
    );
  }

  int get step {
    final value = _data['step'];
    return value is int && value >= 0 ? value : 0;
  }

  bool get shouldOffer =>
      status == SetupGuideStatus.unseen ||
      status == SetupGuideStatus.inProgress;

  Future<void>? _pending;

  Future<void> save(SetupGuideStatus status, int step) {
    // Tuần tự hóa để ghi bước cũ không đè kết quả hoàn tất/bỏ qua.
    final previous = _pending;
    final write = () async {
      if (previous != null) {
        try {
          await previous;
        } catch (_) {}
      }
      await prefs.setString(
        key,
        jsonEncode({'status': status.name, 'step': step}),
      );
    }();
    _pending = write;
    return write;
  }
}
