// lib/views/chat/chat_detail/chat_detail_messages_aurora_part.dart
//
// ══════════════════════════════════════════════════════════════════════════════
// 🎨 PHASE 2.3 — Aurora Soft Chat Bubbles & Input Bar
// ══════════════════════════════════════════════════════════════════════════════
//
// Cách kết nối vào chat_detail_screen.dart (sẽ được thực hiện trong Phase 3):
//
//   1. Import file này:
//        part 'chat_detail/chat_detail_messages_aurora_part.dart';
//
//   2. Trong _buildMsgBubble (chat_detail_messages_part.dart), thay thế
//      logic bong bóng bằng gọi AuroraChatBubbles:
//        return AuroraChatBubbles.buildMessageBubble(
//          context: context,
//          message: msg,
//          isFromMe: isMe,
//          isLatestMe: isLatestMe,
//          onReact: () => _showReactionPicker(msg),
//        );
//
//   3. Trong _buildInputArea (chat_detail_layout_part.dart), thay thế bằng:
//        return AuroraChatBubbles.buildGlassInputBar(
//          controller: _msgController,
//          onSend: _sendMsg,
//          onAttach: _pickImage,
//          onSticker: _showStickerBottomSheet,
//          isComposing: _hasComposerText,
//        );
//
// ══════════════════════════════════════════════════════════════════════════════

import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:soullocket_app/core/fast_backdrop_filter.dart';
import 'package:soullocket_app/core/sl_theme.dart';
import 'package:soullocket_app/models/chat_message.dart';
import 'package:soullocket_app/utils/app_cache_manager.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';
import 'package:soullocket_app/views/ui_prefs.dart';
import 'package:soullocket_app/widgets/animated_rabbit_sticker.dart';

// ─── Aurora Gradient Definitions ───────────────────────────────────────────────

/// Gradient màu hồng phai → lavender nhẹ cho tin nhắn đã gửi
class _AuroraSentGradient {
  // Rose dawn gradient: soft rose blush → light lavender
  static const List<Color> roseDawn = [
    Color(0xFFFF6B9D), // auroraRoseDeep
    Color(0xFFFF8FB1), // warm rose mid
    Color(0xFFB19CD9), // auroraLavender
  ];

  static const LinearGradient gradient = LinearGradient(
    colors: roseDawn,
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Tail direction: bottom-right corner points to sender's avatar
  static const BorderRadius bubbleRadius = BorderRadius.only(
    topLeft: Radius.circular(22),
    topRight: Radius.circular(22),
    bottomLeft: Radius.circular(22),
    bottomRight: Radius.circular(6), // Tail on bottom-right
  );

  static const BoxShadow shadow = BoxShadow(
    color: Color(0x33FF6B9D), // soft rose glow
    blurRadius: 12,
    offset: Offset(0, 4),
  );
}

/// Gradient phụ cho hiệu ứng aurora shimmer (premium only)
class _AuroraShimmerColors {
  static const Color rose = Color(0xFFFF6B9D);
  static const Color lavender = Color(0xFFB19CD9);
  static const Color peach = Color(0xFFFFAB91);
}

// ─── Glass Bubble for Received Messages ───────────────────────────────────────

/// Màu nền Apple-style glass cho tin nhắn nhận được
class _GlassReceivedStyle {
  // Apple slate neutrals
  static const Color background = Color(0xFFF8FAFC); // slate50 equivalent
  static const Color border = Color(0xFFE2E8F0); // slate200
  static const Color textPrimary = Color(0xFF1E293B); // slate800
  static const Color textSecondary = Color(0xFF64748B); // slate500
  static const Color timestamp = Color(0xFF94A3B8); // slate400

  static const BorderRadius bubbleRadius = BorderRadius.only(
    topLeft: Radius.circular(22),
    topRight: Radius.circular(22),
    bottomLeft: Radius.circular(6), // Tail on bottom-left
    bottomRight: Radius.circular(22),
  );

