import 'l10n_service.dart';

typedef NotificationTextResolver = String Function(
  String key, [
  Map<String, Object?> params,
]);

String _defaultNotificationText(String key, [Map<String, Object?>? params]) =>
    L10nService().format(key, params ?? const {});

/// Dịch khung thông báo hệ thống; tên và nội dung do người dùng viết giữ nguyên.
class NotificationTextPresentation {
  const NotificationTextPresentation({required this.title, required this.message});

  final String title;
  final String message;
}

const _notificationCopyKeys = <String, (String, String)>{
  'friend_request': ('p5_notif_type_friend_request', 'notif_friend_request_body'),
  'friend_accept': ('p5_notif_type_friend_accept', 'notif_friend_accept_body'),
  'friend_wave': ('p5_notif_type_friend_wave', 'notif_friend_wave_body'),
  'fire': ('p5_notif_type_fire', 'notif_heart_body'),
  'countdown_space_request': ('p5_notif_type_pair_request', 'notif_space_request_body'),
  'countdown_space_accept': ('p5_notif_type_pair_accept', 'notif_space_accept_body'),
  'countdown_space_delete_request':
      ('p5_notif_type_space_delete_request', 'notif_space_delete_request_body'),
  'countdown_space_deleted': ('p5_notif_type_space_deleted', 'notif_space_deleted_body'),
};

NotificationTextPresentation? describeSystemNotification(
  Map<String, dynamic> raw, {
  required String fallbackMessage,
  NotificationTextResolver text = _defaultNotificationText,
}) {
  final type = raw['type']?.toString().toLowerCase();
  final keys = _notificationCopyKeys[type];
  if (keys == null) return null;
  final copyParams = raw['copyParams'];
  String? name;
  for (final candidate in [
    if (copyParams is Map) copyParams['name'],
    raw['fromName'],
    raw['fromLabel'],
    raw['sourceLabel'],
  ]) {
    if (candidate is String && candidate.trim().isNotEmpty) {
      name = candidate;
      break;
    }
  }
  // Record cũ vẫn dựng theo type; không dùng ID hay câu Việt lưu sẵn làm tên.
  final params = <String, Object?>{
    'name': name ?? text('home_ai_2b68a4'),
  };
  return NotificationTextPresentation(
    title: text(keys.$1),
    message: text(keys.$2, params),
  );
}
