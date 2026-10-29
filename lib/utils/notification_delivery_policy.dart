/// Quy tắc thuần Dart dùng chung cho payload FCM và thông báo local.
abstract final class NotificationDeliveryPolicy {
  static String screen(Map<String, dynamic> data) {
    final explicit = data['screen']?.toString().trim() ?? '';
    if (explicit.isNotEmpty && explicit != '[object Object]') return explicit;
    return switch (data['type']?.toString()) {
      'chat' => 'chat',
      'internal_chat' => 'internal_chat',
      'soul_merge' || 'partner_message' => 'soul_merge',
      'soul_merge_call' => 'soul_merge_call',
      'diary_post' || 'new_memory' => 'diary',
      'time_capsule' => 'time_capsule',
      _ => 'notifications',
    };
  }

  // Đồng nhất với năm tab trong HomeScreen, không dùng thứ tự sáu tab cũ.
  static int homeTab(String screen) => switch (screen) {
    'diary' => 1,
    'utilities' => 2,
    'game' => 3,
    'update' => 4,
    _ => 0,
  };

  static bool allowsLocal(
    Map<String, dynamic> data,
    bool? Function(String) preference,
  ) {
    if (preference('il_notifications_enabled') == false) return false;
    // Payload tương thích có thể chỉ ghi loại cuộc gọi ở screen.
    final type = screen(data) == 'soul_merge_call'
        ? 'soul_merge_call'
        : data['type']?.toString();
    final key = switch (type) {
      'chat' ||
      'internal_chat' ||
      'partner_message' ||
      'soul_merge' ||
      'soul_merge_call' => 'il_notif_chat',
      'diary_post' ||
      'new_memory' ||
      'new_post' ||
      'like' ||
      'comment' ||
      'photo_shot' => 'il_notif_post',
      'friend_request' || 'friend_accept' || 'friend_wave' => 'il_notif_friend',
      'partner_care' ||
      'miss_you' ||
      'heart' ||
      'interaction' => 'il_notif_heart',
      'anniversary' || 'schedule' => 'il_notif_anniversary',
      _ => null,
    };
    return key == null || preference(key) != false;
  }

  static bool expired(Map<String, dynamic> data, DateTime now) {
    if (screen(data) == 'soul_merge_call') {
      // expiresAt của push dùng giờ server. Cuộc gọi sẽ được đọc lại từ room
      // và bù server offset; chỉ dùng deadline local đã xác minh để bỏ sớm.
      if (!data.containsKey('localExpiresAt')) return false;
      final raw = data['localExpiresAt'];
      final local = raw is num && raw.isFinite ? raw.toInt() : int.tryParse(raw?.toString() ?? '');
      return local == null || local <= now.millisecondsSinceEpoch;
    }
    final expiresAt = int.tryParse(data['expiresAt']?.toString() ?? '');
    return expiresAt != null &&
        expiresAt > 0 &&
        expiresAt <= now.millisecondsSinceEpoch;
  }

  static bool matchesScope(
    Map<String, dynamic> data, {
    required String? uid,
    required String? houseId,
  }) {
    if (uid == null || uid.isEmpty) return false;
    final account = data['accountUid']?.toString() ?? '';
    final house = (data['houseId'] ?? data['house_id'])?.toString() ?? '';
    return (account.isEmpty || account == uid) &&
        (house.isEmpty || house == houseId);
  }

  static bool ownsToken(Object? remoteToken, String? localToken) =>
      localToken != null && localToken.isNotEmpty && remoteToken == localToken;

  static bool capsuleReady(Map<String, dynamic> capsule, DateTime now) {
    final unlockMs = int.tryParse(capsule['unlock_time_ms']?.toString() ?? '');
    return capsule['is_opened'] != true &&
        unlockMs != null &&
        unlockMs > 0 &&
        unlockMs <= now.millisecondsSinceEpoch;
  }
}

/// Chỉ đánh dấu sau khi gửi thành công; lỗi hoặc đổi phiên vẫn cho phép thử lại.
class NotificationDeliveryOnce {
  final _pending = <String, Future<bool>>{};

  Future<bool> run({
    required String key,
    required bool Function() active,
    required bool Function() alreadyDelivered,
    required Future<bool> Function() deliver,
    required Future<void> Function() markDelivered,
  }) async {
    final pending = _pending[key];
    if (pending != null) return pending;
    final operation = () async {
      if (!active()) return false;
      if (alreadyDelivered()) return true;
      if (!await deliver() || !active()) return false;
      await markDelivered();
      return true;
    }();
    _pending[key] = operation;
    try {
      return await operation;
    } finally {
      if (identical(_pending[key], operation)) _pending.remove(key);
    }
  }
}

/// Giữ một lần chạm trong lúc Auth/House/Home chưa sẵn sàng, không giữ qua logout.
class PendingNotificationTapBuffer {
  Map<String, dynamic>? _data;
  String? _uid;
  DateTime? _receivedAt;

  void store(Map<String, dynamic> data, {String? uid, required DateTime now}) {
    _data = Map<String, dynamic>.from(data);
    _uid = uid;
    _receivedAt = now;
  }

  Map<String, dynamic>? take({required String uid, required DateTime now}) {
    final data = _data;
    final account = _uid;
    final received = _receivedAt;
    clear();
    if (data == null ||
        received == null ||
        now.difference(received) > const Duration(minutes: 5) ||
        (account != null && account != uid) ||
        ((data['accountUid']?.toString() ?? '').isNotEmpty &&
            data['accountUid'] != uid) ||
        NotificationDeliveryPolicy.expired(data, now)) {
      return null;
    }
    return data;
  }

  void clear() {
    _data = null;
    _uid = null;
    _receivedAt = null;
  }
}
