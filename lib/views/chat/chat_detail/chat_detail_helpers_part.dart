// ignore_for_file: invalid_use_of_protected_member

part of '../chat_detail_screen.dart';

extension _ChatDetailHelpersPart on _ChatDetailScreenState {
  List<_ChatInfoShortcut> _buildShortcutCatalog({
    required bool isChatClosed,
    required String currentBackgroundUrl,
    required String currentBackgroundStoragePath,
  }) {
    return <_ChatInfoShortcut>[
      _ChatInfoShortcut(
        id: 'chat_background',
        icon: Icons.wallpaper_rounded,
        title: 'Nền chat',
        subtitle: _isUpdatingChatBackground
            ? 'Đang cập nhật ảnh nền cho đoạn chat này'
            : currentBackgroundUrl.trim().isEmpty
                ? 'Tải ảnh nền riêng cho giao diện chat'
                : 'Đã có nền riêng, chạm để đổi hoặc xóa',
        color: const Color(0xFF8B5CF6),
        enabled: !_isUpdatingChatBackground,
        closeDrawerBeforeAction: true,
        onTap: () => _openChatBackgroundSheet(
          currentBackgroundUrl: currentBackgroundUrl,
          currentBackgroundStoragePath: currentBackgroundStoragePath,
        ),
      ),
      _ChatInfoShortcut(
        id: 'friendly_wishes',
        icon: Icons.auto_awesome_rounded,
        title: 'Lời chúc thân thiện',
        subtitle: 'Gửi nhanh lời chào, lời chúc hoặc động viên',
        color: const Color(0xFFF472B6),
        enabled: true,
        closeDrawerBeforeAction: true,
        onTap: _sendFriendlyResponse,
      ),
      _ChatInfoShortcut(
        id: 'nickname',
        icon: Icons.badge_outlined,
        title: 'Biệt danh',
        subtitle: _nickname.trim().isEmpty
            ? 'Đặt tên riêng cho cuộc chat này'
            : 'Đang dùng: ${_nickname.trim()}',
        color: const Color(0xFFD81B60),
        enabled: true,
        closeDrawerBeforeAction: false,
        onTap: _changeNickname,
      ),
      _ChatInfoShortcut(
        id: 'quick_reaction',
        icon: Icons.emoji_emotions_outlined,
        title: 'Cảm xúc nhanh',
        subtitle: 'Hiện tại: $_quickReactionEmoji',
        color: const Color(0xFFF59E0B),
        enabled: true,
        closeDrawerBeforeAction: false,
        onTap: _changeQuickReaction,
      ),
      _ChatInfoShortcut(
        id: 'mute_notifications',
        icon: _isChatMuted
            ? Icons.notifications_active_outlined
            : Icons.notifications_off_outlined,
        title: _isChatMuted ? 'Bật lại thông báo' : 'Tắt thông báo',
        subtitle: _isChatMuted
            ? 'Cuộc chat này đang tắt thông báo trên thiết bị này'
            : 'Ẩn thông báo mới từ cuộc chat này trên thiết bị này',
        color: const Color(0xFF6366F1),
        enabled: true,
        closeDrawerBeforeAction: false,
        onTap: _toggleChatMute,
      ),
      _ChatInfoShortcut(
        id: 'send_image',
        icon: Icons.image_outlined,
        title: 'Gửi ảnh',
        subtitle: isChatClosed
            ? 'Đoạn chat đang đóng nên tạm khóa'
            : 'Chọn ảnh từ máy và gửi ngay',
        color: const Color(0xFF0A7CFF),
        enabled: !isChatClosed,
        closeDrawerBeforeAction: true,
        onTap: _pickImage,
      ),
      _ChatInfoShortcut(
        id: 'stickers',
        icon: Icons.auto_awesome,
        title: 'Sticker',
        subtitle: isChatClosed
            ? 'Đoạn chat đang đóng nên tạm khóa'
            : 'Mở bảng sticker nhanh của SoulLocket',
        color: const Color(0xFF14B8A6),
        enabled: !isChatClosed,
        closeDrawerBeforeAction: true,
        onTap: () async {
          _showStickerBottomSheet();
        },
      ),
      if (!_isInternal)
        _ChatInfoShortcut(
          id: 'audio_call',
          icon: Icons.call_rounded,
          title: 'Gọi thoại',
          subtitle: isChatClosed
              ? 'Mở lại đoạn chat để gọi thoại'
              : 'Bắt đầu cuộc gọi thoại ngay',
          color: const Color(0xFF2563EB),
          enabled: !isChatClosed,
          closeDrawerBeforeAction: true,
          onTap: () => _startCall(false),
        ),
      if (!_isInternal)
        _ChatInfoShortcut(
          id: 'video_call',
          icon: Icons.videocam_rounded,
          title: 'Gọi video',
          subtitle: isChatClosed
              ? 'Mở lại đoạn chat để gọi video'
              : 'Bắt đầu video call ngay',
          color: const Color(0xFF0891B2),
          enabled: !isChatClosed,
          closeDrawerBeforeAction: true,
          onTap: () => _startCall(true),
        ),
      if (!_isInternal)
        _ChatInfoShortcut(
          id: 'watch_together',
          icon: Icons.ondemand_video_rounded,
          title: 'Xem chung',
          subtitle: isChatClosed
              ? 'Đoạn chat đang đóng nên tạm khóa'
              : 'Tạo phòng xem chung từ cuộc chat này',
          color: const Color(0xFFEA580C),
          enabled: !isChatClosed,
          closeDrawerBeforeAction: true,
          onTap: _openWatchTogether,
        ),
      if (!_isInternal)
        _ChatInfoShortcut(
          id: 'create_group',
          icon: Icons.group_add_outlined,
          title: 'Tạo nhóm',
          subtitle: 'Chọn thêm bạn bè và tạo nhóm từ cuộc chat này',
          color: const Color(0xFF16A34A),
          enabled: true,
          closeDrawerBeforeAction: true,
          onTap: _createGroupDraftFromChat,
        ),
      _ChatInfoShortcut(
        id: 'delete_chat',
        icon: Icons.delete_outline_rounded,
        title: 'Xóa đoạn chat',
        subtitle: _isInternal
            ? 'Xóa lịch sử trò chuyện trong không gian riêng'
            : 'Xóa lịch sử nhắn tin của cuộc chat này',
        color: const Color(0xFFD97706),
        enabled: true,
        closeDrawerBeforeAction: true,
        onTap: _deleteConversationHistory,
      ),
      if (!_isInternal)
        _ChatInfoShortcut(
          id: 'block_user',
          icon: Icons.block_rounded,
          title: 'Chặn người dùng',
          subtitle: 'Ngăn người này nhắn tin và tương tác với bạn',
          color: const Color(0xFFDC2626),
          enabled: true,
          closeDrawerBeforeAction: true,
          onTap: _blockTargetHouse,
        ),
      if (!_isInternal)
        _ChatInfoShortcut(
          id: 'report_user',
          icon: Icons.report_gmailerrorred_rounded,
          title: 'Báo cáo',
          subtitle: 'Gửi báo cáo tới quản trị viên',
          color: const Color(0xFFBE123C),
          enabled: true,
          closeDrawerBeforeAction: true,
          onTap: _reportTargetHouse,
        ),
    ];
  }

