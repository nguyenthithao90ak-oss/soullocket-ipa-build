import 'package:flutter/material.dart';
import '../../../models/chat_message.dart';
import '../../../core/sl_theme.dart';
import '../../../widgets/skeleton_container.dart';

class ChatMessageList extends StatelessWidget {
  final List<ChatMessage> messages;
  final bool isInitialLoading;
  final bool isLoadingOlder;
  final bool isChatClosed;
  final bool hasChatBackground;
  final bool isInternal;
  final String myHouseId;
  final String currentRole;
  final ScrollController scrollController;
  final Widget Function(ChatMessage msg, bool isMe) bubbleBuilder;

  const ChatMessageList({
    super.key,
    required this.messages,
    required this.isInitialLoading,
    required this.isLoadingOlder,
    required this.isChatClosed,
    this.hasChatBackground = false,
    required this.isInternal,
    required this.myHouseId,
    required this.currentRole,
    required this.scrollController,
    required this.bubbleBuilder,
  });

  @override
  Widget build(BuildContext context) {
    if (isInitialLoading) {
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

    if (messages.isEmpty) {
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

    final itemCount = messages.length + (isLoadingOlder ? 1 : 0);
    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(15, 15, 15, 10),
      reverse: true,
      itemCount: itemCount,
      itemBuilder: (context, index) {
        if (isLoadingOlder && index == messages.length) {
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
        final msg = messages[index];
        final isMe = isInternal
            ? msg.senderId == currentRole
            : msg.senderId == myHouseId;
        return bubbleBuilder(msg, isMe);
      },
    );
  }
}
