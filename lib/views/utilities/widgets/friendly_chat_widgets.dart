import 'package:flutter/material.dart';

import '../../../core/sl_theme.dart';
import '../../../utils/services/l10n_service.dart';
import '../../../widgets/sl_detail_widgets.dart';
import '../../../widgets/sl_settings_kit.dart';
import '../../../widgets/utility_vip_badge.dart';

/// Bảng màu của góc tâm sự: hồng ấm, chữ trắng trên nền hồng đạt tương phản ≥ 4,5:1.
abstract final class FriendlyChatPalette {
  static const deep = SLSettingsColors.accentStrong;
  static const rose = SLSettingsColors.rose;
  static const online = SLSettingsColors.success;

  static const LinearGradient userBubble = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFC63D5E), Color(0xFFA82B4A)],
  );

  static const LinearGradient avatar = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF08AA3), Color(0xFFC63D5E)],
  );

  static Color tint(BuildContext context) => SLDetailStyle.isDark(context)
      ? Color.alphaBlend(
          rose.withValues(alpha: 0.18),
          SLSettingsColors.darkSurface,
        )
      : SLSettingsColors.accentSoft;

  static LinearGradient backdrop(BuildContext context) {
    final base = SLDetailStyle.background(context);
    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Color.alphaBlend(
          rose.withValues(alpha: SLDetailStyle.isDark(context) ? 0.10 : 0.07),
          base,
        ),
        base,
      ],
    );
  }

  static List<BoxShadow> softShadow(BuildContext context) => [
    BoxShadow(
      color: Colors.black.withValues(
        alpha: SLDetailStyle.isDark(context) ? 0.18 : 0.035,
      ),
      blurRadius: 10,
      offset: const Offset(0, 2),
    ),
  ];
}

/// Ảnh đại diện trái tim của người bạn tâm sự (trang trí, không đọc cho trình đọc màn hình).
class FriendlyChatAvatar extends StatelessWidget {
  const FriendlyChatAvatar({super.key, this.size = 30});

  final double size;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: FriendlyChatPalette.avatar,
        boxShadow: [
          BoxShadow(
            color: FriendlyChatPalette.rose.withValues(alpha: 0.28),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Icon(
        Icons.favorite_rounded,
        size: size * 0.5,
        color: Colors.white,
      ),
    ),
  );
}

/// Tiêu đề thanh trên: ảnh đại diện, tên và trạng thái (đang lắng nghe / đang trả lời).
class FriendlyChatHeaderTitle extends StatelessWidget {
  const FriendlyChatHeaderTitle({
    super.key,
    required this.title,
    required this.status,
    this.busy = false,
  });

  final String title;
  final String status;
  final bool busy;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      const FriendlyChatAvatar(size: 38),
      const SizedBox(width: 10),
      Flexible(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: SLTheme.quicksand(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: SLDetailStyle.text(context),
              ),
            ),
            const SizedBox(height: 1),
            Row(
              children: [
                if (!busy) ...[
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: FriendlyChatPalette.online,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                ],
                Flexible(
                  child: Text(
                    status,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: SLTheme.quicksand(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: SLDetailStyle.muted(context),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ],
  );
}

class FriendlyChatLoading extends StatelessWidget {
  const FriendlyChatLoading({super.key});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const FriendlyChatAvatar(size: 64),
          const SizedBox(height: 16),
          Text(
            context.tr('detail_chat_loading'),
            textAlign: TextAlign.center,
            style: SLTheme.quicksand(
              fontSize: 13,
              height: 1.5,
              color: SLDetailStyle.muted(context),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: SLDetailStyle.primary,
            ),
          ),
        ],
      ),
    ),
  );
}

/// Lời mời nâng cấp cho tài khoản thường: Chat thân thiện là tiện ích VIP.
/// `onUpgrade` null (bản không bán gói) thì chỉ hiện lời giải thích.
class FriendlyChatProGate extends StatelessWidget {
  const FriendlyChatProGate({super.key, this.onUpgrade});

  final VoidCallback? onUpgrade;

  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              FriendlyChatAvatar(size: 88),
              Positioned(bottom: -10, child: UtilityVipBadge()),
            ],
          ),
          const SizedBox(height: 28),
          Text(
            context.tr('friendly_chat_pro_only'),
            textAlign: TextAlign.center,
            style: SLTheme.quicksand(
              fontSize: 19,
              height: 1.35,
              fontWeight: FontWeight.w800,
              color: SLDetailStyle.text(context),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            context.tr('friendly_chat_pro_desc'),
            textAlign: TextAlign.center,
            style: SLTheme.quicksand(
              fontSize: 14,
              height: 1.55,
              fontWeight: FontWeight.w500,
              color: SLDetailStyle.muted(context),
            ),
          ),
          if (onUpgrade != null) ...[
            const SizedBox(height: 24),
            FilledButton.icon(
              key: const ValueKey('friendly-chat-upgrade'),
              onPressed: onUpgrade,
              style: FilledButton.styleFrom(
                minimumSize: const Size(220, 52),
                backgroundColor: FriendlyChatPalette.deep,
                foregroundColor: Colors.white,
                shape: const StadiumBorder(),
                textStyle: SLTheme.quicksand(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              icon: const Icon(Icons.workspace_premium_rounded, size: 20),
              label: Text(context.tr('p6_upgrade_vip')),
            ),
          ],
        ],
      ),
    ),
  );
}

