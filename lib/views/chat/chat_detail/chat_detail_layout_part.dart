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
          filterQuality: FilterQuality.medium,
          placeholder: (context, url) =>
              const ColoredBox(color: Color(0xFFF8FAFC)),
          errorWidget: (context, url, error) =>
              const ColoredBox(color: Color(0xFFF8FAFC)),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.white.withValues(alpha: 0.64),
                Colors.white.withValues(alpha: 0.78),
                Colors.white.withValues(alpha: 0.92),
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
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF0A7CFF)),
      );
    }

    if (_messages.isEmpty) {
      return Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
          decoration: BoxDecoration(
            color: hasChatBackground
                ? Colors.white.withValues(alpha: 0.72)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(24),
            border: hasChatBackground
                ? Border.all(color: Colors.white.withValues(alpha: 0.38))
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
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: Color(0xFF0A7CFF),
                ),
              ),
            ),
          );
        }
        final msg = _messages[index];
        final isMe = _isInternal
            ? msg.senderId == _currentRole
            : msg.senderId == widget.myHouseId;

        bool isLatestMe = false;
        if (isMe) {
          final firstMeIndex = _messages.indexWhere((m) => _isInternal
              ? m.senderId == _currentRole
              : m.senderId == widget.myHouseId);
          isLatestMe = index == firstMeIndex;
        }

        return _buildMsgBubble(msg, isMe, isLatestMe: isLatestMe);
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
    if (isChatClosed) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
        color: hasChatBackground
            ? Colors.white.withValues(alpha: 0.92)
            : Colors.white,
        child: Text(
          'Tài khoản này không còn khả dụng nên cuộc chat hiện đã bị khóa.',
          textAlign: TextAlign.center,
          style: SLTheme.quicksand(
            color: const Color(0xFFD81B60),
            fontWeight: FontWeight.w800,
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: hasChatBackground
            ? Colors.white.withValues(alpha: 0.9)
            : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              GestureDetector(
                onTap: _showStickerBottomSheet,
                child: const Padding(
                  padding: EdgeInsets.only(right: 8, bottom: 4),
                  child: Icon(
                    Icons.add_circle,
                    color: Color(0xFF0A7CFF),
                    size: 30,
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  constraints:
                      const BoxConstraints(minHeight: 42, maxHeight: 110),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: hasChatBackground
                        ? const Color(0xFFFFFFFF).withValues(alpha: 0.82)
                        : const Color(0xFFF0F2F5),
                    borderRadius: BorderRadius.circular(24),
                    border: hasChatBackground
                        ? Border.all(
                            color: Colors.white.withValues(alpha: 0.35))
                        : null,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      GestureDetector(
                        onTap: _isUploading ? null : _pickImage,
                        child: SizedBox(
                          width: 28,
                          height: 28,
                          child: _isUploading
                              ? const Padding(
                                  padding: EdgeInsets.all(4),
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(
                                  Icons.image_outlined,
                                  color: Color(0xFF0A7CFF),
                                  size: 20,
                                ),
                        ),
                      ),
                      SLSpacing.w8,
                      Expanded(
                        child: TextField(
                          controller: _msgController,
                          maxLines: null,
                          maxLength: 2000,
                          textInputAction: TextInputAction.send,
                          style: const TextStyle(
                            fontSize: 15,
                            color: Color(0xFF1E293B),
                          ),
                          decoration: InputDecoration(
                            hintText: 'Nhắn tin...',
                            hintStyle: SLTheme.quicksand(
                              color: Colors.grey,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding:
                                const EdgeInsets.symmetric(vertical: 8),
                            counterText: '',
                          ),
                          onSubmitted: (_) => _sendMsg(),
                        ),
                      ),
                      SLSpacing.w8,
                      GestureDetector(
                        onTap: _showStickerBottomSheet,
                        child: const SizedBox(
                          width: 28,
                          height: 28,
                          child: Icon(
                            Icons.emoji_emotions_outlined,
                            color: Color(0xFF6B7280),
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SLSpacing.w8,
              GestureDetector(
                onTap: _sendQuickLike,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: _hasComposerText
                        ? const Color(0xFF0A7CFF)
                        : const Color(0xFFEAF2FF),
                    border: Border.all(
                      color: const Color(0xFFC7DCFF),
                      width: _hasComposerText ? 0 : 1,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: _hasComposerText
                        ? const Icon(
                            Icons.send_rounded,
                            key: ValueKey('send'),
                            color: Colors.white,
                            size: 19,
                          )
                        : Text(
                            _quickReactionEmoji,
                            key: ValueKey('quick_$_quickReactionEmoji'),
                            style: const TextStyle(
                              fontSize: 20,
                              height: 1,
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
