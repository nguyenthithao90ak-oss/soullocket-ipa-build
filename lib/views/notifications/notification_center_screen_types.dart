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
    final type = m['type']?.toString().toLowerCase() ?? 'system';
    final title = (m['title']?.toString().trim().isNotEmpty ?? false)
        ? m['title'].toString().trim()
        : switch (type) {
            'friend_request' => 'Lời mời kết bạn',
            'friend_accept' => 'Kết bạn thành công',
            'friend_wave' => 'Lời chào mới',
            'like' => 'Lượt thích mới',
            'fire' => 'Yêu thích mới',
            'comment' => 'Bình luận mới',
            'new_device' => 'Đăng nhập thiết bị mới',
            'role_change' => 'Thay đổi vai trò',
            'warning' => 'Cảnh báo hệ thống',
            'system' => 'Thông báo hệ thống',
            _ => 'Thông báo mới',
          };
    final normalizedTitle = switch (type) {
      'countdown_space_request' =>
        title == 'Thông báo mới' ? 'Yêu cầu ghép nối không gian đêm' : title,
      'countdown_space_accept' =>
        title == 'Thông báo mới' ? 'Ghép nối không gian đêm thành công' : title,
      'countdown_space_delete_request' =>
        title == 'Thông báo mới' ? 'Yêu cầu xóa không gian đếm' : title,
      'countdown_space_deleted' =>
        title == 'Thông báo mới' ? 'Không gian đếm đã được xóa' : title,
      _ => title,
    };

    return _NotifModel(
      id: id,
      type: type,
      title: normalizedTitle,
      from: (m['sourceLabel'] ??
              m['fromName'] ??
              m['fromLabel'] ??
              m['from'] ??
              'Hệ thống')
          .toString(),
      rawFrom: m['fromId']?.toString() ?? m['from']?.toString(),
      msg: m['msg']?.toString() ??
          m['message']?.toString() ??
          m['content']?.toString() ??
          '',
      ts: (m['ts'] as num?)?.toInt() ??
          (m['timestamp'] as num?)?.toInt() ??
          (m['createdAt'] as num?)?.toInt() ??
          DateTime.now().millisecondsSinceEpoch,
      readAt: (m['readAt'] as num?)?.toInt(),
      postId: m['postId']?.toString(),
      locked: m['immutable'] == true ||
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
