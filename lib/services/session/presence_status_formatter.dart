class PresenceStatusFormatter {
  const PresenceStatusFormatter();

  String onlineLabel() => 'Đang hoạt động';

  String neverConnectedLabel() => 'Chưa mở app';

  String disconnectedLabel() => 'Mất kết nối';

  String justDisconnectedLabel() => 'Vừa thoát';

  String formatLastSeen(int? lastSeenMs) {
    if (lastSeenMs == null) return neverConnectedLabel();
    final diff = DateTime.now().difference(
      DateTime.fromMillisecondsSinceEpoch(lastSeenMs),
    );

    if (diff.inSeconds < 60) return justDisconnectedLabel();
    if (diff.inMinutes < 60) return '${diff.inMinutes} phút trước';
    if (diff.inHours < 24) return '${diff.inHours} giờ trước';
    if (diff.inDays == 1) return 'Hôm qua';
    if (diff.inDays < 30) return '${diff.inDays} ngày trước';
    return 'Lâu rồi';
  }
}
