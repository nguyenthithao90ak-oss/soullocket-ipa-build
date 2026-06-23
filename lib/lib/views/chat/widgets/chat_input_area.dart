import 'package:flutter/material.dart';
import '../../../core/sl_theme.dart';

class ChatInputArea extends StatelessWidget {
  final TextEditingController controller;
  final bool isUploading;
  final bool hasComposerText;
  final String quickReactionEmoji;
  final bool isChatClosed;
  final bool hasChatBackground;
  final VoidCallback onStickerTap;
  final VoidCallback onPickImage;
  final VoidCallback onSend;
  final VoidCallback onQuickReaction;

  const ChatInputArea({
    super.key,
    required this.controller,
    required this.isUploading,
    required this.hasComposerText,
    required this.quickReactionEmoji,
    required this.isChatClosed,
    this.hasChatBackground = false,
    required this.onStickerTap,
    required this.onPickImage,
    required this.onSend,
    required this.onQuickReaction,
  });

  @override
  Widget build(BuildContext context) {
    if (isChatClosed) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
        color: hasChatBackground ? Colors.white.withValues(alpha: 0.92) : Colors.white,
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
        color: hasChatBackground ? Colors.white.withValues(alpha: 0.9) : Colors.white,
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
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              GestureDetector(
                onTap: onStickerTap,
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
                  constraints: const BoxConstraints(minHeight: 42, maxHeight: 110),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: hasChatBackground
                        ? const Color(0xFFFFFFFF).withValues(alpha: 0.82)
                        : const Color(0xFFF0F2F5),
                    borderRadius: BorderRadius.circular(24),
                    border: hasChatBackground
                        ? Border.all(color: Colors.white.withValues(alpha: 0.35))
                        : null,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      GestureDetector(
                        onTap: isUploading ? null : onPickImage,
                        child: SizedBox(
                          width: 28,
                          height: 28,
                          child: isUploading
                              ? const Padding(
                                  padding: EdgeInsets.all(4),
                                  child: CircularProgressIndicator(strokeWidth: 2),
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
                          controller: controller,
                          maxLines: null,
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
                            contentPadding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                          onSubmitted: (_) => onSend(),
                        ),
                      ),
                      SLSpacing.w8,
                      GestureDetector(
                        onTap: onStickerTap,
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
                onTap: hasComposerText ? onSend : onQuickReaction,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: hasComposerText
                        ? const Color(0xFF0A7CFF)
                        : const Color(0xFFEAF2FF),
                    border: Border.all(
                      color: const Color(0xFFC7DCFF),
                      width: hasComposerText ? 0 : 1,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: hasComposerText
                        ? const Icon(
                            Icons.send_rounded,
                            key: ValueKey('send'),
                            color: Colors.white,
                            size: 19,
                          )
                        : Text(
                            quickReactionEmoji,
                            key: ValueKey('quick_$quickReactionEmoji'),
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