  static const BoxShadow shadow = BoxShadow(
    color: Color(0x0C000000), // 5% black
    blurRadius: 8,
    offset: Offset(0, 2),
  );
}

// ─── Animation Curves ─────────────────────────────────────────────────────────

/// Soul Spring: nhẹ nhàng overshoot cho heart reactions
class _SoulSpringCurve extends Curve {
  // Approximation of spring with slight overshoot
  static const Cubic _spring = Cubic(0.34, 1.56, 0.64, 1.0);

  const _SoulSpringCurve();

  @override
  double transformInternal(double t) => _spring.transform(t);
}

// ─── Main Aurora Chat Bubbles Class ───────────────────────────────────────────

class AuroraChatBubbles {
  AuroraChatBubbles._();

  // ─── Message Bubble ────────────────────────────────────────────────────────

  /// Widget bong bóng tin nhắn Aurora Soft.
  ///
  /// [message]    — ChatMessage từ model
  /// [isFromMe]  — true = tin nhắn đã gửi (gradient hồng), false = nhận (glass trắng)
  /// [isLatestMe] — true = tin nhắn mới nhất của người gửi (hiển thị trạng thái đã xem)
  /// [onReact]   — callback khi long-press để mở reaction picker
  static Widget buildMessageBubble({
    required BuildContext context,
    required ChatMessage message,
    required bool isFromMe,
    bool isLatestMe = false,
    VoidCallback? onReact,
  }) {
    // Xử lý các message type đặc biệt trước
    if (message.type == 'call_invite') {
      return _buildAuroraCallInvite(context, message, isFromMe);
    }
    if (message.type == 'watch_invite') {
      return _buildAuroraWatchInvite(context, message, isFromMe);
    }
    if (message.type == 'share') {
      return _buildAuroraShareBubble(context, message, isFromMe);
    }
    if (message.type == 'system' || message.senderId == 'system') {
      return buildSystemMessageChip(context: context, text: message.text);
    }

    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    final maxBubbleWidth = screenWidth * 0.72;
    final imageSize = (screenWidth * 0.56).clamp(140.0, 260.0).toDouble();
    final effectiveImageSize =
        imageSize < maxBubbleWidth ? imageSize : maxBubbleWidth;
    final imageCacheWidth =
        (effectiveImageSize * mediaQuery.devicePixelRatio).round();

    final isSticker = message.type == 'sticker';
    final hasReactions = message.reactions.isNotEmpty;

    return GestureDetector(
      onLongPress: onReact,
      onDoubleTap: () {
        // Double-tap heart shortcut — xử lý ở parent
        onReact?.call();
      },
      child: RepaintBoundary(
        child: Align(
          alignment: isFromMe ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // ── Bubble body ──
                Container(
                  padding: isSticker
                      ? const EdgeInsets.symmetric(horizontal: 10, vertical: 6)
                      : const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  margin: EdgeInsets.only(bottom: hasReactions ? 16 : 0),
                  constraints: BoxConstraints(maxWidth: maxBubbleWidth),
                  decoration: _buildBubbleDecoration(
                    isFromMe: isFromMe,
                    isSticker: isSticker,
                  ),
                  child: Column(
                    crossAxisAlignment:
                        isFromMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                    children: [
                      // Nội dung message
                      _buildBubbleContent(
                        context: context,
                        message: message,
                        isFromMe: isFromMe,
                        isSticker: isSticker,
                        effectiveImageSize: effectiveImageSize,
                        imageCacheWidth: imageCacheWidth,
                      ),

                      const SizedBox(height: 4),

                      // Timestamp + read receipt
                      _buildBubbleFooter(
                        context: context,
                        message: message,
                        isFromMe: isFromMe,
                        isLatestMe: isLatestMe,
                      ),
                    ],
                  ),
                ),

                // ── Reaction bar ──
                if (hasReactions)
                  Positioned(
                    bottom: -8,
                    right: isFromMe ? 10 : null,
                    left: isFromMe ? null : 10,
                    child: _AuroraReactionPill(
                      reactions: message.reactions,
                      isFromMe: isFromMe,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static BoxDecoration _buildBubbleDecoration({
    required bool isFromMe,
    required bool isSticker,
  }) {
    if (isSticker) {
      return const BoxDecoration(color: Colors.transparent);
    }

    if (isFromMe) {
      return const BoxDecoration(
        gradient: _AuroraSentGradient.gradient,
        borderRadius: _AuroraSentGradient.bubbleRadius,
        boxShadow: [_AuroraSentGradient.shadow],
      );
    }

    // Glass received bubble
    return BoxDecoration(
      color: _GlassReceivedStyle.background.withValues(alpha: 0.92),
      borderRadius: _GlassReceivedStyle.bubbleRadius,
      border: Border.all(
        color: _GlassReceivedStyle.border,
        width: 1,
      ),
      boxShadow: const [_GlassReceivedStyle.shadow],
    );
  }

  static Widget _buildBubbleContent({
    required BuildContext context,
    required ChatMessage message,
    required bool isFromMe,
    required bool isSticker,
    required double effectiveImageSize,
    required int imageCacheWidth,
  }) {
    if (message.type == 'image') {
      return _buildImageContent(
        context: context,
        message: message,
        isFromMe: isFromMe,
        effectiveImageSize: effectiveImageSize,
        imageCacheWidth: imageCacheWidth,
      );
    }

    if (isSticker) {
      return RepaintBoundary(
        child: AnimatedRabbitSticker(
          message.text,
          width: effectiveImageSize,
          height: effectiveImageSize,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => const Icon(
            Icons.broken_image_rounded,
            color: Colors.grey,
            size: 42,
          ),
        ),
      );
    }

    // Text message
    return Text(
      message.text,
      style: TextStyle(
        color: isFromMe ? Colors.white : _GlassReceivedStyle.textPrimary,
        fontSize: 15,
        height: 1.4,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  static Widget _buildImageContent({
    required BuildContext context,
    required ChatMessage message,
    required bool isFromMe,
    required double effectiveImageSize,
    required int imageCacheWidth,
  }) {
    if (message.hasActiveImage) {
      // Image bubble với aurora gradient border cho sent images
      if (isFromMe) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: const LinearGradient(
              colors: [
                Color(0xFFFF6B9D),
                Color(0xFFB19CD9),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          padding: const EdgeInsets.all(2), // 2px aurora border
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: CachedNetworkImage(
              cacheManager: AppCacheManager.instance,
              maxWidthDiskCache: imageCacheWidth,
              imageUrl: message.text,
              width: effectiveImageSize - 4,
              height: effectiveImageSize - 4,
              fit: BoxFit.cover,
              memCacheWidth: 800,
              filterQuality: FilterQuality.medium,
              placeholder: (context, url) => SizedBox(
                width: effectiveImageSize,
                height: effectiveImageSize,
                child: const Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
              errorWidget: (context, url, error) => SizedBox(
                width: effectiveImageSize,
                height: effectiveImageSize,
                child: const Icon(Icons.broken_image, color: Colors.grey),
              ),
            ),
          ),
        );
      }

      // Received image
      return ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: CachedNetworkImage(
          cacheManager: AppCacheManager.instance,
          maxWidthDiskCache: imageCacheWidth,
          imageUrl: message.text,
          width: effectiveImageSize,
          height: effectiveImageSize,
          fit: BoxFit.cover,
          memCacheWidth: 800,
          filterQuality: FilterQuality.medium,
          placeholder: (context, url) => SizedBox(
            width: effectiveImageSize,
            height: effectiveImageSize,
            child: const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
          errorWidget: (context, url, error) => SizedBox(
            width: effectiveImageSize,
            height: effectiveImageSize,
            child: const Icon(Icons.broken_image, color: Colors.grey),
          ),
        ),
      );
    }

    // Expired/unavailable image
    return Container(
      width: effectiveImageSize,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isFromMe
            ? Colors.white.withValues(alpha: 0.14)
            : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isFromMe
              ? Colors.white.withValues(alpha: 0.18)
              : const Color(0xFFD8E1EC),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.timer_off_outlined,
            color: isFromMe ? Colors.white : const Color(0xFF64748B),
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message.imageDisplayText,
              style: TextStyle(
                color: isFromMe ? Colors.white : const Color(0xFF475569),
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildBubbleFooter({
    required BuildContext context,
    required ChatMessage message,
    required bool isFromMe,
    required bool isLatestMe,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          DateFormat('HH:mm').format(message.timestamp),
          style: TextStyle(
            color: isFromMe
                ? Colors.white.withValues(alpha: 0.70)
                : _GlassReceivedStyle.timestamp,
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),
        if (isFromMe && isLatestMe) ...[
          const SizedBox(width: 4),
          Icon(
            message.isRead
                ? Icons.done_all_rounded
                : Icons.check_circle_outline_rounded,
            size: 12,
            color: Colors.white.withValues(alpha: 0.70),
          ),
          const SizedBox(width: 2),
          Text(
            message.isRead ? 'Đã xem' : 'Đã gửi',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.70),
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }

  // ─── Call / Watch Invite Bubbles ───────────────────────────────────────────

  static Widget _buildAuroraCallInvite(
    BuildContext context,
    ChatMessage message,
    bool isFromMe,
  ) {
    final isVideo = message.callMode != 'audio';
    final label = isVideo ? 'cuộc gọi video' : 'cuộc gọi thoại';

    return Align(
      alignment: isFromMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        width: MediaQuery.sizeOf(context).width * 0.76,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF0E8FF), // Light lavender tint
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFD6C4FF)),
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
                  color: const Color(0xFF7B68B6), // auroraLavenderDeep
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isFromMe
                        ? 'Bạn đã bắt đầu $label'
                        : '${L10nService().translate('core_partner_female')} mời bạn vào $label',
                    style: SLTheme.quicksand(
                      color: _GlassReceivedStyle.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    DateFormat('HH:mm').format(message.timestamp),
                    style: const TextStyle(
                      color: _GlassReceivedStyle.timestamp,
                      fontSize: 11,
                    ),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    // TODO: join call — wire in Phase 3
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7B68B6),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: Icon(
                    isVideo ? Icons.videocam : Icons.call,
                    size: 16,
                  ),
                  label: Text(
                    isFromMe ? 'Mở lại' : 'Tham gia',
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

  static Widget _buildAuroraWatchInvite(
    BuildContext context,
    ChatMessage message,
    bool isFromMe,
  ) {
    return Align(
      alignment: isFromMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        width: MediaQuery.sizeOf(context).width * 0.76,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF0E8FF),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFD6C4FF)),
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
                const Icon(
                  Icons.ondemand_video,
                  color: Color(0xFF7B68B6),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isFromMe
                        ? 'Bạn đã chia sẻ phòng xem chung'
                        : '${L10nService().translate('core_partner_female')} mời bạn xem chung',
                    style: SLTheme.quicksand(
                      color: _GlassReceivedStyle.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            if ((message.sharedUrl ?? '').isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                message.sharedUrl!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _GlassReceivedStyle.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    DateFormat('HH:mm').format(message.timestamp),
                    style: const TextStyle(
                      color: _GlassReceivedStyle.timestamp,
                      fontSize: 11,
                    ),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    // TODO: open watch together — wire in Phase 3
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7B68B6),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: const Icon(Icons.open_in_new, size: 16),
                  label: Text(
                    isFromMe ? 'Mở lại' : 'Tham gia',
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

  // ─── Share Bubble ───────────────────────────────────────────────────────────

  static Widget _buildAuroraShareBubble(
    BuildContext context,
    ChatMessage message,
    bool isFromMe,
  ) {
    final lines = message.text
        .split('\n')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
    final title = lines.isNotEmpty ? lines.first : 'Đã chia sẻ một nội dung';
    final body = lines.length > 1 ? lines.sublist(1).join('\n') : '';

    return Align(
      alignment: isFromMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        width: MediaQuery.sizeOf(context).width * 0.78,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isFromMe
                ? [const Color(0xFFFFF1F6), const Color(0xFFFFFFFF)]
                : [const Color(0xFFFFFFFF), const Color(0xFFF8FAFC)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: const Color(0xFFFFD9E6),
            width: 1,
          ),
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
            // Community badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFF6B9D).withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.share_rounded,
                    color: Color(0xFFFF6B9D),
                    size: 15,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Chia sẻ từ Cộng đồng',
                    style: SLTheme.quicksand(
                      color: const Color(0xFFFF6B9D),
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
                color: _GlassReceivedStyle.textPrimary,
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
                  border: Border.all(color: _GlassReceivedStyle.border),
                ),
                child: Text(
                  body,
                  maxLines: 5,
                  overflow: TextOverflow.ellipsis,
                  style: SLTheme.quicksand(
                    color: _GlassReceivedStyle.textSecondary,
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
                DateFormat('HH:mm').format(message.timestamp),
                style: SLTheme.quicksand(
                  color: _GlassReceivedStyle.timestamp,
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

  // ─── Reaction Bar ───────────────────────────────────────────────────────────

  /// Widget thanh reaction (emoji pill) hiển thị dưới mỗi message.
  /// Hỗ trợ hiệu ứng float-up animation khi premiumEffects = true.
  static Widget buildReactionBar({
    required BuildContext context,
    required Map<String, String> reactions,
    required bool isFromMe,
  }) {
    if (reactions.isEmpty) return const SizedBox.shrink();

    return RepaintBoundary(
      child: Positioned(
        bottom: -8,
        right: isFromMe ? 10 : null,
        left: isFromMe ? null : 10,
        child: _AuroraReactionPill(
          reactions: reactions,
          isFromMe: isFromMe,
        ),
      ),
    );
  }

  // ─── Typing Indicator ──────────────────────────────────────────────────────

  /// Widget 3 dấu chấm animated Aurora.
  /// Màu sắc stagger: Rose → Lavender → Peach
  /// Tắt animation khi animationEnabled = false.
  static Widget buildTypingIndicator({required BuildContext context}) {
    final ui = UiPrefs.notifier.value;
    final profile = UiPrefs.resolveEffectProfile(
      state: ui,
      isWeb: kIsWeb,
    );
    final animationEnabled = profile.animationEnabled;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (index) {
          final colors = [
            _AuroraShimmerColors.rose,
            _AuroraShimmerColors.lavender,
            _AuroraShimmerColors.peach,
          ];

          if (!animationEnabled) {
            // Static dots when animations disabled
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: colors[index].withValues(alpha: 0.6),
                shape: BoxShape.circle,
              ),
            );
          }

          return _AuroraTypingDot(
            color: colors[index],
            delay: Duration(milliseconds: 200 * index),
          );
        }),
      ),
    );
  }

  // ─── System Message Chip ────────────────────────────────────────────────────

  /// Widget chip glass cho system message (date separator, "joined" notice).
  static Widget buildSystemMessageChip({
    required BuildContext context,
    required String text,
  }) {
    return Center(
      child: RepaintBoundary(
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 10),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: const Color(0xFFFFD9E6).withValues(alpha: 0.6),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            text,
            style: SLTheme.quicksand(
              color: const Color(0xFF7A5565), // muted rose
              fontSize: 12,
              fontWeight: FontWeight.w700,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      ),
    );
  }

  // ─── Glass Input Bar ───────────────────────────────────────────────────────

  /// Widget thanh nhập tin nhắn Aurora Soft.
  ///
  /// [controller]     — TextEditingController của parent
  /// [onSend]        — callback khi nhấn nút gửi
  /// [onAttach]      — callback mở picker ảnh
  /// [onSticker]     — callback mở bảng sticker
  /// [isComposing]   — true = có text → hiển thị nút gửi thay vì emoji quick
  static Widget buildGlassInputBar({
    required BuildContext context,
    required TextEditingController controller,
    required VoidCallback onSend,
    VoidCallback? onAttach,
    VoidCallback? onSticker,
    bool isComposing = false,
    bool isChatClosed = false,
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
            fontSize: 13,
          ),
        ),
      );
    }

    // Kiểm tra premium effects cho backdrop blur
    final ui = UiPrefs.notifier.value;
    final profile = UiPrefs.resolveEffectProfile(
      state: ui,
      isWeb: kIsWeb,
    );

    final Widget inputBar = Container(
      decoration: BoxDecoration(
        color: hasChatBackground
            ? Colors.white.withValues(alpha: 0.55)
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
              // Nút sticker (glass icon)
              _GlassIconButton(
                icon: Icons.add_circle,
                color: const Color(0xFFFF6B9D),
                size: 30,
                onTap: onSticker,
              ),

              const SizedBox(width: 4),

              // Text input pill
              Expanded(
                child: _AuroraInputPill(
                  controller: controller,
                  onAttach: onAttach,
                  onSticker: onSticker,
                  hasChatBackground: hasChatBackground,
                ),
              ),

              const SizedBox(width: 8),

              // Send / Quick reaction button
              _AuroraSendButton(
                isComposing: isComposing,
                onSend: onSend,
                emoji: '\u2764\uFE0F', // default heart
              ),
            ],
          ),
        ),
      ),
    );

    // Áp dụng backdrop blur khi có chat background
    if (hasChatBackground) {
      // Chỉ blur nếu premiumEffects = true
      if (profile.premiumEffects) {
        return ClipRRect(
          child: FastBackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24.0, sigmaY: 24.0),
            fallbackColor: Colors.black.withValues(alpha: 0.1),
            child: inputBar,
          ),
        );
      }
      // Fallback: semi-transparent overlay
      return Container(
        color: Colors.white.withValues(alpha: 0.85),
        child: inputBar,
      );
    }

    return inputBar;
  }
}

// ─── Aurora Typing Dot ────────────────────────────────────────────────────────

class _AuroraTypingDot extends StatefulWidget {
  final Color color;
  final Duration delay;

  const _AuroraTypingDot({
    required this.color,
    required this.delay,
  });

  @override
  State<_AuroraTypingDot> createState() => _AuroraTypingDotState();
}

class _AuroraTypingDotState extends State<_AuroraTypingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _opacity = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );

    // Stagger delay
    Future.delayed(widget.delay, () {
      if (!mounted) return;
      _ctrl.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _opacity,
      builder: (context, child) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 2),
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: widget.color.withValues(alpha: _opacity.value),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: _opacity.value * 0.4),
                blurRadius: 4,
                spreadRadius: 1,
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─── Aurora Reaction Pill ─────────────────────────────────────────────────────

class _AuroraReactionPill extends StatelessWidget {
  final Map<String, String> reactions;
  final bool isFromMe;

  const _AuroraReactionPill({
    required this.reactions,
    required this.isFromMe,
  });

  @override
  Widget build(BuildContext context) {
    // Unique emojis (user may have same emoji multiple times)
    final uniqueEmojis = reactions.values.toSet().toList();

    // Check if current user has reacted (for aurora border)
    final hasUserReacted = reactions.values.any((e) => true); // simplified

    return RepaintBoundary(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: hasUserReacted
                ? const Color(0xFFFF6B9D).withValues(alpha: 0.5)
                : const Color(0xFFE2E8F0),
            width: hasUserReacted ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: uniqueEmojis.map((emoji) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Text(
                emoji,
                style: const TextStyle(fontSize: 13),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

// ─── Aurora Float-up Reaction Animation ──────────────────────────────────────

/// Hiệu ứng float-up animation cho reaction mới thêm.
/// Chỉ chạy khi premiumEffects = true.
class _AuroraFloatingReaction extends StatefulWidget {
  final String emoji;

  const _AuroraFloatingReaction({
    required this.emoji,
  });

  @override
  State<_AuroraFloatingReaction> createState() =>
      _AuroraFloatingReactionState();
}

class _AuroraFloatingReactionState extends State<_AuroraFloatingReaction>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _floatAnim;
  late Animation<double> _opacityAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _floatAnim = Tween<double>(begin: 0, end: -32).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const _SoulSpringCurve(),
      ),
    );

    _opacityAnim = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.6, 1.0, curve: Curves.easeOut),
      ),
    );

    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _floatAnim.value),
          child: Opacity(
            opacity: _opacityAnim.value,
            child: Text(
              widget.emoji,
              style: const TextStyle(fontSize: 28),
            ),
          ),
        );
      },
    );
  }
}

// ─── Aurora Input Pill ────────────────────────────────────────────────────────

class _AuroraInputPill extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback? onAttach;
  final VoidCallback? onSticker;
  final bool hasChatBackground;