/// Thẻ quy tắc riêng tư gọn: chạm để mở 3 quy tắc và nút xóa cuộc trò chuyện.
class FriendlyChatPrivacyBanner extends StatefulWidget {
  const FriendlyChatPrivacyBanner({super.key, this.onClear});

  final VoidCallback? onClear;

  static const List<(IconData, String)> rules = [
    (Icons.password_rounded, 'friendly_chat_rule_secrets'),
    (Icons.history_rounded, 'friendly_chat_rule_memory'),
    (Icons.health_and_safety_outlined, 'friendly_chat_rule_safety'),
  ];

  @override
  State<FriendlyChatPrivacyBanner> createState() =>
      _FriendlyChatPrivacyBannerState();
}

class _FriendlyChatPrivacyBannerState extends State<FriendlyChatPrivacyBanner> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final muted = SLDetailStyle.muted(context);
    final ruleStyle = SLTheme.quicksand(
      fontSize: 12.5,
      height: 1.5,
      color: muted,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: SLDetailStyle.card(context),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: SLDetailStyle.outline(context)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              expanded: _open,
              child: InkWell(
                onTap: () => setState(() => _open = !_open),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: FriendlyChatPalette.tint(context),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.lock_rounded,
                            size: 16,
                            color: FriendlyChatPalette.deep,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                context.tr('friendly_chat_privacy_title'),
                                style: SLTheme.quicksand(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w800,
                                  color: SLDetailStyle.text(context),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                context.tr('friendly_chat_privacy_desc'),
                                maxLines: _open ? null : 2,
                                overflow: _open ? null : TextOverflow.ellipsis,
                                style: SLTheme.quicksand(
                                  fontSize: 12,
                                  height: 1.4,
                                  color: muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        AnimatedRotation(
                          turns: _open ? 0.5 : 0,
                          duration: const Duration(milliseconds: 200),
                          child: Icon(Icons.expand_more_rounded, color: muted),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: !_open
                  ? const SizedBox(width: double.infinity)
                  : Padding(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Divider(
                            height: 1,
                            color: SLDetailStyle.outline(context),
                          ),
                          const SizedBox(height: 10),
                          for (final (icon, key) in FriendlyChatPrivacyBanner.rules)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    icon,
                                    size: 18,
                                    color: FriendlyChatPalette.deep,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(context.tr(key), style: ruleStyle),
                                  ),
                                ],
                              ),
                            ),
                          Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: TextButton.icon(
                              key: const ValueKey('friendly-chat-clear-history'),
                              onPressed: widget.onClear,
                              style: TextButton.styleFrom(
                                minimumSize: const Size(48, 48),
                                foregroundColor: FriendlyChatPalette.deep,
                              ),
                              icon: const Icon(
                                Icons.delete_outline_rounded,
                                size: 18,
                              ),
                              label: Text(context.tr('detail_chat_reset')),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class FriendlyChatTextBubble extends StatelessWidget {
  const FriendlyChatTextBubble({
    super.key,
    required this.text,
    required this.isUser,
    this.onLongPress,
  });

  final String text;
  final bool isUser;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onLongPress: onLongPress,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isUser ? null : SLDetailStyle.card(context),
        gradient: isUser ? FriendlyChatPalette.userBubble : null,
        borderRadius: BorderRadiusDirectional.only(
          topStart: const Radius.circular(22),
          topEnd: const Radius.circular(22),
          bottomStart: Radius.circular(isUser ? 22 : 6),
          bottomEnd: Radius.circular(isUser ? 6 : 22),
        ),
        border: isUser
            ? null
            : Border.all(
                color: SLDetailStyle.outline(context).withValues(alpha: 0.7),
              ),
        boxShadow: FriendlyChatPalette.softShadow(context),
      ),
      child: Text(
        text,
        style: SLTheme.quicksand(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          height: 1.5,
          color: isUser ? Colors.white : SLDetailStyle.text(context),
        ),
      ),
    ),
  );
}

/// Bong bóng "đang soạn" với ba chấm nhảy; trình đọc màn hình đọc nhãn chờ trả lời.
class FriendlyChatTypingBubble extends StatefulWidget {
  const FriendlyChatTypingBubble({super.key});

  @override
  State<FriendlyChatTypingBubble> createState() =>
      _FriendlyChatTypingBubbleState();
}

