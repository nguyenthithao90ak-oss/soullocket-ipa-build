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

  /// Khóa dùng chung cho một lần tự mở của tài khoản trên bản cài này.
  ///
  /// Home và Cài đặt trước đây dùng hai khóa topic riêng. Khi một tour bị
  /// dừng giữa chừng, topic còn lại có thể tự mở lại ở lần đăng nhập sau.
  /// Khóa không phụ thuộc House, topic hoặc version ứng dụng.
  static String firstRunKey(String uid) =>
      'il_setup_guide_first_v1_${base64Url.encode(utf8.encode(jsonEncode([uid])))}';

  /// Chỉ chuyển dấu của tour Home/Cài đặt thuộc đúng tài khoản, kể cả nhà cũ.
  /// Checklist và hướng dẫn tính năng khác giữ nguyên tiến độ riêng.
  static Iterable<String> legacyFirstRunKeys(
    SharedPreferences prefs,
    String uid,
  ) sync* {
    const prefix = 'il_setup_guide_v3_';
    for (final key in prefs.getKeys()) {
      if (!key.startsWith(prefix)) continue;
      try {
        final scope = jsonDecode(utf8.decode(base64Url.decode(
          key.substring(prefix.length),
        )));
        if (scope is List && scope.length == 3 && scope[0] == uid &&
            const {'home', 'settings'}.contains(scope[2])) {
          yield key;
        }
      } catch (_) {
        // Khóa cũ không hợp lệ không được gán sang tài khoản hiện hành.
      }
    }
  }

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

  /// Một tour đã được mở thì không tự mở lại sau khi cập nhật, đăng nhập lại
  /// hoặc bị hệ điều hành thu hồi tiến trình. Nút replay truyền `replay: true`
  /// vẫn có thể mở lại thủ công.
  bool get hasBeenPresented =>
      _data['presented'] == true || status != SetupGuideStatus.unseen;

  bool get shouldOffer => !hasBeenPresented;

  Future<void>? _pending;

  /// Ghi nhận ngay trước khi mở tour tự động. Việc này bảo vệ trường hợp app
  /// bị đóng khi lớp overlay đang hiện và chưa kịp ghi bước đầu tiên.
  Future<void> markPresented() {
    final data = _data;
    return _write(
      status: SetupGuideStatus.inProgress,
      step: data['step'] is int && (data['step'] as int) >= 0
          ? data['step'] as int
          : 0,
      presented: true,
    );
  }

  /// Nếu bản cũ đã từng ghi tiến độ theo topic, chuyển dấu đã mở sang khóa
  /// chung. Trạng thái `unseen` không được coi là đã xem.
  Future<void> migratePresentedFrom(Iterable<String> legacyKeys) async {
    if (hasBeenPresented) return;
    for (final legacyKey in legacyKeys) {
      final raw = prefs.getString(legacyKey);
      if (raw == null || raw.trim().isEmpty) continue;
      try {
        final decoded = jsonDecode(raw);
        if (decoded is! Map) continue;
        final legacyStatus = decoded['status']?.toString();
        if (!const {'inProgress', 'dismissed', 'completed'}.contains(legacyStatus)) {
          continue;
        }
        final legacyStep = decoded['step'] is int && (decoded['step'] as int) >= 0
            ? decoded['step'] as int
            : 0;
        await _write(
          status: SetupGuideStatus.values.firstWhere(
            (value) => value.name == legacyStatus,
            orElse: () => SetupGuideStatus.inProgress,
          ),
          step: legacyStep,
          presented: true,
        );
        return;
      } catch (_) {
        // Dữ liệu cũ hỏng không được phép chặn tour của nhà mới.
      }
    }
  }

  Future<void> save(SetupGuideStatus status, int step) {
    final presented = _data['presented'] == true ||
        status != SetupGuideStatus.unseen;
    return _write(status: status, step: step, presented: presented);
  }

  Future<void> _write({
    required SetupGuideStatus status,
    required int step,
    required bool presented,
  }) {
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
        jsonEncode({
          'status': status.name,
          'step': step,
          'presented': presented || hasBeenPresented,
        }),
      );
    }();
    _pending = write;
    return write;
  }
}
