part of 'notification_center_screen.dart';

class _NotifModel {
  final String id;
  final String type;
  final String title;
  final String from;
  final String? rawFrom;
  final String msg;
  final int ts;
  final int? readAt;
  final String? postId;
  final bool locked;
  final Map<String, dynamic> raw;

  const _NotifModel({
    required this.id,
    required this.type,
    required this.title,
    required this.from,
    required this.msg,
    required this.ts,
    this.rawFrom,
    this.readAt,
    this.postId,
    this.locked = false,
    this.raw = const {},
  });

  factory _NotifModel.fromMap(String id, Map<String, dynamic> m) {
    final l10n = L10nService();
    final type = m['type']?.toString().toLowerCase() ?? 'system';
    final fallbackTitle = switch (type) {
      'friend_request' => l10n.translate('p5_notif_type_friend_request'),
      'friend_accept' => l10n.translate('p5_notif_type_friend_accept'),
      'friend_wave' => l10n.translate('p5_notif_type_friend_wave'),
      'like' => l10n.translate('p5_notif_type_like'),
      'fire' => l10n.translate('p5_notif_type_fire'),
      'comment' => l10n.translate('p5_notif_type_comment'),
      'new_device' => l10n.translate('p5_notif_type_new_device'),
      'role_change' => l10n.translate('p5_notif_type_role_change'),
      'warning' => l10n.translate('p5_notif_type_warning'),
      'system' => l10n.translate('p5_notif_type_system'),
      _ => l10n.translate('p5_notif_type_default'),
    };
    final title = (m['title']?.toString().trim().isNotEmpty ?? false)
        ? m['title'].toString().trim()
        : fallbackTitle;
    final normalizedTitle = switch (type) {
      'countdown_space_request' =>
        title == fallbackTitle
            ? l10n.translate('p5_notif_type_pair_request')
            : title,
      'countdown_space_accept' =>
        title == fallbackTitle
            ? l10n.translate('p5_notif_type_pair_accept')
            : title,
      'countdown_space_delete_request' =>
        title == fallbackTitle
            ? l10n.translate('p5_notif_type_space_delete_request')
            : title,
      'countdown_space_deleted' =>
        title == fallbackTitle
            ? l10n.translate('p5_notif_type_space_deleted')
            : title,
      _ => title,
    };

    return _NotifModel(
      id: id,
      type: type,
      title: normalizedTitle,
      from:
          (m['sourceLabel'] ??
                  m['fromName'] ??
                  m['fromLabel'] ??
                  m['from'] ??
                  l10n.translate('p5_notif_system_source'))
              .toString(),
      rawFrom: m['fromId']?.toString() ?? m['from']?.toString(),
      msg:
          m['msg']?.toString() ??
          m['message']?.toString() ??
          m['content']?.toString() ??
          '',
      ts:
          (m['ts'] as num?)?.toInt() ??
          (m['timestamp'] as num?)?.toInt() ??
          (m['createdAt'] as num?)?.toInt() ??
          DateTime.now().millisecondsSinceEpoch,
      readAt: (m['readAt'] as num?)?.toInt(),
      postId: m['postId']?.toString(),
      locked:
          m['immutable'] == true ||
          m['systemLocked'] == true ||
          m['locked'] == true,
      raw: Map<String, dynamic>.from(m),
    );
  }
}

class NotificationBadgeCounter extends ChangeNotifier {
  static final NotificationBadgeCounter instance = NotificationBadgeCounter._();
  NotificationBadgeCounter._();

  int _count = 0;
  int get count => _count;

  void update(int c) {
    if (_count != c) {
      _count = c;
      notifyListeners();
    }
  }
}
