// ignore_for_file: invalid_use_of_protected_member
part of '../chat_detail_screen.dart';

extension _ChatDetailMessagesPart on _ChatDetailScreenState {
  void _handleMessageScroll() {
    if (!_messagesScrollController.hasClients ||
        _isLoadingOlderMessages ||
        !_hasMoreMessages) {
      return;
    }
    if (_messagesScrollController.position.pixels >=
        _messagesScrollController.position.maxScrollExtent - 200) {
      unawaited(_loadOlderMessages());
    }
  }

  int _compareMessageOrder(ChatMessage left, ChatMessage right) {
    final byTime = right.timestamp.compareTo(left.timestamp);
    if (byTime != 0) {
      return byTime;
    }
    return right.id.compareTo(left.id);
  }

  int _findMessageInsertIndex(ChatMessage message) {
    var low = 0;
    var high = _messages.length;
    while (low < high) {
      final mid = (low + high) >> 1;
      if (_compareMessageOrder(message, _messages[mid]) < 0) {
        high = mid;
      } else {
        low = mid + 1;
      }
    }
    return low;
  }

  void _upsertLiveMessage(ChatMessage message) {
    final existingIndex = _messages.indexWhere((item) => item.id == message.id);
    if (existingIndex >= 0) {
      _messages.removeAt(existingIndex);
    } else {
      _messageIds.add(message.id);
    }
    _messages.insert(_findMessageInsertIndex(message), message);
    if (_messages.isNotEmpty) {
      _newestMessageTs = _messages.first.timestamp.millisecondsSinceEpoch;
      _oldestMessageTs = _messages.last.timestamp.millisecondsSinceEpoch;
    }
  }

  Future<void> _loadInitialMessages() async {
    setState(() => _isInitialMessagesLoading = true);
    try {
      final page = _isInternal
          ? await _chatService.fetchInternalMessagesPage(
              widget.myHouseId,
              limit: _ChatDetailScreenState._chatPageSize,
            )
          : await _chatService.fetchMessagesPage(
              widget.myHouseId,
              widget.targetHouseId,
              limit: _ChatDetailScreenState._chatPageSize,
            );
      if (!mounted) return;
      _replaceMessageState(page);
      _hasMoreMessages = page.length >= _ChatDetailScreenState._chatPageSize;
    } catch (_) {
      if (!mounted) return;
      _replaceMessageState(const []);
      _hasMoreMessages = false;
    } finally {
      _listenForNewMessages();
      if (mounted) {
        setState(() => _isInitialMessagesLoading = false);
      }
    }
  }

  Future<void> _loadOlderMessages() async {
    final cursor = _oldestMessageTs;
    if (cursor == null) {
      _hasMoreMessages = false;
      return;
    }

    setState(() => _isLoadingOlderMessages = true);
    try {
      final older = _isInternal
          ? await _chatService.fetchInternalMessagesPage(
              widget.myHouseId,
              limit: _ChatDetailScreenState._chatPageSize,
              beforeTs: cursor,
            )
          : await _chatService.fetchMessagesPage(
              widget.myHouseId,
              widget.targetHouseId,
              limit: _ChatDetailScreenState._chatPageSize,
              beforeTs: cursor,
            );
      if (!mounted) return;
      if (older.isEmpty) {
        setState(() {
          _hasMoreMessages = false;
          _isLoadingOlderMessages = false;
        });
        return;
      }

      final merged = [..._messages];
      for (final message in older) {
        if (_messageIds.add(message.id)) {
          merged.add(message);
        }
      }
      merged.sort(_compareMessageOrder);

      setState(() {
        _messages
          ..clear()
          ..addAll(merged);
        _oldestMessageTs = _messages.isEmpty ? null : _messages.last.timestamp.millisecondsSinceEpoch;
        _newestMessageTs = _messages.isEmpty ? null : _messages.first.timestamp.millisecondsSinceEpoch;
        _hasMoreMessages = older.length >= _ChatDetailScreenState._chatPageSize;
        _isLoadingOlderMessages = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingOlderMessages = false);
      }
    }
  }

  void _replaceMessageState(List<ChatMessage> messages) {
    _messages
      ..clear()
      ..addAll(messages);
    _messageIds
      ..clear()
      ..addAll(messages.map((message) => message.id));
    _oldestMessageTs = _messages.isEmpty ? null : _messages.last.timestamp.millisecondsSinceEpoch;
    _newestMessageTs = _messages.isEmpty ? null : _messages.first.timestamp.millisecondsSinceEpoch;
    // ⚡ Không cần setState rỗng — widget dùng StreamBuilder hoặc sẽ rebuild
    // khi listener _listenForNewMessages kích hoạt
  }

  void _listenForNewMessages() {
    _liveMessageSub?.cancel();
    final stream = _isInternal
        ? _chatService.streamNewInternalMessages(
            widget.myHouseId,
            afterTs: _newestMessageTs,
          )
        : _chatService.streamNewMessages(
            widget.myHouseId,
            widget.targetHouseId,
            afterTs: _newestMessageTs,
          );
    _liveMessageSub = stream.listen((message) {
      if (!mounted) return;
      setState(() {
        _upsertLiveMessage(message);
      });
    });
  }