class _FriendlyChatTypingBubbleState extends State<FriendlyChatTypingBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Semantics(
      liveRegion: true,
      label: context.tr('ai_task_waiting_reply'),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const FriendlyChatAvatar(),
          const SizedBox(width: 8),
          ExcludeSemantics(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              decoration: BoxDecoration(
                color: SLDetailStyle.card(context),
                borderRadius: const BorderRadiusDirectional.only(
                  topStart: Radius.circular(22),
                  topEnd: Radius.circular(22),
                  bottomStart: Radius.circular(6),
                  bottomEnd: Radius.circular(22),
                ),
                border: Border.all(
                  color: SLDetailStyle.outline(context).withValues(alpha: 0.7),
                ),
                boxShadow: FriendlyChatPalette.softShadow(context),
              ),
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) => Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var index = 0; index < 3; index++)
                      Padding(
                        padding: EdgeInsetsDirectional.only(
                          start: index == 0 ? 0 : 5,
                        ),
                        child: Transform.translate(
                          offset: Offset(0, _bounce(index)),
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: FriendlyChatPalette.rose.withValues(
                                alpha: 0.55 + 0.45 * (-_bounce(index) / 4),
                              ),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );

  // Mỗi chấm nảy lệch pha nhau, biên độ tối đa 4 px.
  double _bounce(int index) {
    final phase = (_controller.value * 3 - index) % 3;
    if (phase > 1) return 0;
    return -4 * (1 - (2 * phase - 1).abs());
  }
}

/// Gợi ý câu mở đầu để người dùng bắt đầu tâm sự chỉ với một chạm.
class FriendlyChatStarters extends StatelessWidget {
  const FriendlyChatStarters({super.key, required this.onSelected});

  static const List<(String, IconData)> starters = [
    ('friendly_chat_starter_sad', Icons.cloud_outlined),
    ('friendly_chat_starter_partner', Icons.favorite_border_rounded),
    ('friendly_chat_starter_stress', Icons.spa_outlined),
    ('friendly_chat_starter_happy', Icons.wb_sunny_outlined),
  ];

  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.only(start: 38, bottom: 12),
    child: LayoutBuilder(
      builder: (context, constraints) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr('friendly_chat_starter_label'),
            style: SLTheme.quicksand(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: SLDetailStyle.muted(context),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (key, icon) in starters)
                ConstrainedBox(
                  // Nhãn dài hoặc cỡ chữ lớn thì xuống dòng, không tràn màn hẹp.
                  constraints: BoxConstraints(
                    maxWidth: constraints.maxWidth,
                    minHeight: 48,
                  ),
                  child: Material(
                    key: ValueKey('friendly-chat-starter-$key'),
                    color: FriendlyChatPalette.tint(context),
                    shape: const StadiumBorder(),
                    child: InkWell(
                      customBorder: const StadiumBorder(),
                      onTap: () => onSelected(context.tr(key)),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              icon,
                              size: 18,
                              color: FriendlyChatPalette.deep,
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                context.tr(key),
                                style: SLTheme.quicksand(
                                  fontSize: 13.5,
                                  height: 1.35,
                                  fontWeight: FontWeight.w700,
                                  color: SLDetailStyle.text(context),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    ),
  );
}

class FriendlyChatComposer extends StatelessWidget {
  const FriendlyChatComposer({
    super.key,
    required this.controller,
    required this.canSend,
    required this.onSend,
  });

  static const int maxLength = 500;
  // Chỉ hiện bộ đếm khi gần chạm giới hạn để ô nhập gọn.
  static const int counterFrom = 400;

  final TextEditingController controller;
  final bool canSend;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: SLDetailStyle.card(context),
      border: Border(top: BorderSide(color: SLDetailStyle.outline(context))),
    ),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              minLines: 1,
              maxLines: 4,
              maxLength: maxLength,
              buildCounter:
                  (
                    context, {
                    required currentLength,
                    required isFocused,
                    required maxLength,
                  }) => currentLength < counterFrom
                  ? null
                  : Text(
                      L10nService().format('friendly_chat_counter', {
                        'count': currentLength,
                        'max': maxLength ?? FriendlyChatComposer.maxLength,
                      }),
                      style: TextStyle(
                        color: SLDetailStyle.muted(context),
                        fontSize: 11,
                      ),
                    ),
              textInputAction: TextInputAction.newline,
              style: SLTheme.quicksand(
                fontSize: 15,
                height: 1.45,
                fontWeight: FontWeight.w500,
                color: SLDetailStyle.text(context),
              ),
              decoration: InputDecoration(
                hintText: context.tr('friendly_chat_confide_hint'),
                hintStyle: SLTheme.quicksand(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: SLDetailStyle.muted(context),
                ),
                filled: true,
                fillColor: SLDetailStyle.background(context),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(color: SLDetailStyle.outline(context)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(
                    color: FriendlyChatPalette.deep,
                    width: 1.5,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 13,
                ),
              ),
              onSubmitted: (_) => onSend(),
            ),
          ),
          const SizedBox(width: 8),
          DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: canSend ? FriendlyChatPalette.userBubble : null,
              color: canSend ? null : SLDetailStyle.outline(context),
            ),
            child: IconButton(
              onPressed: canSend ? onSend : null,
              tooltip: context.tr('detail_chat_send'),
              style: IconButton.styleFrom(
                minimumSize: const Size(48, 48),
                foregroundColor: Colors.white,
                disabledForegroundColor: SLDetailStyle.muted(context),
              ),
              icon: const Icon(Icons.send_rounded, size: 22),
            ),
          ),
        ],
      ),
    ),
  );
}
