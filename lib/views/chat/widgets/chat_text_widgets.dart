import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/sl_theme.dart';

/// Tên trong thẻ hội thoại có giới hạn ngang và vẫn đọc đầy đủ bằng nhấn giữ.
class ChatMateChip extends StatelessWidget {
  const ChatMateChip({super.key, required this.name, this.avatarUrl = ''});

  final String name;
  final String avatarUrl;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? SLColors.darkTextPrimary : const Color(0xFF7A284B);
    return Tooltip(
      message: name,
      excludeFromSemantics: true,
      child: Semantics(
        label: name,
        excludeSemantics: true,
        child: Container(
          padding: const EdgeInsets.fromLTRB(6, 4, 8, 4),
          decoration: BoxDecoration(
            color: isDark ? SLColors.darkBgElevated : const Color(0xFFFFF4F7),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isDark ? SLColors.darkBorder : const Color(0xFFF8BBD0),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 10,
                backgroundColor: isDark ? SLColors.darkBgCard : Colors.pink[50],
                backgroundImage: avatarUrl.isNotEmpty
                    ? CachedNetworkImageProvider(avatarUrl)
                    : null,
                child: avatarUrl.isEmpty
                    ? Text(
                        name.isEmpty
                            ? '?'
                            : name.characters.first.toUpperCase(),
                        textScaler: TextScaler.noScaling,
                        style: SLTheme.quicksand(
                          color: ink,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: SLTheme.quicksand(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    height: 1.35,
                    color: ink,
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

/// Giờ và trạng thái tin nhắn tự chuyển hàng khi không còn đủ chỗ.
class ChatMessageReceipt extends StatelessWidget {
  const ChatMessageReceipt({
    super.key,
    required this.timeLabel,
    required this.isMe,
    this.statusLabel,
    this.isRead = false,
  });

  final String timeLabel;
  final bool isMe;
  final String? statusLabel;
  final bool isRead;

  @override
  Widget build(BuildContext context) {
    final color = isMe ? Colors.white70 : const Color(0xFF66616A);
    final style = SLTheme.quicksand(
      color: color,
      fontSize: 12,
      fontWeight: FontWeight.w500,
      height: 1.35,
    );
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(timeLabel, style: style),
        if (statusLabel != null)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isRead
                    ? Icons.done_all_rounded
                    : Icons.check_circle_outline_rounded,
                size: 14,
                color: color,
              ),
              const SizedBox(width: 3),
              Flexible(child: Text(statusLabel!, style: style)),
            ],
          ),
      ],
    );
  }
}
