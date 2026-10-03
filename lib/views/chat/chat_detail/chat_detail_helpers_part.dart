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
        title: context.tr('ui_chat_chat_background_60fd91'),
        subtitle: _isUpdatingChatBackground
            ? context.tr('ui_chat_updating_the_background_image_for_this_chat_338ab1')
            : currentBackgroundUrl.trim().isEmpty
                ? context.tr('ui_chat_upload_a_custom_chat_background_3ba394')
                : context.tr('ui_chat_already_has_its_own_background_touch_to_418978'),
        color: const Color(0xFF8B5CF6),
        enabled: !_isUpdatingChatBackground,
        closeDrawerBeforeAction: true,
        onTap: () => _openChatBackgroundSheet(
          currentBackgroundUrl: currentBackgroundUrl,
          currentBackgroundStoragePath: currentBackgroundStoragePath,
        ),
      ),
      _ChatInfoShortcut(
        id: 'nickname',
        icon: Icons.badge_outlined,
        title: context.tr('ui_chat_nickname_5206ed'),
        subtitle: _nickname.trim().isEmpty
            ? context.tr('ui_chat_give_this_chat_a_unique_name_fb7e80')
            : L10nScope.of(context).format('ui_chat_currently_using_value1_499491', {'value1': _nickname.trim()}),
        color: const Color(0xFFD81B60),
        enabled: true,
        closeDrawerBeforeAction: false,
        onTap: _changeNickname,
      ),
      _ChatInfoShortcut(
        id: 'quick_reaction',
        icon: Icons.emoji_emotions_outlined,
        title: context.tr('ui_chat_quick_reaction_5e9d2f'),
        subtitle: L10nScope.of(context).format('ui_chat_current_value1_4f3243', {'value1': _quickReactionEmoji}),
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
        title: _isChatMuted ? context.tr('ui_chat_turn_notifications_back_on_33d80c') : context.tr('p9_group_chat_disable_notifications'),
        subtitle: _isChatMuted
            ? context.tr('ui_chat_notifications_for_this_chat_are_muted_on_25bc5a')
            : context.tr('ui_chat_hide_new_notifications_from_this_chat_on_ccc95a'),
        color: const Color(0xFF6366F1),
        enabled: true,
        closeDrawerBeforeAction: false,
        onTap: _toggleChatMute,
      ),
      _ChatInfoShortcut(
        id: 'send_image',
        icon: Icons.image_outlined,
        title: context.tr('ui_chat_send_photos_f7dc07'),
        subtitle: isChatClosed
            ? context.tr('ui_chat_the_chat_is_closed_so_temporarily_locked_12a24f')
            : context.tr('ui_chat_select_photos_from_your_device_and_send_eff1e2'),
        color: const Color(0xFF0A7CFF),
        enabled: !isChatClosed,
        closeDrawerBeforeAction: true,
        onTap: _pickImage,
      ),
      _ChatInfoShortcut(
        id: 'stickers',
        icon: Icons.auto_awesome,
        title: context.tr('sticker'),
        subtitle: isChatClosed
            ? context.tr('ui_chat_the_chat_is_closed_so_temporarily_locked_12a24f')
            : context.tr('ui_chat_open_soullocket_s_quick_sticker_panel_e832a6'),
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
          title: context.tr('p4_soul_voice_call'),
          subtitle: isChatClosed
              ? context.tr('ui_chat_open_the_chat_again_to_make_a_b632f1')
              : context.tr('ui_chat_start_a_voice_call_now_00f66d'),
          color: const Color(0xFF2563EB),
          enabled: !isChatClosed,
          closeDrawerBeforeAction: true,
          onTap: () => _startCall(false),
        ),
      if (!_isInternal)
        _ChatInfoShortcut(
          id: 'video_call',
          icon: Icons.videocam_rounded,
          title: context.tr('p4_soul_video_call'),
          subtitle: isChatClosed
              ? context.tr('ui_chat_reopen_the_chat_to_make_a_video_b14b0f')
              : context.tr('chat_start_video_call_hint'),
          color: const Color(0xFF0891B2),
          enabled: !isChatClosed,
          closeDrawerBeforeAction: true,
          onTap: () => _startCall(true),
        ),
      if (!_isInternal)
        _ChatInfoShortcut(
          id: 'watch_together',
          icon: Icons.ondemand_video_rounded,
          title: context.tr('ui_chat_watch_together_7223de'),
          subtitle: isChatClosed
              ? context.tr('ui_chat_the_chat_is_closed_so_temporarily_locked_12a24f')
              : context.tr('ui_chat_create_a_watch_room_from_this_chat_7b9396'),
          color: const Color(0xFFEA580C),
          enabled: !isChatClosed,
          closeDrawerBeforeAction: true,
          onTap: _openWatchTogether,
        ),
      if (!_isInternal)
        _ChatInfoShortcut(
          id: 'create_group',
          icon: Icons.group_add_outlined,
          title: context.tr('ui_chat_create_groups_5b7194'),
          subtitle: context.tr('ui_chat_select_more_friends_and_create_a_group_bbe529'),
          color: const Color(0xFF16A34A),
          enabled: true,
          closeDrawerBeforeAction: true,
          onTap: _createGroupDraftFromChat,
        ),
      _ChatInfoShortcut(
        id: 'delete_chat',
        icon: Icons.delete_outline_rounded,
        title: context.tr('ui_chat_delete_chat_7ebcf4'),
        subtitle: _isInternal
            ? context.tr('ui_chat_delete_chat_history_in_private_space_521ff6')
            : context.tr('ui_chat_delete_the_messaging_history_of_this_chat_471b9c'),
        color: const Color(0xFFD97706),
        enabled: true,
        closeDrawerBeforeAction: true,
        onTap: _deleteConversationHistory,
      ),
      if (!_isInternal)
        _ChatInfoShortcut(
          id: 'block_user',
          icon: Icons.block_rounded,
          title: context.tr('ui_chat_block_users_a37d68'),
          subtitle: context.tr('ui_chat_prevent_this_person_from_texting_and_interacting_b04045'),
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
          subtitle: context.tr('home_gibocotiqu_e68d16'),
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
