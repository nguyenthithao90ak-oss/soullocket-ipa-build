import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:soullocket_app/core/sl_theme.dart';

class SoulMergeChatBar extends StatelessWidget {
  final List<Map<String, dynamic>> chatHistory;
  final String myRole;
  final String partnerName;
  final String? spamWarning;
  final TextEditingController textController;
  final ScrollController scrollController;
  final bool isUploadingPhoto;
  final int lastAnyMsgTimestamp;
  final bool isMerged;
  final VoidCallback onSendCustomMessage;
  final VoidCallback onPickImage;
  final VoidCallback onShowSticker;
  final ValueChanged<String> onSendPreset;
  final String Function(int? timestamp) formatTime;

  const SoulMergeChatBar({
    super.key,
    required this.chatHistory,
    required this.myRole,
    required this.partnerName,
    required this.spamWarning,
    required this.textController,
    required this.scrollController,
    required this.isUploadingPhoto,
    required this.lastAnyMsgTimestamp,
    required this.isMerged,
    required this.onSendCustomMessage,
    required this.onPickImage,
    required this.onShowSticker,
    required this.onSendPreset,
    required this.formatTime,
  });

  @override
  Widget build(BuildContext context) {
    final addressWord = myRole == 'user1' ? 'em' : 'anh';
    final addressWordTitle = myRole == 'user1' ? 'Em' : 'Anh';
    final presetsBefore = [
      '$addressWordTitle đang làm gì đó? 🤔',
      'Hello $addressWord 👋',
      'Nhớ $partnerName quá đi nhé 💕',
    ];
    final presetsAfter = ['Yêu bạn 😘', 'Nhớ quá! 💖', 'Ú òa! 👻'];

    final now = DateTime.now().millisecondsSinceEpoch;
    final hoursSinceLastMsg = lastAnyMsgTimestamp == 0
        ? 999
        : (now - lastAnyMsgTimestamp) / (1000 * 60 * 60);
    final showPresetsBefore = hoursSinceLastMsg >= 24;

    final presets = isMerged
        ? presetsAfter
        : (showPresetsBefore ? presetsBefore : <String>[]);

    return Padding(
      padding: EdgeInsets.zero,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (spamWarning != null)
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFF4F4F).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFFF4F4F).withValues(alpha: 0.4),
                  width: 1.0,
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: Color(0xFFFF4F4F),
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      spamWarning!,
                      style: SLTheme.quicksand(
                        color: const Color(0xFFFFD1D1),
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Container(
            constraints: const BoxConstraints(maxHeight: 500),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: const BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.all(Radius.circular(20)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: chatHistory.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.favorite_outline_rounded,
                            color: Colors.white.withValues(alpha: 0.35),
                            size: 24,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Hãy gửi những lời thì thầm tâm hồn... 💕',
                            style: SLTheme.quicksand(
                              color: Colors.white.withValues(alpha: 0.35),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    )
                  : RepaintBoundary(
                      child: ListView.builder(
                        controller: scrollController,
                        reverse: true,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        itemCount: chatHistory.length,
                        itemBuilder: (context, index) {
                          final msg = chatHistory.reversed.elementAt(index);
                          final sender = (msg['sender'] ?? '').toString();
                          final isSelf = (sender == myRole);
                          final text = (msg['text'] ?? '').toString();
                          final imageUrl =
                              (msg['imageUrl'] ?? '').toString();
                          final timeStr =
                              formatTime(msg['timestamp'] as int?);
                          final isSticker = imageUrl
                              .startsWith('assets/images/anhtomau_stickers/');

                          return _ChatBubble(
                            isSelf: isSelf,
                            text: text,
                            imageUrl: imageUrl,
                            timeStr: timeStr,
                            isSticker: isSticker,
                          );
                        },
                      ),
                    ),
            ),
          ),
          if (presets.isNotEmpty)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: presets.map((text) {
                  return Container(
                    margin: const EdgeInsets.only(right: 8),
                    child: InkWell(
                      onTap: () => onSendPreset(text),
                      borderRadius: BorderRadius.circular(20),
                      child: Ink(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFFFF758F).withValues(alpha: 0.25),
                              const Color(0xFFFF4F93).withValues(alpha: 0.15),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: const Color(0xFFFF758F)
                                .withValues(alpha: 0.4),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFF4F93)
                                  .withValues(alpha: 0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          text,
                          style: SLTheme.quicksand(
                            color: Colors.white,
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.8),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFFB6C1).withValues(alpha: 0.2),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: onPickImage,
                  child: Container(
                    margin: const EdgeInsets.only(left: 4),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                    child: isUploadingPhoto
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFFFF9A9E)))
                        : const Icon(Icons.add_photo_alternate_rounded,
                            color: Color(0xFF6B5B6D), size: 22),
                  ),
                ),
                GestureDetector(
                  onTap: onShowSticker,
                  child: Container(
                    margin: const EdgeInsets.only(left: 4),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                    child: const Icon(Icons.emoji_emotions_rounded,
                        color: Color(0xFF6B5B6D), size: 22),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: TextField(
                      controller: textController,
                      style: SLTheme.quicksand(
                        color: const Color(0xFF5A4A5E),
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Nhập tin nhắn tâm hồn...',
                        hintStyle: SLTheme.quicksand(
                          color: const Color(0xFF9E8B9F),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        filled: false,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        isDense: true,
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 8),
                      ),
                      onSubmitted: (_) => onSendCustomMessage(),
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: onSendCustomMessage,
                  child: Container(
                    width: 38,
                    height: 38,
                    margin: const EdgeInsets.only(right: 2),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [Color(0xFFFF9A9E), Color(0xFFFECFEF)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Color(0xFFFF9A9E),
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.send_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final bool isSelf;
  final String text;
  final String imageUrl;
  final String timeStr;
  final bool isSticker;

  const _ChatBubble({
    required this.isSelf,
    required this.text,
    required this.imageUrl,
    required this.timeStr,
    required this.isSticker,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isSelf ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(
          top: 2,
          bottom: 2,
          left: isSelf ? 48 : 0,
          right: isSelf ? 0 : 48,
        ),
        padding: isSticker
            ? EdgeInsets.zero
            : (imageUrl.isNotEmpty
                ? const EdgeInsets.all(6)
                : const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 11)),
        decoration: isSticker
            ? null
            : BoxDecoration(
                gradient: isSelf
                    ? const LinearGradient(
                        colors: [
                          Color(0xFFFF9A9E),
                          Color(0xFFFECFEF)
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: isSelf
                    ? null
                    : Colors.white.withValues(alpha: 0.75),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(24),
                  topRight: const Radius.circular(24),
                  bottomLeft:
                      Radius.circular(isSelf ? 24 : 6),
                  bottomRight:
                      Radius.circular(isSelf ? 6 : 24),
                ),
                border: Border.all(
                  color: isSelf
                      ? Colors.white.withValues(alpha: 0.6)
                      : Colors.white.withValues(alpha: 0.9),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isSelf
                        ? const Color(0xFFFF9A9E)
                            .withValues(alpha: 0.4)
                        : Colors.black.withValues(alpha: 0.06),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
        child: Column(
          crossAxisAlignment:
              isSelf ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (imageUrl.isNotEmpty)
              ClipRRect(
                borderRadius:
                    BorderRadius.circular(isSticker ? 0 : 14),
                child: imageUrl.startsWith('assets/')
                    ? Image.asset(imageUrl,
                        fit: BoxFit.contain,
                        width: isSticker ? 160 : 200)
                    : CachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.cover,
                        width: 200,
                        placeholder: (context, url) => Container(
                          width: 200,
                          height: 150,
                          color: Colors.white12,
                          child: const Center(
                              child: CircularProgressIndicator(
                                  color: Colors.white54,
                                  strokeWidth: 2)),
                        ),
                        errorWidget: (context, url, error) => Container(
                          width: 200,
                          height: 150,
                          color: Colors.white12,
                          child: const Icon(Icons.broken_image,
                              color: Colors.white54),
                        ),
                      ),
              ),
            if (text.isNotEmpty)
              Padding(
                padding: EdgeInsets.only(
                    top: imageUrl.isNotEmpty ? 6 : 0,
                    left: imageUrl.isNotEmpty ? 4 : 0,
                    right: imageUrl.isNotEmpty ? 4 : 0,
                    bottom: 2),
                child: Text(
                  text,
                  style: SLTheme.quicksand(
                    color: isSelf
                        ? Colors.white
                        : const Color(0xFF5A4A5E),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            if (timeStr.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  timeStr,
                  style: SLTheme.quicksand(
                    color: isSelf
                        ? Colors.white60
                        : Colors.grey.shade400,
                    fontSize: 9,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
