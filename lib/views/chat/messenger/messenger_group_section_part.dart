part of '../messenger_screen.dart';

extension _MessengerGroupSectionPart on _MessengerScreenState {
  Widget _buildGroupTile(GroupChatRoom group) {
    final hasUnread = _groupHasUnread(group);
    final lastMessageTime = _formatLastMessageTime(group.lastMessage);
    final previewText = _groupPreviewText(group);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _openGroupChat(group),
          borderRadius: SLRadius.lgAll,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: SLRadius.lgAll,
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                _buildGroupAvatarCluster(group),
                SLSpacing.w12,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              repairMojibakeText(group.name),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: SLTheme.quicksand(
                                fontWeight: FontWeight.w900,
                                fontSize: 14,
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
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        repairMojibakeText(
                          '${group.memberHouseIds.length} thành viên',
                        ),
                        style: SLTheme.quicksand(
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                          color: const Color(0xFFD81B60),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        previewText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: SLTheme.quicksand(
                          fontWeight:
                              hasUnread ? FontWeight.w900 : FontWeight.w700,
                          fontSize: 11.5,
                          color: hasUnread
                              ? const Color(0xFFD81B60)
                              : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                if (hasUnread)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: _buildUnreadDot(),
                  ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFF94A3B8),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGroupAvatarCluster(GroupChatRoom group) {
    final members = group.memberHouseIds.take(3).toList();
    return SizedBox(
      width: 62,
      height: 56,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (int index = 0; index < members.length; index++)
            Positioned(
              left: (index * 16).toDouble(),
              top: index.isEven ? 8 : 0,
              child: _buildAvatarBubble(
                avatarUrl: _groupHouseAvatar(members[index]),
                label: _groupHouseName(members[index]),
                radius: 18,
                borderColor: const Color(0xFFFFD9E6),
              ),
            ),
        ],
      ),
    );
  }
}
