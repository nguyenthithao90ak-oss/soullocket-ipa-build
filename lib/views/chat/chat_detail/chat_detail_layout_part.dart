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
    return ChatMessageList(
      messages: _messages,
      isInitialLoading: _isInitialMessagesLoading,
      isLoadingOlder: _isLoadingOlderMessages,
      isChatClosed: isChatClosed,
      hasChatBackground: hasChatBackground,
      isInternal: _isInternal,
      myHouseId: widget.myHouseId,
      currentRole: _currentRole,
      scrollController: _messagesScrollController,
      bubbleBuilder: (msg, isMe) => _buildMsgBubble(msg, isMe),
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