  String _formatConversationPreview(
    Map<dynamic, dynamic>? raw, {
    String fallback = 'Nhắn tin để bắt đầu trò chuyện',
  }) {
    return formatChatMessagePreview(
      raw,
      labels: _ChatDetailScreenState._conversationPreviewLabels,
      fallbackOverride: fallback,
    );
    /*
    if (raw == null) return fallback;
    final type = raw['type']?.toString();
    final text = raw['text']?.toString().trim() ?? '';
    final normalizedText = text.toLowerCase();

    if (type == 'call_invite' ||
        text.startsWith('[Call ') ||
        text == '[Cuộc gọi]') {
      return 'Đã bắt đầu cuộc gọi';
    }
    if (type == 'watch_invite' ||
        text == '[Watch Together]' ||
        text == '[Xem cùng]') {
      return 'Đã chia sẻ phòng xem cùng';
    }
    if (text == '[Image]' ||
        text == '[Hình ảnh]' ||
        normalizedText == '[hình ảnh]') {
      return 'Đã gửi hình ảnh';
    }
    return text.isEmpty ? fallback : text;
    */
  }

  String _buildHeaderPreview(ChatRoomMeta meta) {
    final lastMessage = meta.lastMessage;
    if (meta.isClosed) {
      return _formatConversationPreview(
        lastMessage,
        fallback: meta.closedMessage.trim().isEmpty
            ? 'Chỉ xem lại lịch sử trò chuyện'
            : meta.closedMessage.trim(),
      );
    }
    return _formatConversationPreview(meta.lastMessage);
  }
}