  Widget _buildMsgBubble(ChatMessage msg, bool isMe, {bool isLatestMe = false}) {
    if (msg.type == 'call_invite') {
      return _buildCallInviteBubble(msg, isMe);
    }

    if (msg.type == 'watch_invite') {
      return _buildWatchInviteBubble(msg, isMe);
    }

    if (msg.type == 'share') {
      return _buildShareBubble(msg, isMe);
    }

    if (msg.type == 'system' || msg.senderId == 'system') {
      return Center(
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 10),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
              color: Colors.grey[300], borderRadius: SLRadius.lgAll),
          child: Text(msg.text,
              style: const TextStyle(
                  fontSize: 12,
                  color: Colors.black54,
                  fontStyle: FontStyle.italic)),
        ),
      );
    }

    final hasReactions = msg.reactions.isNotEmpty;
    final isSticker = msg.type == 'sticker';
    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    final maxBubbleWidth = screenWidth * 0.72;
    final imageSize = (screenWidth * 0.56).clamp(140.0, 260.0).toDouble();
    final effectiveImageSize =
        imageSize < maxBubbleWidth ? imageSize : maxBubbleWidth;
    final imageCacheWidth =
        (effectiveImageSize * mediaQuery.devicePixelRatio).round();

    return GestureDetector(
      onLongPress: () => _showReactionPicker(msg),
      onDoubleTap: () => _addReaction(msg.id, '\u2764\uFE0F'),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                padding: isSticker
                    ? const EdgeInsets.symmetric(horizontal: 10, vertical: 6)
                    : const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                margin: EdgeInsets.only(bottom: hasReactions ? 14 : 0),
                constraints: BoxConstraints(maxWidth: maxBubbleWidth),
                decoration: BoxDecoration(
                  gradient: isMe && !isSticker
                      ? const LinearGradient(
                          colors: [Color(0xFF1E88FF), Color(0xFF0A7CFF)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  color: isSticker
                      ? Colors.transparent
                      : (isMe ? null : const Color(0xFFE4E6EB)),
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(18),
                    topRight: const Radius.circular(18),
                    bottomLeft: Radius.circular(isMe ? 18 : 4),
                    bottomRight: Radius.circular(isMe ? 4 : 18),
                  ),
                  boxShadow: isSticker
                      ? []
                      : [
                          BoxShadow(
                            color: isMe
                                ? const Color(0xFF0A7CFF).withValues(alpha: 0.24)
                                : Colors.black.withValues(alpha: 0.06),
                            blurRadius: isMe ? 8 : 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                ),
                child: Column(
                  crossAxisAlignment:
                      isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  children: [
                    if (msg.type == 'image')
                      msg.hasActiveImage
                          ? ClipRRect(
                              borderRadius: SLRadius.mdAll,
                              child: CachedNetworkImage(
                                memCacheWidth: imageCacheWidth,
                                imageUrl: msg.text,
                                width: effectiveImageSize,
                                height: effectiveImageSize,
                                fit: BoxFit.cover,
                                filterQuality: FilterQuality.medium,
                                placeholder: (context, url) => SizedBox(
                                  width: effectiveImageSize,
                                  height: effectiveImageSize,
                                  child: const Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                ),
                                errorWidget: (context, url, error) => SizedBox(
                                  width: effectiveImageSize,
                                  height: effectiveImageSize,
                                  child: const Icon(
                                    Icons.broken_image,
                                    color: Colors.grey,
                                  ),
                                ),
                              ),
                            )
                          : Container(
                              width: effectiveImageSize,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: isMe
                                    ? Colors.white.withValues(alpha: 0.14)
                                    : const Color(0xFFF8FAFC),
                                borderRadius: SLRadius.mdAll,
                                border: Border.all(
                                  color: isMe
                                      ? Colors.white.withValues(alpha: 0.18)
                                      : const Color(0xFFD8E1EC),
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.timer_off_outlined,
                                    color: isMe
                                        ? Colors.white
                                        : const Color(0xFF64748B),
                                    size: 18,
                                  ),
                                  SLSpacing.w8,
                                  Expanded(
                                    child: Text(
                                      msg.imageDisplayText,
                                      style: TextStyle(
                                        color: isMe
                                            ? Colors.white
                                            : const Color(0xFF475569),
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        height: 1.35,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )
                    else if (isSticker)
                      AnimatedRabbitSticker(
                        msg.text,
                        width: effectiveImageSize,
                        height: effectiveImageSize,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(
                          Icons.broken_image_rounded,
                          color: Colors.grey,
                          size: 42,
                        ),
                      )
                    else
                      Text(
                        msg.text,
                        style: TextStyle(
                          color: isMe ? Colors.white : const Color(0xFF1E293B),
                          fontSize: 15,
                          height: 1.4,
                        ),
                      ),
                    SLSpacing.h4,
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          DateFormat('HH:mm').format(msg.timestamp),
                          style: TextStyle(
                            color: isMe ? Colors.white60 : Colors.black38,
                            fontSize: 10,
                          ),
                        ),
                        if (isMe && isLatestMe) ...[
                          const SizedBox(width: 4),
                          Icon(
                            msg.isRead ? Icons.done_all_rounded : Icons.check_circle_outline_rounded,
                            size: 12,
                            color: isMe ? Colors.white70 : Colors.black38,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            msg.isRead ? 'Đã xem' : 'Đã gửi',
                            style: TextStyle(
                              color: isMe ? Colors.white70 : Colors.black38,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              if (hasReactions)
                Positioned(
                  bottom: -5,
                  right: isMe ? 10 : null,
                  left: isMe ? null : 10,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: SLRadius.mdAll,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 3,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: msg.reactions.values.toSet().map((emoji) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child:
                              Text(emoji, style: const TextStyle(fontSize: 12)),
                        );
                      }).toList(),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCallInviteBubble(ChatMessage msg, bool isMe) {
    final isVideo = msg.callMode != 'audio';
    final label = isVideo ? 'cuộc gọi video' : 'cuộc gọi thoại';

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.76,
        margin: const EdgeInsets.only(bottom: 12),
        padding: SLSpacing.all12,
        decoration: BoxDecoration(
          color: isMe ? const Color(0xFFEAF2FF) : Colors.white,
          borderRadius: SLRadius.lgAll,
          border: Border.all(color: const Color(0xFFD6E4FF)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isVideo ? Icons.videocam : Icons.call,
                  color: const Color(0xFF0A7CFF),
                ),
                SLSpacing.w8,
                Expanded(
                  child: Text(
                    isMe
                        ? 'Bạn đã bắt đầu $label'
                        : '${widget.targetName} mời bạn vào $label',
                    style: SLTheme.quicksand(
                      color: Colors.black87,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            SLSpacing.h8,
            Row(
              children: [
                Expanded(
                  child: Text(
                    DateFormat('HH:mm').format(msg.timestamp),
                    style: const TextStyle(color: Colors.black45, fontSize: 11),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _joinCall(msg),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0A7CFF),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: SLRadius.mdAll,
                    ),
                  ),
                  icon: Icon(isVideo ? Icons.videocam : Icons.call, size: 16),
                  label: Text(
                    isMe ? 'Mở lại' : 'Tham gia',
                    style: SLTheme.quicksand(fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWatchInviteBubble(ChatMessage msg, bool isMe) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.76,
        margin: const EdgeInsets.only(bottom: 12),
        padding: SLSpacing.all12,
        decoration: BoxDecoration(
          color: isMe ? const Color(0xFFEAF2FF) : Colors.white,
          borderRadius: SLRadius.lgAll,
          border: Border.all(color: const Color(0xFFD6E4FF)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.ondemand_video, color: Color(0xFF2563EB)),
                SLSpacing.w8,
                Expanded(
                  child: Text(
                    isMe
                        ? 'Bạn đã chia sẻ phòng xem chung'
                        : '${widget.targetName} mời bạn xem chung',
                    style: SLTheme.quicksand(
                      color: Colors.black87,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            if ((msg.sharedUrl ?? '').isNotEmpty) ...[
              SLSpacing.h8,
              Text(
                msg.sharedUrl!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.black54,
                  fontSize: 12,
                ),
              ),
            ],
            SLSpacing.h8,
            Row(
              children: [
                Expanded(
                  child: Text(
                    DateFormat('HH:mm').format(msg.timestamp),
                    style: const TextStyle(color: Colors.black45, fontSize: 11),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () =>
                      _openWatchTogether(initialUrl: msg.sharedUrl),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: SLRadius.mdAll,
                    ),
                  ),
                  icon: const Icon(Icons.open_in_new, size: 16),
                  label: Text(
                    isMe ? 'Mở lại' : 'Tham gia',
                    style: SLTheme.quicksand(fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShareBubble(ChatMessage msg, bool isMe) {
    final lines = msg.text
        .split('\n')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
    final title = lines.isNotEmpty ? lines.first : 'Đã chia sẻ một nội dung';
    final body = lines.length > 1 ? lines.sublist(1).join('\n') : '';

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.78,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isMe
                ? const [Color(0xFFFFF1F6), Color(0xFFFFFFFF)]
                : const [Color(0xFFFFFFFF), Color(0xFFF8FAFC)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFFFD9E6)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x120F172A),
              blurRadius: 16,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFD81B60).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.share_rounded,
                    color: Color(0xFFD81B60),
                    size: 15,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Chia sẻ từ Cộng đồng',
                    style: SLTheme.quicksand(
                      color: const Color(0xFFD81B60),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: SLTheme.quicksand(
                color: const Color(0xFF1E293B),
                fontSize: 14.2,
                fontWeight: FontWeight.w900,
                height: 1.3,
              ),
            ),
            if (body.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.72),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFF1F5F9)),
                ),
                child: Text(
                  body,
                  maxLines: 5,
                  overflow: TextOverflow.ellipsis,
                  style: SLTheme.quicksand(
                    color: const Color(0xFF475569),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    height: 1.4,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                DateFormat('HH:mm').format(msg.timestamp),
                style: SLTheme.quicksand(
                  color: const Color(0xFF94A3B8),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
