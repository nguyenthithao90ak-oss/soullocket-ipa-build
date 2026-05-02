// ignore_for_file: invalid_use_of_protected_member

part of '../chat_detail_screen.dart';

extension _ChatDetailLayoutPart on _ChatDetailScreenState {
  Widget _buildConversationBackground(String backgroundUrl) {
    final normalizedUrl = backgroundUrl.trim();
    if (normalizedUrl.isEmpty) {
      return const ColoredBox(color: Colors.white);
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        CachedNetworkImage(
          key: ValueKey<String>(normalizedUrl),
          imageUrl: normalizedUrl,
          fit: BoxFit.cover,
          placeholder: (context, url) =>
              const ColoredBox(color: Color(0xFFF8FAFC)),
          errorWidget: (context, url, error) =>
              const ColoredBox(color: Color(0xFFF8FAFC)),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.white.withOpacity(0.64),
                Colors.white.withOpacity(0.78),
                Colors.white.withOpacity(0.92),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMessagesList(
    bool isChatClosed, {
    bool hasChatBackground = false,
  }) {
    if (_isInitialMessagesLoading) {
      return ListView.builder(
        itemCount: 8,
        padding: const EdgeInsets.all(16),
        itemBuilder: (context, index) {
          final isMe = index % 2 == 0;
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
              children: [
                if (!isMe) ...[
                  const SkeletonContainer.circle(size: 32),
                  const SizedBox(width: 8),
                ],
                SkeletonContainer.rounded(
                  width: MediaQuery.of(context).size.width * 0.6,
                  height: 44,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: Radius.circular(isMe ? 16 : 4),
                    bottomRight: Radius.circular(isMe ? 4 : 16),
                  ),
                ),
              ],
            ),
          );
        },
      );
    }

    if (_messages.isEmpty) {
      return Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
          decoration: BoxDecoration(
            color: hasChatBackground
                ? Colors.white.withOpacity(0.72)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(24),
            border: hasChatBackground
                ? Border.all(color: Colors.white.withOpacity(0.38))
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                  color: Color(0xFFF0F2F5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.chat_bubble_outline,
                  size: 36,
                  color: Color(0xFF0A7CFF),
                ),
              ),
              SLSpacing.h16,
              Text(
                isChatClosed
                    ? 'Đoạn chat này đã đóng'
                    : 'Bắt đầu cuộc trò chuyện',
                style: SLTheme.quicksand(
                  color: const Color(0xFF6B7280),
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
              SLSpacing.h8,
              Text(
                isChatClosed
                    ? 'Bạn vẫn có thể xem lại tin nhắn cũ, nhưng chưa thể gửi tin nhắn mới.'
                    : 'Gửi tin nhắn, sticker hoặc ảnh để bắt đầu.',
                textAlign: TextAlign.center,
                style: SLTheme.quicksand(
                  color: const Color(0xFF94A3B8),
                  fontWeight: FontWeight.w700,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      );
    }
    final itemCount = _messages.length + (_isLoadingOlderMessages ? 1 : 0);
    return ListView.builder(
      controller: _messagesScrollController,
      padding: const EdgeInsets.fromLTRB(15, 15, 15, 10),
      reverse: true,
      itemCount: itemCount,
      itemBuilder: (context, index) {
        if (_isLoadingOlderMessages && index == _messages.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: SkeletonContainer.rounded(
                width: 100,
                height: 20,
              ),
            ),
          );
        }
        final msg = _messages[index];
        final isMe = _isInternal
            ? msg.senderId == _currentRole
            : msg.senderId == widget.myHouseId;
        return _buildMsgBubble(msg, isMe);
      },
    );
  }

  Widget _buildAppBarAction(
    IconData icon,
    VoidCallback onPressed, {
    bool compact = false,
  }) {
    final buttonSize = compact ? 32.0 : 36.0;
    final iconSize = compact ? 17.0 : 18.0;
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: buttonSize,
        height: buttonSize,
        margin: EdgeInsets.only(right: compact ? 2 : 4),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Icon(icon, size: iconSize, color: const Color(0xFF334155)),
      ),
    );
  }

  Widget _buildInputArea(
    bool isChatClosed, {
    bool hasChatBackground = false,
  }) {
    return ChatInputArea(
      controller: _msgController,
      isUploading: _isUploading,
      hasComposerText: _hasComposerText,
      quickReactionEmoji: _quickReactionEmoji,
      isChatClosed: isChatClosed,
      hasChatBackground: hasChatBackground,
      onStickerTap: _showStickerBottomSheet,
      onPickImage: _pickImage,
      onSend: _sendMsg,
      onQuickReaction: _sendQuickLike,
    );
  }
}
