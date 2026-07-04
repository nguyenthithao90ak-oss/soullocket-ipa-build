part of '../messenger_screen.dart';

extension _MessengerRoomListPart on _MessengerScreenState {
  Widget _buildFriendAvatarCluster(
    String friendId,
    Color statusColor, {
    bool showStatus = true,
  }) {
    final mates = _houseMates(friendId);
    if (mates.length >= 2) {
      return SizedBox(
        width: 68,
        height: 56,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: 0,
              top: 6,
              child: _buildAvatarBubble(
                avatarUrl: mates[0].avatar,
                label: mates[0].name,
                radius: 21,
                borderColor: const Color(0xFFFFD1E1),
              ),
            ),
            Positioned(
              left: 24,
              top: 0,
              child: _buildAvatarBubble(
                avatarUrl: mates[1].avatar,
                label: mates[1].name,
                radius: 21,
                borderColor: const Color(0xFFF9A8D4),
              ),
            ),
            if (showStatus)
              Positioned(
                right: 2,
                bottom: 3,
                child: _buildStatusDot(statusColor),
              ),
          ],
        ),
      );
    }

    final fallbackLabel =
        mates.isNotEmpty ? mates.first.name : _primaryLabel(friendId);
    final fallbackAvatar =
        mates.isNotEmpty ? mates.first.avatar : _displayAvatar(friendId);

    return SizedBox(
      width: 56,
      height: 56,
      child: Stack(
        children: [
          _buildAvatarBubble(
            avatarUrl: fallbackAvatar,
            label: fallbackLabel,
            radius: 26,
            borderColor: const Color(0xFFFFD9E6),
          ),
          if (showStatus)
            Positioned(
              right: 1,
              bottom: 1,
              child: _buildStatusDot(statusColor),
            ),
        ],
      ),
    );
  }

  Widget _buildAvatarBubble({
    required String avatarUrl,
    required String label,
    required double radius,
    required Color borderColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        border: Border.all(color: borderColor, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: CircleAvatar(
        radius: radius,
        backgroundColor: Colors.pink[50],
        backgroundImage:
            avatarUrl.isNotEmpty ? CachedNetworkImageProvider(avatarUrl) : null,
        child: avatarUrl.isEmpty
            ? Text(
                label.isNotEmpty ? label[0].toUpperCase() : '?',
                style: SLTheme.quicksand(
                  color: const Color(0xFFD81B60),
                  fontWeight: FontWeight.w900,
                  fontSize: radius * 0.66,
                ),
              )
            : null,
      ),
    );
  }

  Widget _buildStatusDot(Color color) {
    return Container(
      width: 13,
      height: 13,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
    );
  }

  Widget _buildTimeBadge(String value, {bool highlighted = false}) {
    if (value.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: highlighted ? const Color(0xFFFFEEF5) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color:
              highlighted ? const Color(0xFFF8BBD0) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Text(
        value,
        style: SLTheme.quicksand(
          fontSize: 10.5,
          fontWeight: FontWeight.w900,
          color:
              highlighted ? const Color(0xFFD81B60) : const Color(0xFF94A3B8),
        ),
      ),
    );
  }

  Widget _buildUnreadDot({bool prominent = false}) {
    return Container(
      width: prominent ? 11 : 9,
      height: prominent ? 11 : 9,
      decoration: BoxDecoration(
        color: const Color(0xFFD81B60),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1.6),
      ),
    );
  }

  Widget _buildConversationPreviewRow({
    required String preview,
    required String statusText,
    required Color statusColor,
  }) {
    final safePreview = repairMojibakeText(
      preview.trim().isEmpty ? 'Nhấn để bắt đầu trò chuyện...' : preview.trim(),
    );
    final safeStatus = repairMojibakeText(statusText.trim());

    return Row(
      children: [
        Expanded(
          child: Text(
            safePreview,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: SLTheme.quicksand(
              fontWeight: FontWeight.w800,
              fontSize: 12.5,
              color: const Color(0xFF64748B),
            ),
          ),
        ),
        if (safeStatus.isNotEmpty) ...[
          const SizedBox(width: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 120),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    safeStatus,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    style: SLTheme.quicksand(
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildMateStrip(String friendId) {
    final mates = _houseMates(friendId);
    if (mates.isEmpty) {
      return const SizedBox.shrink();
    }

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: mates.take(2).map((mate) {
        return Container(
          padding: const EdgeInsets.fromLTRB(6, 4, 8, 4),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF4F7),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: const Color(0xFFF8BBD0)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 9,
                backgroundColor: Colors.pink[50],
                backgroundImage: mate.avatar.isNotEmpty
                    ? CachedNetworkImageProvider(mate.avatar)
                    : null,
                child: mate.avatar.isEmpty
                    ? Text(
                        mate.name.isNotEmpty ? mate.name[0].toUpperCase() : '?',
                        style: SLTheme.quicksand(
                          color: const Color(0xFFD81B60),
                          fontWeight: FontWeight.w900,
                          fontSize: 9,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 6),
              Text(
                mate.name,
                style: SLTheme.quicksand(
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                  color: const Color(0xFF7A284B),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildQuickAvatarRow(List<String> friends) {
    final quickFriends = friends.take(12).toList(growable: false);
    final hasInternalPartner = _shouldShowInternalPartnerTile;
    if (quickFriends.isEmpty && !hasInternalPartner) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: 112,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
        children: [
          if (hasInternalPartner)
            Padding(
              padding: const EdgeInsets.only(right: 14),
              child: GestureDetector(
                onTap: _openInternalChatDetail,
                child: SizedBox(
                  width: 74,
                  child: Column(
                    children: [
                      SizedBox(
                        width: 66,
                        height: 66,
                        child: Stack(
                          children: [
                            _buildAvatarBubble(
                              avatarUrl: _internalPartnerAvatar(),
                              label: _internalPartnerName(),
                              radius: 30,
                              borderColor: const Color(0xFFE5E7EB),
                            ),
                            Positioned(
                              right: 3,
                              bottom: 3,
                              child: _buildStatusDot(
                                  _internalPartnerStatusColor()),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _internalPartnerName(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: SLTheme.quicksand(
                          fontWeight: FontWeight.w800,
                          fontSize: 12.5,
                          color: const Color(0xFF111827),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          for (final friendId in quickFriends)
            Padding(
              padding: const EdgeInsets.only(right: 14),
              child: GestureDetector(
                onTap: () => _openChatDetail(
                  friendId,
                  _primaryLabel(friendId),
                  _displayAvatar(friendId),
                ),
                child: SizedBox(
                  width: 74,
                  child: Column(
                    children: [
                      SizedBox(
                        width: 66,
                        height: 66,
                        child: Stack(
                          children: [
                            _buildFriendAvatarCluster(
                              friendId,
                              _presenceColor(_presenceByFriendId[friendId]),
                            ),
                            if (_friendHasUnread(friendId))
                              Positioned(
                                top: 1,
                                right: 1,
                                child: _buildUnreadDot(prominent: true),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _primaryLabel(friendId),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: SLTheme.quicksand(
                          fontWeight: FontWeight.w800,
                          fontSize: 12.5,
                          color: const Color(0xFF111827),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildUnifiedMessengerBody({
    required List<String> filteredFriends,
    required List<GroupChatRoom> filteredGroups,
  }) {
    final hasInternalPartner = _shouldShowInternalPartnerTile;
    final totalCount = filteredFriends.length +
        filteredGroups.length +
        (hasInternalPartner ? 1 : 0);
    if (totalCount == 0) {
      return _searchQuery.isNotEmpty
          ? _buildEmptyState(
              icon: Icons.search_off_rounded,
              title: 'Không tìm thấy đoạn chat phù hợp',
              body: 'Thử tìm bằng tên nhà, tên người hoặc tên nhóm khác.',
            )
          : _buildEmptyState(
              icon: Icons.chat_bubble_outline_rounded,
              title: 'Chưa có cuộc trò chuyện nào',
              body: 'Kết bạn trước rồi quay lại đây để bắt đầu nhắn tin.',
            );
    }

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 10),
      children: [
        _buildQuickAvatarRow(filteredFriends),
        if (hasInternalPartner) _buildInternalConversationTile(),
        ...filteredFriends.map(_buildConversationTile),
        ...filteredGroups.map(_buildGroupTile),
      ],
    );
  }

  Widget _buildConversationTile(String friendId) {
    final name = _primaryLabel(friendId);
    final avatar = _displayAvatar(friendId);
    final meta = _roomMetaByFriendId[friendId] ?? const ChatRoomMeta();
    final lastMap = meta.lastMessage;
    final isClosed = meta.isClosed;
    final presence = _presenceByFriendId[friendId];
    final lastMessageTime = _formatLastMessageTime(lastMap);
    final hasUnread = _friendHasUnread(friendId);
    final previewText = isClosed
        ? 'Tài khoản đã bị xóa, chỉ còn xem lại lịch sử.'
        : _formatLastMessage(lastMap);
    final statusColor =
        isClosed ? const Color(0xFFD81B60) : _presenceColor(presence);
    final statusText =
        isClosed ? 'Đoạn chat đã đóng' : _presenceLabel(presence);

    final tile = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _openChatDetail(friendId, name, avatar),
          borderRadius: SLRadius.lgAll,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.05),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                _buildFriendAvatarCluster(friendId, statusColor),
                SLSpacing.w12,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: SLTheme.quicksand(
                                fontWeight: FontWeight.w900,
                                fontSize: 15,
                                color: const Color(0xFF1E293B),
                              ),
                            ),
                          ),
                          if (lastMessageTime.isNotEmpty) ...[
                            _buildTimeBadge(
                              lastMessageTime,
                              highlighted: hasUnread,
                            ),
                            if (hasUnread) ...[
                              const SizedBox(width: 6),
                              _buildUnreadDot(prominent: true),
                            ],
                          ]
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (_houseMates(friendId).isNotEmpty) ...[
                        _buildMateStrip(friendId),
                        const SizedBox(height: 8),
                      ] else if (_displayUsername(friendId).isNotEmpty) ...[
                        Text(
                          _displayName(friendId),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: SLTheme.quicksand(
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                            color: const Color(0xFF94A3B8),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ] else
                        const SizedBox(height: 2),
                      _buildConversationPreviewRow(
                        preview: previewText,
                        statusText: statusText,
                        statusColor: statusColor,
                      ),
                      if (hasUnread)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: _buildUnreadDot(),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    return _FriendRealtimeScope(
      key: ValueKey<String>('conversation-$friendId'),
      friendId: friendId,
      onActivate: _activateFriendRealtime,
      onDeactivate: _deactivateFriendRealtime,
      child: tile,
    );
  }

  Widget _buildInternalConversationTile() {
    final name = _internalPartnerName();
    final avatar = _internalPartnerAvatar();
    final lastMap = _internalPartnerRoomMeta.lastMessage;
    final lastMessageTime = _formatLastMessageTime(lastMap);
    final statusColor = _internalPartnerStatusColor();
    final statusText = _internalPartnerStatusLabel();
    final hasUnread = _internalPartnerHasUnread;
    final previewText = _formatLastMessage(
      lastMap,
      fallback: 'Nhắn để bắt đầu trò chuyện cùng $name',
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _openInternalChatDetail,
          borderRadius: SLRadius.lgAll,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFD81B60).withValues(alpha: 0.08),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 56,
                  height: 56,
                  child: Stack(
                    children: [
                      _buildAvatarBubble(
                        avatarUrl: avatar,
                        label: name,
                        radius: 26,
                        borderColor: const Color(0xFFFFC6DB),
                      ),
                      Positioned(
                        right: 1,
                        bottom: 1,
                        child: _buildStatusDot(statusColor),
                      ),
                    ],
                  ),
                ),
                SLSpacing.w12,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: SLTheme.quicksand(
                                fontWeight: FontWeight.w900,
                                fontSize: 15,
                                color: const Color(0xFF1E293B),
                              ),
                            ),
                          ),
                          if (lastMessageTime.isNotEmpty) ...[
                            _buildTimeBadge(
                              lastMessageTime,
                              highlighted: hasUnread,
                            ),
                            if (hasUnread) ...[
                              const SizedBox(width: 6),
                              _buildUnreadDot(prominent: true),
                            ],
                          ]
                        ],
                      ),
                      const SizedBox(height: 8),
                      _buildConversationPreviewRow(
                        preview: previewText,
                        statusText: statusText,
                        statusColor: statusColor,
                      ),
                      if (hasUnread)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: _buildUnreadDot(),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