  const _AuroraInputPill({
    required this.controller,
    this.onAttach,
    this.onSticker,
    this.hasChatBackground = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 42, maxHeight: 110),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: hasChatBackground
            ? Colors.white.withValues(alpha: 0.82)
            : const Color(0xFFF0F2F5),
        borderRadius: BorderRadius.circular(24),
        border: hasChatBackground
            ? Border.all(color: Colors.white.withValues(alpha: 0.35))
            : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Attachment button
          GestureDetector(
            onTap: onAttach,
            child: const SizedBox(
              width: 28,
              height: 28,
              child: Icon(
                Icons.image_outlined,
                color: Color(0xFFFF6B9D),
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Text field
          Expanded(
            child: TextField(
              controller: controller,
              maxLines: null,
              maxLength: 2000,
              textInputAction: TextInputAction.send,
              style: const TextStyle(
                fontSize: 15,
                color: _GlassReceivedStyle.textPrimary,
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                hintText: 'Nhắn tin...',
                hintStyle: SLTheme.quicksand(
                  color: const Color(0xFF9CA3AF),
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                counterText: '',
              ),
            ),
          ),

          const SizedBox(width: 8),

          // Emoji button
          GestureDetector(
            onTap: onSticker,
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
    );
  }
}

// ─── Aurora Send Button ───────────────────────────────────────────────────────

class _AuroraSendButton extends StatefulWidget {
  final bool isComposing;
  final VoidCallback onSend;
  final String emoji;

  const _AuroraSendButton({
    required this.isComposing,
    required this.onSend,
    required this.emoji,
  });

  @override
  State<_AuroraSendButton> createState() => _AuroraSendButtonState();
}

class _AuroraSendButtonState extends State<_AuroraSendButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _scaleCtrl;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _scaleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.92).animate(
      CurvedAnimation(parent: _scaleCtrl, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _scaleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _scaleCtrl.forward(),
      onTapUp: (_) {
        _scaleCtrl.reverse();
        widget.onSend();
      },
      onTapCancel: () => _scaleCtrl.reverse(),
      child: ScaleTransition(
        scale: _scaleAnim,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            gradient: widget.isComposing
                ? const LinearGradient(
                    colors: [
                      Color(0xFFFF6B9D),
                      Color(0xFFB19CD9),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: widget.isComposing ? null : const Color(0xFFEAF2FF),
            border: Border.all(
              color: widget.isComposing
                  ? Colors.transparent
                  : const Color(0xFFFFD9E6),
              width: widget.isComposing ? 0 : 1,
            ),
            shape: BoxShape.circle,
            boxShadow: widget.isComposing
                ? [
                    BoxShadow(
                      color: const Color(0xFFFF6B9D).withValues(alpha: 0.30),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: widget.isComposing
                ? const Icon(
                    Icons.send_rounded,
                    key: ValueKey('send'),
                    color: Colors.white,
                    size: 19,
                  )
                : Text(
                    widget.emoji,
                    key: ValueKey('emoji_${widget.emoji}'),
                    style: const TextStyle(
                      fontSize: 20,
                      height: 1,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

// ─── Glass Icon Button ────────────────────────────────────────────────────────

class _GlassIconButton extends StatefulWidget {
  final IconData icon;
  final Color color;
  final double size;
  final VoidCallback? onTap;

  const _GlassIconButton({
    required this.icon,
    required this.color,
    required this.size,
    this.onTap,
  });

  @override
  State<_GlassIconButton> createState() => _GlassIconButtonState();
}

class _GlassIconButtonState extends State<_GlassIconButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.88).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) {
        _ctrl.reverse();
        widget.onTap?.call();
      },
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(
        scale: _scaleAnim,
        child: Padding(
          padding: const EdgeInsets.only(right: 8, bottom: 4),
          child: Icon(
            widget.icon,
            color: widget.color,
            size: widget.size,
          ),
        ),
      ),
    );
  }
}
